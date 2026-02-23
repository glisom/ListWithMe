# ListWithMe Modernization Design

## Overview

Complete overhaul of ListWithMe, an iMessage extension for collaborative shopping lists. This design covers modernizing the tech stack, updating the UI to current iOS patterns, and adding collaboration-focused enhancements.

## Goals

- Rewrite from UIKit/Storyboards to SwiftUI
- Target iOS 17+
- Implement CloudKit sync for real-time collaboration
- Polished native design with refined animations and interactions
- Phased enhancement rollout prioritizing collaboration features

---

## Architecture

### App Structure

**Container App + Messages Extension**
- Container app handles CloudKit setup and provides standalone list management
- Messages extension remains the primary interface for sharing/collaborating

### Architecture Pattern: MVVM with @Observable

```
Views → ViewModels → Services → CloudKit/Core Data
```

- `@Observable` classes (iOS 17) for ViewModels
- Dependency injection for testability

### Key Services

| Service | Responsibility |
|---------|----------------|
| `ListService` | CRUD operations, sync management |
| `CollaborationService` | Sharing, activity tracking, presence |
| `MessageService` | Messages framework integration |

---

## Data Models

### List

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Primary identifier |
| `name` | `String` | List name |
| `createdAt` | `Date` | Creation timestamp |
| `createdBy` | `String` | CloudKit user identifier |
| `sortOrder` | `Int` | Manual ordering |
| `category` | `String?` | Future: organization phase |

### ListItem

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Primary identifier |
| `listId` | `UUID` | Parent list reference |
| `text` | `String` | Item content |
| `isComplete` | `Bool` | Completion status |
| `completedAt` | `Date?` | When completed |
| `completedBy` | `String?` | Who completed |
| `createdBy` | `String` | Who created |
| `createdAt` | `Date` | Creation timestamp |
| `modifiedBy` | `String` | Last modifier |
| `modifiedAt` | `Date` | Last modification |
| `sortOrder` | `Int` | Manual ordering |
| `quantity` | `Int?` | Future: item details phase |
| `note` | `String?` | Future: item details phase |

### Activity

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Primary identifier |
| `listId` | `UUID` | Related list |
| `userId` | `String` | Who performed action |
| `userName` | `String` | Display name |
| `action` | `ActivityType` | added, completed, edited, deleted, joined |
| `itemText` | `String?` | Affected item |
| `timestamp` | `Date` | When it happened |

### Participant (Transient)

| Field | Type | Description |
|-------|------|-------------|
| `userId` | `String` | CloudKit user identifier |
| `displayName` | `String` | Display name |
| `isActive` | `Bool` | Currently viewing |
| `lastSeen` | `Date` | Last activity |

---

## UI Structure

### Messages Extension Views

#### ListsView (Compact Mode)
- Grid/list of recent shared lists
- Quick "New List" button
- Tap list → opens in expanded mode

#### ListDetailView (Expanded Mode)
- Editable list name header
- Items in SwiftUI `List` with custom `ListItemRow`
- Swipe actions: complete (leading), delete (trailing)
- Inline editing via tap
- Floating "+" button for new items
- Participant avatars in header
- "Send Update" button

#### ListItemRow
- Animated checkbox (SF Symbol)
- Item text with strikethrough animation on complete
- Initials badge showing last editor
- Quantity badge (future)

#### ActivitySheetView
- Chronological feed with timestamps
- Grouped by time period
- Triggered via header icon

### Container App Views
- Mirror of Messages extension views
- Settings screen (notifications, account)
- Standalone list management

---

## Visual Design

### Color System
- Primary accent: Soft, friendly tint (configurable)
- Semantic colors: Green (complete), red (delete), gray (secondary)
- Full dark mode support

### Typography
- System fonts (SF Pro)
- `.headline` for list names
- `.body` for items
- `.caption` for metadata
- Dynamic Type support

### Polish & Animations
- **Completion**: Spring animation on checkbox, animated strikethrough
- **Swipe actions**: Custom icons, colored backgrounds, haptic feedback
- **Reordering**: Long-press drag handle, smooth transitions
- **Avatars**: Circular, stacked with overlap
- **Presence**: Pulsing dot for active users
- **Empty states**: Friendly illustrations with CTAs

