#!/usr/bin/env bash
# HTTP QUERY method examples via curl
# RFC 10008 — https://www.rfc-editor.org/rfc/rfc10008
#
# Usage: ./client-curl.sh [BASE_URL]
# Default BASE_URL: http://localhost:3000

set -euo pipefail

BASE_URL="${1:-http://localhost:3000}"

echo "=== HTTP QUERY examples (RFC 10008) ==="
echo "Base URL: ${BASE_URL}"
echo ""

# Basic QUERY — JSON body with search criteria
echo "--- Basic QUERY ---"
curl -s -X QUERY "${BASE_URL}/search" \
  -H "Content-Type: application/json" \
  -d '{"status":"active","limit":10}' | python3 -m json.tool 2>/dev/null || true

echo ""

# QUERY with multiple criteria
echo "--- QUERY with tags filter ---"
curl -s -X QUERY "${BASE_URL}/search" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"tags":["production"],"fields":["id","name"],"limit":20}' | python3 -m json.tool 2>/dev/null || true

echo ""

# QUERY showing response headers (Content-Location, Accept-Query)
echo "--- QUERY response headers ---"
curl -s -X QUERY "${BASE_URL}/search" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"q":"test"}' \
  -D - -o /dev/null

echo ""

# Discover QUERY support via OPTIONS
echo "--- OPTIONS — discover QUERY support ---"
curl -s -X OPTIONS "${BASE_URL}/search" \
  -H "Access-Control-Request-Method: QUERY" \
  -D - -o /dev/null | grep -E "Allow:|Accept-Query:" || true

echo ""

# QUERY with SQL-like body
echo "--- QUERY with complex criteria ---"
curl -s -X QUERY "${BASE_URL}/search" \
  -H "Content-Type: application/json" \
  -d '{
    "select": ["id","name","email"],
    "where": {"domain": "example.org", "active": true},
    "orderBy": "name",
    "limit": 5,
    "offset": 0
  }' | python3 -m json.tool 2>/dev/null || true

echo ""
echo "=== Done ==="
