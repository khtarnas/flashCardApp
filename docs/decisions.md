# Decision Log – HanaHou

Significant decisions with rationale. Newest first. Size: mini | small | medium | large | huge.

---

### D035: CardDraft carries text only; deck membership is a separate argument to CardStore.create [mini]
**Date:** 2026-05-02
**Decision:** `CardDraft` has only `frontText` and `backText`. Initial deck membership is a separate `deckIds: Set<UUID>` parameter on `CardStore.create(frontText:backText:deckIds:)`. The P0 editor passes a singleton set from the per-deck flow; a future multi-deck editor can pass any set without changing the draft value type.
**Rationale:** Keeps the draft value type small and stable. Multi-deck editing is a P1+ concern — making it additive through the store parameter means the draft doesn't need to evolve later.

### D034: AllCardsView replaces AllCardsPlaceholderView; placeholder source file is deleted [mini]
**Date:** 2026-05-02
**Decision:** The P0 `AllCardsPlaceholderView` is removed from the project entirely. The `.allCards` navigation destination resolves to `AllCardsView`. Git history preserves the placeholder — no reason to keep dead code in the repo.
**Rationale:** Simpler navigation and no maintenance tax on a file that no code paths reach.

### D033: CardStore.update / .delete on unknown id are silent no-ops that do not emit on changes [small]
**Date:** 2026-05-02
**Decision:** Both in-memory and Core Data `CardStore` implementations treat `update(id:...)` and `delete(id:)` with an id that doesn't exist as a no-op: no throw, no mutation, no emission on `changes`. Mirrors `DeckStore.delete`'s idempotent-mutation contract.
**Rationale:** Idempotent mutations are safer and easier to reason about from the view-model layer. View models that fire stale ids (e.g., after a background deletion) don't need to special-case "it's already gone".

### D032: CardOrderingStrategy introduced as a Card-side sibling of DeckOrderingStrategy, not a generic [small]
**Date:** 2026-05-02
**Decision:** `CardOrderingStrategy` is its own protocol taking `[CardSnapshot]`, mirroring `DeckOrderingStrategy`. Considered a generic `OrderingStrategy<Item>` that both would adopt, and rejected it: the symmetry-with-existing-pattern payoff beats the marginal DRY at P0 scale, and a generic protocol would need constraints (`Item: Identifiable` + accessors) that add indirection without paying for themselves yet.
**Rationale:** D009 says ordering is a pluggable strategy per concept, not a cross-entity abstraction. Future card orderings (e.g., "most recently updated") fit a card-specific protocol naturally.

### D031: Tapping a user-deck row opens CardListView, not DeckEditorView [small]
**Date:** 2026-05-02
**Decision:** In `DeckListView`, tapping a user-deck row pushes `.cardList(deck)` instead of the previous `.editDeck(deck)`. The rename/delete editor is reachable from `CardListView`'s toolbar "Edit Deck" button and the existing swipe-to-delete on the deck-list row.
**Rationale:** Users open a deck to see its cards. The previous edit-on-tap was a placeholder-era artifact because there was nothing to show inside a deck yet. Now that cards exist, the natural destination is the card list.

### D030: Card updatedAt added in Core Data schema v3 with a static Date default [mini]
**Date:** 2026-05-02
**Decision:** Added `Card.updatedAt: Date` (required) in `HanaHou 3.xcdatamodel`. Lightweight inferred migration uses a non-nil default value so any pre-v3 rows get a migration-time `Date()` — no post-migration fixup to set `updatedAt = createdAt` for existing rows. HanaHou has never shipped, so the semantic-correctness payoff of the fixup was zero.
**Rationale:** Simpler migration, same observable behavior. If the app ever ships before this migration runs, we revisit.

### D029: Branching and PR conventions [small]
**Date:** 2026-05-02
**Decision:** Always branch off main. Use `feature/`, `fix/`, `docs/` prefixes. Regular merge by default, squash on a case-by-case basis. Delete branch after merge. Docs-only changes push directly to main. Code changes go through PRs with CodeRabbit auto-review in the GitHub UI.
**Rationale:** Simple workflow for a solo project. Flexible granularity — each PR is a coherent unit. CodeRabbit provides free automated review on public repos.

### D028: Orientation lock via Info.plist as single point of change [mini]
**Date:** 2026-05-02
**Decision:** Portrait lock is implemented by setting `UISupportedInterfaceOrientations~ipad` in Info.plist. If that proves insufficient, a `UIApplicationDelegateAdaptor` is the fallback — still a single point. No per-view overrides.
**Rationale:** One place to change when landscape support is added. Simplest mechanism that satisfies the requirement.

### D027: Name uniqueness enforced in code, not Core Data constraints [small]
**Date:** 2026-05-02
**Decision:** Deck name uniqueness and reserved-name checks are enforced by `DeckNameValidator` (pure function) and re-checked in `CoreDataDeckStore` before save. Core Data's `uniquenessConstraints` are not used for name validation.
**Rationale:** Core Data constraints compare stored values byte-for-byte and can't express "trimmed" or "case-insensitive" comparisons. Enforcing in code gives full control over the comparison rules.

