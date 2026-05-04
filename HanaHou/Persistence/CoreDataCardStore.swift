//
//  CoreDataCardStore.swift
//  HanaHou
//
//  Feature: card-management
//

import Foundation
import CoreData
import Combine
import os

final class CoreDataCardStore: CardStore {

    private let context: NSManagedObjectContext
    private let clock: () -> Date
    private let changesSubject = PassthroughSubject<Void, Never>()
    private var saveObserver: NSObjectProtocol?
    private let logger = Logger(
        subsystem: "com.hanahou",
        category: "CardStore"
    )

    init(context: NSManagedObjectContext, clock: @escaping () -> Date = Date.init) {
        self.context = context
        self.clock = clock
        self.saveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: context,
            queue: nil
        ) { [weak self] _ in
            self?.changesSubject.send()
        }
    }

    deinit {
        if let token = saveObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    var changes: AnyPublisher<Void, Never> {
        changesSubject.eraseToAnyPublisher()
    }

    // MARK: - Fetch

    func fetchAll() throws -> [CardSnapshot] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Card")
        let results = try context.fetch(request)
        return results.compactMap { snapshot(from: $0) }
    }

    func fetchInDeck(deckId: UUID) throws -> [CardSnapshot] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Card")
        request.predicate = NSPredicate(format: "ANY decks.id == %@", deckId as CVarArg)
        let results = try context.fetch(request)
        return results.compactMap { snapshot(from: $0) }
    }

    // MARK: - Create

    func create(frontText: String, backText: String, deckIds: Set<UUID>) throws -> CardSnapshot {
        let draft = CardDraft(frontText: frontText, backText: backText)
        switch CardTextValidator.validate(draft: draft) {
        case .failure(let textError):
            throw textError
        case .success:
            break
        }

        let decks = try fetchDecks(withIds: deckIds)

        let card = NSEntityDescription.insertNewObject(forEntityName: "Card", into: context)
        let id = UUID()
        let now = clock()
        card.setValue(id, forKey: "id")
        card.setValue(frontText, forKey: "frontText")
        card.setValue(backText, forKey: "backText")
        card.setValue(now, forKey: "createdAt")
        card.setValue(now, forKey: "updatedAt")
        if !decks.isEmpty {
            card.setValue(Set(decks) as NSSet, forKey: "decks")
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            logger.error("create save failed: \(error.localizedDescription, privacy: .public)")
            throw CardStoreError.persistenceFailed(underlying: error)
        }

        // Resolve the persisted deckIds from the relationship — missing deck
        // ids are silently dropped (consistent with the "unknown id is a
        // no-op" principle).
        let persistedDeckIds = Set(decks.compactMap { $0.value(forKey: "id") as? UUID })

        return CardSnapshot(
            id: id,
            frontText: frontText,
            backText: backText,
            createdAt: now,
            updatedAt: now,
            deckIds: persistedDeckIds
        )
    }

    // MARK: - Update

    func update(id: UUID, frontText: String, backText: String) throws {
        // Unknown-id update is a silent no-op (Req 7 AC 9). Check existence
        // BEFORE validation so an unknown-id call does not throw a validation
        // error either.
        guard let card = try fetchCard(withId: id) else {
            return
        }

        let draft = CardDraft(frontText: frontText, backText: backText)
        switch CardTextValidator.validate(draft: draft) {
        case .failure(let textError):
            throw textError
        case .success:
            break
        }

        card.setValue(frontText, forKey: "frontText")
        card.setValue(backText, forKey: "backText")
        card.setValue(clock(), forKey: "updatedAt")

        do {
            try context.save()
        } catch {
            context.rollback()
            logger.error("update(id:frontText:backText:) save failed for \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw CardStoreError.persistenceFailed(underlying: error)
        }
    }

    // MARK: - Delete

    func delete(id: UUID) throws {
        guard let card = try fetchCard(withId: id) else {
            // Deleting a non-existent id is a silent no-op — idempotent per
            // the `CardStore` contract.
            return
        }
        context.delete(card)

        do {
            try context.save()
        } catch {
            context.rollback()
            logger.error("delete(id:) save failed for \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw CardStoreError.persistenceFailed(underlying: error)
        }
    }

    // MARK: - Helpers

    private func fetchCard(withId id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Card")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchDecks(withIds ids: Set<UUID>) throws -> [NSManagedObject] {
        guard !ids.isEmpty else { return [] }
        let request = NSFetchRequest<NSManagedObject>(entityName: "Deck")
        request.predicate = NSPredicate(format: "id IN %@", ids as CVarArg)
        return try context.fetch(request)
    }

    private func snapshot(from card: NSManagedObject) -> CardSnapshot? {
        guard
            let id = card.value(forKey: "id") as? UUID,
            let frontText = card.value(forKey: "frontText") as? String,
            let backText = card.value(forKey: "backText") as? String,
            let createdAt = card.value(forKey: "createdAt") as? Date,
            let updatedAt = card.value(forKey: "updatedAt") as? Date
        else { return nil }

        let deckIds: Set<UUID>
        if let decks = card.value(forKey: "decks") as? Set<NSManagedObject> {
            deckIds = Set(decks.compactMap { $0.value(forKey: "id") as? UUID })
        } else {
            deckIds = []
        }

        return CardSnapshot(
            id: id,
            frontText: frontText,
            backText: backText,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deckIds: deckIds
        )
    }
}
