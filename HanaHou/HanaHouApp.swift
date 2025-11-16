//
//  HanaHouApp.swift
//  HanaHou
//
//  Created by Tarnas, Hokua on 11/16/25.
//

import SwiftUI
import CoreData

@main
struct HanaHouApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
