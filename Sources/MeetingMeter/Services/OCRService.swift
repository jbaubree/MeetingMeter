// Sources/MeetingMeter/Services/OCRService.swift
import Vision
import CoreGraphics
import MeetingMeterCore

public final class OCRService {
    public init() {}

    public enum OCRError: Error {
        case recognitionFailed(Error)
    }

    public func recognizeParticipantCount(from image: CGImage) async throws -> Int? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["fr-FR", "en-US", "de-DE", "es-ES"]
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw OCRError.recognitionFailed(error)
        }
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let joined = lines.joined(separator: "\n")
        return OCRParticipantParser.parseCount(from: joined)
    }
}
