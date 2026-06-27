using System.Text.Json;

// ASP.NET Core Minimal API — HTTP QUERY server (RFC 10008)
// Run: dotnet run

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// MapMethods accepts any HTTP verb, including custom ones like QUERY
app.MapMethods("/search", ["QUERY"], async (HttpRequest req) =>
{
    if (!req.HasJsonContentType())
    {
        return Results.Problem("Content-Type: application/json required", statusCode: 400);
    }

    var body = await req.ReadFromJsonAsync<object>();
    return Results.Ok(new { results = new object[0], query = body });
})
.WithName("QuerySearch")
.Produces(200)
.ProducesProblem(400);

app.MapGet("/search", () => Results.Ok(new
{
    message = "Use QUERY method with JSON body to search"
}));

app.Use(async (context, next) =>
{
    context.Response.Headers.Append("Accept-Query", "application/json");
    await next();
});

Console.WriteLine("ASP.NET Core QUERY server starting on http://localhost:5000");
Console.WriteLine("Test: curl -X QUERY http://localhost:5000/search \\");
Console.WriteLine("  -H \"Content-Type: application/json\" -d '{\"status\":\"active\"}'");

app.Run("http://localhost:5000");
