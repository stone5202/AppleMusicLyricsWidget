import SwiftUI

/// App、小工具與即時動態共用的配色，與 App 圖示的紫→粉紅漸層一致。
enum Theme {
    static let accent = Color(red: 1.0, green: 0.30, blue: 0.47)
    static let accentSecondary = Color(red: 0.49, green: 0.23, blue: 0.93)

    static let accentGradient = LinearGradient(
        colors: [accentSecondary, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let background = LinearGradient(
        colors: [
            Color(red: 0.17, green: 0.09, blue: 0.33),
            Color(red: 0.08, green: 0.04, blue: 0.16),
            Color(red: 0.03, green: 0.02, blue: 0.07)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let widgetBackground = LinearGradient(
        colors: [
            Color(red: 0.22, green: 0.11, blue: 0.44),
            Color(red: 0.09, green: 0.04, blue: 0.19)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
