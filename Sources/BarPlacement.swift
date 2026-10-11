import Foundation
import CoreGraphics

struct BarPlacement {
    static func frame(below window: CGRect, visibleFrame: CGRect) -> CGRect {
        let width = min(max(window.width - 24, 300), 760, visibleFrame.width)
        let height: CGFloat = 40
        let x = min(max(window.midX - width / 2, visibleFrame.minX), visibleFrame.maxX - width)
        let below = window.minY - height - 6
        let y = below >= visibleFrame.minY ? below : max(visibleFrame.minY, window.minY + 8)
        return CGRect(x: x, y: min(y, visibleFrame.maxY - height), width: width, height: height)
    }
}
