//
//  CameraService.swift
//  petalog
//

import AVFoundation
import Combine
import CoreImage
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
    @Published var isSelfieLensActive = true
    @Published var isCapturing = false

    let session = AVCaptureSession()
    let selfieSession = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let selfiePhotoOutput = AVCapturePhotoOutput()
    private let selfieOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "petalog.camera.session")
    private let selfieOutputQueue = DispatchQueue(label: "petalog.camera.selfie-output")
    private var latestSelfieImage: UIImage?
    private var pendingOuterPhoto: UIImage?
    private var pendingSelfiePhoto: UIImage?
    private var waitsForSelfiePhoto = false

    override init() {
        super.init()
        syncPermissionState()
    }

    func requestPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .authorized
            configureAndStart()
            configureSelfieAndStartIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.permissionState = granted ? .authorized : .denied
                    if granted {
                        self?.configureAndStart()
                        self?.configureSelfieAndStartIfNeeded()
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
        pendingOuterPhoto = nil
        pendingSelfiePhoto = nil
        waitsForSelfiePhoto = isSelfieLensActive

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)

            guard self.isSelfieLensActive,
                  self.selfieSession.isRunning,
                  self.selfiePhotoOutput.connection(with: .video) != nil else {
                Task { @MainActor in
                    self.waitsForSelfiePhoto = false
                    self.finishCaptureIfPossible()
                }
                return
            }

            self.selfiePhotoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func retake() {
        capturedImage = nil
        errorMessage = nil
        isCapturing = false
        pendingOuterPhoto = nil
        pendingSelfiePhoto = nil
        waitsForSelfiePhoto = false
        configureAndStart()
        configureSelfieAndStartIfNeeded()
    }

    func switchCamera() {
        isSelfieLensActive.toggle()
        if isSelfieLensActive {
            configureSelfieAndStartIfNeeded()
        } else {
            sessionQueue.async { [weak self] in
                guard let self, self.selfieSession.isRunning else { return }
                self.selfieSession.stopRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            if self.selfieSession.isRunning {
                self.selfieSession.stopRunning()
            }
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
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            self.session.inputs.forEach { self.session.removeInput($0) }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                Task { @MainActor in self.errorMessage = "カメラを準備できませんでした。" }
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)
            if !self.session.outputs.contains(self.output), self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            if let connection = self.output.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            self.session.commitConfiguration()

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func configureSelfieAndStartIfNeeded() {
        guard isSelfieLensActive else { return }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.selfieSession.beginConfiguration()
            self.selfieSession.sessionPreset = .medium
            self.selfieSession.inputs.forEach { self.selfieSession.removeInput($0) }
            self.selfieSession.outputs.forEach { self.selfieSession.removeOutput($0) }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.selfieSession.canAddInput(input) else {
                Task { @MainActor in self.isSelfieLensActive = false }
                self.selfieSession.commitConfiguration()
                return
            }

            self.selfieSession.addInput(input)
            self.selfieOutput.alwaysDiscardsLateVideoFrames = true
            self.selfieOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            self.selfieOutput.setSampleBufferDelegate(self, queue: self.selfieOutputQueue)
            if self.selfieSession.canAddOutput(self.selfieOutput) {
                self.selfieSession.addOutput(self.selfieOutput)
            }
            if self.selfieSession.canAddOutput(self.selfiePhotoOutput) {
                self.selfieSession.addOutput(self.selfiePhotoOutput)
            }

            if let connection = self.selfieOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }
            if let connection = self.selfiePhotoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }
            self.selfieSession.commitConfiguration()

            if !self.selfieSession.isRunning {
                self.selfieSession.startRunning()
            }
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            Task { @MainActor in self.errorMessage = error.localizedDescription }
            return
        }

        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            Task { @MainActor in self.errorMessage = "撮影した写真を読み込めませんでした。" }
            return
        }

        Task { @MainActor in
            let fixedImage = image.fixedOrientation()
            if output === self.selfiePhotoOutput {
                self.pendingSelfiePhoto = fixedImage
            } else {
                self.pendingOuterPhoto = fixedImage
            }
            self.finishCaptureIfPossible()
        }
    }

    private func finishCaptureIfPossible() {
        guard let outerPhoto = pendingOuterPhoto else { return }
        guard !waitsForSelfiePhoto || pendingSelfiePhoto != nil else { return }

        let selfieImage = pendingSelfiePhoto ?? latestSelfieImage
        capturedImage = selfieImage.map { outerPhoto.petalogCompositedWithSelfie($0) } ?? outerPhoto
        pendingOuterPhoto = nil
        pendingSelfiePhoto = nil
        waitsForSelfiePhoto = false
        isCapturing = false
        stop()
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)

        Task { @MainActor in
            self.latestSelfieImage = image
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

    func petalogCompositedWithSelfie(_ selfieImage: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let fullRect = CGRect(origin: .zero, size: size)
            draw(in: fullRect)

            let shortSide = min(size.width, size.height)
            let lensSide = shortSide * 0.56
            let lensRect = CGRect(
                x: (size.width - lensSide) / 2,
                y: (size.height - lensSide) / 2,
                width: lensSide,
                height: lensSide
            )

            context.cgContext.saveGState()
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 14), blur: 22, color: UIColor.black.withAlphaComponent(0.22).cgColor)
            UIColor.white.withAlphaComponent(0.92).setStroke()
            let shadowRimPath = UIBezierPath(ovalIn: lensRect.insetBy(dx: -10, dy: -10))
            shadowRimPath.lineWidth = 18
            shadowRimPath.stroke()
            context.cgContext.restoreGState()

            context.cgContext.saveGState()
            UIBezierPath(ovalIn: lensRect).addClip()
            selfieImage.drawAspectFill(in: lensRect)
            context.cgContext.restoreGState()

            UIColor.white.withAlphaComponent(0.82).setStroke()
            let rimPath = UIBezierPath(ovalIn: lensRect.insetBy(dx: -6, dy: -6))
            rimPath.lineWidth = 12
            rimPath.stroke()
        }
    }

    func drawAspectFill(in rect: CGRect) {
        let imageSize = size
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        draw(in: drawRect)
    }
}
