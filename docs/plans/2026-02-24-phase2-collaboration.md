# Phase 2: Collaboration Depth Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add activity feed, real-time presence, participant management, and change notifications to enable deep collaboration features.

**Architecture:** Extend existing ListService with activity tracking, create new CollaborationService for presence/participants, add CloudKit subscriptions for real-time updates, and build ActivitySheetView UI.

**Tech Stack:** SwiftUI, Core Data, CloudKit (CKDatabaseSubscription, CKQuerySubscription), UserNotifications

---

## Task 1: CDActivity Core Data Extensions

**Files:**
- Create: `ListWithMe/Persistence/CDActivity+Extensions.swift`

**Step 1: Create the extensions file**

```swift
import CoreData

extension CDActivity {
    func toActivity() -> Activity {
        Activity(
            id: id ?? UUID(),
            userId: userId ?? "",
            userName: userName ?? "Unknown",
            action: ActivityAction(rawValue: action ?? "added") ?? .added,
            itemText: itemText,
            timestamp: timestamp ?? Date()
        )
    }

    static func create(from activity: Activity, list: CDList, context: NSManagedObjectContext) -> CDActivity {
        let cdActivity = CDActivity(context: context)
        cdActivity.id = activity.id
        cdActivity.userId = activity.userId
        cdActivity.userName = activity.userName
        cdActivity.action = activity.action.rawValue
        cdActivity.itemText = activity.itemText
        cdActivity.timestamp = activity.timestamp
        cdActivity.list = list
        return cdActivity
    }

    static func fetchAll(for listId: UUID, context: NSManagedObjectContext) -> [CDActivity] {
        let request: NSFetchRequest<CDActivity> = CDActivity.fetchRequest()
        request.predicate = NSPredicate(format: "list.id == %@", listId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDActivity.timestamp, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Persistence/CDActivity+Extensions.swift
git commit -m "feat: add CDActivity Core Data extensions"
```

---

## Task 2: Update Activity Model with Initializer

**Files:**
- Modify: `ListWithMe/Models/ListModels.swift`

**Step 1: Update Activity struct to support Core Data conversion**

Add a new initializer to the Activity struct:

```swift
struct Activity: Identifiable {
    let id: UUID
    let userId: String
    let userName: String
    let action: ActivityAction
    let itemText: String?
    let timestamp: Date

    // Existing initializer for creating new activities
    init(userId: String, userName: String, action: ActivityAction, itemText: String? = nil) {
        self.id = UUID()
        self.userId = userId
        self.userName = userName
        self.action = action
        self.itemText = itemText
        self.timestamp = Date()
    }

    // New initializer for Core Data conversion
    init(id: UUID, userId: String, userName: String, action: ActivityAction, itemText: String?, timestamp: Date) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.action = action
        self.itemText = itemText
        self.timestamp = timestamp
    }
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Models/ListModels.swift
git commit -m "feat: add Activity initializer for Core Data conversion"
```

---

## Task 3: Add Activity Recording to ListService

**Files:**
- Modify: `ListWithMe/Services/ListService.swift`

**Step 1: Add activity recording methods**

Add these methods and modify existing methods in ListService:

```swift
// Add property for current user
var currentUserId: String = ""
var currentUserName: String = ""

// MARK: - Activity Operations

func recordActivity(for listId: UUID, action: ActivityAction, itemText: String? = nil) {
    guard let cdList = CDList.fetch(id: listId, context: context) else { return }

    let activity = Activity(
        userId: currentUserId,
        userName: currentUserName,
        action: action,
        itemText: itemText
    )
    _ = CDActivity.create(from: activity, list: cdList, context: context)
    saveContext()
}

func getActivities(for listId: UUID) -> [Activity] {
    return CDActivity.fetchAll(for: listId, context: context).map { $0.toActivity() }
}
```

**Step 2: Update item operations to record activities**

Modify `addItem` method:

