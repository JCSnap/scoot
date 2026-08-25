import Cocoa
import OSLog

class KeyboardInputWindow: TransparentWindow {

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear
        delegate = self

        makeFirstResponder(self)
    }

    var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }

    let mouse = Mouse()

    /// The currently-active jump mode, which determines whether element-based
    /// or grid-based navigation is in use.
    var activeJumpMode: JumpMode = .grid {
        didSet {
            currentNode = nil
        }
    }

    /// The decision tree enabling grid-based navigation.
    var treeForGridBasedNavigation: Tree<CGRect>!

    /// The decision tree enabling element-based navigation.
    var treeForElementBasedNavigation: Tree<CGRect>!

    /// The underlying data structure enabling cursor movement via a
    /// character-based decision tree (as determined by the active jump mode).
    var currentTree: Tree<CGRect>? {
        switch activeJumpMode {
        case .grid:
            return treeForGridBasedNavigation
        case .element:
            return treeForElementBasedNavigation
        case .freestyle:
            return nil
        }
    }

    // Non-nil, if the user is in the process of entering a key sequence to
    // navigate via the decision tree.
    var currentNode: Tree<CGRect>.Node<CGRect>? {
        didSet {
            if let currentNode = currentNode {
                currentSequence.append(currentNode.label)
            } else {
                currentSequence = []
            }
            redrawJumpViews()
        }
    }

    // The sequence of characters that the user has entered, when navigating
    // via the decision tree.
    var currentSequence = [Character]()

    /// The grid cell that the user is refining, in Cocoa screen coordinates.
    ///
    /// This is set after a grid cell is chosen, and cleared as soon as the user
    /// presses a key on the refinement layout, or cancels. See
    /// `RefinementGrid`.
    var refinementRect: CGRect? {
        didSet {
            propagateRefinementRect()
        }
    }

    var isRefiningGridCell: Bool {
        refinementRect != nil
    }

    var isWalkingDecisionTree: Bool {
        currentNode != nil
    }

    var isHoldingDownLeftMouseButton = false

    var scrollEventMonitor: Any?

    var scrollEventDebounceTimer: Timer?

    var targetCellSize: CGSize {
        let targetSideLength = UserSettings.shared.targetGridCellSideLength
        return CGSize(width: targetSideLength, height: targetSideLength)
    }

    let numStepsPerCell = CGFloat(6.0)

    /// The screen that the mouse cursor is currently on.
    var activeScreen: NSScreen? {
        mouse.currentScreen
    }

    /// The grid corresponding to the screen that the mouse cursor is currently on.
    var activeGrid: Grid? {
        guard let activeScreen = activeScreen else {
            return nil
        }

        return appDelegate?.jumpWindowController(for: activeScreen)?.viewController.grid
    }

    var stepWidth: CGFloat {
        (activeGrid?.cellWidth ?? targetCellSize.width) / numStepsPerCell
    }

    var stepHeight: CGFloat {
        (activeGrid?.cellHeight ?? targetCellSize.height) / numStepsPerCell
    }

    func initializeCoreDataStructuresForGridBasedMovement() {
        guard let jumpWindowControllers = appDelegate?.jumpWindowControllers else {
            return
        }

        OSLog.main.log("Preparing data structures for grid-based nav")

        var data = [(grid: Grid, screenRects: [CGRect])]()

        for jumpWindowController in jumpWindowControllers {
            guard let screen = jumpWindowController.assignedScreen else {
                return
            }

            let grid = Grid(gridSize: screen.visibleFrame.size,
                            targetCellSize: targetCellSize)

            jumpWindowController.viewController.grid = grid

            // All rects, transformed into screen coordinates. (This
            // transformation is needed to account for cases where multiple
            // screens are connected.)
            let screenRects = grid.rects.map {
                CGRect(
                    x: $0.origin.x + screen.visibleFrame.origin.x,
                    y: $0.origin.y + screen.visibleFrame.origin.y,
                    width: $0.width,
                    height: $0.height
                )
            }

            data.append((grid, screenRects))
        }

        let candidates = data.flatMap { $0.screenRects }

        let tree = Tree(
            candidates: candidates,
            keys: determineAvailableKeys(numCandidates: candidates.count)
        )

        for (n, (grid, _)) in data.enumerated() {
            assert(grid.numCells == grid.rects.count,
                   "grid.numCells \(grid.numCells) != grid.rects.count \(grid.rects.count)")

            let startIndex = data[0..<n].reduce(0, { $0 + $1.grid.numCells })
            let endIndex = startIndex + grid.numCells

            let sequences = tree.sequences[startIndex..<endIndex]

            grid.data = Array(sequences)
        }

        assert(tree.sequences.count == candidates.count)

        self.treeForGridBasedNavigation = tree
    }

    func initializeCoreDataStructuresForElementBasedMovement(of app: NSRunningApplication) {
        guard let jumpWindowControllers = appDelegate?.jumpWindowControllers else {
            return
        }

        OSLog.main.log("Preparing data structures for element-based nav")

        let foundElements = Accessibility
          .getAccessibleElementsForFocusedWindow(of: app)

        // Because Scoot places labels vertically, horizontal congestion is
        // less of an issue in practice. For this reason, add padding in the y
        // direction only (`paddingY`).
        let elements = foundElements
          .reducingCrowding(intersectionThreshold: 0.1, paddingX: 0.0, paddingY: 10.0)

        // Report what crowding removed. Role and frame only: enough to find a
        // missing target on screen, without recording its text.
        let kept = Set(elements.map { $0.frame.debugDescription })

        for element in foundElements where !kept.contains(element.frame.debugDescription) {
            OSLog.main.log("""
                Crowding removed \(element.role.rawValue, privacy: .public) \
                \(element.frame.debugDescription, privacy: .public)
                """)
        }

        OSLog.main.log("""
            Crowding: \(elements.count, privacy: .public) of \
            \(foundElements.count, privacy: .public) elements kept.
            """)

        var data = [(elements: [Accessibility.Element], screenRects: [CGRect])]()

        for jumpWindowController in jumpWindowControllers {
            guard let screen = jumpWindowController.assignedScreen else {
                return
            }

            let elements = elements.filter {
                screen == $0.screen
            }

            let screenRects: [CGRect] = elements.map {
                $0.frame
            }

            data.append((elements, screenRects))
        }

        let candidates = data.flatMap { $0.screenRects }

        let tree = Tree(
            candidates: candidates,
            keys: determineAvailableKeys(numCandidates: candidates.count)
        )

        for (n, (elements, _)) in data.enumerated() {
            let startIndex = data[0..<n].reduce(0, { $0 + $1.elements.count })
            let endIndex = startIndex + elements.count

            let sequences = tree.sequences[startIndex..<endIndex]

            let viewController = jumpWindowControllers[n].viewController
            viewController.elements = Array(zip(elements, sequences))
        }

        self.treeForElementBasedNavigation = tree
    }

    func determineAvailableKeys(numCandidates: Int) -> [Character] {

        let keys: [[Character]] = [
            ["a", "s", "d", "f", "j", "k", "l"],
            ["g", "h"],
            ["q", "w", "e", "r", "u", "i", "o", "p"],
            ["t", "y"],
            ["z", "x", "c", "v", "b", "n", "m"],
        ]

        let selectedKeys: [Character]

        switch numCandidates {
        case 0..<80:
            selectedKeys = keys[0] + keys[1]
        case 80..<200:
            selectedKeys = keys[0] + keys[1] + keys[2]
        case 200..<1400:
            selectedKeys = keys[0] + keys[1] + keys[2] + keys[3]
        default:
            selectedKeys = keys.flatMap { $0 }
        }

        return selectedKeys.filter {
            !UserSettings.shared.keybindingMode.isCharacterSpecial($0)
        }

    }

}
