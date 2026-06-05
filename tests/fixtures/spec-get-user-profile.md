# SPEC-PROF-001: Get User Profile endpoint (no-conflict test fixture)
# This file is a BATS test fixture for SPEC-190 AC-11.
# It proposes a new endpoint with no conflicts against the existing twin.

## Status

DRAFT

## Background

This spec introduces a new endpoint to retrieve a user's public profile. The endpoint
path (`GET /users/{id}/profile`) does not exist in the current API twin, so no
route conflicts should be detected.

## Acceptance Criteria

### AC-1: Retrieve user profile

The system must return a `UserProfileDto` when `GET /users/{id}/profile` is called
with a valid user ID.

- Response: `200 { user_id, display_name, avatar_url }` on success
- Response: `404 NOT_FOUND` if user does not exist
- Response: `401 UNAUTHORIZED` if no token provided

### AC-2: Authorization

The endpoint requires a valid Bearer token. No specific role is required.

## API Changes

One new endpoint is introduced:

- `GET /users/{id}/profile` — retrieve user public profile (NEW, no conflict)

## New Data Transfer Object

### UserProfileDto

**Fields**: `user_id: uuid`, `display_name: string`, `avatar_url: string | null`
**Notes**: Read-only DTO, not persisted directly.

## Notes

This fixture is designed to produce feasibility_score = 100 and conflicts = [].
Used in SPEC-190 AC-11 BATS assertions.
