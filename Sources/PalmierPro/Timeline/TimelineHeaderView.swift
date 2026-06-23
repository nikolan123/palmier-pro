import AppKit
import UniformTypeIdentifiers

/// Fixed track header column drawn to the left of the scrollable timeline.
final class TimelineHeaderView: NSView {
    unowned var editor: EditorViewModel

    private static let headerBg = AppTheme.Background.surface.cgColor
    private static let labelAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: AppTheme.FontSize.sm, weight: .medium),
        .foregroundColor: AppTheme.Text.secondary,
    ]

    /// Rects for mute/hide/sync-lock buttons, indexed by track. Used for hit testing.
    var muteButtonRects: [Int: NSRect] = [:]
    var hideButtonRects: [Int: NSRect] = [:]
    var syncLockButtonRects: [Int: NSRect] = [:]
    var trackMenuButtonRects: [Int: NSRect] = [:]

    init(editor: EditorViewModel) {
        self.editor = editor
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = Self.headerBg
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Background
        ctx.setFillColor(Self.headerBg)
        ctx.fill(bounds)

        let rulerBottom = bounds.origin.y + Layout.rulerHeight - 0.5
        ctx.setFillColor(AppTheme.Border.primary.cgColor)
        ctx.fill(NSRect(x: 0, y: rulerBottom, width: bounds.width, height: 1))

        // Clip drawing below the ruler so headers don't overlap it when scrolled
        let clipTop = bounds.origin.y + Layout.rulerHeight
        ctx.clip(to: NSRect(x: bounds.origin.x, y: clipTop, width: bounds.width, height: bounds.height))

        muteButtonRects.removeAll()
        hideButtonRects.removeAll()
        syncLockButtonRects.removeAll()
        trackMenuButtonRects.removeAll()
        let stripWidth: CGFloat = 3
        let iconSize: CGFloat = 14
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        let headerWidth = bounds.width

        let geo = TimelineGeometry(editor: editor, bounds: bounds)

        for (i, track) in editor.timeline.tracks.enumerated() {
            let y = geo.trackY(at: i)
            let h = geo.trackHeight(at: i)

            // Color-coded left border strip
            ctx.setFillColor(track.type.themeColor.cgColor)
            ctx.fill(NSRect(x: 0, y: y, width: stripWidth, height: h))

            // Track label
            let str = NSAttributedString(string: editor.timelineTrackDisplayLabel(at: i), attributes: Self.labelAttrs)
            let labelSize = str.size()
            let labelY = y + (h - labelSize.height) / 2
            str.draw(at: NSPoint(x: stripWidth + 6, y: labelY))


            let iconY = y + (h - iconSize) / 2
            let rightmostX = headerWidth - iconSize - 6
            let syncX = rightmostX - iconSize - 4
            let menuX = syncX - iconSize - 4

            if track.type != .audio {
                trackMenuButtonRects[i] = drawIconButton(
                    x: menuX, y: iconY, size: iconSize, config: iconConfig, context: ctx,
                    symbol: "ellipsis", active: true
                )
            }
            syncLockButtonRects[i] = drawToggleIcon(
                x: syncX, y: iconY, size: iconSize, config: iconConfig, context: ctx,
                active: track.syncLocked, onSymbol: "link", offSymbol: "personalhotspot.slash"
            )
            if track.type == .audio {
                muteButtonRects[i] = drawToggleIcon(
                    x: rightmostX, y: iconY, size: iconSize, config: iconConfig, context: ctx,
                    active: !track.muted, onSymbol: "speaker.wave.2.fill", offSymbol: "speaker.slash.fill"
                )
            } else {
                hideButtonRects[i] = drawToggleIcon(
                    x: rightmostX, y: iconY, size: iconSize, config: iconConfig, context: ctx,
                    active: !track.hidden, onSymbol: "eye", offSymbol: "eye.slash"
                )
            }

            // White border at top of first track and bottom of every track
            if i == 0 {
                ctx.setFillColor(AppTheme.Border.primary.cgColor)
                ctx.fill(NSRect(x: 0, y: y, width: headerWidth, height: 1))
            }
            let handleY = y + h - 1
            ctx.setFillColor(AppTheme.Border.primary.cgColor)
            ctx.fill(NSRect(x: 0, y: handleY, width: headerWidth, height: 1))
        }

        // Thick divider between the video zone and the audio zone,
        let z = editor.zones
        if z.videoTrackCount > 0, z.audioTrackCount > 0 {
            let dividerY = geo.trackY(at: z.firstAudioIndex)
            ctx.setFillColor(AppTheme.Border.divider.cgColor)
            ctx.fill(NSRect(x: 0, y: dividerY - 1, width: headerWidth, height: 2))
        }
    }

    /// Draw a toggleable SF Symbol button; returns the hit-test rect (padded).
    private func drawToggleIcon(
        x: CGFloat, y: CGFloat, size: CGFloat,
        config: NSImage.SymbolConfiguration, context: CGContext,
        active: Bool, onSymbol: String, offSymbol: String
    ) -> NSRect {
        let rect = NSRect(x: x, y: y, width: size, height: size)
        let tint = active ? AppTheme.Text.secondary : AppTheme.Text.secondary.withAlphaComponent(0.3)
        drawSymbol(active ? onSymbol : offSymbol, in: rect, tint: tint, config: config, context: context)
        return rect.insetBy(dx: -4, dy: -4)
    }

    private func drawIconButton(
        x: CGFloat, y: CGFloat, size: CGFloat,
        config: NSImage.SymbolConfiguration, context: CGContext,
        symbol: String, active: Bool
    ) -> NSRect {
        let rect = NSRect(x: x, y: y, width: size, height: size)
        let tint = active ? AppTheme.Text.secondary : AppTheme.Text.secondary.withAlphaComponent(AppTheme.Opacity.muted)
        drawSymbol(symbol, in: rect, tint: tint, config: config, context: context)
        return rect.insetBy(dx: -4, dy: -4)
    }

    private func drawSymbol(_ name: String, in rect: NSRect, tint: NSColor, config: NSImage.SymbolConfiguration, context: CGContext) {
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }
        let symbolSize = img.size
        let drawRect = NSRect(x: rect.midX - symbolSize.width / 2, y: rect.midY - symbolSize.height / 2, width: symbolSize.width, height: symbolSize.height)
        let tinted = NSImage(size: drawRect.size, flipped: true) { drawRect in
            tint.set()
            img.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            drawRect.fill(using: .sourceAtop)
            return true
        }
        tinted.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    // MARK: - Input handling (mute/hide/resize)

    private var resizeDrag: (trackIndex: Int, originalHeight: CGFloat)?

    private func hitTestResizeHandle(at point: NSPoint) -> Int? {
        let geo = TimelineGeometry(editor: editor, bounds: bounds)
        for i in editor.timeline.tracks.indices {
            let trackBottom = geo.trackY(at: i) + geo.trackHeight(at: i)
            if abs(point.y - trackBottom) <= TrackSize.resizeHandleZone {
                return i
            }
        }
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        for (ti, rect) in muteButtonRects {
            if rect.contains(point) {
                editor.toggleTrackMute(trackIndex: ti)
                needsDisplay = true
                return
            }
        }
        for (ti, rect) in hideButtonRects {
            if rect.contains(point) {
                editor.toggleTrackHidden(trackIndex: ti)
                needsDisplay = true
                return
            }
        }
        for (ti, rect) in syncLockButtonRects {
            if rect.contains(point) {
                editor.toggleTrackSyncLock(trackIndex: ti)
                needsDisplay = true
                return
            }
        }
        for (ti, rect) in trackMenuButtonRects {
            if rect.contains(point) {
                showTrackMenu(trackIndex: ti, at: rect)
                return
            }
        }

        if let ti = hitTestResizeHandle(at: point) {
            resizeDrag = (ti, editor.timeline.tracks[ti].displayHeight)
        }
    }

    private func showTrackMenu(trackIndex: Int, at rect: NSRect) {
        guard editor.timeline.tracks.indices.contains(trackIndex) else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false

        let captionsOnly = NSMenuItem(title: "Export Captions as SRT…", action: #selector(exportTrackSRTCaptionsOnly(_:)), keyEquivalent: "")
        captionsOnly.target = self
        captionsOnly.representedObject = trackIndex
        captionsOnly.isEnabled = !editor.exportSRTCaptions(trackIndex: trackIndex).isEmpty
        menu.addItem(captionsOnly)

        let allText = NSMenuItem(title: "Export All Text as SRT…", action: #selector(exportTrackSRTAllText(_:)), keyEquivalent: "")
        allText.target = self
        allText.representedObject = trackIndex
        allText.isEnabled = !editor.exportSRTCaptions(trackIndex: trackIndex, includeAllText: true).isEmpty
        menu.addItem(allText)

        menu.popUp(positioning: nil, at: NSPoint(x: rect.minX, y: rect.maxY), in: self)
    }

    @objc private func exportTrackSRTCaptionsOnly(_ sender: NSMenuItem) {
        guard let trackIndex = sender.representedObject as? Int else { return }
        exportTrackSRT(trackIndex: trackIndex, includeAllText: false)
    }

    @objc private func exportTrackSRTAllText(_ sender: NSMenuItem) {
        guard let trackIndex = sender.representedObject as? Int else { return }
        exportTrackSRT(trackIndex: trackIndex, includeAllText: true)
    }

    private func exportTrackSRT(trackIndex: Int, includeAllText: Bool) {
        guard editor.timeline.tracks.indices.contains(trackIndex) else { return }
        let captions = editor.exportSRTCaptions(trackIndex: trackIndex, includeAllText: includeAllText)
        guard !captions.isEmpty else {
            presentMessage(includeAllText ? "No text to export." : "No captions to export.")
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "srt") ?? .plainText]
        let projectName = editor.projectURL?.deletingPathExtension().lastPathComponent ?? "Captions"
        panel.nameFieldStringValue = "\(projectName) \(editor.timelineTrackDisplayLabel(at: trackIndex)).srt"
        panel.title = "Export SRT"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                try SRTCaptionCodec.encode(captions).write(to: url, atomically: true, encoding: .utf8)
            } catch {
                self.presentMessage(error.localizedDescription)
            }
        }
    }

    private func presentMessage(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag = resizeDrag else { return }
        let point = convert(event.locationInWindow, from: nil)
        let geo = TimelineGeometry(editor: editor, bounds: bounds)
        let trackTop = geo.trackY(at: drag.trackIndex)
        let newHeight = max(TrackSize.minHeight, min(TrackSize.maxHeight, point.y - trackTop))
        if editor.timeline.tracks[drag.trackIndex].displayHeight != newHeight {
            editor.timeline.tracks[drag.trackIndex].displayHeight = newHeight
            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let drag = resizeDrag else { return }
        let finalHeight = editor.timeline.tracks[drag.trackIndex].displayHeight
        if finalHeight != drag.originalHeight {
            editor.timeline.tracks[drag.trackIndex].displayHeight = drag.originalHeight
            editor.setTrackHeight(trackIndex: drag.trackIndex, height: finalHeight)
        }
        resizeDrag = nil
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if hitTestResizeHandle(at: point) != nil {
            NSCursor.resizeUpDown.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self
        ))
    }
}