```swift
func addItem(to listId: UUID, text: String, createdBy: String) {
    guard let cdList = CDList.fetch(id: listId, context: context) else { return }

    let item = ListItem(text: text, createdBy: createdBy)
    _ = CDListItem.create(from: item, list: cdList, context: context)

    // Record activity
    recordActivity(for: listId, action: .added, itemText: text)

    saveContext()
    fetchLists()
}
```

Modify `deleteItem` method to accept listId parameter and record activity:

```swift
func deleteItem(_ item: ListItem, from listId: UUID) {
    guard let cdItem = CDListItem.fetch(id: item.id, context: context) else { return }

    // Record activity before deleting
    recordActivity(for: listId, action: .deleted, itemText: item.text)

    context.delete(cdItem)
    saveContext()
    fetchLists()
}
```

Modify `toggleItemComplete` to record activity:

```swift
func toggleItemComplete(_ item: ListItem, in listId: UUID, by userId: String) {
    var updatedItem = item
    let action: ActivityAction
    if item.isComplete {
        updatedItem.markIncomplete(by: userId)
        action = .uncompleted
    } else {
        updatedItem.markComplete(by: userId)
        action = .completed
    }

    // Record activity
    recordActivity(for: listId, action: action, itemText: item.text)

    updateItem(updatedItem, in: listId)
}
```

**Step 3: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ListWithMe/Services/ListService.swift
git commit -m "feat: add activity recording to ListService"
```

---

## Task 4: Create ActivityFeedView

**Files:**
- Create: `ListWithMe/Views/ActivityFeedView.swift`

**Step 1: Create the activity feed view**

```swift
import SwiftUI

