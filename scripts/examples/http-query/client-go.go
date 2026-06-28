package main

// HTTP QUERY client examples — Go (RFC 10008)

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

// MethodQuery — string constant until net/http stdlib adds MethodQuery (proposal #80058)
const MethodQuery = "QUERY"

// QueryResource sends an HTTP QUERY request (RFC 10008).
// QUERY is safe, idempotent and cacheable — use instead of POST for read queries.
func QueryResource(url string, criteria interface{}) (*http.Response, error) {
	body, err := json.Marshal(criteria)
	if err != nil {
		return nil, fmt.Errorf("marshal criteria: %w", err)
	}

	req, err := http.NewRequest(MethodQuery, url, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("new request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	return http.DefaultClient.Do(req)
}

// QueryResourceJSON sends QUERY and decodes the JSON response into result.
func QueryResourceJSON(url string, criteria interface{}, result interface{}) error {
	resp, err := QueryResource(url, criteria)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("QUERY %s returned %d: %s", url, resp.StatusCode, b)
	}

	return json.NewDecoder(resp.Body).Decode(result)
}

func main() {
	criteria := map[string]interface{}{
		"status": "active",
		"tags":   []string{"production"},
		"limit":  10,
	}

	var results map[string]interface{}
	err := QueryResourceJSON("http://localhost:3000/search", criteria, &results)
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	fmt.Printf("QUERY results: %+v\n", results)
}
