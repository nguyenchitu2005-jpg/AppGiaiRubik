import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // A tall, phone-like window to start with; it can be resized freely.
    self.title = "Rubik Solver"
    self.setContentSize(NSSize(width: 480, height: 900))
    self.contentMinSize = NSSize(width: 360, height: 480)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
