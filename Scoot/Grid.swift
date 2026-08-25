import Foundation

class Grid {

    /// The underlying data stored in the grid.  (See `index` for details on how grid
    /// coordinates are mapped to this 1-dimensional array.)
    var data: [String] {
        didSet {
            if numCells != data.count {
                data = oldValue
            }
        }
    }

    let numColumns: Int

    let numRows: Int

    let size: CGSize

    let cellWidth: CGFloat

    let cellHeight: CGFloat

    let cellSize: CGSize

    let numCells: Int

    lazy var rects: [CGRect] = {
        var rects = [CGRect]()
        rects.reserveCapacity(numCells)

        let xs = stride(from: 0.0, to: size.width, by: cellWidth)
        let ys = stride(from: 0.0, to: size.height, by: cellHeight)

        for y in ys {
            for x in xs {
                let rect = CGRect(origin: CGPoint(x: x, y: y), size: cellSize)
                rects.append(rect)
            }
        }

        return rects
    }()

    convenience init(gridSize: CGSize, targetCellSize: CGSize) {
        let numRows = Int(floor(gridSize.height / targetCellSize.height))
        let numColumns = Int(floor(gridSize.width / targetCellSize.width))
        self.init(numRows: numRows, numColumns: numColumns, gridSize: gridSize)
    }

    init(numRows: Int, numColumns: Int, gridSize: CGSize) {
        let numCells = numRows * numColumns
        self.size = gridSize
        self.numRows = numRows
        self.numColumns = numColumns
        self.numCells = numCells
        self.cellWidth = gridSize.width / CGFloat(numColumns)
        self.cellHeight = gridSize.height / CGFloat(numRows)
        self.cellSize = CGSize(width: cellWidth, height: cellHeight)
        self.data = (0..<numCells).map { String($0) }
    }

    func data(atX x: Int, y: Int) -> String {
        let index = (y * numColumns) + x
        return data[index]
    }

    func data(atIndex index: Int) -> String {
        return data[index]
    }

    /// Converts grid coordinates into an index in a 1-dimensional array.
    ///
    /// Consider a grid with 6 columns and 4 rows: (x: 0, y: 0) is the is the
    /// bottom-left corner, and (x: 5, y: 3) is the top-right corner. This maps
    /// to the following indices in a 1-dimensional array:
    ///
    /// 18 19 20 21 22 23
    /// 12 13 14 15 16 17
    ///  6  7  8  9 10 11
    ///  0  1  2  3  4  5
    ///
    /// For example, the coordinate (x: 0, y: 0) has an index of 0, and the
    /// coordinate (x: 5, y: 3) has an index of 23.
    internal func index(atX x: Int, y: Int) -> Int {
        (y * numColumns) + x
    }

    /// The inverse of `index`: given the index in a 1-dimensional array,
    /// return the grid coordinates.
    internal func coordinates(atIndex index: Int) -> (x: Int, y: Int) {
        let x = index % self.numColumns
        let y = (index - x) / self.numColumns
        return (x: x, y: y)
    }

}

/// Splits one grid cell into a small grid shaped like the keyboard.
///
/// A grid cell is often larger than the thing you want to click, so the centre
/// of the cell is not always on the target. `RefinementGrid` adds a second
/// step. After you choose a cell, the cell is divided into the same shape as
/// the three letter rows of a QWERTY keyboard, and the key you press is the
/// place the cursor goes. "q" is the top left of the cell, "g" and "h" are the
/// middle, "p" is the top right, and "/" is the bottom right.
///
/// No label is needed to use this. The keyboard is the map.
enum RefinementGrid {

    /// The three letter rows of a QWERTY keyboard, top row first.
    ///
    /// Every row must hold `numColumns` keys.
    static let rows: [[Character]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";"],
        ["z", "x", "c", "v", "b", "n", "m", ",", ".", "/"],
    ]

    static let numColumns = 10

    static var numRows: Int {
        rows.count
    }

    /// The place of `character` on the keyboard, or nil when the character is
    /// not one of the keys above. Row 0 is the top row.
    static func coordinates(of character: Character) -> (column: Int, row: Int)? {
        for (row, keys) in rows.enumerated() {
            if let column = keys.firstIndex(of: character) {
                return (column: column, row: row)
            }
        }
        return nil
    }

    /// The part of `cell` that the key at `column` and `row` selects.
    ///
    /// `cell` is in Cocoa coordinates, where y grows upwards, so the top row of
    /// the keyboard maps to the highest y.
    static func rect(atColumn column: Int, row: Int, in cell: CGRect) -> CGRect {
        let width = cell.width / CGFloat(numColumns)
        let height = cell.height / CGFloat(numRows)

        return CGRect(
            x: cell.minX + (CGFloat(column) * width),
            y: cell.maxY - (CGFloat(row + 1) * height),
            width: width,
            height: height
        )
    }

    /// The part of `cell` that `character` selects, or nil when the character
    /// is not on the layout.
    static func rect(for character: Character, in cell: CGRect) -> CGRect? {
        guard let (column, row) = coordinates(of: character) else {
            return nil
        }

        return rect(atColumn: column, row: row, in: cell)
    }

    /// Every part of `cell`, paired with the key that selects it. Used to draw
    /// the layout over the chosen cell.
    static func cells(in cell: CGRect) -> [(key: Character, rect: CGRect)] {
        var result = [(key: Character, rect: CGRect)]()
        result.reserveCapacity(numRows * numColumns)

        for (row, keys) in rows.enumerated() {
            for (column, key) in keys.enumerated() {
                result.append((key: key, rect: rect(atColumn: column, row: row, in: cell)))
            }
        }

        return result
    }

}
