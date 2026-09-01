namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// Ask Jay response-priority pricing — DB-backed (not a static array) so the
/// admin panel can change price/SLA without a redeploy. Id is the stable
/// slug ("standard", "priority") the frontend and Question.Plan already key
/// off of.
/// </summary>
public class ConsultPlanRow
{
    public required string Id { get; set; }
    public required string Name { get; set; }
    public required long PriceRupees { get; set; }
    public required int SlaHours { get; set; }
}
