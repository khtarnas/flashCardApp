//
//  Persistence.swift
//  HanaHou
//
//  Feature: deck-management
//

import CoreData

/// Owns the Core Data stack. Vends a `CoreDataDeckStore` as the public
/// persistence entry point for deck management. Load failures are surfaced via
/// `init(inMemory:) throws` rather than `fatalError`, so callers can decide
/// how to handle them.
struct PersistenceController {

    static let shared: PersistenceController = {
        do {
            return try PersistenceController()
        } catch {
            // The composition root (HanaHouApp) wraps `.shared` and is
            // responsible for reporting a load failure to the user. This
            // fallback keeps the shared-accessor API ergonomic while still
            // surfacing the failure through the `loadError` property.
            return PersistenceController(failedLoad: error)
        }
    }()

    @MainActor
    static let preview: PersistenceController = {
        // In-memory store for SwiftUI previews. Seed data will be added when
        // Card/Deck CRUD is implemented in subsequent specs.
        // swiftlint:disable:next force_try
        return try! PersistenceController(inMemory: true)
    }()

    let container: NSPersistentContainer

    /// Populated when the persistent store fails to load. Callers that care
    /// (for example, the composition root) can inspect this and surface an
    /// error to the user instead of crashing.
    let loadError: Error?

    init(inMemory: Bool = false) throws {
        container = NSPersistentContainer(name: "HanaHou")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        var capturedError: Error?
        container.loadPersistentStores { _, error in
            if let error = error {
                capturedError = error
            }
        }
        if let capturedError = capturedError {
            throw capturedError
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        self.loadError = nil
    }

    /// Fallback initializer used by `.shared` when the store fails to load.
    /// Leaves the container unusable; callers should inspect `loadError`.
    private init(failedLoad error: Error) {
        container = NSPersistentContainer(name: "HanaHou")
        self.loadError = error
    }

    /// Vends a `CoreDataDeckStore` backed by the container's `viewContext`.
    /// The store is the public persistence API for deck management.
    func makeDeckStore(clock: @escaping () -> Date = Date.init) -> CoreDataDeckStore {
        CoreDataDeckStore(context: container.viewContext, clock: clock)
    }

    /// Vends a `CoreDataCardStore` backed by the container's `viewContext` —
    /// the SAME context used by `makeDeckStore`. Sharing the context is what
    /// makes orphan handling work: a deck deletion's `NSManagedObjectContextDidSave`
    /// notification reaches both stores' observers, and the card store
    /// re-publishes so the All Cards view refreshes automatically
    /// (per `.kiro/specs/card-management/design.md` §Composition Root).
    func makeCardStore(clock: @escaping () -> Date = Date.init) -> CoreDataCardStore {
        CoreDataCardStore(context: container.viewContext, clock: clock)
    }
}
