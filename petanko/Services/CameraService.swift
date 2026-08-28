//
//  CameraService.swift
//  petanko
//

import AVFoundation
import Combine
import UIKit

@MainActor
final class CameraService: NSObject, ObservableObject {
    enum PermissionState {
        case unknown
        case authorized
        case denied
    }

    @Published var permissionState: PermissionState = .unknown
    @Published var capturedImage: UIImage?
    @Published var errorMessage: String?
    @Published var isCapturing = false
    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .back
    @Published private(set) var captureOrientation: AVCaptureVideoOrientation = .portrait

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "petanko.camera.session")

    override init() {
        super.init()
        syncPermissionState()
    }

    func requestPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .authorized
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.permissionState = granted ? .authorized : .denied
                    if granted {
                        self?.configureAndStart()
                    }
                }
            }
        default:
            permissionState = .denied
        }
    }

    func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        errorMessage = nil
        let orientation = captureOrientation

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if let connection = self.output.connection(with: .video) {
                Self.apply(orientation, to: connection)
            }
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func retake() {
        capturedImage = nil
        errorMessage = nil
        isCapturing = false
        configureAndStart()
    }

    func switchCamera() {
        guard capturedImage == nil, permissionState == .authorized, hasFrontCamera else { return }
        cameraPosition = cameraPosition == .back ? .front : .back
        configureAndStart()
    }

    var canSwitchCamera: Bool {
        hasFrontCamera && AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    var isUsingFrontCamera: Bool {
        cameraPosition == .front
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func updateDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) {
        guard let nextOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation),
              nextOrientation != captureOrientation else {
            return
        }

        captureOrientation = nextOrientation
        sessionQueue.async { [weak self] in
            guard let self,
                  let connection = self.output.connection(with: .video) else {
                return
            }
            Self.apply(nextOrientation, to: connection)
        }
    }

    private func syncPermissionState() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .authorized
        case .denied, .restricted:
            permissionState = .denied
        default:
            permissionState = .unknown
        }
    }

    private func configureAndStart() {
        let position = cameraPosition
        let orientation = captureOrientation
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            self.session.inputs.forEach { self.session.removeInput($0) }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                Task { @MainActor in self.errorMessage = "カメラを準備できませんでした。" }
                self.session.commitConfiguration()
                return
            }

            if device.minAvailableVideoZoomFactor <= 1, device.maxAvailableVideoZoomFactor >= 1,
               (try? device.lockForConfiguration()) != nil {
                device.videoZoomFactor = 1
                device.unlockForConfiguration()
            }

            self.session.addInput(input)
            if !self.session.outputs.contains(self.output), self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            if let connection = self.output.connection(with: .video) {
                Self.apply(orientation, to: connection)
            }
            self.session.commitConfiguration()

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private var hasFrontCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    private static func apply(_ orientation: AVCaptureVideoOrientation, to connection: AVCaptureConnection) {
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            Task { @MainActor in
                self.errorMessage = error.localizedDescription
                self.isCapturing = false
            }
            return
        }

        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            Task { @MainActor in
                self.errorMessage = "撮影した写真を読み込めませんでした。"
                self.isCapturing = false
            }
            return
        }

        Task { @MainActor in
            // The original photo is used only as the editor source; keep a
            // 2K working copy so editing does not retain a multi-megapixel
            // camera buffer unnecessarily.
            self.capturedImage = image.fixedOrientation().petankoResized(maxDimension: 2_000)
            self.isCapturing = false
            self.stop()
        }
    }
}

private extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait:
            self = .portrait
        case .landscapeLeft:
            self = .landscapeRight
        case .landscapeRight:
            self = .landscapeLeft
        default:
            return nil
        }
    }
}

private extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
