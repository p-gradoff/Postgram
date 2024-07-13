import Foundation
import AVFoundation
import UIKit

// TODO: manage delegates

protocol CameraServiceDelegate : AnyObject {
    func startRunning() async throws
    func switchCamera()
    func setPhoto(_ image: UIImage)
}

final class CameraService : NSObject {
    // MARK: private properties
    private var captureDevice : AVCaptureDevice? // general camera API
    private var backCamera : AVCaptureDevice? // back camera API
    private var frontCamera : AVCaptureDevice? // front camera API
    
    private var backInput : AVCaptureDeviceInput! // back camera input
    private var frontInput : AVCaptureDeviceInput! // front camera input
    
    private var isBackCameraOnFlag : Bool = true
    weak var delegate : CameraServiceDelegate?
    
    private let captureSession : AVCaptureSession = AVCaptureSession() // connection between input & outputs to configure with
    private let photoOutput : AVCapturePhotoOutput = AVCapturePhotoOutput() // photo output
    
    //MARK: init
    override init() {
        super.init()
        setupCaptureSession()
    }
}

// MARK: private methods
private extension CameraService {
    
    private func currentDevice() -> AVCaptureDevice? {
        // using DiscoverySession with special camera order to chose best option for current device
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        
        guard let device = discoverySession.devices.first else { return nil }
        return device
    }
    
    private func setupInputs() {
        // setup cameras
        backCamera = currentDevice()
        frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        
        // check available devices
        guard let backCamera = backCamera, let frontCamera = frontCamera else { return }
        
        // check inputs
        do {
            backInput = try AVCaptureDeviceInput(device: backCamera)
            guard captureSession.canAddInput(backInput) else { return }
            
            frontInput = try AVCaptureDeviceInput(device: frontCamera)
            guard captureSession.canAddInput(frontInput) else { return }
        } catch {
            fatalError("could not connect camera")
        }
        
        // setup backCamera by default
        captureDevice = backCamera
        captureSession.addInput(backInput)
    }
    
    private func setupOutputs() {
        guard captureSession.canAddOutput(photoOutput) else { return }
        photoOutput.maxPhotoQualityPrioritization = .balanced
        
        captureSession.addOutput(photoOutput)
    }
    
    private func setupCaptureSession() {
        // begin configuration session
        captureSession.beginConfiguration()
        
        // check photo preset for current session
        if captureSession.canSetSessionPreset(.photo) { captureSession.sessionPreset = .photo }
        captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
        
        setupInputs()
        setupOutputs()
        
        // end configration session
        captureSession.commitConfiguration()
    }
    
    private func checkPermissions() {
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraAuthStatus {
        case .authorized:
            return
        case .denied:
            abort()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { authorized in
                if !authorized { abort() }
            }
        case .restricted:
            abort()
        default:
            fatalError()
        }
    }
}

extension CameraService : CameraServiceDelegate {
    
    func startRunning() async throws {
        captureSession.startRunning()
    }
    
    func switchCamera() {
        // change inputs-outputs
        if isBackCameraOnFlag {
            isBackCameraOnFlag = false
            captureSession.removeInput(backInput)
            captureSession.addInput(frontInput)
            captureDevice = frontCamera
        } else {
            isBackCameraOnFlag = true
            captureSession.removeInput(frontInput)
            captureSession.addInput(backInput)
            captureDevice = backCamera
        }
        
        photoOutput.connections.first?.videoRotationAngle = 90
        photoOutput.connections.first?.isVideoMirrored = !isBackCameraOnFlag
    }
    
    func setPhoto(_ image: UIImage) {
        <#code#>
    }
}

extension CameraService : AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        guard error == nil else {
            print("Fail to capture photo: \(String(describing: error))")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        
        guard let image = UIImage(data: imageData) else {
            return
        }
        
        DispatchQueue.main.async {
            self.delegate?.setPhoto(image)
        }
    }
}
