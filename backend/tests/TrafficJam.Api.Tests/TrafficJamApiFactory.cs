using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using TrafficJam.Api.Data;
using TrafficJam.Api.Modules.Auth;

namespace TrafficJam.Api.Tests;

/// <summary>
/// Boots the real app in-memory against its own uniquely-named test schema
/// (never the dev database) and swaps the real Firebase verifier for
/// <see cref="FakeFirebaseTokenVerifier"/> — everything else (JWT issuance,
/// EF Core, encryption, MySQL, Redis) is the genuine article.
///
/// Each instance gets a fresh random database name — xUnit gives every test
/// class its own <see cref="TrafficJamApiFactory"/> instance via
/// IClassFixture, and different test classes run in parallel by default, so
/// a shared fixed database name causes tests to race each other's
/// EnsureDeleted/EnsureCreated calls.
/// </summary>
public class TrafficJamApiFactory : WebApplicationFactory<Program>
{
    private readonly string _databaseName = $"trafficjam_test_{Guid.NewGuid():N}";

    protected override void ConfigureWebHost(Microsoft.AspNetCore.Hosting.IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((_, config) =>
        {
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:MySql"] =
                    $"Server=localhost;Port=3307;Database={_databaseName};User=root;Password=devpassword;",
            });
        });

        builder.ConfigureServices(services =>
        {
            services.RemoveAll<IFirebaseTokenVerifier>();
            services.AddSingleton<IFirebaseTokenVerifier, FakeFirebaseTokenVerifier>();
        });
    }

    private readonly SemaphoreSlim _initLock = new(1, 1);
    private bool _initialized;

    /// <summary>
    /// Creates this instance's database schema exactly once, no matter how
    /// many test methods call it. Each test class already uses distinct
    /// user identifiers per test method for isolation, so a shared schema
    /// within a class is safe — repeated drop/recreate per test method is
    /// what caused the original flakiness (racing MySQL connection pooling).
    /// </summary>
    public async Task ResetDatabaseAsync()
    {
        if (_initialized) return;

        await _initLock.WaitAsync();
        try
        {
            if (_initialized) return;

            using var scope = Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            await db.Database.EnsureDeletedAsync();
            await db.Database.EnsureCreatedAsync();
            _initialized = true;
        }
        finally
        {
            _initLock.Release();
        }
    }

    /// <summary>
    /// Drops this instance's uniquely-named test database. Without this,
    /// every test run leaves its trafficjam_test_&lt;guid&gt; schema behind
    /// permanently — harmless to correctness (each run gets its own fresh
    /// name) but an ever-growing pile of dead databases on the dev MySQL
    /// instance. Deliberately a raw connection to the server rather than
    /// going through <see cref="Services"/> or a real AppDbContext — by the
    /// time a fixture's Dispose runs the app host's own service provider may
    /// already be torn down (observed as ObjectDisposedException when this
    /// first went through Services.CreateScope()), and AppDbContext itself
    /// needs an IEncryptionService that has nothing to do with dropping a
    /// schema, so this sidesteps both instead of fighting the app's lifecycle.
    /// </summary>
    protected override void Dispose(bool disposing)
    {
        if (disposing && _initialized)
        {
            using var connection = new MySqlConnector.MySqlConnection(
                "Server=localhost;Port=3307;User=root;Password=devpassword;");
            connection.Open();
            using var command = connection.CreateCommand();
            command.CommandText = $"DROP DATABASE IF EXISTS `{_databaseName}`;";
            command.ExecuteNonQuery();
        }

        base.Dispose(disposing);
    }
}
