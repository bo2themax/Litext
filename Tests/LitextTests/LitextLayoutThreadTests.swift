//
//  Created by Litext Team.
//  Copyright (c) 2026 Litext Team. All rights reserved.
//

@testable import Litext
import Foundation
import Testing

#if canImport(UIKit) && !os(watchOS)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

#if !os(watchOS)

    /// A layout built on a background thread, then handed to the main actor (see
    /// `TextLabel.Layout`'s threads).
    @Suite("Layouts off the main actor")
    struct LitextLayoutThreadTests {
        private static func text(_ index: Int) -> NSAttributedString {
            let font = PlatformFont.systemFont(ofSize: 15)
            let string = NSMutableAttributedString(
                string: "Message \(index): the quick brown fox jumps over the lazy dog, \u{FFFC} and again in another paragraph.\nSecond line.",
                attributes: [.font: font],
            )
            string.addAttribute(.link, value: URL(string: "https://example.com/\(index)")!, range: NSRange(location: 0, length: 7))
            return string
        }

        /// Measures and lays out `string` at `width`: the line count and size it ends with.
        private static func measure(_ string: NSAttributedString, width: CGFloat) -> (size: CGSize, lines: Int) {
            let layout = TextLabel.Layout(attributedString: string)
            let size = layout.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            layout.containerSize = size
            return (size, layout.layoutLines.count)
        }

        @Test func aLayoutBuiltInTheBackgroundMatchesOneBuiltOnTheMainActor() async {
            let background = await Task.detached { Self.measure(Self.text(1), width: 180) }.value
            let main = await MainActor.run { Self.measure(Self.text(1), width: 180) }
            #expect(background.size == main.size)
            #expect(background.lines == main.lines)
            #expect(background.lines > 1)
        }

        @Test func layoutsOnManyThreadsAtOnceDoNotInterfere() async {
            let expected = (0 ..< 64).map { Self.measure(Self.text($0), width: 200) }
            let results = await withTaskGroup(of: (Int, CGSize, Int).self) { group in
                for index in 0 ..< 64 {
                    group.addTask {
                        let result = Self.measure(Self.text(index), width: 200)
                        return (index, result.size, result.lines)
                    }
                }
                var results: [Int: (CGSize, Int)] = [:]
                for await (index, size, lines) in group { results[index] = (size, lines) }
                return results
            }
            for index in 0 ..< 64 {
                #expect(results[index]?.0 == expected[index].size)
                #expect(results[index]?.1 == expected[index].lines)
            }
        }

        @Test func anAttachmentMadeInTheBackgroundReservesItsSpace() async {
            let width: CGFloat = await Task.detached {
                let attachment = TextLabel.Attachment(size: CGSize(width: 40, height: 10), descent: 0)
                let string = NSMutableAttributedString(string: "ab", attributes: [.font: PlatformFont.systemFont(ofSize: 15)])
                let plain = TextLabel.Layout(attributedString: string)
                    .sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width
                string.insert(attachment.attributedStringFromAnyThread(attributes: [.font: PlatformFont.systemFont(ofSize: 15)]), at: 1)
                let withAttachment = TextLabel.Layout(attributedString: string)
                    .sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width
                return withAttachment - plain
            }.value
            #expect(abs(width - 40) < 0.5)
        }
    }

#endif
