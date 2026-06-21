import Foundation
import Testing
@testable import PalmierPro

@Suite("AI integration preferences")
@MainActor
struct IntegrationPreferencesTests {

    @Test func integrationsDefaultToDisabled() {
        let defaults = makeDefaults()

        #expect(!ClaudeIntegrationPreferences.isEnabled(in: defaults))
        #expect(!MCPService.isEnabled(in: defaults))
    }

    @Test func integrationsRespectExplicitPreferences() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "io.palmier.pro.claude.enabled")
        defaults.set(true, forKey: "io.palmier.pro.mcp.enabled")

        #expect(ClaudeIntegrationPreferences.isEnabled(in: defaults))
        #expect(MCPService.isEnabled(in: defaults))
    }

    @Test func disabledClaudeIntegrationRejectsChatEntryPoints() {
        let editor = EditorViewModel(claudeIntegrationEnabled: false)
        let asset = MediaAsset(
            id: "asset-video",
            url: URL(fileURLWithPath: "/tmp/interview.mov"),
            type: .video,
            name: "Interview Take",
            duration: 5
        )

        editor.agentService.attachMention(for: asset)
        editor.agentService.newChat()
        editor.agentService.send(text: "Edit this", mentions: [])

        #expect(!editor.agentService.isIntegrationEnabled)
        #expect(!editor.agentService.canStream)
        #expect(editor.agentService.sessions.isEmpty)
        #expect(editor.agentService.mentions.isEmpty)
        #expect(editor.agentService.messages.isEmpty)
        #expect(!editor.agentPanelVisible)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "IntegrationPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
