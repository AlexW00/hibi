import EventKit
import EventKitUI
import SwiftUI
import UIKit

struct EventEditorSheet: UIViewControllerRepresentable {
    enum Mode: Identifiable {
        case new(defaultStart: Date)
        case edit(EKEvent)

        var id: String {
            switch self {
            case .new(let date): "new-\(date.timeIntervalSince1970)"
            case .edit(let ek):  "edit-\(ek.eventIdentifier ?? UUID().uuidString)"
            }
        }
    }

    let store: EKEventStore
    let mode: Mode
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.editViewDelegate = context.coordinator

        switch mode {
        case .new(let defaultStart):
            let event = EKEvent(eventStore: store)
            event.startDate = defaultStart
            event.endDate = defaultStart.addingTimeInterval(3600)
            event.calendar = store.defaultCalendarForNewEvents
            controller.event = event
        case .edit(let existing):
            controller.event = existing
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true) { [onDismiss] in
                onDismiss()
            }
        }
    }
}
