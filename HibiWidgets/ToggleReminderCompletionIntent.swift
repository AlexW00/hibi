import AppIntents
import EventKit
import Foundation
import WidgetKit

/// Tapped on a reminder pill's checkbox in the Schedule widget.
///
/// Runs in the widget extension process (no app launch). Resolves the
/// `EKReminder` by `calendarItemIdentifier`, flips `isCompleted`, saves it
/// back through `EKEventStore`. To paper over the EventKit ↔ App Group
/// round-trip latency, the snapshot is also updated optimistically before
/// asking WidgetKit to reload — otherwise the checkbox would visually lag
/// until the host app foregrounds and rewrites the snapshot from its
/// `EKEventStoreChanged` observer.
struct ToggleReminderCompletionIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Reminder"
    static var description = IntentDescription("Mark a reminder complete or incomplete from the widget.")
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Reminder ID")
    var reminderID: String

    init() {
        self.reminderID = ""
    }

    init(reminderID: String) {
        self.reminderID = reminderID
    }

    func perform() async throws -> some IntentResult {
        guard !reminderID.isEmpty else { return .result() }
        guard PlusEntitlementStore().isPlus else { return .result() }
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            return .result()
        }

        let store = EKEventStore()
        if let item = store.calendarItem(withIdentifier: reminderID) as? EKReminder {
            item.isCompleted.toggle()
            try? store.save(item, commit: true)
        }

        // Optimistic snapshot update so the new state appears on the very
        // next timeline reload, without waiting for the main app to observe
        // the EventKit change and rewrite the snapshot.
        if let data = AppGroup.defaults?.data(forKey: AppGroup.Key.eventsSnapshot),
           let snapshot = try? JSONDecoder().decode(WidgetEventsSnapshot.self, from: data) {
            let updated = snapshot.togglingReminderCompletion(identifier: reminderID)
            if let encoded = try? JSONEncoder().encode(updated) {
                AppGroup.defaults?.set(encoded, forKey: AppGroup.Key.eventsSnapshot)
            }
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "EventsWidget")
        return .result()
    }
}