struct ActivityFeedView: View {
    let activities: [Activity]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    emptyState
                } else {
                    activityList
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var emptyState: View {
        ContentUnavailableView(
            "No Activity Yet",
            systemImage: "clock.arrow.circlepath",
            description: Text("Activity will appear here as people make changes to the list.")
        )
    }

    private var activityList: some View {
        List {
            ForEach(groupedActivities, id: \.0) { date, activities in
                Section(header: Text(formatSectionDate(date))) {
                    ForEach(activities) { activity in
                        ActivityRow(activity: activity)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var groupedActivities: [(Date, [Activity])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activities) { activity in
            calendar.startOfDay(for: activity.timestamp)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 12) {
            activityIcon
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(activityDescription)
                    .font(.subheadline)

                Text(activity.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var activityIcon: some View {
        Image(systemName: iconName)
    }

    private var iconName: String {
        switch activity.action {
        case .added: return "plus.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .uncompleted: return "circle"
        case .edited: return "pencil.circle.fill"
        case .deleted: return "trash.circle.fill"
        case .joined: return "person.badge.plus"
        }
    }

    private var iconColor: Color {
        switch activity.action {
        case .added: return .blue
        case .completed: return .green
        case .uncompleted: return .orange
        case .edited: return .purple
        case .deleted: return .red
        case .joined: return .teal
        }
    }

    private var activityDescription: AttributedString {
        var result = AttributedString()

        var name = AttributedString(activity.userName)
        name.font = .subheadline.weight(.semibold)
        result.append(name)

        let actionText: String
        switch activity.action {
        case .added:
            actionText = " added "
        case .completed:
            actionText = " completed "
        case .uncompleted:
            actionText = " unchecked "
        case .edited:
            actionText = " edited "
        case .deleted:
            actionText = " deleted "
        case .joined:
            actionText = " joined the list"
        }
        result.append(AttributedString(actionText))

        if let itemText = activity.itemText {
            var item = AttributedString("\"\(itemText)\"")
            item.foregroundColor = .primary
            result.append(item)
        }

        return result
    }
}

#Preview {
    ActivityFeedView(activities: [
        Activity(userId: "1", userName: "Alice", action: .added, itemText: "Milk"),
        Activity(userId: "2", userName: "Bob", action: .completed, itemText: "Bread"),
        Activity(userId: "1", userName: "Alice", action: .deleted, itemText: "Eggs")
    ])
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Views/ActivityFeedView.swift
git commit -m "feat: add ActivityFeedView for displaying list history"
```

---

## Task 5: Add Activity Button to ListDetailView

**Files:**
- Modify: `ListWithMe/Views/ListDetailView.swift`

**Step 1: Read current ListDetailView implementation**

Read the file to understand current structure before modifying.

**Step 2: Add activity sheet state and toolbar button**

Add state property:

```swift
@State private var showActivitySheet = false
```

Add toolbar button for activity:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            showActivitySheet = true
        } label: {
            Image(systemName: "clock.arrow.circlepath")
        }
    }
}
```

Add sheet modifier:

```swift
.sheet(isPresented: $showActivitySheet) {
    ActivityFeedView(activities: listService.getActivities(for: list.id))
}
```

**Step 3: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ListWithMe/Views/ListDetailView.swift
git commit -m "feat: add activity feed button to ListDetailView"
```

---

## Task 6: Create Participant Model

**Files:**
- Modify: `ListWithMe/Models/ListModels.swift`

**Step 1: Add Participant struct**

Add at end of file:

```swift
struct Participant: Identifiable, Hashable {
    let id: String  // CloudKit user ID
    var displayName: String
    var isActive: Bool
    var lastSeen: Date

    init(id: String, displayName: String, isActive: Bool = false, lastSeen: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.isActive = isActive
        self.lastSeen = lastSeen
    }

    var initials: String {
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Models/ListModels.swift
git commit -m "feat: add Participant model for presence tracking"
```

---

## Task 7: Create CollaborationService

**Files:**
- Create: `ListWithMe/Services/CollaborationService.swift`

**Step 1: Create the collaboration service**

```swift
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
        fetchCurrentUser()
    }

    // MARK: - User Identity

    private func fetchCurrentUser() {
        container.fetchUserRecordID { [weak self] recordID, error in
            guard let self = self, let recordID = recordID else { return }
            self.currentUserId = recordID.recordName

            self.container.discoverUserIdentity(withUserRecordID: recordID) { identity, error in
                if let identity = identity,
                   let nameComponents = identity.nameComponents {
                    let formatter = PersonNameComponentsFormatter()
                    DispatchQueue.main.async {
                        self.currentUserName = formatter.string(from: nameComponents)
                    }
                }
            }
        }
    }

    // MARK: - Presence

    func startPresenceUpdates(for listId: UUID) {
        // Initial presence update
        updatePresence(for: listId)

        // Update every 30 seconds
        let timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updatePresence(for: listId)
        }
        presenceTimers[listId] = timer
    }

    func stopPresenceUpdates(for listId: UUID) {
        presenceTimers[listId]?.invalidate()
        presenceTimers.removeValue(forKey: listId)
    }

    private func updatePresence(for listId: UUID) {
        let database = container.sharedCloudDatabase

        // Create or update presence record
        let recordID = CKRecord.ID(recordName: "presence_\(listId.uuidString)_\(currentUserId)")
        let record = CKRecord(recordType: "Presence", recordID: recordID)
        record["listId"] = listId.uuidString
        record["userId"] = currentUserId
        record["userName"] = currentUserName
        record["lastSeen"] = Date()

        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.modifyRecordsResultBlock = { result in
            // Presence update complete
        }
        database.add(operation)

        // Fetch active participants
        fetchActiveParticipants(for: listId)
    }

    private func fetchActiveParticipants(for listId: UUID) {
        let database = container.sharedCloudDatabase

        // Query for presence records updated in last 2 minutes
        let cutoff = Date().addingTimeInterval(-120)
        let predicate = NSPredicate(format: "listId == %@ AND lastSeen > %@", listId.uuidString, cutoff as NSDate)
        let query = CKQuery(recordType: "Presence", predicate: predicate)

        database.perform(query, inZoneWith: nil) { [weak self] records, error in
            guard let self = self, let records = records else { return }

            let participants = records.compactMap { record -> Participant? in
                guard let userId = record["userId"] as? String,
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

            DispatchQueue.main.async {
                self.participantsByList[listId] = participants
            }
        }
    }

    func getParticipants(for listId: UUID) -> [Participant] {
        return participantsByList[listId] ?? []
    }
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Services/CollaborationService.swift
git commit -m "feat: add CollaborationService for presence tracking"
```

---

## Task 8: Create ParticipantsView

**Files:**
- Create: `ListWithMe/Views/ParticipantsView.swift`

**Step 1: Create the participants view component**

```swift
import SwiftUI

struct ParticipantsView: View {
    let participants: [Participant]
    let maxVisible: Int

    init(participants: [Participant], maxVisible: Int = 3) {
        self.participants = participants
        self.maxVisible = maxVisible
    }

    var body: some View {
        HStack(spacing: -8) {
            ForEach(visibleParticipants) { participant in
                ParticipantAvatar(participant: participant)
            }

            if overflowCount > 0 {
                overflowBadge
            }
        }
    }

    private var visibleParticipants: [Participant] {
        Array(participants.prefix(maxVisible))
    }

    private var overflowCount: Int {
        max(0, participants.count - maxVisible)
    }

    private var overflowBadge: some View {
        Text("+\(overflowCount)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(Color.gray)
            .clipShape(Circle())
            .overlay(Circle().stroke(.background, lineWidth: 2))
    }
}

struct ParticipantAvatar: View {
    let participant: Participant

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor)
                .frame(width: 28, height: 28)

            Text(participant.initials)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)

            if participant.isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(.background, lineWidth: 1.5))
                    .offset(x: 10, y: 10)
            }
        }
        .overlay(Circle().stroke(.background, lineWidth: 2))
    }

    private var avatarColor: Color {
        // Generate consistent color from user ID
        let hash = participant.id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
}

#Preview {
    VStack(spacing: 20) {
        ParticipantsView(participants: [
            Participant(id: "1", displayName: "Alice Smith", isActive: true),
            Participant(id: "2", displayName: "Bob Jones", isActive: false),
            Participant(id: "3", displayName: "Carol White", isActive: true)
        ])

        ParticipantsView(participants: [
            Participant(id: "1", displayName: "Alice", isActive: true),
            Participant(id: "2", displayName: "Bob", isActive: true),
            Participant(id: "3", displayName: "Carol", isActive: false),
            Participant(id: "4", displayName: "Dan", isActive: true),
            Participant(id: "5", displayName: "Eve", isActive: false)
        ])
    }
    .padding()
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Views/ParticipantsView.swift
git commit -m "feat: add ParticipantsView for displaying active collaborators"
```

---

## Task 9: Add Participants to ListDetailView Header

**Files:**
- Modify: `ListWithMe/Views/ListDetailView.swift`

**Step 1: Add CollaborationService and participants display**

Add environment property:

```swift
@Environment(CollaborationService.self) private var collaborationService
```

Add onAppear/onDisappear for presence:

```swift
.onAppear {
    collaborationService.startPresenceUpdates(for: list.id)
}
.onDisappear {
    collaborationService.stopPresenceUpdates(for: list.id)
}
```

Add participants view to header area (in toolbar or custom header):

```swift
ToolbarItem(placement: .topBarLeading) {
    ParticipantsView(participants: collaborationService.getParticipants(for: list.id))
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Views/ListDetailView.swift
git commit -m "feat: add participants display and presence tracking to ListDetailView"
```

---

## Task 10: Inject CollaborationService into App

**Files:**
- Modify: `ListWithMe/ListWithMeApp.swift`

**Step 1: Create and inject CollaborationService**

Add service property:

```swift
@State private var collaborationService = CollaborationService()
```

Add environment modifier to ContentView:

```swift
ContentView()
    .environment(listService)
    .environment(collaborationService)
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/ListWithMeApp.swift
git commit -m "feat: inject CollaborationService into app environment"
```

---

## Task 11: Update MessagesView with CollaborationService

**Files:**
- Modify: `ListWithMe MessagesExtension/MessagesView.swift`

**Step 1: Add CollaborationService to MessagesView**

Update the view to accept and use CollaborationService, passing user info to ListService.

**Step 2: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "ListWithMe MessagesExtension/MessagesView.swift"
git commit -m "feat: integrate CollaborationService into MessagesView"
```

---

## Task 12: Add CloudKit Subscription for Real-Time Updates

**Files:**
- Modify: `ListWithMe/Persistence/PersistenceController.swift`

**Step 1: Add database subscription setup**

Add method to PersistenceController:

```swift
func setupCloudKitSubscriptions() {
    let container = CKContainer(identifier: "iCloud.com.isom.ListWithMe")
    let database = container.sharedCloudDatabase

    // Subscribe to Activity record changes
    let subscription = CKDatabaseSubscription(subscriptionID: "activity-changes")

    let notificationInfo = CKSubscription.NotificationInfo()
    notificationInfo.shouldSendContentAvailable = true
    subscription.notificationInfo = notificationInfo

    let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
    operation.modifySubscriptionsResultBlock = { result in
        switch result {
        case .success:
            print("CloudKit subscription created")
        case .failure(let error):
            print("Failed to create subscription: \(error)")
        }
    }
    database.add(operation)
}
```

Call from init after container setup:

```swift
setupCloudKitSubscriptions()
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Persistence/PersistenceController.swift
git commit -m "feat: add CloudKit subscriptions for real-time sync"
```

---

## Task 13: Add Notification Service

**Files:**
- Create: `ListWithMe/Services/NotificationService.swift`

**Step 1: Create notification service**

```swift
import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func scheduleListUpdateNotification(listName: String, changedBy: String, action: String) {
        let content = UNMutableNotificationContent()
        content.title = listName
        content.body = "\(changedBy) \(action)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Services/NotificationService.swift
git commit -m "feat: add NotificationService for change alerts"
```

---

## Task 14: Request Notification Permissions in App

**Files:**
- Modify: `ListWithMe/ListWithMeApp.swift`

**Step 1: Add notification permission request on launch**

Add task modifier:

```swift
.task {
    _ = await NotificationService.shared.requestAuthorization()
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/ListWithMeApp.swift
git commit -m "feat: request notification permissions on app launch"
```

---

## Task 15: Add New Files to Xcode Project

**Files:**
- Modify: `ListWithMe.xcodeproj/project.pbxproj`

**Step 1: Add all new files to project**

Add PBXFileReference and PBXBuildFile entries for:
- CDActivity+Extensions.swift
- ActivityFeedView.swift
- CollaborationService.swift
- ParticipantsView.swift
- NotificationService.swift

Add files to appropriate PBXGroup and Sources build phases for both targets.

**Step 2: Build to verify all files are included**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe.xcodeproj/project.pbxproj
git commit -m "chore: add Phase 2 files to Xcode project"
```

---

## Task 16: Final Build and Integration Test

**Step 1: Clean build**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' clean build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 2: Verify all Phase 2 features compile**

Check that:
- Activity recording works in ListService
- ActivityFeedView displays activities
- CollaborationService tracks presence
- ParticipantsView shows active users
- NotificationService can send alerts

**Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "feat: complete Phase 2 collaboration depth features"
```

---

## Summary

Phase 2 adds:
1. **Activity Feed** - Full history of all list changes with timestamps
2. **Real-Time Presence** - See who's currently viewing a list
3. **Participant Management** - Avatar display for collaborators
4. **Change Notifications** - Alerts when others modify shared lists

All features integrate with existing Phase 1 foundation using:
- Core Data for activity persistence (synced via CloudKit)
- CloudKit subscriptions for real-time updates
- UserNotifications for background alerts
- SwiftUI views matching existing design patterns
