import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

// HTTP QUERY client — Java / Spring WebFlux (RFC 10008)
// Spring Framework doesn't yet have HttpMethod.QUERY constant (PR #34993 open)
// Workaround: HttpMethod.valueOf("QUERY") works in Spring 6.x

/**
 * HTTP QUERY client using Spring WebClient.
 * RFC 10008 — QUERY is safe, idempotent and cacheable.
 */
public class HttpQueryClient {

    private final WebClient webClient;

    public HttpQueryClient(String baseUrl) {
        this.webClient = WebClient.builder()
            .baseUrl(baseUrl)
            .defaultHeader("Accept", MediaType.APPLICATION_JSON_VALUE)
            .build();
    }

    /**
     * Sends an HTTP QUERY request (RFC 10008).
     *
     * @param path         Resource path
     * @param criteria     Query criteria serialized as JSON body
     * @param responseType Expected response type
     * @return Mono with the deserialized response
     */
    public <T> Mono<T> query(String path, Object criteria, Class<T> responseType) {
        return webClient
            .method(HttpMethod.valueOf("QUERY"))
            .uri(path)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(criteria)
            .retrieve()
            .bodyToMono(responseType);
    }

    // Example usage:
    // HttpQueryClient client = new HttpQueryClient("http://localhost:3000");
    // SearchCriteria criteria = new SearchCriteria("active", List.of("production"), 10);
    // SearchResults results = client.query("/search", criteria, SearchResults.class).block();
}
