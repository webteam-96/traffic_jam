using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;
using TrafficJam.Api.Infrastructure;

namespace TrafficJam.Api.Data;

/// <summary>
/// Used only by `dotnet ef` design-time commands (migrations add/bundle/script) —
/// takes priority over Program.cs's own DbContext registration, which calls
/// ServerVersion.AutoDetect() and therefore needs a *live* database connection
/// just to build the model. Design-time tooling never needs a real connection
/// (it only inspects the model/migrations), so this factory uses a fixed
/// ServerVersion and a syntactically-valid but unreachable placeholder
/// connection string instead. Never used by the running app itself.
/// </summary>
public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optionsBuilder.UseMySql(
            "Server=localhost;Port=3306;Database=trafficjam;User=design_time;Password=unused;",
            new MySqlServerVersion(new Version(8, 0, 36)));

        // Never actually invoked at design time — HasConversion() lambdas are
        // built but not executed until real row data is read/written — so a
        // throwaway key is fine here and never touches a real deployment.
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Encryption:Key"] = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
            })
            .Build();

        return new AppDbContext(optionsBuilder.Options, new AesEncryptionService(config));
    }
}
