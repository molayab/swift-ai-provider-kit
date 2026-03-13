---
applyTo: "Sources/**/*.swift"
---

# Security Rules

## Credentials

- API keys and tokens must never be hardcoded or interpolated into string literals.
- All authorization headers must be provided through `AuthorizationProvider` injection.
- Flag any string literal that matches patterns like `sk-`, `Bearer `, or similar credential prefixes.

## Logging

- Never log API keys, auth tokens, request payloads, or user content via `print()` or `NSLog()`.
- All diagnostic output must go through `AILogger`. `AILogger` writes to the system log (`os.Logger`) where it is protected by the OS privacy model.
- Flag `print(request)`, `print(response)`, or similar debug output left in production paths.

## HTTP

- All HTTP requests must go through the `HTTPClient` protocol. Direct use of `URLSession` in provider or mapper code is not permitted.
- Responses must be validated for status codes before being passed to mappers. Non-2xx responses must throw a typed `AIError`.

## Input Validation

- Tool inputs arrive as `JSONValue`. Validate expected keys and types before use; do not assume structure.
- Flag force-cast patterns (`as! String`) on `JSONValue` payloads.
