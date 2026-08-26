namespace TrafficJam.Api.Modules.Users;

/// <summary>
/// Server-side proxy for Google Places — the API key never reaches the app.
/// API_REQUIREMENTS.md §1.5: birth-place autocomplete + geocoding to the
/// lat/lng/timezone the (future) Astro Engine needs.
/// </summary>
public interface IPlacesClient
{
    Task<IReadOnlyList<PlaceSuggestion>> AutocompleteAsync(string query, CancellationToken cancellationToken = default);
    Task<PlaceDetails> GeocodeAsync(string placeId, CancellationToken cancellationToken = default);
}

public record PlaceSuggestion(string PlaceId, string Description);
public record PlaceDetails(double Lat, double Lng, string Timezone);

public class PlacesNotConfiguredException(string message) : Exception(message);
