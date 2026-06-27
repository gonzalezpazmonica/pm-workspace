using System.Net.Http.Json;
using System.Text.Json;

// HTTP QUERY client examples — C# / .NET (RFC 10008)

/// <summary>
/// Extension methods for sending HTTP QUERY requests (RFC 10008).
/// QUERY is safe, idempotent and cacheable — correct for complex read queries.
/// </summary>
public static class HttpQueryExtensions
{
    /// <summary>Sends an HTTP QUERY request and deserializes the JSON response.</summary>
    /// <typeparam name="T">Response type.</typeparam>
    /// <param name="client">HttpClient instance.</param>
    /// <param name="url">Target URL.</param>
    /// <param name="criteria">Query criteria serialized as JSON body.</param>
    /// <param name="options">Optional JSON serializer options.</param>
    public static async Task<T?> QueryAsync<T>(
        this HttpClient client,
        string url,
        object criteria,
        JsonSerializerOptions? options = null)
    {
        var request = new HttpRequestMessage(new HttpMethod("QUERY"), url);
        request.Content = JsonContent.Create(criteria, options: options);

        var response = await client.SendAsync(request);
        response.EnsureSuccessStatusCode();

        return await response.Content.ReadFromJsonAsync<T>(options);
    }

    /// <summary>Sends HTTP QUERY and returns the raw HttpResponseMessage.</summary>
    public static async Task<HttpResponseMessage> QueryRawAsync(
        this HttpClient client,
        string url,
        object criteria)
    {
        var request = new HttpRequestMessage(new HttpMethod("QUERY"), url);
        request.Content = JsonContent.Create(criteria);
        return await client.SendAsync(request);
    }
}

// Example usage:
// var client = new HttpClient { BaseAddress = new Uri("http://localhost:3000") };
// var results = await client.QueryAsync<SearchResults>("/search", new {
//     status = "active",
//     tags = new[] { "production" },
//     limit = 10
// });
