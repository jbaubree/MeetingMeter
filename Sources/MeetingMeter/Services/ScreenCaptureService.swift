// Sources/MeetingMeter/Services/ScreenCaptureService.swift
import AppKit
import ScreenCaptureKit
import CoreGraphics

public final class ScreenCaptureService {
    public init() {}

    public enum CaptureError: Error {
        case noWindowFound
        case cropFailed
    }

    public func captureTopBand(for pid: pid_t) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.owningApplication?.processID == pid && $0.isOnScreen && ($0.title ?? "").isEmpty == false })
        else { throw CaptureError.noWindowFound }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)

        let full = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return try cropTopBand(full)
    }

    private func cropTopBand(_ image: CGImage) throws -> CGImage {
        let bandHeight = max(1, image.height / 4)
        let rect = CGRect(x: 0, y: 0, width: image.width, height: bandHeight)
        guard let cropped = image.cropping(to: rect) else { throw CaptureError.cropFailed }
        return cropped
    }
}
