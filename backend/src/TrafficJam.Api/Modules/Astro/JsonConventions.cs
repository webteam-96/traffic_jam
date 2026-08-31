using System.Text.Json;

namespace TrafficJam.Api.Modules.Astro;

/// <summary>
/// ASP.NET Core's `Results.Ok(...)` applies camelCase property naming by
/// default, which is why /panchang/today and /signal/today (both built on
/// record types returned via Results.Ok) already come back camelCase. Any
/// place that calls JsonSerializer.Serialize directly instead — storing
/// chart/Dasha JSON in the database, or /transits/today's manual
/// Results.Content — bypasses that default and gets JsonSerializer's own
/// default (PascalCase), silently breaking API consistency. Found while
/// building /chart, which would otherwise have produced a response that was
/// camelCase at the top level and PascalCase in every nested chart field.
/// Use this options instance anywhere JSON is serialized by hand for
/// anything that a client will consume, so the whole API is one convention.
/// </summary>
public static class JsonConventions
{
    public static readonly JsonSerializerOptions CamelCase = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };
}
