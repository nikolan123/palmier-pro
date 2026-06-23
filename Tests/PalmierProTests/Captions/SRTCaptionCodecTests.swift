import Testing
@testable import PalmierPro

@Suite("SRTCaptionCodec")
struct SRTCaptionCodecTests {
    @Test func parsesMultilineCaptionsAndSortsByStartTime() throws {
        let captions = try SRTCaptionCodec.parse("""
        2
        00:00:03,500 --> 00:00:04,000
        Later

        1
        00:00:01.000 --> 00:00:02.250
        Hello
        world
        """)

        #expect(captions == [
            SRTCaption(start: 1.0, end: 2.25, text: "Hello\nworld"),
            SRTCaption(start: 3.5, end: 4.0, text: "Later"),
        ])
    }

    @Test func encodesStandardCommaTimestamps() {
        let encoded = SRTCaptionCodec.encode([
            SRTCaption(start: 1.0, end: 2.25, text: "Hello"),
            SRTCaption(start: 3661.5, end: 3662.75, text: "Later"),
        ])

        #expect(encoded == """
        1
        00:00:01,000 --> 00:00:02,250
        Hello

        2
        01:01:01,500 --> 01:01:02,750
        Later

        """)
    }
}
