import Cocoa

class GridView: NSView {

    weak var viewController: JumpViewController!

    func redraw() {
        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let grid = viewController.grid else {
            return
        }

        guard let ctx = NSGraphicsContext.current else {
            return
        }

        ctx.cgContext.setFillColor(
            NSColor.black.withAlphaComponent(
                viewController.gridBackgroundAlphaComponent
            ).cgColor)

        ctx.cgContext.fill(bounds)

        // A cell has been chosen and is being refined. The whole grid is no
        // longer useful, so draw the keyboard layout over that one cell
        // instead. See `RefinementGrid`.
        if let refinementRect = viewController.refinementRect {
            drawRefinement(in: refinementRect, ctx: ctx)
            return
        }

        let cellSize = grid.cellSize

        ctx.cgContext.setStrokeColor(
            UserSettings.shared.primaryColor.withAlphaComponent(
                viewController.gridLineAlphaComponent
            ).cgColor
        )
        ctx.cgContext.setLineWidth(2)

        if UserSettings.shared.showGridLines {
            for x in stride(from: 0.0, to: grid.size.width, by: cellSize.width) {
                ctx.cgContext.move(to: CGPoint(x: x, y: 0))
                ctx.cgContext.addLine(to: CGPoint(x: x, y: grid.size.height))
            }

            for y in stride(from: 0.0, to: grid.size.height, by: cellSize.height) {
                ctx.cgContext.move(to: CGPoint(x: 0, y: y))
                ctx.cgContext.addLine(to: CGPoint(x: grid.size.width, y: y))
            }

            ctx.cgContext.drawPath(using: .stroke)
        }

        guard UserSettings.shared.showGridLabels else {
            return
        }

        let fontSize = UserSettings.shared.gridViewFontSize
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let foregroundColor = UserSettings.shared.primaryColor.withAlphaComponent(
            viewController.gridLabelAlphaComponent
        )

        let attrs: [NSAttributedString.Key: Any]  = [
          .font: font,
          .foregroundColor: foregroundColor,
          .paragraphStyle: paragraphStyle,
//          .strokeWidth: -2.0,
//          .strokeColor: NSColor.black,
        ]

        let currentSequence = String(viewController.keyboardInputWindow?.currentSequence ?? [])

        for (index, cellRect) in grid.rects.enumerated() {

            let text = grid.data(atIndex: index)
            let string = NSMutableAttributedString(string: text)

            string.addAttributes(attrs, range: NSRange(text.startIndex..., in: text))

            if !currentSequence.isEmpty {
                if let range = text.range(of: currentSequence),
                   text.distance(from: text.startIndex, to: range.lowerBound) == 0  {
                    string.addAttribute(.foregroundColor,
                                        value: foregroundColor.withAlphaComponent(0.5),
                                        range: NSRange(range, in: text))
                } else {
                    string.addAttribute(.foregroundColor,
                                        value: foregroundColor.withAlphaComponent(0.1),
                                        range: NSRange(text.startIndex..., in: text))
                }
            }

            let boundingRect = text.boundingRect(
                with: cellRect.size,
                options: .usesLineFragmentOrigin,
                attributes: attrs
            )

            let textHeight = boundingRect.height

            string.draw(
                with: CGRect(
                    origin: CGPoint(
                        x: cellRect.origin.x,
                        y: cellRect.origin.y - textHeight
                    ),
                    size: cellRect.size
                ),
                options: .usesLineFragmentOrigin,
                context: nil
            )

        }

    }

    /// Draw the keyboard layout over the cell being refined.
    ///
    /// The letters are sized to fit the cell, so on a small cell they are tiny.
    /// That is fine: the layout is the keyboard, so the lines alone tell you
    /// where each key lands. Raise "Grid cell side length" in Settings for a
    /// coarser grid and larger, readable refinement keys.
    private func drawRefinement(in cell: CGRect, ctx: NSGraphicsContext) {

        let primaryColor = UserSettings.shared.primaryColor

        // Clear the dimming over the chosen cell, so it stands out from the
        // rest of the screen.
        ctx.cgContext.setBlendMode(.clear)
        ctx.cgContext.fill(cell)
        ctx.cgContext.setBlendMode(.normal)

        let cells = RefinementGrid.cells(in: cell)

        guard let first = cells.first else {
            return
        }

        // Split the cell.
        ctx.cgContext.setStrokeColor(
            primaryColor.withAlphaComponent(
                viewController.gridLineAlphaComponent
            ).cgColor
        )
        ctx.cgContext.setLineWidth(1)

        for subCell in cells.map({ $0.rect }) {
            ctx.cgContext.stroke(subCell)
        }

        // Outline the cell itself.
        ctx.cgContext.setStrokeColor(
            primaryColor.withAlphaComponent(
                viewController.gridLabelAlphaComponent
            ).cgColor
        )
        ctx.cgContext.setLineWidth(2)
        ctx.cgContext.stroke(cell)

        guard UserSettings.shared.showGridLabels else {
            return
        }

        // Size the letters to the sub-cell, and never below a floor, so that a
        // small cell still shows something.
        let fontSize = Swift.max(
            6.0,
            Swift.min(
                UserSettings.shared.gridViewFontSize,
                first.rect.height * 0.7,
                first.rect.width * 1.2
            )
        )

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: primaryColor.withAlphaComponent(
                viewController.gridLabelAlphaComponent
            ),
            .paragraphStyle: paragraphStyle,
        ]

        for (key, subCell) in cells {
            let text = String(key)
            let string = NSAttributedString(string: text, attributes: attrs)

            let textHeight = string.boundingRect(
                with: subCell.size,
                options: .usesLineFragmentOrigin
            ).height

            string.draw(
                with: CGRect(
                    origin: CGPoint(
                        x: subCell.origin.x,
                        y: subCell.midY - (textHeight / 2)
                    ),
                    size: CGSize(width: subCell.width, height: textHeight)
                ),
                options: .usesLineFragmentOrigin,
                context: nil
            )
        }
    }
}
