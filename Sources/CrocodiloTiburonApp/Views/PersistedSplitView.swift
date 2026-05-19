import AppKit
import SwiftUI

struct PersistedSplitPane {
    var minWidth: CGFloat
    var defaultWidth: CGFloat
    var maxWidth: CGFloat?
    var view: AnyView
}

struct PersistedHSplitView: NSViewRepresentable {
    var storageKey: String
    var panes: [PersistedSplitPane]

    func makeCoordinator() -> Coordinator {
        Coordinator(storageKey: storageKey, panes: panes)
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator

        for pane in panes {
            let hostingView = NSHostingView(rootView: pane.view)
            splitView.addArrangedSubview(hostingView)
        }

        for index in panes.indices.dropLast() {
            splitView.setHoldingPriority(.defaultHigh, forSubviewAt: index)
        }
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: panes.count - 1)

        context.coordinator.scheduleInitialLayout(for: splitView)
        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        context.coordinator.panes = panes

        for (index, pane) in panes.enumerated() where index < splitView.subviews.count {
            guard let hostingView = splitView.subviews[index] as? NSHostingView<AnyView> else {
                continue
            }
            hostingView.rootView = pane.view
        }

        context.coordinator.scheduleInitialLayout(for: splitView)
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        var panes: [PersistedSplitPane]

        private let defaultsKey: String
        private var didApplyInitialLayout = false
        private var isApplyingLayout = false

        init(storageKey: String, panes: [PersistedSplitPane]) {
            self.defaultsKey = "layout.\(storageKey).splitWidths"
            self.panes = panes
        }

        func scheduleInitialLayout(for splitView: NSSplitView) {
            guard !didApplyInitialLayout else { return }

            DispatchQueue.main.async { [weak self, weak splitView] in
                guard let self, let splitView else { return }
                self.applyInitialLayoutIfPossible(for: splitView)
            }
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard
                didApplyInitialLayout,
                !isApplyingLayout,
                let splitView = notification.object as? NSSplitView,
                splitView.subviews.count == panes.count
            else { return }

            let widths = splitView.subviews.dropLast().map { Double($0.frame.width.rounded()) }
            UserDefaults.standard.set(widths, forKey: defaultsKey)
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainMinCoordinate proposedMinimumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            guard dividerIndex + 1 < splitView.subviews.count else { return proposedMinimumPosition }

            let current = splitView.subviews[dividerIndex].frame
            let next = splitView.subviews[dividerIndex + 1].frame
            let currentMin = current.minX + minWidth(for: dividerIndex)
            let nextMax = maxWidth(for: dividerIndex + 1).map {
                next.maxX - $0 - splitView.dividerThickness
            } ?? -CGFloat.greatestFiniteMagnitude

            return max(proposedMinimumPosition, currentMin, nextMax)
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainMaxCoordinate proposedMaximumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            guard dividerIndex + 1 < splitView.subviews.count else { return proposedMaximumPosition }

            let current = splitView.subviews[dividerIndex].frame
            let next = splitView.subviews[dividerIndex + 1].frame
            let currentMax = maxWidth(for: dividerIndex).map {
                current.minX + $0
            } ?? CGFloat.greatestFiniteMagnitude
            let nextMin = next.maxX - minWidth(for: dividerIndex + 1) - splitView.dividerThickness

            return min(proposedMaximumPosition, currentMax, nextMin)
        }

        private func applyInitialLayoutIfPossible(for splitView: NSSplitView) {
            guard !didApplyInitialLayout else { return }

            guard splitView.bounds.width > 0, splitView.subviews.count == panes.count else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak splitView] in
                    guard let self, let splitView else { return }
                    self.applyInitialLayoutIfPossible(for: splitView)
                }
                return
            }

            isApplyingLayout = true
            defer {
                isApplyingLayout = false
                didApplyInitialLayout = true
            }

            var dividerPosition: CGFloat = 0
            let widths = initialWidths()

            for dividerIndex in 0..<max(0, panes.count - 1) {
                let width = constrained(widths[dividerIndex], for: dividerIndex)
                dividerPosition += width
                splitView.setPosition(dividerPosition, ofDividerAt: dividerIndex)
                dividerPosition += splitView.dividerThickness
            }
        }

        private func initialWidths() -> [CGFloat] {
            let savedWidths = UserDefaults.standard.array(forKey: defaultsKey) as? [Double]
            let defaults = panes.dropLast().map(\.defaultWidth)
            let loaded = savedWidths?.map { CGFloat($0) } ?? []

            return defaults.enumerated().map { index, defaultWidth in
                loaded.indices.contains(index) ? loaded[index] : defaultWidth
            }
        }

        private func constrained(_ width: CGFloat, for index: Int) -> CGFloat {
            let lowerBounded = max(width, minWidth(for: index))
            guard let maxWidth = maxWidth(for: index) else {
                return lowerBounded
            }
            return min(lowerBounded, maxWidth)
        }

        private func minWidth(for index: Int) -> CGFloat {
            panes.indices.contains(index) ? panes[index].minWidth : 80
        }

        private func maxWidth(for index: Int) -> CGFloat? {
            panes.indices.contains(index) ? panes[index].maxWidth : nil
        }
    }
}
