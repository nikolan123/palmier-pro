import SwiftUI

/// Left-dock panel that hosts the Media and Captions tabs.
struct MediaPanelView: View {
    @Environment(EditorViewModel.self) private var editor
    @State private var panelTab: PanelTab = .media

    enum PanelTab: String, CaseIterable {
        case media = "Media", captions = "Captions"
        var icon: String {
            switch self {
            case .media: "folder"
            case .captions: "captions.bubble"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            panelTabRail
                .layoutPriority(1)
                .zIndex(1)
            Group {
                switch panelTab {
                case .media: MediaTab()
                case .captions: CaptionTab()
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .zIndex(0)
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(AppTheme.Border.primaryColor).frame(width: AppTheme.BorderWidth.hairline)
        }
        .onChange(of: editor.mediaPanelShowMediaTabTick) { _, _ in
            withAnimation(.easeInOut(duration: AppTheme.Anim.transition)) { panelTab = .media }
        }
    }

    private var panelTabRail: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                panelTabButton(tab)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, AppTheme.Spacing.sm)
        .frame(
            minWidth: AppTheme.MediaPanel.tabRailWidth,
            idealWidth: AppTheme.MediaPanel.tabRailWidth,
            maxWidth: AppTheme.MediaPanel.tabRailWidth
        )
        .frame(maxHeight: .infinity, alignment: .top)
        .fixedSize(horizontal: true, vertical: false)
        .background(AppTheme.Background.raisedColor)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppTheme.Border.primaryColor)
                .frame(width: AppTheme.BorderWidth.hairline)
        }
    }

    private func panelTabButton(_ tab: PanelTab) -> some View {
        let selected = panelTab == tab
        return Button {
            withAnimation(.easeInOut(duration: AppTheme.Anim.transition)) { panelTab = tab }
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: AppTheme.FontSize.md, weight: selected ? AppTheme.FontWeight.semibold : AppTheme.FontWeight.medium))
                .foregroundStyle(selected ? AppTheme.Text.primaryColor : AppTheme.Text.tertiaryColor)
                .frame(width: AppTheme.IconSize.lg, height: AppTheme.IconSize.lg)
                .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                .hoverHighlight(cornerRadius: AppTheme.Radius.sm, isActive: selected)
                .overlay(alignment: .leading) {
                    if selected {
                        Capsule()
                            .fill(AppTheme.Border.primaryColor)
                            .frame(width: AppTheme.BorderWidth.thick, height: AppTheme.IconSize.sm)
                    }
                }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(tab.rawValue)
        .accessibilityLabel(tab.rawValue)
    }
}
