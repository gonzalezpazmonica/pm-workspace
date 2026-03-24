# PBI: Password Reset via Email

As an **authenticated user** who has forgotten their password,
I want to **request a password reset link via email**
so that I can **regain access to my account without contacting support**.

## Acceptance Criteria

1. Given a registered email, when the user requests a reset,
   then a unique time-limited token (valid 30 min) is sent to that email.
2. Given a valid token, when the user submits a new password,
   then the password is updated and all existing sessions are invalidated.
3. Given an expired or already-used token, when the user tries to reset,
   then an error message is shown and the user must request a new link.
4. Given an unregistered email, when the user requests a reset,
   then no email is sent but the UI shows the same success message
   (to prevent user enumeration).
5. Rate limit: max 3 reset requests per email per hour.

## Business Rules

- RN-AUTH-01: Passwords must meet complexity requirements (min 8 chars,
  1 uppercase, 1 number, 1 special character).
- RN-AUTH-02: Password reset tokens are single-use and expire after 30 min.
- RN-AUTH-03: Previous 5 passwords cannot be reused.

## Technical Notes

- Use existing EmailService for sending (SMTP configured in env).
- Token stored as SHA-256 hash in DB (never store raw token).
- Endpoint: POST /api/auth/reset-request, POST /api/auth/reset-confirm.
