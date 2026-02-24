import Foundation
import CoreData
import Observation

@Observable
final class SuggestionService {
    private let persistence: PersistenceController
    private(set) var recentItems: [String] = []

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        loadRecentItems()
    }

    func loadRecentItems() {
        let request: NSFetchRequest<CDListItem> = CDListItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDListItem.createdAt, ascending: false)]
        request.fetchLimit = 100

        do {
            let items = try persistence.viewContext.fetch(request)
            let texts = items.compactMap { $0.text?.trimmingCharacters(in: .whitespaces) }
            // Unique items preserving order
            var seen = Set<String>()
            recentItems = texts.filter { item in
                let lowercased = item.lowercased()
                if seen.contains(lowercased) { return false }
                seen.insert(lowercased)
                return true
            }
        } catch {
            print("Failed to load recent items: \(error)")
        }
    }

    func suggestions(for query: String) -> [String] {
        guard !query.isEmpty else { return [] }
        let lowercasedQuery = query.lowercased()
        return recentItems
            .filter { $0.lowercased().contains(lowercasedQuery) }
            .prefix(5)
            .map { $0 }
    }
}
