//
//  CoreDataDeckStore.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation
import CoreData
import Combine
import os

final class CoreDataDeckStore: DeckStore {

    private let context: NSManagedObjectContext
    private let clock: () -> Date
    private let changesSubject = PassthroughSubject<Void, Never>()
    private var saveObserver: NSObjectProtocol?
    private let logger = Logger(
        subsystem: "com.hanahou",
        category: "DeckStore"
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

    func fetchAll() throws -> [DeckSnapshot] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Deck")
        let results = try context.fetch(request)
        return results.compactMap { snapshot(from: $0) }
    }

    // MARK: - Create

    func create(_ draft: DeckDraft) throws -> DeckSnapshot {
        let existing = try fetchAll()

        switch DeckNameValidator.validate(
            name: draft.name,
            against: existing,
            editingDeckId: nil
        ) {
        case .failure(let nameError):
            throw nameError
        case .success:
            break
        }

        let deck = NSEntityDescription.insertNewObject(forEntityName: "Deck", into: context)
        let id = UUID()
        let now = clock()
        deck.setValue(id, forKey: "id")
        deck.setValue(draft.name, forKey: "name")
        deck.setValue(draft.frontLanguage.rawValue, forKey: "frontLanguageRaw")
        deck.setValue(draft.backLanguage.rawValue, forKey: "backLanguageRaw")
        deck.setValue(now, forKey: "createdAt")
        deck.setValue(now, forKey: "updatedAt")

        do {
            try context.save()
        } catch {
            context.rollback()
            logger.error("create save failed: \(error.localizedDescription, privacy: .public)")
            throw DeckStoreError.persistenceFailed(underlying: error)
        }

        return DeckSnapshot(
            id: id,
            name: draft.name,
            frontLanguage: draft.frontLanguage,
            backLanguage: draft.backLanguage,
            createdAt: now,
            updatedAt: now
        )
    }

    // MARK: - Update

    func update(id: UUID, with draft: DeckDraft) throws -> DeckSnapshot {
        guard let deck = try fetchDeck(withId: id) else {
            let underlying = NSError(
                domain: "CoreDataDeckStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No deck with id \(id)"]
            )
            throw DeckStoreError.persistenceFailed(underlying: underlying)
        }

        let existing = try fetchAll()

        switch DeckNameValidator.validate(
            name: draft.name,
            against: existing,
            editingDeckId: id
        ) {
        case .failure(let nameError):
            throw nameError
        case .success:
            break
        }

        let now = clock()
        deck.setValue(draft.name, forKey: "name")
        deck.setValue(draft.frontLanguage.rawValue, forKey: "frontLanguageRaw")
        deck.setValue(draft.backLanguage.rawValue, forKey: "backLanguageRaw")
        deck.setValue(now, forKey: "updatedAt")

        do {
            try context.save()
        } catch {
            context.rollback()
            logger.error("update(id:with:) save failed for \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw DeckStoreError.persistenceFailed(underlying: error)
        }

        guard let updated = snapshot(from: deck) else {
            let underlying = NSError(
                domain: "CoreDataDeckStore",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to build snapshot after update"]
            )
            logger.error("update(id:with:) succeeded but snapshot conversion failed for \(id.uuidString, privacy: .public)")
            throw DeckStoreError.persistenceFailed(underlying: underlying)
        }
        return updated
    }

    // MARK: - Delete

    func delete(id: UUID) throws {
        guard let deck = try fetchDeck(withId: id) else {
            // Deleting a non-existent id is a silent no-op — idempotent by design.
            return
        }
        context.delete(deck)

        do {
            try context.save()
        } catch {
            context.rollback()
            logger.error("delete(id:) save failed for \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw DeckStoreError.persistenceFailed(underlying: error)
        }
    }

    // MARK: - Helpers

    private func fetchDeck(withId id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Deck")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func snapshot(from deck: NSManagedObject) -> DeckSnapshot? {
        guard
            let id = deck.value(forKey: "id") as? UUID,
            let name = deck.value(forKey: "name") as? String,
            let frontRaw = deck.value(forKey: "frontLanguageRaw") as? String,
            let backRaw = deck.value(forKey: "backLanguageRaw") as? String,
            let createdAt = deck.value(forKey: "createdAt") as? Date,
            let updatedAt = deck.value(forKey: "updatedAt") as? Date
        else { return nil }
        return DeckSnapshot(
            id: id,
            name: name,
            frontLanguage: Language(rawValue: frontRaw) ?? .other,
            backLanguage: Language(rawValue: backRaw) ?? .other,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
