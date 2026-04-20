import CalendarPermission
import PermissionsKit
import SwiftUI

struct CalendarAccessPrompt: View {
    let isDenied: Bool
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
                if isDenied {
                    Permission.calendar(access: .full).openSettingPage()
                } else {
                    onRequestAccess()
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
        isDenied ? "Calendar access denied" : "Calendar access needed"
    }

    private var message: LocalizedStringResource {
        isDenied
            ? "Enable full calendar access in Settings to see your events."
            : "Grant access to see and edit your events."
    }

    private var buttonLabel: LocalizedStringResource {
        isDenied ? "Open Settings" : "Grant access"
    }
}
