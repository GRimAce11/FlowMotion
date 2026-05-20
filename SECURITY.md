# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.2.x   | Yes       |
| 0.1.x   | Yes       |

## Reporting a Vulnerability

FlowMotion is a UI animation library with no network access, no data persistence, and no cryptographic operations. The attack surface is limited to:

- SwiftUI view hierarchy manipulation
- Unsafe `@unchecked Sendable` conformances on internal types

If you discover a security vulnerability, please **do not open a public issue**. Instead:

1. Open a [GitHub Security Advisory](https://github.com/GRimAce11/FlowMotion/security/advisories/new) (private disclosure)
2. Include a description of the vulnerability and steps to reproduce
3. Allow up to 7 days for an initial response

We will coordinate a fix and public disclosure together.
