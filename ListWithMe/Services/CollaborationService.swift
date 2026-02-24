import Foundation
import CloudKit
import Observation

@Observable
final class CollaborationService {
    private let container: CKContainer
    private var presenceTimers: [UUID: Timer] = [:]

    private(set) var currentUserId: String = ""
    private(set) var currentUserName: String = "Me"
    private(set) var participantsByList: [UUID: [Participant]] = [:]

    init() {
        self.container = CKContainer(identifier: "iCloud.com.isom.ListWithMe")
        Task {
            await fetchCurrentUser()
        }
    }

    // MARK: - User Identity

    private func fetchCurrentUser() async {
        do {
            let recordID = try await container.userRecordID()
            await MainActor.run {
                self.currentUserId = recordID.recordName
            }

            // Try to get user identity if available
            do {
                let identity = try await container.userIdentity(forUserRecordID: recordID)
                if let nameComponents = identity?.nameComponents {
                    let formatter = PersonNameComponentsFormatter()
                    let name = formatter.string(from: nameComponents)
                    await MainActor.run {
                        self.currentUserName = name
                    }
                }
            } catch {
                // User identity discovery may not be available, use default name
                print("Could not discover user identity: \(error.localizedDescription)")
            }
        } catch {
            print("Failed to fetch user record ID: \(error.localizedDescription)")
        }
    }

    // MARK: - Presence

    func startPresenceUpdates(for listId: UUID) {
        // Update presence immediately
        Task {
            await updatePresence(for: listId)
        }

        // Then update every 30 seconds
        let timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.updatePresence(for: listId)
            }
        }
        presenceTimers[listId] = timer
    }

    func stopPresenceUpdates(for listId: UUID) {
        presenceTimers[listId]?.invalidate()
        presenceTimers.removeValue(forKey: listId)
    }

    private func updatePresence(for listId: UUID) async {
        guard !currentUserId.isEmpty else { return }

        let database = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "\(listId.uuidString)_\(currentUserId)")

        do {
            // First try to fetch existing record
            let record: CKRecord
            if let existingRecord = try? await database.record(for: recordID) {
                record = existingRecord
            } else {
                record = CKRecord(recordType: "Presence", recordID: recordID)
            }

            record["listId"] = listId.uuidString
            record["userId"] = currentUserId
            record["userName"] = currentUserName
            record["lastSeen"] = Date()

            _ = try await database.save(record)
            await fetchActiveParticipants(for: listId)
        } catch {
            print("Failed to save presence: \(error.localizedDescription)")
        }
    }

    private func fetchActiveParticipants(for listId: UUID) async {
        let database = container.publicCloudDatabase

        // Query for presence records from the last 2 minutes
        let twoMinutesAgo = Date().addingTimeInterval(-120)
        let listPredicate = NSPredicate(format: "listId == %@", listId.uuidString)
        let timePredicate = NSPredicate(format: "lastSeen >= %@", twoMinutesAgo as NSDate)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [listPredicate, timePredicate])

        let query = CKQuery(recordType: "Presence", predicate: compoundPredicate)

        do {
            let (matchResults, _) = try await database.records(matching: query)

            let participants = matchResults.compactMap { (_, result) -> Participant? in
                guard case .success(let record) = result,
                      let userId = record["userId"] as? String,
                      let userName = record["userName"] as? String,
                      let lastSeen = record["lastSeen"] as? Date else {
                    return nil
                }

                return Participant(
                    id: userId,
                    displayName: userName,
                    isActive: true,
                    lastSeen: lastSeen
                )
            }

            await MainActor.run {
                self.participantsByList[listId] = participants
            }
        } catch {
            print("Failed to fetch participants: \(error.localizedDescription)")
        }
    }

    func getParticipants(for listId: UUID) -> [Participant] {
        return participantsByList[listId] ?? []
    }
}
