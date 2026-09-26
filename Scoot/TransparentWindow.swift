import Cocoa

class TransparentWindow: NSWindow {

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = NSColor.clear

        isOpaque = false
        isMovable = false
        ignoresMouseEvents = true

        styleMask = .borderless
        collectionBehavior = [
            // The window exists on all Spaces simultaneously.
            // This prevents the OS (or tiling window managers) from forcefully
            // moving the window to the current display on activation.
            .canJoinAllSpaces,

            .fullScreenAuxiliary,
            // The window floats in Spaces and hides in Exposé.
            .transient,
        ]
    }
}
