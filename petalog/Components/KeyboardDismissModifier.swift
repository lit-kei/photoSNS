import SwiftUI
import UIKit

struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                KeyboardDismissGestureInstaller()
                    .frame(width: 0, height: 0)
            }
    }
}

extension View {
    func dismissKeyboardOnOutsideTap() -> some View {
        modifier(KeyboardDismissModifier())
    }
}

private struct KeyboardDismissGestureInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.onWindowChange = { window in
            context.coordinator.updateWindow(window)
        }
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {
        context.coordinator.updateWindow(uiView.window)
    }

    final class InstallerView: UIView {
        var onWindowChange: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChange?(window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private var recognizer: UITapGestureRecognizer?

        func updateWindow(_ window: UIWindow?) {
            guard installedWindow !== window else { return }

            if let recognizer, let installedWindow {
                installedWindow.removeGestureRecognizer(recognizer)
            }

            installedWindow = window

            guard let window else {
                recognizer = nil
                return
            }

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            self.recognizer = recognizer
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            recognizer.view?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            !touch.view.isTextInputOrInsideTextInput
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

private extension Optional where Wrapped == UIView {
    var isTextInputOrInsideTextInput: Bool {
        var current = self
        while let view = current {
            if view is UITextField || view is UITextView {
                return true
            }
            current = view.superview
        }
        return false
    }
}
