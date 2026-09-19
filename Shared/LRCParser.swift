import Foundation

enum LRCParser {
    private static let regex = try! NSRegularExpression(pattern: #"\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]"#)

    static func parse(_ lrc: String) -> [LyricLine] {
        var output: [LyricLine] = []
        for raw in lrc.components(separatedBy: .newlines) {
            let ns = raw as NSString
            let range = NSRange(location: 0, length: ns.length)
            let matches = regex.matches(in: raw, range: range)
            guard !matches.isEmpty else { continue }

            let lyricStart = matches.last!.range.location + matches.last!.range.length
            let text = ns.substring(from: lyricStart).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }

            for match in matches {
                let min = Int(ns.substring(with: match.range(at: 1))) ?? 0
                let sec = Int(ns.substring(with: match.range(at: 2))) ?? 0
                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound {
                    let digits = ns.substring(with: match.range(at: 3))
                    fraction = (Double(digits) ?? 0) / pow(10, Double(digits.count))
                }
                output.append(LyricLine(time: Double(min * 60 + sec) + fraction, text: text))
            }
        }
        return output.sorted { $0.time < $1.time }
    }
}
