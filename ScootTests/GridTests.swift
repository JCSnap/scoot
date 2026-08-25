import XCTest
@testable import Scoot

class GridTests: XCTestCase {

    let grid = Grid(numRows: 3, numColumns: 4, gridSize: .zero)

    func testIndexing() {
        XCTAssertEqual(grid.index(atX: 0, y: 0), 0)
        XCTAssertEqual(grid.index(atX: 1, y: 0), 1)
        XCTAssertEqual(grid.index(atX: 2, y: 0), 2)
        XCTAssertEqual(grid.index(atX: 3, y: 0), 3)
        XCTAssertEqual(grid.index(atX: 0, y: 1), 4)
        XCTAssertEqual(grid.index(atX: 1, y: 1), 5)
        XCTAssertEqual(grid.index(atX: 2, y: 1), 6)
        XCTAssertEqual(grid.index(atX: 3, y: 1), 7)
        XCTAssertEqual(grid.index(atX: 0, y: 2), 8)
        XCTAssertEqual(grid.index(atX: 1, y: 2), 9)
        XCTAssertEqual(grid.index(atX: 2, y: 2), 10)
        XCTAssertEqual(grid.index(atX: 3, y: 2), 11)
    }

    func testInverseIndexing() {
        XCTAssertEqual(grid.coordinates(atIndex: 0).x, 0)
        XCTAssertEqual(grid.coordinates(atIndex: 0).y, 0)

        XCTAssertEqual(grid.coordinates(atIndex: 1).x, 1)
        XCTAssertEqual(grid.coordinates(atIndex: 1).y, 0)

        XCTAssertEqual(grid.coordinates(atIndex: 2).x, 2)
        XCTAssertEqual(grid.coordinates(atIndex: 2).y, 0)

        XCTAssertEqual(grid.coordinates(atIndex: 3).x, 3)
        XCTAssertEqual(grid.coordinates(atIndex: 3).y, 0)

        XCTAssertEqual(grid.coordinates(atIndex: 4).x, 0)
        XCTAssertEqual(grid.coordinates(atIndex: 4).y, 1)

        XCTAssertEqual(grid.coordinates(atIndex: 5).x, 1)
        XCTAssertEqual(grid.coordinates(atIndex: 5).y, 1)

        XCTAssertEqual(grid.coordinates(atIndex: 6).x, 2)
        XCTAssertEqual(grid.coordinates(atIndex: 6).y, 1)

        XCTAssertEqual(grid.coordinates(atIndex: 7).x, 3)
        XCTAssertEqual(grid.coordinates(atIndex: 7).y, 1)

        XCTAssertEqual(grid.coordinates(atIndex: 8).x, 0)
        XCTAssertEqual(grid.coordinates(atIndex: 8).y, 2)

        XCTAssertEqual(grid.coordinates(atIndex: 9).x, 1)
        XCTAssertEqual(grid.coordinates(atIndex: 9).y, 2)

        XCTAssertEqual(grid.coordinates(atIndex: 10).x, 2)
        XCTAssertEqual(grid.coordinates(atIndex: 10).y, 2)

        XCTAssertEqual(grid.coordinates(atIndex: 11).x, 3)
        XCTAssertEqual(grid.coordinates(atIndex: 11).y, 2)
    }

    func testInitialization() {
        let numRows = 3
        let numColumns = 4
        let gridSize = CGSize(width: 200, height: 400)

        let grid = Grid(numRows: numRows, numColumns: numColumns, gridSize: gridSize)

        XCTAssertEqual(grid.numCells, numRows*numColumns)
        XCTAssertEqual(grid.cellWidth, gridSize.width/CGFloat(numColumns))
        XCTAssertEqual(grid.cellHeight, gridSize.height/CGFloat(numRows))
        XCTAssertEqual(
            grid.cellSize,
            CGSize(
                width: gridSize.width/CGFloat(numColumns),
                height: gridSize.height/CGFloat(numRows))
        )
    }

    func testInitializationViaTargetCellSizing() {
        let gridSize = CGSize(width: 200, height: 440)

        // This target size evenly divides the grid size, in both dimensions.
        var targetCellSize = CGSize(width: 20, height: 40)

        var grid = Grid(gridSize: gridSize, targetCellSize: targetCellSize)

        XCTAssertEqual(grid.numColumns, 10)

        XCTAssertEqual(grid.numRows, 11)

        XCTAssertEqual(grid.cellSize, targetCellSize)

        // This target size doesn't evenly divide the grid size, in either dimension.
        targetCellSize = CGSize(width: 30, height: 30)

        grid = Grid(gridSize: gridSize, targetCellSize: targetCellSize)

        XCTAssertEqual(grid.numColumns, 6)
        XCTAssertEqual(grid.numRows, 14)

        XCTAssertEqual(grid.cellSize, CGSize(
                        width: gridSize.width/CGFloat(6),
                        height: gridSize.height/CGFloat(14)))
    }

