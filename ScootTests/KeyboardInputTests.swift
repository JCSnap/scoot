import AppKit
import XCTest
@testable import Scoot

final class KeyboardInputTests: XCTestCase {
    func testActivationRoutesLabelToInputWindow() throws {
        let delegate = try XCTUnwrap(NSApp.delegate as? AppDelegate)
        let input = delegate.inputWindow
        let previousControllers = delegate.jumpWindowControllers
        delegate.jumpWindowControllers = []
        for screen in NSScreen.screens {
            delegate.spawnJumpWindow(on: screen)
        }
        input.initializeCoreDataStructuresForGridBasedMovement()
        defer {
            delegate.bringToBackground()
            delegate.jumpWindowControllers.forEach { $0.close() }
            delegate.jumpWindowControllers = previousControllers
            input.currentNode = nil
        }

        for _ in 0..<3 {
            delegate.bringToForeground(using: .grid)
            let focused = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in NSApp.isActive && NSApp.keyWindow === input },
                object: nil
            )
            wait(for: [focused], timeout: 3)
            let receiver = try XCTUnwrap(NSApp.keyWindow)
            receiver.sendEvent(try keyEvent("a", window: receiver))
            XCTAssertEqual(input.currentSequence, ["a"])
            delegate.bringToBackground()
            let hidden = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in !NSApp.isActive }, object: nil
            )
            wait(for: [hidden], timeout: 3)
        }
    }

    func testHintWindowCannotTakeKeyboardFocus() throws {
        let delegate = try XCTUnwrap(NSApp.delegate as? AppDelegate)
        let input = delegate.inputWindow
        input.activeJumpMode = .element
        input.treeForElementBasedNavigation = Scoot.Tree(
            candidates: (0..<4).map { CGRect(x: $0 * 20, y: 0, width: 20, height: 20) },
            keys: ["a", "s"]
        )
        defer {
            input.orderOut(nil)
            input.currentNode = nil
        }

        input.makeMain()
        input.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let active = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in NSApp.isActive && NSApp.keyWindow != nil },
            object: nil
        )
        wait(for: [active], timeout: 3)

        let overlay = JumpWindowController.spawn(on: try XCTUnwrap(NSScreen.main))
        defer { overlay.close() }
        overlay.window?.makeKeyAndOrderFront(nil)

        let receiver = try XCTUnwrap(NSApp.keyWindow)
        receiver.sendEvent(try keyEvent("a", window: receiver))
        XCTAssertEqual(input.currentSequence, ["a"])
        XCTAssertTrue(NSApp.keyWindow === input)
        XCTAssertTrue(NSApp.mainWindow === input)
    }

    func testUnmodifiedLabelAdvancesThroughInputWindow() throws {
        let input = KeyboardInputWindow(
            contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false
        )
        input.activeJumpMode = .element
        input.treeForElementBasedNavigation = Scoot.Tree(
            candidates: (0..<4).map { CGRect(x: $0 * 20, y: 0, width: 20, height: 20) },
            keys: ["a", "s"]
        )
        input.sendEvent(try keyEvent("a", window: input))
        XCTAssertEqual(input.currentSequence, ["a"])
    }

    private func keyEvent(_ characters: String, window: NSWindow) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: 0
        ))
    }
}
