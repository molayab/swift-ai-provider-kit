# Security Reference — PR Comment Fixer

Load this file when a PR comment raises a security concern.

## Common Swift / iOS Security Vulnerabilities

### Injection

| Pattern | Risk | Fix |
|---|---|---|
| `"SELECT * FROM t WHERE id = \(userInput)"` | SQL injection | Use parameterized queries / GRDB binding |
| `Process(); process.arguments = ["-c", input]` | Shell injection | Validate / allowlist input; avoid shell invocation |
| `URL(string: "https://host/\(path)")` | Open redirect / path traversal | Use `URLComponents`; validate components individually |

### Credential / Secret Handling

- **Keychain** for all secrets, tokens, private keys — not `UserDefaults`, not `NSUserDefaults`, not in-memory globals with `static var`
- Never log secrets: `print(apiKey)` or `Logger().debug("\(secret)")`
- Never hardcode secrets in source — use environment variables or a secrets manager
- Check `ProcessInfo.processInfo.environment` usages — ensure they are not logged

### Transport Security

- All network calls must use HTTPS
- `NSAllowsArbitraryLoads` in `Info.plist` is a red flag — document the justification
- `URLSession` with `URLSessionDelegate` implementing `urlSession(_:didReceive:completionHandler:)` without calling `performDefaultHandling` bypasses ATS — flag it
- Certificate pinning is required for high-sensitivity endpoints; check if the project's security policy mandates it

### Force Unwrapping External Data

Never force-unwrap data from:
- Network responses: `response["key"]!`
- User input: `Int(textField.text!)!`
- File I/O: `try! Data(contentsOf: url)`
- JSON decoding: `try! JSONDecoder().decode(...)`

Use `guard let` / `try?` / `Result` / structured error handling.

### Swift Concurrency — Security Considerations

- `nonisolated(unsafe) var secret: String` creates a data race that could expose partial writes — always document the invariant
- `@unchecked Sendable` on types that hold credentials bypasses the compiler's safety net — require a written invariant

### File System

- Do not write sensitive data to `NSTemporaryDirectory()` — it may be readable by other processes on a jailbroken device
- Use `FileProtectionType.complete` or `.completeUnlessOpen` for sensitive files
- Validate file paths to prevent path traversal: `path.hasPrefix(sandboxRoot)`

## Authoritative Sources

| Topic | Source |
|---|---|
| iOS Security Overview | https://support.apple.com/guide/security/welcome/web |
| Keychain Services | https://developer.apple.com/documentation/security/keychain_services |
| App Transport Security | https://developer.apple.com/documentation/bundleresources/information_property_list/nsapptransportsecurity |
| OWASP Mobile Top 10 | https://owasp.org/www-project-mobile-top-10/ |
| OWASP iOS Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/iOS_Developer_Cheat_Sheet.html |
| CWE Top 25 | https://cwe.mitre.org/top25/archive/2024/2024_cwe_top25.html |

## How to Validate a Security Claim

1. Identify the **CWE** or **OWASP category** the reviewer is citing (ask the reviewer if unclear).
2. Reproduce the concern: can you construct a concrete exploit path in the codebase?
3. If yes → fix it. If no → document why the concern does not apply (sandboxing, input validation upstream, etc.).
4. Search for similar patterns elsewhere in the codebase: `Grep: <pattern>` across `Sources/`.
