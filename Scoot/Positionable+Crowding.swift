import Cocoa

extension Array where Element: Positionable, Element: Equatable {

    /// Implements a naive algorithm to reduce "crowding", by filtering out
    /// elements that are positioned too closely together.
    ///
    /// If two elements have duplicate frames, one of the elements is removed.
    ///
    /// If two elements have frames that overlap fully (i.e., one of the frames
    /// contains the other frame), the two elements are only merged when they
    /// are close to the same size (see `nestedCollapseRatio`). In that case,
    /// the element with the larger frame is removed. A small element nested
    /// inside a much larger one is a separate target, so both are kept.
    ///
    /// If two elements have frames that overlap more than
    /// `intersectionThreshold`%, the element with the smaller frame is
    /// removed.
    ///
    /// If two elements have frames that do not intersect, but do intersect
    /// with padding applied (see `paddingX` and `paddingY` parameters), the
    /// element with the smaller frame is removed.
    ///
    /// - Parameter intersectionThreshold: the percentage (expressed as a float
    ///   ranging between 0 and 1) that two elements' frames need to overlap in
    ///   order for the element with the smaller frame to be removed.
    ///
    /// - Parameter paddingX: the number of pixels to increase the width of an
    ///   element's frame by, when testing to see if the padded frame intersects
    ///   with another element.
    ///
    /// - Parameter paddingY: the number of pixels to increase the height of an
    ///   element's frame by, when testing to see if the padded frame intersects
    ///   with another element.
    ///
    /// - Parameter nestedCollapseRatio: when one frame fully contains another,
    ///   the two elements are merged only if the smaller frame covers at least
    ///   this fraction of the larger frame. Below this fraction, both elements
    ///   are kept, because the larger element still has enough uncovered area
    ///   to be a distinct click target. (Example: a web link that contains a
    ///   small overflow menu button. Both must remain selectable.)
    func reducingCrowding(intersectionThreshold: CGFloat = 0.1, paddingX: CGFloat = 0, paddingY: CGFloat = 0, nestedCollapseRatio: CGFloat = 0.75) -> [Element] {

        var discard = [Element]()

        func nextPartialResult(accumulator: [Element], element: Element) -> [Element] {

            let predicate: (Element) -> Bool = {

                // An element that is already in the accumulator.
                let accumulated = $0

                // The element currently under consideration for inclusion in
                // the accumulator.
                let candidate = element

                if candidate.frame == accumulated.frame {
                    // Do not include the candidate in the accumulator.
                    return true
                }

                let framesIntersect = candidate.frame.intersects(accumulated.frame)

                let percentageOverlapping = candidate.frame.percentageOverlapping(accumulated.frame)

                let paddedFramesIntersect = candidate.frame.insetBy(dx: -paddingX, dy: -paddingY).intersects(accumulated.frame)

                if percentageOverlapping == 1 {
                    // One frame fully contains the other.
                    //
                    // Only merge the two elements when they are close to the
                    // same size. A wrapper that is barely larger than its child
                    // (common in native apps, where an AXCell wraps an
                    // AXButton) is the same target, so we keep the child,
                    // because it is more specific.
                    //
                    // A small element nested inside a much larger one is a
                    // different story. A web link, for example, can contain a
                    // small overflow menu button. The link keeps most of its
                    // area uncovered, so it is still its own click target, and
                    // both elements must stay selectable.
                    let smallerArea = Swift.min(candidate.frame.area, accumulated.frame.area)
                    let largerArea = Swift.max(candidate.frame.area, accumulated.frame.area)

                    guard largerArea > 0, (smallerArea / largerArea) >= nestedCollapseRatio else {
                        // Keep both elements.
                        return false
                    }

                    // To reduce crowding, only one element is kept (either the
                    // candidate, or the accumulated). We choose the element
                    // with the smaller area, because it is more specific.
                    if candidate.frame.area >= accumulated.frame.area {
                        // The frame with the smaller area is already in the
                        // accumulator. Don't include the candidate.
                        return true
                    } else {
                        // Include the candidate in the accumulator, because
                        // its frame has a smaller area. (However, the other
                        // element is already in the accumulator, and needs to
                        // be removed.)
                        discard.append(accumulated)
                        return false
                    }
                } else if (framesIntersect && percentageOverlapping >= intersectionThreshold) || (!framesIntersect && paddedFramesIntersect) {
                    // To reduce crowding, only one element is kept (either the
                    // candidate, or the accumulated). We choose the element
                    // with the larger area.
                    if candidate.frame.area <= accumulated.frame.area {
                        // The frame with the larger area is already in the
                        // accumulator. Don't include the candidate.
                        return true
                    } else {
                        // Include the candidate in the accumulator, because
                        // its frame has a larger area. (However, the other
                        // element is already in the accumulator, and needs to
                        // be removed.)
                        discard.append(accumulated)
                        return false
                    }
                }

                // No other criteria disqualified the candidate; add it to the
                // accumulator.
                return false
            }

            if accumulator.contains(where: predicate) {
                return accumulator
            } else {
                return accumulator + [element]
            }
        }

        return self.reduce([], nextPartialResult).filter {
            !discard.contains($0)
        }

    }
}
