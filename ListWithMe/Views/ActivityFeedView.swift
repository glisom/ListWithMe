import SwiftUI

struct ActivityFeedView: View {
    let activities: [Activity]
    @Environment(\.dismiss) private var dismiss

    private var groupedActivities: [(String, [Activity])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activities) { activity -> String in
            if calendar.isDateInToday(activity.timestamp) {
                return "Today"
            } else if calendar.isDateInYesterday(activity.timestamp) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter.string(from: activity.timestamp)
            }
        }

        // Sort groups by most recent first
        return grouped.sorted { first, second in
            guard let firstActivity = first.value.first,
                  let secondActivity = second.value.first else {
                return false
            }
            return firstActivity.timestamp > secondActivity.timestamp
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    ContentUnavailableView(
                        "No Activity",
                        systemImage: "clock.badge.questionmark",
                        description: Text("Activity will appear here as you and others make changes to the list.")
                    )
                } else {
                    List {
                        ForEach(groupedActivities, id: \.0) { section in
                            Section(header: Text(section.0)) {
                                ForEach(section.1) { activity in
                                    ActivityRow(activity: activity)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ActivityRow: View {
    let activity: Activity

    private var iconName: String {
        switch activity.action {
        case .added:
            return "plus.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .uncompleted:
            return "circle"
        case .edited:
            return "pencil.circle.fill"
        case .deleted:
            return "trash.circle.fill"
        case .joined:
            return "person.badge.plus"
        }
    }

    private var iconColor: Color {
        switch activity.action {
        case .added:
            return .blue
        case .completed:
            return .green
        case .uncompleted:
            return .orange
        case .edited:
            return .purple
        case .deleted:
            return .red
        case .joined:
            return .teal
        }
    }

    private var descriptionText: String {
        let actionText: String
        switch activity.action {
        case .added:
            actionText = "added"
        case .completed:
            actionText = "completed"
        case .uncompleted:
            actionText = "uncompleted"
        case .edited:
            actionText = "edited"
        case .deleted:
            actionText = "deleted"
        case .joined:
            actionText = "joined"
        }

        if let itemText = activity.itemText {
            return "\(activity.userName) \(actionText) \(itemText)"
        } else {
            return "\(activity.userName) \(actionText)"
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: activity.timestamp)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(descriptionText)
                    .font(.body)

                Text(timeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ActivityFeedView(activities: [
        Activity(id: UUID(), userId: "user1", userName: "John", action: .added, itemText: "Milk", timestamp: Date()),
        Activity(id: UUID(), userId: "user2", userName: "Jane", action: .completed, itemText: "Bread", timestamp: Date().addingTimeInterval(-3600)),
        Activity(id: UUID(), userId: "user1", userName: "John", action: .joined, itemText: nil, timestamp: Date().addingTimeInterval(-86400)),
        Activity(id: UUID(), userId: "user2", userName: "Jane", action: .deleted, itemText: "Eggs", timestamp: Date().addingTimeInterval(-172800))
    ])
}
