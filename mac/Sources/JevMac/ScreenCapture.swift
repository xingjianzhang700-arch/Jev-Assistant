import AppKit
import CoreGraphics
import ScreenCaptureKit
import Vision
import JevCore

/// One-shot front-window screenshot + Vision OCR. Never writes the image to disk.
enum ScreenCapture {
    enum Failure: LocalizedError {
        case noPermission
        case noWindow
        case capture(String)

        var errorDescription: String? {
            switch self {
            case .noPermission:
                return "Enable Jev Assistant under System Settings → Privacy & Security → Screen Recording."
            case .noWindow:
                return "No front window to capture. Bring a chat window to the front, then Analyze now."
            case .capture(let msg):
                return msg
            }
        }
    }

    /// Prompt once if needed. Returns false when Screen Recording is still off.
    static func ensureAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        _ = CGRequestScreenCaptureAccess()
        return CGPreflightScreenCaptureAccess()
    }

    /// Capture the frontmost app's largest on-screen window and OCR it into a Snapshot.
    static func snapshotFrontWindow() async throws -> Snapshot {
        guard ensureAccess() else { throw Failure.noPermission }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let app = NSWorkspace.shared.frontmostApplication else { throw Failure.noWindow }
        let pid = app.processIdentifier
        let wins = content.windows.filter {
            $0.owningApplication?.processID == pid && $0.isOnScreen
                && $0.frame.width >= 120 && $0.frame.height >= 120
        }
        guard let window = wins.max(by: {
            $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height
        }) else { throw Failure.noWindow }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let scale = max(NSScreen.main?.backingScaleFactor ?? 2, 1)
        config.width = max(Int(window.frame.width * scale), 1)
        config.height = max(Int(window.frame.height * scale), 1)
        config.showsCursor = false
        config.captureResolution = .best

        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            throw Failure.capture(error.localizedDescription)
        }
        let boxes = try ocrBoxes(image)
        return snapshotFromScreenText(boxes, title: nil)
    }

    private static func ocrBoxes(_ image: CGImage) throws -> [ScreenTextBox] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let iw = Double(image.width)
        let ih = Double(image.height)
        guard iw > 0, ih > 0, let results = request.results else { return [] }
        return results.compactMap { obs -> ScreenTextBox? in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let box = obs.boundingBox // normalized, origin bottom-left
            let x = box.origin.x * iw
            let w = box.width * iw
            let h = box.height * ih
            let y = (1 - box.origin.y - box.height) * ih
            return ScreenTextBox(text: candidate.string, x: x, y: y, w: w, h: h)
        }
    }
}
