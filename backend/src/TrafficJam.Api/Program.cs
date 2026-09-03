using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using TrafficJam.Api.Data;
using TrafficJam.Api.Infrastructure;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Users;
using TrafficJam.Api.Modules.Notifications;
using TrafficJam.Api.Modules.Consultation;
using TrafficJam.Api.Modules.Astro;
using TrafficJam.Api.Modules.Remedies;
using TrafficJam.Api.Modules.Admin;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();

builder.Services.AddSingleton<IEncryptionService, AesEncryptionService>();

// Resolved lazily from the DI-provided IConfiguration (not builder.Configuration
// read here at top level) so that config overrides applied by test hosts —
// WebApplicationFactory's ConfigureAppConfiguration only composes into the
// final IConfiguration during builder.Build(), not into this early reference —
// are actually picked up. Reading builder.Configuration directly at this point
// in the file previously meant TrafficJamApiFactory's per-test-run database
// name override was silently ignored and every test run hit the real dev
// MySQL database instead of its own trafficjam_test_<guid> schema.
builder.Services.AddDbContext<AppDbContext>((serviceProvider, options) =>
{
    var connectionString = serviceProvider.GetRequiredService<IConfiguration>().GetConnectionString("MySql")
        ?? throw new InvalidOperationException("ConnectionStrings:MySql is not configured.");
    options.UseMySql(connectionString, ServerVersion.AutoDetect(connectionString));
});

builder.Services.AddHealthChecks()
    .AddCheck<MySqlHealthCheck>("mysql");

// Api:PublicBaseUrl is this deployment's single source of truth for "where
// does this API actually live" — e.g. "https://trafficjam-live.kaizeninfotech.com/api/api/v1"
// in production, "http://localhost:5227/api/v1" in Development (see each
// appsettings.*.json). The CORS origin and JWT issuer below are both derived
// from it rather than configured separately, so there's exactly one value to
// update if the domain/proxy setup ever changes — previously Cors:AllowedOrigins
// and Jwt:Issuer were separate hand-typed config entries that had to be kept
// in sync with this URL (and with the copies hardcoded in frontend/lib/services/
// api_config.dart and admin/src/lib/api.ts) by hand.
var publicBaseUrl = builder.Configuration["Api:PublicBaseUrl"];
var publicOrigin = publicBaseUrl is null ? null : new Uri(publicBaseUrl).GetLeftPart(UriPartial.Authority);

// Also overrides Jwt:Issuer in-place (rather than computing it separately
// below) so JwtService — which reads Jwt:Issuer independently to sign tokens
// — and this file's own ValidIssuer (used to validate them) can never drift
// apart by reading two different derivations of the same URL.
if (publicBaseUrl is not null)
{
    builder.Configuration["Jwt:Issuer"] = new Uri(publicBaseUrl).Host;
}

// Dev: wide-open CORS so `flutter run -d chrome` (a different origin —
// localhost:PORT — than this API) can call it. Native iOS/Android builds
// don't go through a browser and aren't affected by CORS at all, so this
// only matters for the admin panel and any Flutter web build.
//
// Production: scoped to publicOrigin (the deployed admin panel shares this
// API's own domain via the reverse proxy). Unset means no browser origin is
// allowed — a safe default, not a startup failure, since native clients are
// unaffected.
var corsAllowedOrigins = publicOrigin is null ? Array.Empty<string>() : [publicOrigin];
builder.Services.AddCors(options =>
{
    options.AddPolicy("Web", policy =>
    {
        if (builder.Environment.IsDevelopment())
        {
            policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();
        }
        else
        {
            policy.WithOrigins(corsAllowedOrigins).AllowAnyMethod().AllowAnyHeader();
        }
    });
});

// ── Auth ─────────────────────────────────────────────────────────────────
// Firebase Admin SDK: only initialize against a real service account if one
// is configured. Without it, FirebaseTokenVerifier throws a clear error at
// call time rather than the app silently accepting unverified tokens.
var firebaseCredentialsPath = builder.Configuration["Firebase:CredentialsPath"];
if (!string.IsNullOrWhiteSpace(firebaseCredentialsPath) && FirebaseAdmin.FirebaseApp.DefaultInstance is null)
{
    FirebaseAdmin.FirebaseApp.Create(new FirebaseAdmin.AppOptions
    {
        Credential = Google.Apis.Auth.OAuth2.GoogleCredential.FromFile(firebaseCredentialsPath),
    });
}

// Auth:DevModeEnabled powers POST /auth/dev-login — a fixed-OTP stand-in for
// real Firebase phone-OTP, used until a real Firebase project exists.
// Deliberately no longer a hard startup failure outside Development — this
// deployment intentionally ships it on (see appsettings.Production.json)
// since there's no real Firebase project yet. Logged loudly on every
// startup instead, so it's never silently forgotten.
if (builder.Configuration.GetValue<bool>("Auth:DevModeEnabled") && !builder.Environment.IsDevelopment())
{
    Console.Error.WriteLine(
        "WARNING: Auth:DevModeEnabled=true outside Development — POST /auth/dev-login accepts " +
        "OTP '123456' for ANY phone number. This must not stay on once a real Firebase project is wired up.");
}

