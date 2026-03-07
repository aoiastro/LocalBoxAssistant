import AVFoundation
import Foundation

@MainActor
final class FrontCameraCaptureService: NSObject, AVCapturePhotoCaptureDelegate {
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<URL, Error>?

    func captureFrontPhoto() async throws -> URL {
        try await ensureCameraPermission()
        try configureSession()
        session.startRunning()

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    private func ensureCameraPermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            guard granted else {
                throw LocalLLMError.cameraFailed("Camera permission denied")
            }
        default:
            throw LocalLLMError.cameraFailed("Camera permission unavailable")
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw LocalLLMError.cameraFailed("Front camera unavailable")
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw LocalLLMError.cameraFailed("Cannot add front camera input")
        }
        session.addInput(input)

        guard session.canAddOutput(output) else {
            throw LocalLLMError.cameraFailed("Cannot add photo output")
        }
        session.addOutput(output)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer {
            session.stopRunning()
        }

        guard let continuation else { return }
        self.continuation = nil

        if let error {
            continuation.resume(throwing: error)
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            continuation.resume(throwing: LocalLLMError.cameraFailed("Failed to build image data"))
            return
        }

        do {
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("front-camera-\(UUID().uuidString).jpg")
            try data.write(to: destination, options: .atomic)
            continuation.resume(returning: destination)
        } catch {
            continuation.resume(throwing: error)
        }
    }
}