### D026: "All Cards" is a synthetic view-model item, not a stored Deck [small]
**Date:** 2026-05-02
**Decision:** The "All Cards" entry is represented as a `DeckListItem.allCards` enum case in the view model. It is not a Deck record in Core Data.
**Rationale:** Matches Req 8.5 ("system concept rather than a user-created Deck record"). Avoids a sentinel row that could be accidentally edited/deleted. Keeps the Core Data model clean.

### D025: Portrait lock confined to single configuration point [mini]
**Date:** 2026-05-02
**Decision:** The orientation lock must be removable from a single place when landscape support is added later.
**Rationale:** "Everything is mutable" — orientation support will change, so the lock must be easy to lift.

### D024: updatedAt timestamp captured on deck edit [mini]
**Date:** 2026-05-02
**Decision:** Decks get an `updatedAt` attribute set to `createdAt` on creation and bumped to current time on edit. Not displayed in P0 but persisted for future use (e.g., sort by recently modified).
**Rationale:** Cheap to capture now, useful later. Avoids a data migration to add it retroactively.

### D023: Deck list ordered by creation date via swappable strategy [small]
**Date:** 2026-05-02
**Decision:** P0 orders user-created decks by creation date (oldest first) using a `DeckOrderingStrategy` protocol. The strategy is injected at the composition root and swappable without changing the view.
**Rationale:** Follows the swappable-strategy pattern from D009. Eventually ordering should be usage-based, so the mechanism must be pluggable.

### D022: "All Cards" is a reserved deck name [mini]
**Date:** 2026-05-02
**Decision:** Users cannot create a deck named "All Cards". The name is checked case-insensitively after trimming whitespace. The reserved-name check is independent of the uniqueness check.
**Rationale:** Prevents confusion between the system "All Cards" entry and a user-created deck with the same name.

### D021: Example-based tests for P0, not property-based [small]
**Date:** 2026-05-02
**Decision:** Use example-based unit tests (hand-picked inputs and expected outputs) for P0 rather than property-based testing (PBT). Revisit PBT when algorithm complexity warrants it (e.g., SRS scheduling in P2) or if the app's scale increases significantly.
**Rationale:** P0's validation rules are simple (3 rules, small input space) and the app is personal-scale (dozens of decks, not thousands). Example-based tests are more readable, easier to debug, and sufficient for coverage. PBT's strengths — finding unexpected edge cases across huge input spaces — don't justify the added complexity at this scale.

### D020: Prompting guidelines recorded in steering doc [mini]
**Date:** 2026-05-02
**Decision:** Added prompting guidelines (goal-first, reference docs, state out-of-scope, cite decisions, keep concise) to the steering doc. These guidelines are themselves subject to reevaluation.
**Rationale:** Good prompts produce better spec output. Recording the principles ensures consistency and gives us something concrete to improve over time.

### D019: "Nothing is sacred" — but only with user approval [medium]
**Date:** 2026-05-02
**Decision:** The agent must follow all recorded decisions and conventions. However, any decision can be revisited if the user changes their mind or the agent flags a conflict. Reevaluation is always user-initiated or user-approved — the agent may raise concerns but must not unilaterally override recorded decisions.
**Rationale:** Prevents rigidity without enabling rogue behavior. The docs are the source of truth; the user is the authority to change them.

### D018: Custom modes complement Kiro IDE modes, not replace them [small]
**Date:** 2026-05-02
**Decision:** Our PM/SDE/Reviewer modes define *what* the agent works on. Kiro IDE's Vibe/Spec modes define *how* it works. They layer together. The steering files ensure consistent behavior across any agent tool.
**Rationale:** Kiro IDE's Spec mode already provides structured requirements→design→tasks flow. Fighting it would be counterproductive. Our modes add behavioral constraints on top.

### D017: Reviewer mode added as third agent mode [small]
**Date:** 2026-05-02
**Decision:** Added Reviewer mode: audit code, docs, and architecture. Report findings categorized as must-fix / should-fix / consider. No direct changes — findings are handed off to PM or SDE mode.
**Rationale:** Reviewing is a distinct activity from planning and coding. Strict separation prevents a review session from drifting into ad-hoc fixes.

### D016: Strict PM/SDE agent modes [medium]
**Date:** 2026-05-02
**Decision:** The agent operates in one of two strictly separated modes: PM mode (discovery, planning, docs — no code) or SDE mode (design, test, implement — no product decisions). The agent asks which mode at session start. Modes do not blend; if a cross-concern arises, the agent flags it and asks the user to switch.
**Rationale:** Context mixing makes sessions unfocused. Strict separation keeps PM work clean (no accidental code) and SDE work clean (no accidental scope changes). The user controls when to switch.

### D015: Product philosophy lives in product.md (extract later if needed) [mini]
**Date:** 2026-05-02
**Decision:** Guiding philosophy and design values are captured in a "Product Philosophy" section of `.kiro/steering/product.md`. If it grows too large, extract to a separate `docs/philosophy.md`.
**Rationale:** Philosophy statements directly influence every design decision, so they should be always-loaded agent context. Keeping them in product.md is simple; extraction is a future option, not a current need.

