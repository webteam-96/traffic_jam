using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using MySqlConnector;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;
using TrafficJam.Api.Infrastructure;
using Xunit;

namespace TrafficJam.Api.Tests;

/// <summary>
/// Proves birth data is actually encrypted in MySQL — not just that the app
/// layer round-trips correctly (a converter could no-op and still pass a
/// purely in-app test). Requires the dev-compose MySQL container running on
/// localhost:3307 (see backend/docker-compose.yml). Uses a dedicated
/// "trafficjam_test" schema so it never touches dev data.
/// </summary>
public class BirthDataEncryptionIntegrationTests : IAsyncLifetime
{
    private const string TestConnectionString =
        "Server=localhost;Port=3307;Database=trafficjam_test;User=root;Password=devpassword;";

    private AppDbContext _db = null!;

    public async Task InitializeAsync()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Encryption:Key"] = "tN8PuoSgs8BmWh7UWKeTVqGWmYR10rg822Eq+iR1x9s=",
            })
            .Build();

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseMySql(TestConnectionString, ServerVersion.AutoDetect(TestConnectionString))
            .Options;

        _db = new AppDbContext(options, new AesEncryptionService(config));
        await _db.Database.EnsureDeletedAsync();
        await _db.Database.EnsureCreatedAsync();
    }

    public async Task DisposeAsync()
    {
        await _db.Database.EnsureDeletedAsync();
        await _db.DisposeAsync();
    }

    [Fact]
    public async Task SavedBirthData_IsReadableThroughEfCore_AsPlainValues()
    {
        var user = new User { PhoneHash = "hash-1", FirebaseUid = "fb-1", Name = "Test User" };
        _db.Users.Add(user);
        _db.BirthData.Add(new BirthData
        {
            UserId = user.Id,
            Dob = new DateOnly(1988, 10, 24),
            Tob = new TimeOnly(4, 42),
            UnknownTime = false,
            Place = "Mumbai, Maharashtra, India",
            Lat = 19.0760,
            Lng = 72.8777,
            Timezone = "Asia/Kolkata",
        });
        await _db.SaveChangesAsync();
        _db.ChangeTracker.Clear();

        var reloaded = await _db.BirthData.SingleAsync(b => b.UserId == user.Id);

        Assert.Equal(new DateOnly(1988, 10, 24), reloaded.Dob);
        Assert.Equal("Mumbai, Maharashtra, India", reloaded.Place);
        Assert.Equal(19.0760, reloaded.Lat, precision: 4);
    }

    [Fact]
    public async Task RawMySqlColumn_NeverContainsThePlaintextPlaceName()
    {
        var user = new User { PhoneHash = "hash-2", FirebaseUid = "fb-2", Name = "Test User 2" };
        _db.Users.Add(user);
        _db.BirthData.Add(new BirthData
        {
            UserId = user.Id,
            Dob = new DateOnly(1990, 1, 1),
            UnknownTime = true,
            Place = "Bengaluru, Karnataka, India",
            Lat = 12.9716,
            Lng = 77.5946,
            Timezone = "Asia/Kolkata",
        });
        await _db.SaveChangesAsync();

        await using var connection = new MySqlConnection(TestConnectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT Place, Dob FROM BirthData WHERE UserId = @id";
        command.Parameters.AddWithValue("@id", user.Id.ToString());
        await using var reader = await command.ExecuteReaderAsync();
        await reader.ReadAsync();

        var rawPlace = reader.GetString(0);
        var rawDob = reader.GetString(1);

        Assert.DoesNotContain("Bengaluru", rawPlace);
        Assert.DoesNotContain("1990", rawDob);
    }
}