    func testRectGeneration() {
        let numRows = 3
        let numColumns = 2
        let gridSize = CGSize(width: 200, height: 90)

        let grid = Grid(numRows: numRows, numColumns: numColumns, gridSize: gridSize)

        XCTAssertEqual(grid.rects, [
            CGRect(x: 0, y: 0, width: 100, height: 30),
            CGRect(x: 100, y: 0, width: 100, height: 30),
            CGRect(x: 0, y: 30, width: 100, height: 30),
            CGRect(x: 100, y: 30, width: 100, height: 30),
            CGRect(x: 0, y: 60, width: 100, height: 30),
            CGRect(x: 100, y: 60, width: 100, height: 30),
        ])
    }

    func testDataAssignment() {
        let numRows = 3
        let numColumns = 2
        let numCells = numRows * numColumns

        let grid = Grid(numRows: numRows, numColumns: numColumns, gridSize: .zero)

        grid.data = (0..<numCells).map { String($0 * $0) }

        let expected = ["0", "1", "4", "9", "16", "25"]

        XCTAssertEqual(grid.data, expected)

        // Too many items; grid.data shouldn't change.
        grid.data = (0..<numCells+1).map { String($0) }
        XCTAssertEqual(grid.data, expected)

        // Too few items; grid.data shouldn't change.
        grid.data = (0..<numCells-1).map { String($0) }
        XCTAssertEqual(grid.data, expected)

        // Now, grid.data should change (correct number of items in array).
        grid.data = (0..<numCells).map { String($0) }
        XCTAssertEqual(grid.data, ["0", "1", "2", "3", "4", "5"])
    }

}

class RefinementGridTests: XCTestCase {

    // A cell 100 wide and 30 tall makes every sub-cell exactly 10 by 10.
    let cell = CGRect(x: 0, y: 0, width: 100, height: 30)

    func testEveryRowHoldsTheSameNumberOfKeys() {
        for row in RefinementGrid.rows {
            XCTAssertEqual(row.count, RefinementGrid.numColumns)
        }
    }

    func testEveryKeyAppearsOnce() {
        let keys = RefinementGrid.rows.flatMap { $0 }
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testTopLeftKeyMapsToTheTopLeftOfTheCell() {
        // Cocoa coordinates: y grows upwards, so the top row has the highest y.
        let rect = RefinementGrid.rect(for: "q", in: cell)
        XCTAssertEqual(rect, CGRect(x: 0, y: 20, width: 10, height: 10))
    }

    func testHomeRowMiddleKeysMapToTheMiddleOfTheCell() {
        XCTAssertEqual(RefinementGrid.rect(for: "g", in: cell),
                       CGRect(x: 40, y: 10, width: 10, height: 10))
        XCTAssertEqual(RefinementGrid.rect(for: "h", in: cell),
                       CGRect(x: 50, y: 10, width: 10, height: 10))
    }

    func testTopRightKeyMapsToTheTopRightOfTheCell() {
        XCTAssertEqual(RefinementGrid.rect(for: "p", in: cell),
                       CGRect(x: 90, y: 20, width: 10, height: 10))
    }

    func testBottomRightKeyMapsToTheBottomRightOfTheCell() {
        XCTAssertEqual(RefinementGrid.rect(for: "/", in: cell),
                       CGRect(x: 90, y: 0, width: 10, height: 10))
    }

    func testKeyThatIsNotOnTheLayoutHasNoRect() {
        XCTAssertNil(RefinementGrid.rect(for: "1", in: cell))
        XCTAssertNil(RefinementGrid.coordinates(of: "1"))
    }

    func testEveryCellIsInsideTheChosenCell() {
        let offset = CGRect(x: 512, y: 384, width: 85, height: 61)

        let cells = RefinementGrid.cells(in: offset)

        XCTAssertEqual(cells.count, RefinementGrid.numColumns * RefinementGrid.numRows)

        for (_, rect) in cells {
            XCTAssertTrue(offset.insetBy(dx: -0.001, dy: -0.001).contains(rect))
        }
    }

    func testCellsTileTheChosenCellWithoutOverlap() {
        let cells = RefinementGrid.cells(in: cell)
        let totalArea = cells.reduce(0.0) { $0 + ($1.rect.width * $1.rect.height) }
        XCTAssertEqual(totalArea, cell.width * cell.height, accuracy: 0.001)
    }

}
