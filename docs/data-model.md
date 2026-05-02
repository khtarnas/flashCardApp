# Data Model – HanaHou

## Current State

The Xcode template shipped a single `Item` entity with a `timestamp` attribute. The current model (v2) replaces it with `Deck` and `Card`. The original `Item` schema is preserved as v1 to establish a real versioned migration baseline for future schema changes.

## P0 Entities

### Deck

| Attribute | Type | Constraints |
|-----------|------|-------------|
| id | UUID | Primary key, auto-generated |
| name | String | Required, unique |
| frontLanguage | String (Language enum raw value) | Required |
| backLanguage | String (Language enum raw value) | Required |
| createdAt | Date | Auto-set on creation |
| updatedAt | Date | Auto-set on creation, bumped on edit (D024) |

**Relationships:**
- `cards`: Many-to-many with Card (via join entity or Core Data many-to-many)

### Card

| Attribute | Type | Constraints |
|-----------|------|-------------|
| id | UUID | Primary key, auto-generated |
| frontText | String | Required |
| backText | String | Required |
| createdAt | Date | Auto-set on creation |

**Relationships:**
- `decks`: Many-to-many with Deck

### Language Enum

```swift
enum Language: String, CaseIterable {
    case english
    case japanese
    case spanish
    case mandarin
    case hawaiian
    case other
}
```

The enum is stored as a raw String value in Core Data. New languages can be added without migration.

## Future Entities (not yet implemented)

### StudyEvent (P2 — SRS)

| Attribute | Type | Constraints |
|-----------|------|-------------|
| id | UUID | Primary key |
| card | Card | Required relationship |
| outcome | String (enum raw value) | e.g., "correct", "incorrect" |
| reviewedAt | Date | When the review happened |

**Retention rule:** Keep only the last N events per card (e.g., 10).

### StudySession (P2+)

Deferred. Will be added when SRS or logging requires it.

## Design Decisions

- **Many-to-many from day one:** Even though P0 UI only shows one deck per card, the Core Data model uses a many-to-many relationship so cards can be reused across decks in P1+.
- **Language as String:** Stored as raw string for Core Data compatibility. The Swift enum provides type safety in code.
- **UUID primary keys:** Every entity gets a UUID. Deck name uniqueness is enforced separately as a business rule.