### Haptics
- Light tap: Checkbox toggle
- Medium impact: Swipe action commit
- Success: List shared

### Transitions
- Matched geometry for navigation
- Smooth keyboard avoidance

---

## CloudKit & Collaboration

### Setup
- `NSPersistentCloudKitContainer` for Core Data ↔ CloudKit sync
- Private database for user's lists
- Shared database for collaborative lists via `CKShare`

### Sharing Flow
1. User creates list → stored in private database
2. User sends in Messages → creates `CKShare`, adds recipients
3. Recipients open message → app retrieves via `CKShare.URL`
4. All participants see real-time updates

### Real-time Sync
- `CKDatabaseSubscription` for background notifications
- Silent push triggers sync
- Foreground: automatic merge via `NSPersistentCloudKitContainer`

### Presence Implementation
- Lightweight heartbeat record every 30 seconds
- Query recent presence to show active participants
- Clean up stale records (>2 minutes old)

### Activity Feed
- Write `Activity` records on each action
- Subscription delivers real-time updates
- Local cache for offline viewing

### Conflict Resolution
- Last-writer-wins for simple fields
- CloudKit handles merge automatically

---

## Messages Framework Integration

### Extension Lifecycle
- `MSMessagesAppViewController` hosts SwiftUI via `UIHostingController`
- Handle compact ↔ expanded transitions
- Compact: list picker, Expanded: full detail

### Sending a List
- Compose `MSMessage` with `MSMessageTemplateLayout`
  - `image`: Generated preview (list name + items)
  - `caption`: "List Name • X items"
  - `subcaption`: "Tap to collaborate"
- Attach `CKShare.URL` for CloudKit access
- Insert via `activeConversation?.insert(message)`

### Receiving a List
- Handle `didSelect(_:conversation:)` and `didReceive(_:conversation:)`
- Extract `CKShare.URL` from message
- Accept share via `CKAcceptSharesOperation` (first time)
- Fetch and display shared list

### Message Updates
- Send updated `MSMessage` on list changes
- New message replaces previous (keeps conversation tidy)
- Recipients see latest snapshot before opening

### Transcript Representation
- Rich bubble with generated `UIImage`
- Shows: list name, item count, progress (e.g., "3/7 done")

---

## Phased Implementation

### Phase 1: Foundation & Core (MVP)
- [ ] SwiftUI app structure with Messages extension
- [ ] Core Data + CloudKit setup
- [ ] Basic list CRUD
- [ ] Item management (add, edit, complete, delete, reorder)
- [ ] Messages integration (send/receive)
- [ ] CloudKit sharing (basic collaboration)
- [ ] Who edited/added indicators

### Phase 2: Collaboration Depth
- [ ] Activity feed (full history)
- [ ] Real-time presence
- [ ] Participant management
- [ ] Change notifications

### Phase 3: Organization
- [ ] Categories/sections
- [ ] Sorting options
- [ ] Persistent drag-to-reorder

### Phase 4: Item Details
- [ ] Quantities
- [ ] Notes per item
- [ ] Due dates
- [ ] Priority levels

### Phase 5: Convenience
- [ ] List templates
- [ ] Duplicate list
- [ ] Recently used suggestions
- [ ] Siri Shortcuts

---

## Testing Strategy

### Unit Tests
- ViewModels: State changes, business logic
- Services: Mock CloudKit, test sync
- Models: Encoding/decoding, validation

### UI Tests
- Core flows: Create → add → complete → share
- Messages extension: Send/receive
- Edge cases: Empty states, offline, conflicts

### CloudKit Testing
- Development environment during dev
- Multi-account sharing tests
- Cross-device sync verification

### Manual QA
- Dark mode
- Dynamic Type
- VoiceOver
- Offline → online transitions
- Low connectivity

### TestFlight
- Internal testing first
- Small external group for real collaboration testing
- Monitor CloudKit dashboard

---

## Technical Requirements

- **iOS**: 17.0+
- **Swift**: 5.9+
- **Frameworks**: SwiftUI, Messages, CloudKit, Core Data
- **No external dependencies**
