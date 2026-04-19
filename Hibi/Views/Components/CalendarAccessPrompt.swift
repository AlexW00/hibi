import EventKit
import SwiftUI
import UIKit

struct CalendarAccessPrompt: View {
    let status: EKAuthorizationStatus
    let onRequestAccess: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                switch status {
                case .notDetermined:
                    onRequestAccess()
                default:
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } label: {
                Text(buttonLabel)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var title: LocalizedStringResource {
        switch status {
        case .notDetermined: "Calendar access needed"
        case .denied, .restricted: "Calendar access denied"
        case .writeOnly: "Full calendar access needed"
        default: "Calendar unavailable"
        }
    }

    private var message: LocalizedStringResource {
        switch status {
        case .notDetermined: "Grant access to see and edit your events."
        case .denied, .restricted: "Enable calendar access in Settings to see your events."
        case .writeOnly: "Enable full calendar access in Settings to see your events."
        default: "Your events can't be loaded right now."
        }
    }

    private var buttonLabel: LocalizedStringResource {
        status == .notDetermined ? "Grant access" : "Open Settings"
    }
}
