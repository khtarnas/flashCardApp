# Learnings

Personal knowledge journal — concepts I've learned while building HanaHou. Newest first. Only the user adds entries here; the agent must have explicit permission to add an entry.

---

### 2026-05-02: Property-based testing (PBT)
Instead of writing tests with specific hand-picked inputs ("does `""` get rejected?"), PBT describes a *property* — a rule that should always be true — and generates hundreds of random inputs to try to break it ("does ANY whitespace-only string get rejected?"). It finds edge cases you'd never think of, but adds complexity: you need to write input generators, failures are harder to debug (random input), and readability drops. Best suited for complex algorithms with large input spaces. For simple rules at small scale, well-chosen example-based tests are more readable and sufficient. In Swift, the framework for PBT is `swift-testing` (Apple first-party, ships with Xcode 16+), which provides randomized input generation via `@Test(arguments:)` and custom generators.
