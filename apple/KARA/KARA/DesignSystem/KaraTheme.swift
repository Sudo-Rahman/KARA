import Observation
import SwiftUI

@MainActor
@Observable
final class KaraTheme {
    var background = Color("KaraVoid")
    var surface = Color("KaraSurface")
    var ink = Color("KaraInk")
    var muted = Color("KaraMuted")
    var cobalt = Color("KaraCobalt")
    var cobaltBright = Color("KaraCobaltBright")
    var gold = Color("KaraGold")
    var goldBright = Color("KaraGoldBright")

    func displayFont(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("Geologica", size: size, relativeTo: style)
            .weight(.medium)
    }
}

enum KaraSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 48
}
