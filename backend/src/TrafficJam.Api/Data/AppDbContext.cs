using System.Globalization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;

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
    }
}
