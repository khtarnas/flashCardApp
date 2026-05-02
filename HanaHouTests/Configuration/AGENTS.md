# AGENTS.md — HanaHouTests/Configuration/

Tests that assert project-level build settings and bundle configuration rather than Swift code.

## Current contents

| File | Covers |
|------|--------|
| `InfoPlistOrientationTests.swift` | `UISupportedInterfaceOrientations~ipad` (and fallback key) contains only portrait variants (Req 7.2, 7.3, 7.4, 7.5). |

## Directives

- Read values from `Bundle.object(forInfoDictionaryKey:)` — do not hardcode the plist path.
- Keep the set of allowed values explicit (portrait + portrait-upside-down) so a future landscape change trips the test.
