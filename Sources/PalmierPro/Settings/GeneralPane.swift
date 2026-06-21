import SwiftUI

struct GeneralPane: View {
    @State private var confirmBeforeClosingProject = GeneralPreferences.confirmBeforeClosingProject

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            NotificationsPane()

            Divider()
                .overlay(AppTheme.Border.subtleColor)

            SettingsToggleRow(
                title: "Confirm before closing projects",
                subtitle: "Ask before closing a project window.",
                isOn: $confirmBeforeClosingProject
            )
            .onChange(of: confirmBeforeClosingProject) { _, newValue in
                GeneralPreferences.confirmBeforeClosingProject = newValue
            }
        }
    }
}
