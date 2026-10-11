import Foundation
import CoreGraphics

@main
struct SmokeTests {
    static func main() {
        let strangePath = "/tmp/space 'quote' & percent% #hash /🗂"
        let request = ActionRequest(action: .newFile, folder: URL(fileURLWithPath: strangePath))
        let decoded = ActionRequest(url: request.url)!
        precondition(decoded.folder.path == strangePath)
        precondition(decoded.action == .newFile)
        for input in ["https://action?name=copy&folder=/tmp", "pathlet://action?name=unknown&folder=/tmp",
                      "pathlet://action?name=copy&folder=relative", "pathlet://action?name=copy&folder=/%00"] {
            precondition(ActionRequest(url: URL(string: input)!) == nil)
        }
        // A secondary display can have a negative origin; keep every control onscreen.
        let display = CGRect(x: -1440, y: -400, width: 1440, height: 900)
        for window in [CGRect(x: -1800, y: -380, width: 800, height: 600),
                       CGRect(x: -800, y: 0, width: 900, height: 400)] {
            let bar = BarPlacement.frame(below: window, visibleFrame: display)
            precondition(display.contains(bar))
            if window.minY - 46 >= display.minY { precondition(bar.maxY < window.minY) }
            else { precondition(bar.minY >= window.minY) }
        }
        print("PASS: action URL encoding/validation and multi-display bar placement")
    }
}
