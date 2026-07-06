---
inclusion: always
---
# Steering Doc – HanaHou Flashcard iPad App

## 1. Project Overview

- **App type:** Personal iPadOS flashcard app for language learning.
- **Primary goal:** High-quality, offline-first flashcard experience, then gradually add Apple Pencil, SRS, AI, and logging features.
- **User model:** Single user (me). No accounts or sync initially.

### Long-term feature priorities (in order)

1. Flashcards (core deck/card management and study mode)
2. Apple Pencil integration
3. SRS (spaced repetition based on study events)
4. AI integration (remote or local model, behind a clean interface)
5. Word-count tracking + conversational topics + study logging (including external resources)

## 2. Agent Modes

At the start of every new session, ask the user: **"PM mode, SDE mode, or Reviewer mode?"**

- **PM mode:** Discovery, planning, and documentation. No code. See `.kiro/steering/agent-modes/pm-mode.md`.
- **SDE mode:** Design, test, and implement features. TDD only. See `.kiro/steering/agent-modes/sde-mode.md`.
- **Reviewer mode:** Audit code, docs, and architecture. Report findings only — no changes. See `.kiro/steering/agent-modes/reviewer-mode.md`.

Modes are **strictly separated.** Do not blend them. If a cross-concern arises (e.g., a design question in SDE mode, or a bug found in PM mode), flag it and ask the user to switch modes.

The user may switch modes mid-session by saying so explicitly.

### Mode file access rules

Agents in a given mode should only read their own mode file from `.kiro/steering/agent-modes/`. Only PM mode may read all three.

- **PM mode:** May read `pm-mode.md`, `sde-mode.md`, `reviewer-mode.md`
- **SDE mode:** May read `sde-mode.md` only
- **Reviewer mode:** May read `reviewer-mode.md` only

### Relationship to Kiro IDE modes

These custom modes define *what* the agent works on (planning vs coding vs reviewing). Kiro IDE's built-in modes (Vibe mode, Spec mode) define *how* the agent works (free-form vs structured). They are complementary:

- **Kiro Spec mode** aligns naturally with PM work (requirements → design → tasks).
- **Kiro Vibe mode + SDE steering** aligns with implementation.
- **Kiro Vibe mode + Reviewer steering** aligns with code/doc review.

The steering files ensure consistent behavior regardless of which IDE mode or agent tool is used. The "ask which mode" prompt is most important for non-Kiro agents (CLI, Claude, Cursor) that lack built-in structured modes.

## 3. Tech Stack & Constraints

See `.kiro/steering/tech.md` for full details.

- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** Core Data
- **Platform:** iPadOS only (for now)
- **Offline:** All core features must work completely offline
- **Networking:** No network calls in early priorities; AI integration comes later

## 4. Development Process

### Nothing is sacred — but only with user approval

The agent **must follow all recorded decisions and conventions**. These docs are the source of truth.

However, if the agent encounters a conflict, something that doesn't work in practice, or the user changes their mind, decisions can be revisited. Reevaluation is **always user-initiated or user-approved** — the agent may flag a concern, but must not unilaterally override a recorded decision. When a change is approved, update the relevant docs and add a new entry to `docs/decisions.md` explaining what changed and why.

### Priority tiers, not versions

Features are organized into priority tiers (P0, P1, P2, etc.) rather than version numbers. See `docs/roadmap.md` for the full backlog. Each tier's scope is defined in `docs/p0.md`, `docs/p1.md`, etc.

### Per-feature workflow

For each feature, follow three phases in order:

1. **Design phase**
   - Write or update a mini-design for the feature within the relevant priority doc.
   - Cover: scope, user flows, data model changes (if any).
   - Design must be reviewed before tests or code.

2. **Test-writing phase**
   - Before implementing new behavior, write tests that describe it.
   - Prioritize:
     - Core domain logic (e.g., SRS scheduling, data retention rules).
     - Any non-trivial transformations.
   - Tests are based strictly on the feature's design.

