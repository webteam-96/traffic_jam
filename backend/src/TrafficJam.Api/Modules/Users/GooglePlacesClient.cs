using System.Text.Json.Serialization;

namespace TrafficJam.Api.Modules.Users;

public class GooglePlacesClient : IPlacesClient
{
    private readonly HttpClient _http;
    private readonly string? _apiKey;

    public GooglePlacesClient(HttpClient http, IConfiguration configuration)
    {
        _http = http;
        _apiKey = configuration["GooglePlaces:ApiKey"];
    }

    private string RequireApiKey() => string.IsNullOrWhiteSpace(_apiKey)
        ? throw new PlacesNotConfiguredException(
            "GooglePlaces:ApiKey is not configured — set it before /places/* can be used. See backend/README.md.")
        : _apiKey;

    public async Task<IReadOnlyList<PlaceSuggestion>> AutocompleteAsync(string query, CancellationToken cancellationToken = default)
    {
        var apiKey = RequireApiKey();
        var url = $"https://maps.googleapis.com/maps/api/place/autocomplete/json?input={Uri.EscapeDataString(query)}&types=(cities)&key={apiKey}";
        var response = await _http.GetFromJsonAsync<AutocompleteResponse>(url, cancellationToken)
            ?? throw new HttpRequestException("Empty response from Google Places autocomplete.");

        return response.Predictions
            .Select(p => new PlaceSuggestion(p.PlaceId, p.Description))
            .ToList();
    }

    public async Task<PlaceDetails> GeocodeAsync(string placeId, CancellationToken cancellationToken = default)
    {
        var apiKey = RequireApiKey();
        var detailsUrl = $"https://maps.googleapis.com/maps/api/place/details/json?place_id={Uri.EscapeDataString(placeId)}&fields=geometry&key={apiKey}";
        var details = await _http.GetFromJsonAsync<DetailsResponse>(detailsUrl, cancellationToken)
            ?? throw new HttpRequestException("Empty response from Google Places details.");

        var lat = details.Result.Geometry.Location.Lat;
        var lng = details.Result.Geometry.Location.Lng;

        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var tzUrl = $"https://maps.googleapis.com/maps/api/timezone/json?location={lat},{lng}&timestamp={timestamp}&key={apiKey}";
        var tz = await _http.GetFromJsonAsync<TimezoneResponse>(tzUrl, cancellationToken)
            ?? throw new HttpRequestException("Empty response from Google Time Zone API.");

        return new PlaceDetails(lat, lng, tz.TimeZoneId);
    }

    private record AutocompleteResponse([property: JsonPropertyName("predictions")] List<Prediction> Predictions);
    private record Prediction(
        [property: JsonPropertyName("place_id")] string PlaceId,
        [property: JsonPropertyName("description")] string Description);

    private record DetailsResponse([property: JsonPropertyName("result")] DetailsResult Result);
    private record DetailsResult([property: JsonPropertyName("geometry")] Geometry Geometry);
    private record Geometry([property: JsonPropertyName("location")] Location Location);
    private record Location(
        [property: JsonPropertyName("lat")] double Lat,
        [property: JsonPropertyName("lng")] double Lng);

    private record TimezoneResponse([property: JsonPropertyName("timeZoneId")] string TimeZoneId);
}
