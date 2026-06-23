import Foundation

struct SRTCaption: Equatable {
    var start: Double
    var end: Double
    var text: String
}

enum SRTCaptionCodec {
    enum CodecError: LocalizedError {
        case empty
        case noCaptions
        case invalidTimestamp(String)

        var errorDescription: String? {
            switch self {
            case .empty: "The SRT file is empty."
            case .noCaptions: "No captions were found in the SRT file."
            case .invalidTimestamp(let value): "Invalid SRT timestamp: \(value)"
            }
        }
    }

    static func parse(_ text: String) throws -> [SRTCaption] {
        let normalized = text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw CodecError.empty }

        let blocks = normalized.components(separatedBy: "\n\n")
        let captions = try blocks.compactMap(parseBlock)
        guard !captions.isEmpty else { throw CodecError.noCaptions }
        return captions.sorted { $0.start < $1.start }
    }

    static func encode(_ captions: [SRTCaption]) -> String {
        captions.enumerated().map { index, caption in
            """
            \(index + 1)
            \(formatTime(caption.start)) --> \(formatTime(caption.end))
            \(caption.text)
            """
        }
        .joined(separator: "\n\n")
        + "\n"
    }

    private static func parseBlock(_ block: String) throws -> SRTCaption? {
        let lines = block
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { return nil }
        let parts = lines[timingIndex].components(separatedBy: "-->")
        guard parts.count >= 2 else { return nil }
        let startText = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let endText = parts[1]
            .split(separator: " ")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let start = try parseTime(startText)
        let end = try parseTime(endText)
        let text = lines[(timingIndex + 1)...]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard end > start, !text.isEmpty else { return nil }
        return SRTCaption(start: start, end: end, text: text)
    }

    private static func parseTime(_ value: String) throws -> Double {
        let fields = value.replacingOccurrences(of: ".", with: ",").split(separator: ":")
        guard fields.count == 3,
              let hours = Double(fields[0]),
              let minutes = Double(fields[1]) else {
            throw CodecError.invalidTimestamp(value)
        }
        let secondParts = fields[2].split(separator: ",", omittingEmptySubsequences: false)
        guard let seconds = Double(secondParts.first ?? "") else {
            throw CodecError.invalidTimestamp(value)
        }
        let millisText = secondParts.count > 1 ? String(secondParts[1].prefix(3)) : "0"
        guard let millis = Double(millisText.padding(toLength: 3, withPad: "0", startingAt: 0)) else {
            throw CodecError.invalidTimestamp(value)
        }
        return hours * 3600 + minutes * 60 + seconds + millis / 1000
    }

    private static func formatTime(_ seconds: Double) -> String {
        let totalMillis = max(0, Int((seconds * 1000).rounded()))
        let millis = totalMillis % 1000
        let totalSeconds = totalMillis / 1000
        let secs = totalSeconds % 60
        let mins = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        return String(format: "%02d:%02d:%02d,%03d", hours, mins, secs, millis)
    }
}
