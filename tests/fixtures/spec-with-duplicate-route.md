# SPEC-DUP-001: Item Registration v2 (duplicate-route test fixture)
# This file is a BATS test fixture for SPEC-190 AC-5.
# It intentionally proposes routes that already exist in the API twin.

## Status

DRAFT

## Background

This spec proposes adding item creation and listing capabilities via a new version
of the registration flow. These routes already exist in the twin and are used to
validate route-duplicate conflict detection.

## Acceptance Criteria

### AC-1: Create item endpoint

The system must accept POST /items with a valid JSON body containing `title: string`.
Returns 201 on success with the created record, 400 on validation error.

### AC-2: List items endpoint

The system must support GET /items with optional query parameters for filtering.
Returns 200 with a paginated list of items.

### AC-3: Authorization

Both endpoints require Bearer token authentication (role: user).

## API Changes

The following endpoints are required for this spec:

- `POST /items` — create item (this route already exists in the current twin)
- `GET /items` — list items (this route also already exists in the current twin)

## Notes

This fixture is intentionally crafted to trigger route_duplicate conflicts.
Two conflicts produce feasibility_score = 60 (below the 70 threshold).