builder.Services.AddSingleton<IFirebaseTokenVerifier, FirebaseTokenVerifier>();
builder.Services.AddSingleton<IJwtService, JwtService>();
builder.Services.AddMemoryCache();
builder.Services.AddSingleton<OtpResendRateLimiter>();

var jwtSigningKey = builder.Configuration["Jwt:SigningKey"]
    ?? throw new InvalidOperationException("Jwt:SigningKey is not configured.");
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "trafficjam.life";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "trafficjam.app";

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(Convert.FromBase64String(jwtSigningKey)),
            ClockSkew = TimeSpan.FromSeconds(30),
        };
    });
builder.Services.AddAuthorization(options =>
{
    // Admin-panel endpoints require this claim; a regular consumer JWT
    // (see JwtService.IssueAccessToken) never carries it, and an admin JWT
    // (IssueAdminAccessToken) always does — the two token kinds are mutually
    // exclusive by construction, not just by convention.
    options.AddPolicy("AdminOnly", policy => policy.RequireClaim(System.Security.Claims.ClaimTypes.Role, "admin"));
});

// ── Users ────────────────────────────────────────────────────────────────
builder.Services.AddHttpClient<IPlacesClient, GooglePlacesClient>();

// ── Consultation ─────────────────────────────────────────────────────────
// Swap for a real Razorpay/Stripe-backed implementation once credentials exist.
builder.Services.AddSingleton<IPaymentGateway, NotConfiguredPaymentGateway>();

// ── Astro ────────────────────────────────────────────────────────────────
// Built on Astronomy Engine (MIT), not Swiss Ephemeris — see backend/README.md.
builder.Services.AddSingleton<IAyanamsaService, LahiriAyanamsaService>();
builder.Services.AddSingleton<IAscendantCalculator, AscendantCalculator>();
builder.Services.AddSingleton<IAstroEngineService, AstroEngineService>();
builder.Services.AddSingleton<IDashaService, VimshottariDashaService>();
builder.Services.AddSingleton<IPanchangService, PanchangService>();
builder.Services.AddSingleton<ITransitService, TransitService>();
builder.Services.AddSingleton<ITrafficSignalService, TrafficSignalService>();
builder.Services.AddSingleton<IPlacidusHouseCalculator, PlacidusHouseCalculator>();
builder.Services.AddSingleton<IKpService, KpService>();
builder.Services.AddSingleton<IDoshaService, DoshaService>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}
else
{
    // Never leak stack traces / internals to a real client — generic 500 only.
    app.UseExceptionHandler(handler => handler.Run(async context =>
    {
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsJsonAsync(new
        {
            error = new { code = "INTERNAL_ERROR", message = "Something went wrong." },
        });
    }));
}

app.UseCors("Web");
app.UseAuthentication();
app.UseAuthorization();

// Unprefixed — infra health checks (uptime monitors, load balancers) expect
// this at a fixed conventional path, not versioned alongside the API itself.
app.MapHealthChecks("/health");

// Everything else lives under /api/v1. The production domain's reverse
// proxy adds its own "/api" on top of this, so the real external path ends
// up "/api/api/v1/..." — see frontend/lib/services/api_config.dart and
// admin/src/lib/api.ts, which both call this same "/api/v1" prefix.
//
// Also mapped a second time at the old root paths (MapEverythingOn below) —
// every integration test (TrafficJamApiFactory) and, for now, the local
// dev workflow still call unprefixed paths like "/chart" directly. Rather
// than rewrite ~190 call sites across the test suite, both prefixes serve
// the exact same handlers; there's no behavioral difference between them.
// Drop the root mount once tests/tooling are updated to call /api/v1 too.
MapEverythingOn(app.MapGroup("/api/v1"));
MapEverythingOn(app);

app.Run();

static void MapEverythingOn(IEndpointRouteBuilder routes)
{
    routes.MapAuthEndpoints();
    routes.MapUserEndpoints();
    routes.MapPlacesEndpoints();
    routes.MapNotificationEndpoints();
    routes.MapConsultationEndpoints();
    routes.MapSubscriptionEndpoints();
    routes.MapPanchangEndpoints();
    routes.MapTransitEndpoints();
    routes.MapSignalEndpoints();
    routes.MapChartEndpoints();
    routes.MapRemedyEndpoints();
    routes.MapDoshaEndpoints();
    routes.MapAdminAuthEndpoints();
    routes.MapAdminDashboardEndpoints();
    routes.MapAdminUserEndpoints();
    routes.MapAdminQuestionEndpoints();
    routes.MapAdminAppointmentEndpoints();
    routes.MapAdminRemedyEndpoints();
    routes.MapAdminPlanEndpoints();
}

// Required for WebApplicationFactory-based integration tests.
public partial class Program;