### D014: Portrait only for P0, both orientations later [mini]
**Date:** 2026-05-02
**Decision:** P0 supports portrait orientation only. Landscape support added in a future priority.
**Rationale:** Reduces layout complexity for P0. Portrait is the natural orientation for card-based study.

### D013: Stack navigation for P0, collapsible sidebar later [small]
**Date:** 2026-05-02
**Decision:** P0 uses simple stack navigation (NavigationStack). Future priority adds a collapsible sidebar (NavigationSplitView).
**Rationale:** Stack is simplest to build and matches the single linear flow of P0 (decks → cards → study). Navigation logic will be separated from view logic so swapping to sidebar is painless. Sidebar is the long-term goal for iPad-native feel.

### D012: Deck deletion detaches cards; "All Cards" deck is undeletable [medium]
**Date:** 2026-05-02
**Decision:** Deleting a deck removes deck-card associations but does not delete cards. An "All Cards" deck (system-managed, not deletable) provides access to every card regardless of deck membership.
**Rationale:** Safe for many-to-many — deleting Deck A won't destroy cards that Deck B also uses. "All Cards" prevents orphans from becoming invisible. Can be made configurable later.

### D011: Plain text only for P0 card content [mini]
**Date:** 2026-05-02
**Decision:** Card front and back are plain strings in P0. No rich text, formatting, or media.
**Rationale:** Simplest implementation. Rich content (Apple Pencil drawings, images) comes in P1+.

### D010: Study completion — return to home screen in P0, summary screen later [small]
**Date:** 2026-05-02
**Decision:** P0: finishing a study session returns to the home screen. A summary screen with statistics is a future feature.
**Rationale:** Summary screen is part of a broader statistics/analytics vision and deserves its own design cycle. P0 keeps it simple.

### D009: Card ordering — start with easiest, make swappable [small]
**Date:** 2026-05-02
**Decision:** P0 implements whichever card ordering is easiest (likely sequential/deck order). The study mode accepts a card-ordering strategy so it's swappable. User choice via settings comes later.
**Rationale:** Modularity first — the ordering algorithm is a pluggable strategy, not hardcoded. Sequential is simplest to implement and test.

### D008: Self-grading with 3 categories [small]
**Date:** 2026-05-02
**Decision:** Study mode uses self-grading with three categories: "I know it", "I'm close", "No idea". The grading scale is designed to be mutable (easy to add/remove/rename categories).
**Rationale:** Three tiers provide useful signal without overwhelming the user. Designing for mutability means the scale can evolve when SRS is introduced.

### D007: Per-feature TDD, not per-tier [small]
**Date:** 2026-05-02
**Decision:** The design → test → implement workflow applies per feature, not per priority tier.
**Rationale:** Features within a tier are independent enough to design and build separately. This keeps each cycle small and focused.

### D006: Priority tiers (P0/P1/P2) instead of version numbers (v1/v2) [medium]
**Date:** 2026-05-02
**Decision:** Organize features by priority tier rather than release version.
**Rationale:** Decouples "what matters most" from "when it ships." A solo developer can cut a release whenever it feels right rather than when an arbitrary scope is complete.

### D005: AGENTS.md per directory, one root README.md [medium]
**Date:** 2026-05-02
**Decision:** Every directory gets an `AGENTS.md` (for the AI agent). One `README.md` at the project root (for humans). AGENTS.md can be created when a directory is created or after its initial contents are established — whichever produces a more accurate description. Update it when contents change.
**Rationale:** The primary consumer of per-directory documentation is the AI agent, not a human reader. AGENTS.md is the standard for agent directives. README.md serves a different audience (humans wanting setup/overview info). Replaces the earlier "README in every directory" rule.

### D004: Two-layer documentation (centralized + distributed) [medium]
**Date:** 2026-05-02
**Decision:** `.kiro/steering/structure.md` provides the top-level map (always loaded). Per-directory `AGENTS.md` files provide local detail. Each level only knows about its immediate children; abstraction increases upward.
**Rationale:** Scales naturally — when a directory grows complex, its AGENTS.md becomes the centralized doc for that subtree. No single document has to be exhaustive.

### D003: Many-to-many Card-Deck relationship from day one [large]
**Date:** 2026-05-02 (from original steering doc)
**Decision:** Model Card-Deck as many-to-many in Core Data even though P0 UI only exposes one-to-one.
**Rationale:** Avoids a painful data migration later. The UI can restrict behavior without the data model being a bottleneck.

### D002: Offline-first, no network calls in early priorities [large]
**Date:** 2026-05-02 (from original steering doc)
**Decision:** All core features work completely offline. No networking until AI integration (P3+).
**Rationale:** Simplifies the app, eliminates a class of bugs, and matches the use case (personal study on iPad).

### D001: iPadOS only [large]
**Date:** 2026-05-02 (from original steering doc)
**Decision:** Target iPadOS only. No iPhone or macOS support initially.
**Rationale:** Apple Pencil integration is a key differentiator and is iPad-specific. Focusing on one platform keeps scope manageable.
