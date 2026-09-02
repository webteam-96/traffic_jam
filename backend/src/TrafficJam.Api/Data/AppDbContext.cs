using System.Globalization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;
using TrafficJam.Api.Modules.Remedies;

namespace TrafficJam.Api.Data;

/// <summary>
/// The single EF Core context for the modular monolith. Entity sets are added
/// module by module as each is built — see TASKLIST.md Phase 1 for the order.
/// </summary>
public class AppDbContext(DbContextOptions<AppDbContext> options, IEncryptionService encryption)
    : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<BirthData> BirthData => Set<BirthData>();
    public DbSet<Chart> Charts => Set<Chart>();
    public DbSet<Dasha> Dashas => Set<Dasha>();
    public DbSet<DailySignal> DailySignals => Set<DailySignal>();
    public DbSet<PanchangCache> PanchangCache => Set<PanchangCache>();
    public DbSet<Question> Questions => Set<Question>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<Subscription> Subscriptions => Set<Subscription>();
    public DbSet<NotificationPrefs> NotificationPrefs => Set<NotificationPrefs>();
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<RemedyContent> RemedyContent => Set<RemedyContent>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<OnboardingDraft> OnboardingDrafts => Set<OnboardingDraft>();
    public DbSet<Entities.Notification> Notifications => Set<Entities.Notification>();
    public DbSet<Appointment> Appointments => Set<Appointment>();
    public DbSet<AdminUser> AdminUsers => Set<AdminUser>();
    public DbSet<ConsultPlanRow> ConsultPlanRows => Set<ConsultPlanRow>();
    public DbSet<SubscriptionPlanRow> SubscriptionPlanRows => Set<SubscriptionPlanRow>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var encryptedString = new ValueConverter<string, string>(
            v => encryption.Encrypt(v),
            v => encryption.Decrypt(v));

        var encryptedDateOnly = new ValueConverter<DateOnly, string>(
            v => encryption.Encrypt(v.ToString("O", CultureInfo.InvariantCulture)),
            v => DateOnly.ParseExact(encryption.Decrypt(v), "O", CultureInfo.InvariantCulture));

        var encryptedNullableTimeOnly = new ValueConverter<TimeOnly?, string?>(
            v => v == null ? null : encryption.Encrypt(v.Value.ToString("O", CultureInfo.InvariantCulture)),
            v => v == null ? null : TimeOnly.ParseExact(encryption.Decrypt(v), "O", CultureInfo.InvariantCulture));

        var encryptedDouble = new ValueConverter<double, string>(
            v => encryption.Encrypt(v.ToString("R", CultureInfo.InvariantCulture)),
            v => double.Parse(encryption.Decrypt(v), CultureInfo.InvariantCulture));

        var encryptedNullableString = new ValueConverter<string?, string?>(
            v => v == null ? null : encryption.Encrypt(v),
            v => v == null ? null : encryption.Decrypt(v));

        var encryptedNullableDateOnly = new ValueConverter<DateOnly?, string?>(
            v => v == null ? null : encryption.Encrypt(v.Value.ToString("O", CultureInfo.InvariantCulture)),
            v => v == null ? null : DateOnly.ParseExact(encryption.Decrypt(v), "O", CultureInfo.InvariantCulture));

        var encryptedNullableDouble = new ValueConverter<double?, string?>(
            v => v == null ? null : encryption.Encrypt(v.Value.ToString("R", CultureInfo.InvariantCulture)),
            v => v == null ? null : double.Parse(encryption.Decrypt(v), CultureInfo.InvariantCulture));

        modelBuilder.Entity<User>(e =>
        {
            e.HasIndex(u => u.FirebaseUid).IsUnique();
            e.HasIndex(u => u.PhoneHash).IsUnique();
        });

        modelBuilder.Entity<BirthData>(e =>
        {
            e.HasKey(b => b.UserId);
            e.Property(b => b.Dob).HasConversion(encryptedDateOnly);
            e.Property(b => b.Tob).HasConversion(encryptedNullableTimeOnly);
            e.Property(b => b.Place).HasConversion(encryptedString);
            e.Property(b => b.Lat).HasConversion(encryptedDouble);
            e.Property(b => b.Lng).HasConversion(encryptedDouble);
            e.HasOne(b => b.User).WithOne(u => u.BirthData)
                .HasForeignKey<BirthData>(b => b.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Chart>(e =>
        {
            e.HasKey(c => c.UserId);
            e.HasOne(c => c.User).WithOne(u => u.Chart)
                .HasForeignKey<Chart>(c => c.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Dasha>(e =>
        {
            e.HasKey(d => d.UserId);
            e.HasOne(d => d.User).WithOne(u => u.Dasha)
                .HasForeignKey<Dasha>(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<DailySignal>(e =>
        {
            e.HasKey(s => new { s.UserId, s.Date });
            e.HasOne(s => s.User).WithMany(u => u.DailySignals)
                .HasForeignKey(s => s.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<PanchangCache>(e =>
        {
            e.HasKey(p => new { p.City, p.Date });
        });

        modelBuilder.Entity<Question>(e =>
        {
            e.HasOne(q => q.User).WithMany(u => u.Questions)
                .HasForeignKey(q => q.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            e.Property(q => q.Status).HasConversion<string>();
        });

        modelBuilder.Entity<Message>(e =>
        {
            e.HasOne(m => m.Question).WithMany(q => q.Messages)
                .HasForeignKey(m => m.QuestionId)
                .OnDelete(DeleteBehavior.Cascade);
            e.Property(m => m.Sender).HasConversion<string>();
        });

        modelBuilder.Entity<Subscription>(e =>
        {
            e.HasKey(s => s.UserId);
            e.Property(s => s.Tier).HasConversion<string>();
            e.Property(s => s.Cycle).HasConversion<string>();
            e.HasOne(s => s.User).WithOne(u => u.Subscription)
                .HasForeignKey<Subscription>(s => s.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<NotificationPrefs>(e =>
        {
            e.HasKey(n => n.UserId);
            e.HasOne(n => n.User).WithOne(u => u.NotificationPrefs)
                .HasForeignKey<NotificationPrefs>(n => n.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Device>(e =>
        {
            e.HasOne(d => d.User).WithMany(u => u.Devices)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<RefreshToken>(e =>
        {
            e.HasIndex(r => r.TokenHash).IsUnique();
            e.HasOne(r => r.User).WithMany(u => u.RefreshTokens)
                .HasForeignKey(r => r.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<OnboardingDraft>(e =>
        {
            e.HasKey(d => d.UserId);
            e.Property(d => d.Dob).HasConversion(encryptedNullableDateOnly);
            e.Property(d => d.Tob).HasConversion(encryptedNullableTimeOnly);
            e.Property(d => d.Place).HasConversion(encryptedNullableString);
            e.Property(d => d.Lat).HasConversion(encryptedNullableDouble);
            e.Property(d => d.Lng).HasConversion(encryptedNullableDouble);
            e.HasOne(d => d.User).WithOne(u => u.OnboardingDraft)
                .HasForeignKey<OnboardingDraft>(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Entities.Notification>(e =>
        {
            e.Property(n => n.Source).HasConversion<string>();
            e.HasOne(n => n.User).WithMany(u => u.Notifications)
                .HasForeignKey(n => n.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Appointment>(e =>
        {
            e.Property(a => a.Status).HasConversion<string>();
            e.HasOne(a => a.User).WithMany(u => u.Appointments)
                .HasForeignKey(a => a.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<RemedyContent>().HasData(RemedySeedData.All);

        modelBuilder.Entity<AdminUser>(e =>
        {
            e.HasIndex(a => a.Email).IsUnique();
        });

        modelBuilder.Entity<ConsultPlanRow>().HasData(
            new ConsultPlanRow { Id = "standard", Name = "Standard", PriceRupees = 99, SlaHours = 4 },
            new ConsultPlanRow { Id = "priority", Name = "Priority", PriceRupees = 299, SlaHours = 1 });

        modelBuilder.Entity<SubscriptionPlanRow>().HasData(
            new SubscriptionPlanRow
            {
                Id = "free", Name = "Free", Tier = "Free", Cycle = "None", PriceRupees = 0,
                FeaturesJson = "[\"Daily Traffic Signal\",\"Basic Panchang\"]",
            },
            new SubscriptionPlanRow
            {
                Id = "saga_plus_monthly", Name = "Saga+ Monthly", Tier = "SagaPlus", Cycle = "Monthly", PriceRupees = 299,
                FeaturesJson = "[\"Deep-space transits\",\"Unlimited Panchang\",\"Priority Ask Jay\"]",
            },
            new SubscriptionPlanRow
            {
                Id = "saga_plus_annual", Name = "Saga+ Annual", Tier = "SagaPlus", Cycle = "Yearly", PriceRupees = 2999,
                FeaturesJson = "[\"Deep-space transits\",\"Unlimited Panchang\",\"Priority Ask Jay\",\"2 months free\"]",
            });

        // Dev-only bootstrap login — email admin@trafficjam.life, password
        // "TrafficJam2026!" (see backend/README.md). Change or remove this
        // account before any real deployment; it exists only so the admin
        // panel has *something* to log in with out of the box.
        modelBuilder.Entity<AdminUser>().HasData(new AdminUser
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000001"),
            Email = "admin@trafficjam.life",
            Name = "Traffic Jam Admin",
            PasswordHash = "210000.sBvGgNG4BNIZo1TOLt0P1w==.D8IqhFYqaSICrUItAR/LrOUjll5Rjayp7mZtdppxldE=",
            CreatedAt = new DateTime(2026, 9, 1, 0, 0, 0, DateTimeKind.Utc),
        });

        // Dev-login demo accounts — sign in with these numbers via POST
        // /auth/dev-login (OTP "123456", requires Auth:DevModeEnabled=true;
        // see appsettings.Production.json) until a real Firebase project
        // exists. Not encrypted (PhoneHash is a one-way SHA-256, FirebaseUid
        // is a plain synthetic string — see PhoneHasher/dev-login), so this
        // is safe to seed via migration regardless of environment. No
        // BirthData is seeded; sign in and complete onboarding to fill it in.
        // Remove before any real deployment, same as the admin seed above.
        modelBuilder.Entity<User>().HasData(
            new User
            {
                Id = Guid.Parse("10000000-0000-0000-0000-000000000001"),
                PhoneHash = "2ec2c1d2994802d3bba5aa6e697c7d132bcdf9a5c4c5af59a5a9c5e428fedf1",
                FirebaseUid = "dev:+919999900001",
                Name = "Demo (Free)",
                CreatedAt = new DateTime(2026, 9, 2, 0, 0, 0, DateTimeKind.Utc),
            },
            new User
            {
                Id = Guid.Parse("10000000-0000-0000-0000-000000000002"),
                PhoneHash = "6a6cbd5fd6f9a693465f6dc2f36698de2502492eec8c4c739cc214b82c02dfe",
                FirebaseUid = "dev:+919999900002",
                Name = "Demo (Saga+ Monthly)",
                CreatedAt = new DateTime(2026, 9, 2, 0, 0, 0, DateTimeKind.Utc),
            },
            new User
            {
                Id = Guid.Parse("10000000-0000-0000-0000-000000000003"),
                PhoneHash = "6acfb35b135a02360298fcb372d6672718fb65c1f36cfcb396012deaea2a89a",
                FirebaseUid = "dev:+919999900003",
                Name = "Demo (Saga+ Annual)",
                CreatedAt = new DateTime(2026, 9, 2, 0, 0, 0, DateTimeKind.Utc),
            });

        // Free tier needs no Subscription row at all (see SubscriptionEndpoints'
        // fallback) — only the two paid demo accounts get one. RenewsAt is set
        // far out so the demo doesn't quietly fall back to Free mid-showcase.
        modelBuilder.Entity<Subscription>().HasData(
            new Subscription
            {
                UserId = Guid.Parse("10000000-0000-0000-0000-000000000002"),
                Tier = SubscriptionTier.SagaPlus,
                Cycle = BillingCycle.Monthly,
                RenewsAt = new DateTime(2030, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                GatewayRef = "demo-seed",
            },
            new Subscription
            {
                UserId = Guid.Parse("10000000-0000-0000-0000-000000000003"),
                Tier = SubscriptionTier.SagaPlus,
                Cycle = BillingCycle.Yearly,
                RenewsAt = new DateTime(2030, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                GatewayRef = "demo-seed",
            });

        // Every DateTime this app stores is UTC by convention (DateTime.UtcNow,
        // AstroTime.ToUtcDateTime(), etc.) — but MySqlConnector reads `datetime`
        // columns back as DateTimeKind.Unspecified, not Utc, since MySQL's
        // `datetime` type carries no timezone info of its own. That silently
        // strips the "this is UTC" tag on every read, which then makes
        // System.Text.Json omit the "Z" suffix when serializing it — and a
        // client that only converts UTC-marked timestamps to local time (as
        // this app's Flutter side does) ends up displaying the raw UTC clock
        // number as if it were already local. Real bug this caught: Panchang
        // windows (Rahu Kaal, Abhijit Muhurat, ...) showed correctly on the
        // first computation of a day (an in-memory value, never touched the
        // DB) but wrong — off by exactly the local UTC offset — on every
        // later view of that same day (a cache hit, genuinely round-tripped
        // through MySQL). Forcing Kind=Utc back on every DateTime/DateTime?
        // read, for every entity, fixes it at the root instead of patching
        // PanchangCache alone — any other entity's DateTime column read back
        // from the DB was silently exposed to the same bug.
        var forceUtc = new ValueConverter<DateTime, DateTime>(
            v => v, v => DateTime.SpecifyKind(v, DateTimeKind.Utc));
        var forceUtcNullable = new ValueConverter<DateTime?, DateTime?>(
            v => v, v => v.HasValue ? DateTime.SpecifyKind(v.Value, DateTimeKind.Utc) : v);

        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            foreach (var property in entityType.GetProperties())
            {
                if (property.ClrType == typeof(DateTime))
                {
                    property.SetValueConverter(forceUtc);
                }
                else if (property.ClrType == typeof(DateTime?))
                {
                    property.SetValueConverter(forceUtcNullable);
                }
            }
        }
    }
}
