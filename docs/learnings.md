# Learnings

Personal knowledge journal — concepts I've learned while building HanaHou. Newest first. Only the user adds entries here; the agent must have explicit permission to add an entry.

## Learnings

---

### 2026-05-03: Git commit title vs description
`git commit -m "title" -m "description"` creates a commit with a title (first `-m`) and an extended description (second `-m`), separated by a blank line. The title is what shows in `git log --oneline` and GitHub's commit list. The description appears in the full commit view. This is the same format GitHub's squash-merge UI uses with its separate "title" and "description" fields.

### 2026-05-03: CodeRabbit for automated PR review
CodeRabbit (coderabbit.ai) is an AI-powered PR reviewer that auto-comments on GitHub PRs. We installed it on the HanaHou repo and used it on PR #1 (card management). It caught real issues: missing Core Data uniqueness constraint on Card.id, swallowed errors in view models (`try?` hiding persistence failures), and nondeterministic test fixtures. It also flagged low-value items (session log prose, markdown lint). The free trial lasts one week — after that it requires a paid plan. Worth using during active development sprints. If the trial expires, our manual review prompt template (`.kiro/steering/prompt-templates.md`) covers the same ground.

### 2026-05-03: Deploying to a physical iPad (free path)
You can run your own app on a physical iPad without the $99/year Apple Developer Program. Sign into Xcode with your Apple ID (Settings → Accounts), connect the iPad via USB, select it as the run destination, and hit ⌘R. First time requires trusting the developer certificate on the device (Settings → General → VPN & Device Management). Limitations: apps expire after 7 days (must rebuild/reinstall), max 3 test devices, max 10 App IDs. The $99/year program removes these limits and adds TestFlight, App Store distribution, push notifications, and CloudKit.

### 2026-05-03: Xcode CLI — xcode-select vs DEVELOPER_DIR
When `xcodebuild` errors with "requires Xcode, but active developer directory is a command line tools instance," there are two fixes: (1) `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` permanently changes the system-wide pointer, or (2) prefix the single command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild …` for a per-invocation override that needs no sudo and touches no system state. Option 2 is less intrusive; option 1 is more convenient if you always want Xcode.app.

### 2026-05-03: Parallel testing overhead on small suites
Xcode defaults to parallel testing, which boots multiple simulator clones. On a ~200-test project this causes "Lost connection to testmanagerd" failures due to memory pressure. Fix: run with `-parallel-testing-enabled NO` in xcodebuild, or turn it off in the Xcode scheme/test plan. Parallel testing only pays off at 500+ tests.

### 2026-05-02: Property-based testing (PBT)
Instead of writing tests with specific hand-picked inputs ("does `""` get rejected?"), PBT describes a *property* — a rule that should always be true — and generates hundreds of random inputs to try to break it ("does ANY whitespace-only string get rejected?"). It finds edge cases you'd never think of, but adds complexity: you need to write input generators, failures are harder to debug (random input), and readability drops. Best suited for complex algorithms with large input spaces. For simple rules at small scale, well-chosen example-based tests are more readable and sufficient. In Swift, the framework for PBT is `swift-testing` (Apple first-party, ships with Xcode 16+), which provides randomized input generation via `@Test(arguments:)` and custom generators.
