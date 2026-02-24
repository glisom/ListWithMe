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
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)

            Text("+\(overflowCount)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
    }
}

struct ParticipantAvatar: View {
    let participant: Participant

    var body: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: 32, height: 32)
            .overlay(
                Text(participant.initials)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            )
            .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
            .overlay(alignment: .bottomTrailing) {
                if participant.isActive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 1.5))
                }
            }
    }

    private var avatarColor: Color {
        let hash = participant.id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
}

#Preview {
    VStack(spacing: 20) {
        ParticipantsView(participants: [
            Participant(id: "1", displayName: "John Doe", isActive: true),
            Participant(id: "2", displayName: "Jane Smith", isActive: false),
            Participant(id: "3", displayName: "Bob Wilson", isActive: true)
        ])

        ParticipantsView(participants: [
            Participant(id: "1", displayName: "John Doe", isActive: true),
            Participant(id: "2", displayName: "Jane Smith", isActive: false),
            Participant(id: "3", displayName: "Bob Wilson", isActive: true),
            Participant(id: "4", displayName: "Alice Brown", isActive: false),
            Participant(id: "5", displayName: "Charlie Davis", isActive: true)
        ])
    }
    .padding()
}
