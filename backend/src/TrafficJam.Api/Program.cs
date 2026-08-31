using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using StackExchange.Redis;
using TrafficJam.Api.Data;
using TrafficJam.Api.Infrastructure;
using TrafficJam.Api.Modules.Auth;
using TrafficJam.Api.Modules.Users;
using TrafficJam.Api.Modules.Notifications;
using TrafficJam.Api.Modules.Consultation;
using TrafficJam.Api.Modules.Astro;

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

builder.Services.AddSingleton<IConnectionMultiplexer>(serviceProvider =>
{
    var connectionString = serviceProvider.GetRequiredService<IConfiguration>().GetConnectionString("Redis")
        ?? throw new InvalidOperationException("ConnectionStrings:Redis is not configured.");
    return ConnectionMultiplexer.Connect(connectionString);
});

builder.Services.AddHealthChecks()
    .AddCheck<MySqlHealthCheck>("mysql")
    .AddCheck<RedisHealthCheck>("redis");

// Dev-only, wide-open CORS so `flutter run -d chrome` (a different origin —
// localhost:PORT — than this API) can call it. Native iOS/Android builds
// don't go through a browser and aren't affected by CORS at all. Production
// needs a real policy scoped to the deployed app's actual origin(s).
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddCors(options =>
    {
        options.AddPolicy("DevWeb", policy => policy
            .AllowAnyOrigin()
            .AllowAnyMethod()
            .AllowAnyHeader());
    });
}

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
// real Firebase phone-OTP, used until a real Firebase project exists. Refuse
// to even start if it's ever true outside Development, so it can never ship.
if (builder.Configuration.GetValue<bool>("Auth:DevModeEnabled") && !builder.Environment.IsDevelopment())
{
    throw new InvalidOperationException(
        "Auth:DevModeEnabled must never be true outside the Development environment — " +
        "it bypasses real phone verification entirely.");
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
builder.Services.AddAuthorization();

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

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseCors("DevWeb");
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

app.UseAuthentication();
app.UseAuthorization();

app.MapHealthChecks("/health");
app.MapAuthEndpoints();
app.MapUserEndpoints();
app.MapPlacesEndpoints();
app.MapNotificationEndpoints();
app.MapConsultationEndpoints();
app.MapSubscriptionEndpoints();
app.MapPanchangEndpoints();
app.MapTransitEndpoints();
app.MapSignalEndpoints();
app.MapChartEndpoints();

app.Run();

// Required for WebApplicationFactory-based integration tests.
public partial class Program;