3. **Implementation phase**
   - Implement code to satisfy the tests and design.
   - Refactor as needed, keeping tests passing.
   - Keep implementation aligned with the design and this steering doc.

**Always use test-driven development.** No implementation without tests first.

### Commit messages

- Imperative mood ("Add", "Fix", "Resolve" — not past tense)
- Three sentences or less
- First line is the summary; keep it under 70 characters if possible

### Branching and pull requests

- Always branch off `main`.
- Branch prefixes: `feature/`, `fix/`, `docs/`.
- Each PR should be a coherent unit describable in one sentence. Granularity is flexible — one PR per feature, per phase, or per task, depending on what makes sense for the change.
- Regular merge by default. Squash merge on a case-by-case basis.
- Delete the branch after merge.
- Docs-only changes can push directly to `main` — no PR needed.
- Code changes go through PRs with a local reviewer agent (spec-blind, per `.kiro/steering/agent-modes/reviewer-mode.md`).
- PR review happens in the GitHub UI.

### Prompting guidelines (for Spec mode and agent interactions)

- **Pipeline PM work during reviews.** While a PR is open and under review, PM mode can start requirements/design/tasks for the next feature in parallel. Don't wait for the current PR to merge before beginning the next spec.

- For any content where formatting matters (PR descriptions, commit messages, prompts for other agents), write to `~/Downloads/` as a file rather than outputting inline in chat. Copy-paste from the chat window often breaks formatting.
- **No emojis.** Do not use emojis in code, docs, commit messages, PR descriptions, comments, or any project artifact. The only exception is if code genuinely needs to handle emoji (e.g., a test verifying emoji support in text fields).

- State the user's goal, not just the feature name
- Point to existing docs (`docs/p0.md`, `docs/data-model.md`) rather than restating their contents
- Call out constraints and non-obvious decisions by ID (e.g., D012)
- Explicitly state what is out of scope
- Keep it concise — long prompts dilute the important parts
- These guidelines are themselves subject to reevaluation (see Section 4.1)

## 5. Documentation Rules

### Two-layer documentation system

1. **Centralized (always loaded):** `.kiro/steering/structure.md` describes the top-level project layout.
2. **Distributed (per-directory):** Every directory has an `AGENTS.md` that describes its contents, key files, and agent directives. Each AGENTS.md only knows about its immediate children.

### AGENTS.md rules

- An `AGENTS.md` is created when a new directory is created.
- An `AGENTS.md` is updated when files in that directory are added, removed, or repurposed.
- These are for the AI agent, not for human readers.

### Root README.md

- One `README.md` at the project root, for humans.
- Updated when setup/build instructions change.

### Steering files

Kiro should always consult:
- This steering doc
- `.kiro/steering/product.md`
- `.kiro/steering/tech.md`
- `.kiro/steering/structure.md`
- The current priority tier's doc (e.g., `docs/p0.md`)

before generating tests or implementation.

## 6. Data Model – Core Principles

### Decks

- A Deck has a unique name (primary identifier) and a front/back language (language enum with `.other` case).

### Cards and Deck relationships

- Cards should support a many-to-many relationship with decks long-term.
- Early priorities may only expose one-to-one in the UI.
- Data model and architecture must keep many-to-many flexibility from the start.

### Study events & data retention (future)

- StudyEvents will store outcomes for card reviews when SRS is introduced.
- Retain only the most recent N events per card (e.g., last 10) to avoid data bloat.

### Study sessions (future)

- A separate StudySession entity is not needed in early priorities.
- Adding it later is acceptable and expected.

## 7. Decision Tracking

All significant decisions are recorded in `docs/decisions.md` with rationale. This is the source of truth for "why did we do it this way?"

## 8. Open Questions

Unanswered questions that may affect design or implementation are tracked in `docs/open-questions.md`. These must be resolved before the relevant feature enters the test-writing phase.
