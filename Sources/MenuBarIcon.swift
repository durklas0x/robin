import AppKit

enum MenuBarIcon {
    // A template mask stays legible against either menu bar appearance.
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { _ in
            let mask = NSBezierPath()
            mask.move(to: NSPoint(x: 1, y: 12))
            mask.curve(to: NSPoint(x: 11, y: 11), controlPoint1: NSPoint(x: 4, y: 15), controlPoint2: NSPoint(x: 8, y: 13))
            mask.curve(to: NSPoint(x: 21, y: 12), controlPoint1: NSPoint(x: 14, y: 13), controlPoint2: NSPoint(x: 18, y: 15))
            mask.curve(to: NSPoint(x: 16, y: 3), controlPoint1: NSPoint(x: 21, y: 6), controlPoint2: NSPoint(x: 19, y: 3))
            mask.curve(to: NSPoint(x: 11, y: 5), controlPoint1: NSPoint(x: 13, y: 3), controlPoint2: NSPoint(x: 12, y: 5))
            mask.curve(to: NSPoint(x: 6, y: 3), controlPoint1: NSPoint(x: 10, y: 5), controlPoint2: NSPoint(x: 9, y: 3))
            mask.curve(to: NSPoint(x: 1, y: 12), controlPoint1: NSPoint(x: 3, y: 3), controlPoint2: NSPoint(x: 1, y: 6))
            mask.close()
            for center in [6.0, 16.0] {
                mask.move(to: NSPoint(x: center - 3, y: 8))
                mask.curve(to: NSPoint(x: center + 3, y: 8), controlPoint1: NSPoint(x: center - 1, y: 11), controlPoint2: NSPoint(x: center + 1, y: 11))
                mask.curve(to: NSPoint(x: center - 3, y: 8), controlPoint1: NSPoint(x: center + 1, y: 5), controlPoint2: NSPoint(x: center - 1, y: 5))
                mask.close()
            }
            mask.windingRule = .evenOdd
            NSColor.black.setFill()
            mask.fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
