namespace TrafficJam.Api.Modules.Users;

public static class PlacesEndpoints
{
    public static void MapPlacesEndpoints(this IEndpointRouteBuilder app)
    {
        var places = app.MapGroup("/places").RequireAuthorization();

        places.MapGet("/autocomplete", async (string q, IPlacesClient client, CancellationToken ct) =>
        {
            try
            {
                return Results.Ok(await client.AutocompleteAsync(q, ct));
            }
            catch (PlacesNotConfiguredException ex)
            {
                return Results.Json(new { error = new { code = "PLACES_NOT_CONFIGURED", message = ex.Message } },
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            }
        });

        places.MapGet("/geocode", async (string placeId, IPlacesClient client, CancellationToken ct) =>
        {
            try
            {
                return Results.Ok(await client.GeocodeAsync(placeId, ct));
            }
            catch (PlacesNotConfiguredException ex)
            {
                return Results.Json(new { error = new { code = "PLACES_NOT_CONFIGURED", message = ex.Message } },
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            }
        });
    }
}
