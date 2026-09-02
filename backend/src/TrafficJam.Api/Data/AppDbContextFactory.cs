using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Data;

/// <summary>
/// Used only by `dotnet ef` design-time commands (migrations add/bundle/script/
/// database update) — takes priority over Program.cs's own DbContext
/// registration, which calls ServerVersion.AutoDetect() and therefore needs a
/// *live* database connection just to build the model, even for commands like
/// `migrations bundle` that never actually touch a database.
///
/// Reads the same appsettings.json + appsettings.{ASPNETCORE_ENVIRONMENT}.json
/// + environment variables Program.cs would, so `dotnet ef database update`
/// still applies migrations to the real target database — only ServerVersion
/// is fixed instead of auto-detected, which is the one part that needs a live
/// connection and isn't necessary for either building the model or applying a
/// migration. Never used by the running app itself.
/// </summary>
public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
            ?? Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT")
            ?? "Production";

        var config = new ConfigurationBuilder()
            .SetBasePath(AppContext.BaseDirectory)
            .AddJsonFile("appsettings.json", optional: true)
            .AddJsonFile($"appsettings.{environment}.json", optional: true)
            .AddEnvironmentVariables()
            .Build();

        // A syntactically-valid placeholder if no real connection string is
        // configured (e.g. building a migrations bundle with no local DB
        // available) — ServerVersion is fixed either way, so this is only
        // ever actually dialed for commands that need a live connection,
        // like `database update`.
        var connectionString = config.GetConnectionString("MySql")
            ?? "Server=localhost;Port=3306;Database=trafficjam;User=design_time;Password=unused;";

        var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optionsBuilder.UseMySql(connectionString, new MySqlServerVersion(new Version(8, 0, 36)));

        // Real key when available (needed for `database update` against a
        // database with existing encrypted rows to read back); a throwaway
        // otherwise — HasConversion() lambdas are built but not executed
        // until real row data is read/written, so this only matters if a
        // design-time command actually queries encrypted data, which none do.
        if (config["Encryption:Key"] is null)
        {
            config = new ConfigurationBuilder()
                .AddConfiguration(config)
                .AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Encryption:Key"] = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
                })
                .Build();
        }

        return new AppDbContext(optionsBuilder.Options, new AesEncryptionService(config));
    }
}
