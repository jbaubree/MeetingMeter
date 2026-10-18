// Sources/MeetingMeter/Services/ScreenCaptureService.swift
import AppKit
import ScreenCaptureKit
import CoreGraphics

public final class ScreenCaptureService {
    public init() {}

    public enum CaptureError: Error {
        case noWindowFound
    }

    public func captureWindow(for pid: pid_t) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.owningApplication?.processID == pid && $0.isOnScreen && ($0.title ?? "").isEmpty == false })
        else { throw CaptureError.noWindowFound }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}
