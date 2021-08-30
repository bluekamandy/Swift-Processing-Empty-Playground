/*
 * SwiftProcessing: Alert
 *
 *
 * */


import Foundation
import UIKit

open class Alert {

    var alert: UIAlertController

    init(_ title: String, _ message: String, _ preferredStyle: UIAlertController.Style? = UIAlertController.Style.alert) {
        self.alert = UIAlertController(title: title,message: message, preferredStyle: preferredStyle!)
    }

    init(_ error: NSError) {
        self.alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        self.addAction("Ok")
    }

    public  func show() {
        DispatchQueue.main.async {
            UIApplication.topViewController?.present(self.alert, animated: true, completion: nil)
        }
    }

    public func addAction(_ title: String, _ style: UIAlertAction.Style = UIAlertAction.Style.default, handler: ((UIAlertAction) -> Void)?) {
        self.alert.addAction(UIAlertAction(title: title, style: style, handler: handler))
    }

    public func addAction(_ title: String, _ style: UIAlertAction.Style = UIAlertAction.Style.default, handler: (() -> Void)? = nil) {
        self.alert.addAction(UIAlertAction(title: title, style: style, handler: {
            action in
            handler?()
        }))
    }

}

public extension Sketch {
    func createAlert(_ title: String, _ message: String) -> Alert{
        return Alert(title, message)
    }
}
/*
 * SwiftProcessing: Microphone Input
 *
 * This is an implementation of microphone input for
 * SwiftProcessing. It allows the user to access a global
 * static singleton
 *
 * */

import UIKit
import AVFoundation

// =======================================================================
// MARK: - CLASS: MIC INPUT
// =======================================================================

open class AudioIn {
    
    /*
     * MARK: - PRIVATE PROPERTIES
     */
    
    // Variables related to the microphone.
    
    private var recorder: AVAudioRecorder!
    private var updated: ((Float) -> Void)?
    private let minDecibels: Float = -80
    
    private let settings: [String:Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false
    ]
    
    // Change the multiplier to amplify the effect of sound on your shapes.
    // You can, optionally, create more than one multiplier.
    
    /// A multiplier that enables you to magnify the effect of the microphone input.
    /// Larger = bigger.
    
    public static var multiplier = 1.0
    
    /// The property where the audio level is stored. This includes the effect of any mulitplier.
    
    public var level: Double!
    
    /*
     * MARK: - INIT
     */
    
    /// AudioIn() is a singleton object that is associated with the microphone.
    /// Singleton's ensure that only one object is created. They're often used when
    /// they are associated with a single piece of hardware, like a camera or a
    /// microphone. This is private, but you can refer direclty to
    /// `AudioIn.getLevel()` to access audio input.
    
    private static let shared = AudioIn()
    
    private init() {
        // print("Creating audio in object")
        // Set up the microphone to start listening.
        
        setupAudioSession()
        enableBuiltInMic()
        
        // Create the recorder object.
        do {
            let url = URL(string: NSTemporaryDirectory().appending("tmp.caf"))!
            try recorder = AVAudioRecorder(url: url, settings: settings)
        } catch {
            print("Error occured when attempting to initialize the audio microphone.")
        }
        
        switch AVAudioSession.sharedInstance().recordPermission {
        case AVAudioSession.RecordPermission.granted:
            // print("Permission granted")
        break
        case AVAudioSession.RecordPermission.denied:
            print("Pemission to use the microphone has been denied.")
        case AVAudioSession.RecordPermission.undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                // Handle granted if need be.
            })
            
        @unknown default:
            print("Failed to configure and activate microphone. Make sure you have properly set up your info.plist file in your project to include microphone privacy permissions. If you have not, click the + sign to add a key and look for this key: Privacy - Microphone Usage Description. Then enter a string that explains why you are using the microphone. If that has been done, then make sure you give your program access to your microphone when prompted by iOS or the iOS Simulator.")
        }
    }
    
    // Source: https://developer.apple.com/documentation/avfaudio/avaudiosession/capturing_stereo_audio_from_built-in_microphones
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to configure and activate microphone. Make sure you have properly set up your info.plist file in your project to include microphone privacy permissions. If you have not, click the + sign to add a key and look for this key: Privacy - Microphone Usage Description. Then enter a string that explains why you are using the microphone. If that has been done, then make sure you give your program access to your microphone when prompted by iOS or the iOS Simulator.")
        }
    }
    
    
    private func enableBuiltInMic() {
        // Get the shared audio session.
        let session = AVAudioSession.sharedInstance()
        
        // Find the built-in microphone input.
        guard let availableInputs = session.availableInputs,
              let builtInMicInput = availableInputs.first(where: { $0.portType == .builtInMic }) else {
            print("The device must have a built-in microphone.")
            return
        }
        
        // Make the built-in microphone input the preferred input.
        do {
            try session.setPreferredInput(builtInMicInput)
        } catch {
            print("Unable to set the built-in mic as the preferred input.")
        }
    }
    
    /*
     * MARK: - PUBLIC METHODS
     */
    
    /// Starts the input from the micrphone. This should be run once before input is expected.
    /// `setup()` would be a good place for this function. Do not place it in `draw()`.
    /// ```
    /// // Starts the microphone
    /// func setup() {
    ///   AudioIn.start()
    /// }
    /// ```
    
    public static func start() {
        // Start the microphone.
        print("Starting microphone")
        
        shared.recorder.prepareToRecord()
        shared.recorder.isMeteringEnabled = true
        print(shared.recorder.record())
    }
    
    /// Returns the level of the input coming into the microphone. This can be done on a
    /// frame by frame basis to control shapes or other objects within your sketch.
    /// ```
    /// // Draws a circle using the input level of the mic.
    /// func draw() {
    ///   AudioIn.update()
    ///   circle(width/2, height/2, AudioIn.getLevel())
    /// }
    /// ```

    public static func getLevel() -> Double {
        return shared.level
    }
    
    /*
     * MARK: - PRIVATE CALCULATED PROPERTIES: MIC SIGNAL CONVERSION
     */
    
    // Converting input from microphone to useful, human-readable numbers.
    
    private var micLevel: Float {
        
        let decibels = recorder.averagePower(forChannel: 0)
        
        if decibels < minDecibels {
            return 0
        } else if decibels >= 0 {
            return 1
        }
        
        let minAmp = powf(10, 0.05 * minDecibels)
        let inverseAmpRange = 1 / (1 - minAmp)
        let amp = powf(10, 0.05 * decibels)
        let adjAmp = (amp - minAmp) * inverseAmpRange
        
        return sqrtf(Float(adjAmp))
    }
    
    private var pos: Float {
        // linear level * by max + min scale (20 - 130db)
        return micLevel * 130 + 20
    }
    
    /*
     * MARK: - SAMPLE THE MICROPHONE AND CALL THE CHANGE SHAPE FUNCTION
     */
    
    /// Updates the microphone. This should be done in the `draw()` function.
    /// ```
    /// // Draws a circle using the input level of the mic.
    /// func draw() {
    ///   AudioIn.update()
    ///   circle(width/2, height/2, AudioIn.getLevel())
    /// }
    /// ```
    
    public static func update() {
        self.shared.updateMeter()
    }
    
    @objc private func updateMeter() {
        recorder.updateMeters()
        updated?(pos)
        print(pos)
        level = Double(self.pos)/2.0*AudioIn.multiplier
    }
    
}
/*
 * SwiftProcessing: Button
 *
 *
 * */


import Foundation
import UIKit

public extension Sketch {
    
    class Button: UIKitControlElement {
        var image: Image!
        
        init(_ view: Sketch, _ title: String) {
            let button = UIButton()
            button.setTitle(title, for: .normal)
            button.sizeToFit()
            super.init(view, button)
        }
        
        open func image(_ i: Image){
            (self.element as! UIButton).setImage(i.uiImage[0], for: .normal)
        }
        
        open func textFont(_ name: String){
            (self.element as! UIButton).titleLabel?.font = UIFont(name: name, size: ((self.element as! UIButton).titleLabel?.font.pointSize)!)
        }
        
        open func textSize(_ size: CGFloat){
            (self.element as! UIButton).titleLabel?.font = UIFont(name: ((self.element as! UIButton).titleLabel?.font.fontName)!, size: size)
        }
        
        open func textColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 255){
            (self.element as! UIButton).setTitleColor(UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a / 255), for: .normal)
        }
        
    }
    
    func createButton(_ t: String = "") -> Button{
        let b = Button(self, t)
        viewRefs[b.id] = b
        return b
    }
}
import UIKit
import SceneKit
import Foundation


open class Camera3D {
    
    var baseNode: SCNNode = SCNNode()
    var cameraNode: SCNNode = SCNNode()
    var upVector: simd_float3 = simd_float3(0,1,0)
    
    init(){
        self.baseNode = SCNNode()
        self.baseNode.position = SCNVector3(x: 0, y: 0, z: 0)
        
        let camera = SCNCamera()
        self.cameraNode = SCNNode()
        self.cameraNode.camera = camera
        self.cameraNode.position = SCNVector3(x: 0, y: 0, z: 100)
        
        let lookAtConstraint = SCNLookAtConstraint(target: self.baseNode)
        self.cameraNode.constraints = [lookAtConstraint]
    }
    
    
    open func perspective(_ fovy: CGFloat,_ aspect: CGFloat, _ near: CGFloat, _ far: CGFloat){
        
        self.cameraNode.camera!.zFar = Double(far)
        self.cameraNode.camera!.zNear = Double(near)
        
        self.cameraNode.camera!.focalLength = fovy
        
    }
    
    open func ortho(_ left: CGFloat, _ right: CGFloat, _ bottom: CGFloat, _ top: CGFloat, _ near: CGFloat, _ far: CGFloat) {
        
        self.cameraNode.camera!.usesOrthographicProjection = true
        
    }
    
    open func frustum(_ viewingAngle: CGFloat, _ direction: String){
        
        if (direction == "vertical"){
            self.cameraNode.camera!.projectionDirection = SCNCameraProjectionDirection(rawValue: 0)!
        } else if (direction == "horizontal"){
            self.cameraNode.camera!.projectionDirection = SCNCameraProjectionDirection(rawValue: 1)!
        } else {
            
        }
        self.cameraNode.camera!.fieldOfView = viewingAngle
        
    }
    
    open func move(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat){
        self.cameraNode.position = SCNVector3(self.cameraNode.position.x + Float(x),self.cameraNode.position.y + Float(y),self.cameraNode.position.z + Float(z))
    }
    
    open func setPosition(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat){
        self.cameraNode.position = SCNVector3(x,y,z)
    }
    
    open func lookAt(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat){
        self.baseNode.position = SCNVector3(x,y,z)
    }
    
    open func camera(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat, _ centerX: CGFloat, _ centerY: CGFloat, _ centerZ: CGFloat, _ upX: CGFloat, _ upY: CGFloat, _ upZ: CGFloat){
        
        self.cameraNode.position = SCNVector3(x, y, z)
        self.baseNode.position = SCNVector3(centerX, centerY, centerZ)
        
        self.cameraNode.rotation = SCNVector4(upX,upY,upZ,1)
    }
    
    

    
}
/*
 * SwiftProcessing: Capture
 *
 *
 * */


import UIKit
import AVFoundation
import Vision

public extension Sketch {
    
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    @available(macCatalyst 14.0, *)
    class Camera: UIKitViewElement {
        
        private var previewView: UIView?
        private(set) var cameraIsReadyToUse = false
        
        var alert: Alert
        
        private let session = AVCaptureSession()
        private weak var previewLayer: AVCaptureVideoPreviewLayer?
        private lazy var sequenceHandler = VNSequenceRequestHandler()
        private lazy var capturePhotoOutput = AVCapturePhotoOutput()
        private var videoConnection: AVCaptureConnection?
        private var cameraDevice: AVCaptureDevice?
        
        
        private lazy var dataOutputQueue = DispatchQueue(label: "FaceDetectionService",
                                                         qos: .userInitiated, attributes: [],
                                                         autoreleaseFrequency: .workItem)
        
        private var captureCompletionBlock: ((UIImage) -> Void)?
        private var preparingCompletionHandler: ((Bool) -> Void)?
        private var snapshotImageOrientation = UIImage.Orientation.upMirrored
        
        private var photo:Image?
        
        var AVCapturePositions = ["front" : AVCaptureDevice.Position.front,
                                  "back" : AVCaptureDevice.Position.back]
        
        var AVCaptureQuality = ["high" : AVCaptureSession.Preset.high,
                                "medium" : AVCaptureSession.Preset.medium,
                                "low" : AVCaptureSession.Preset.low,
                                "vga" : AVCaptureSession.Preset.vga640x480,
                                "hd" : AVCaptureSession.Preset.hd1280x720,
                                "qhd" : AVCaptureSession.Preset.hd1920x1080]
        
        var orientation = [UIInterfaceOrientation.landscapeLeft : AVCaptureVideoOrientation.landscapeLeft,
                           UIInterfaceOrientation.landscapeRight : AVCaptureVideoOrientation.landscapeRight,
                           UIInterfaceOrientation.portrait : AVCaptureVideoOrientation.portrait,
                           UIInterfaceOrientation.portraitUpsideDown : AVCaptureVideoOrientation.portraitUpsideDown]
        
        var orientationWords = ["up" : AVCaptureVideoOrientation.portrait,
                                "upsidedown" : AVCaptureVideoOrientation.portraitUpsideDown,
                                "left" : AVCaptureVideoOrientation.landscapeLeft,
                                "right" : AVCaptureVideoOrientation.landscapeRight]
        
        init(_ view: Sketch) {
            self.previewView = UIView()
            self.alert = Alert("default", "default")
            super.init(view, self.previewView!)
        }
        
        open func setResolution(_ resolution: String) {
            if let captureQuality = self.AVCaptureQuality[resolution] {
                self.session.sessionPreset = captureQuality
            } else {
                print("Wrong Resolution Key Word")
            }
        }
        
        open func setFrameRate(_ desiredFrameRate: Float64) {
            guard let range = self.cameraDevice!.formats.first!.videoSupportedFrameRateRanges.first,
                  range.minFrameRate...range.maxFrameRate ~= (desiredFrameRate)
            else {
                print("Requested FPS is not supported by the device's activeFormat !")
                return
            }
            
            do {
                try self.cameraDevice!.lockForConfiguration()
                self.cameraDevice!.activeVideoMaxFrameDuration = CMTimeMake(value: 1,timescale: Int32(desiredFrameRate))
                self.cameraDevice!.unlockForConfiguration()
            } catch {
                print("Failure when locking Configuration")
            }
        }
        
        private var cameraPosition = AVCaptureDevice.Position.front {
            didSet {
                switch cameraPosition {
                case .front: snapshotImageOrientation = .upMirrored
                case .unspecified, .back: fallthrough
                @unknown default: snapshotImageOrientation = .up
                }
            }
        }
        
        open func getCameraPosition(_ position: String) -> AVCaptureDevice.Position {
            if let AVPosition = self.AVCapturePositions[position] {
                return AVPosition
            } else {
                return AVCaptureDevice.Position.front
            }
        }
        
        func setPhoto(_ x: CGFloat = 0,_ y: CGFloat = 0,_ width: CGFloat? = nil,_ height: CGFloat? = nil,_ finished: @escaping () -> Void) {
            self.capturePhoto { image in
                self.photo =  Image(image)
                if width != nil && height != nil {
                    self.photo = self.photo!.get(x,y,width!,height!)
                }
                finished()
            }
            
        }
        
        open func get(_ x: CGFloat = 0,_ y: CGFloat = 0,_ width: CGFloat? = nil,_ height: CGFloat? = nil) -> Image {
            setPhoto(x,y,width,height) {}
            if width == nil && height == nil {
                return self.photo ?? Image(UIColor.black.image(CGSize(width: 640, height: 480)))
            }
            return self.photo ?? Image(UIColor.black.image(CGSize(width: width!, height: height!)))
        }
        
        func prepare(
            cameraPosition: AVCaptureDevice.Position,
            desiredFrameRate: Int? = nil,
            completion: ((Bool) -> Void)?
        ) {
            
            self.preparingCompletionHandler = completion
            self.cameraPosition = cameraPosition
            checkCameraAccess { allowed in
                if allowed { self.setup(desiredFrameRate) }
                completion?(allowed)
                self.preparingCompletionHandler = nil
            }
        }
        
        private func setup(_ desiredFrameRate: Int? = nil) {
            configureCaptureSession(desiredFrameRate)
        }
        
        open func start() {
            if cameraIsReadyToUse { session.startRunning()
            }
        }
        
        open func stop() {
            session.stopRunning()
        }
        
    }
    
}

@available(macCatalyst 14.0, *)
extension Sketch.Camera {
    
    private func askUserForCameraPermission(_ completion:  ((Bool) -> Void)?) {
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { (allowedAccess) -> Void in
            DispatchQueue.main.async { completion?(allowedAccess) }
        }
    }
    
    private func checkCameraAccess(_ completion: ((Bool) -> Void)?) {
        askUserForCameraPermission { [weak self] allowed in
            guard let self = self, let completion = completion else { return }
            self.cameraIsReadyToUse = allowed
            if allowed {
                completion(true)
            } else {
                self.showDisabledCameraAlert(completion)
                print("No Access to Camera")
            }
        }
    }
    
    private func configureCaptureSession(_ desiredFrameRate: Int? = nil) {
        guard let previewView = previewView else { return }
        // Define the capture device we want to use
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey : "No front camera available"])
            let errorAlert = Alert(error)
            errorAlert.show()
            return
        }
        
        // Connect the camera to the capture session input
        do {
            
            try camera.lockForConfiguration()
            defer { camera.unlockForConfiguration() }
            
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            if desiredFrameRate != nil {
                
                self.configureFrameRate(camera,desiredFrameRate!)
                
            }
            
            self.cameraDevice = camera
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            session.addInput(cameraInput)
            
        } catch {
            let errorAlert = Alert(error as NSError)
            errorAlert.show()
            return
        }
        
        // Create the video data output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        // Add the video output to the capture session
        session.addOutput(videoOutput)
        
        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = getOrientation((UIApplication.shared.windows.first?.windowScene!.interfaceOrientation)!)
        self.videoConnection = videoConnection
        
        // Configure the preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspect
        previewLayer.frame = previewView.bounds
        previewLayer.connection?.videoOrientation = getOrientation((UIApplication.shared.windows.first?.windowScene!.interfaceOrientation)!)
        previewView.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer
    }
    
    func configureFrameRate(_ camera: AVCaptureDevice,_ desiredFrameRate: Int) {
        guard let range = camera.formats.first!.videoSupportedFrameRateRanges.first,
              range.minFrameRate...range.maxFrameRate ~= Float64(desiredFrameRate)
        else {
            print("Requested FPS is not supported by the device's activeFormat !")
            return
        }
        
        do {
            try camera.lockForConfiguration()
            camera.activeVideoMinFrameDuration = CMTimeMake(value: 1,timescale: Int32(desiredFrameRate))
            camera.activeVideoMaxFrameDuration = CMTimeMake(value: 1,timescale: Int32(desiredFrameRate))
            camera.unlockForConfiguration()
        } catch {
            print("Failure when locking Configuration")
        }
    }
    
    func getOrientation(_ orientation : UIInterfaceOrientation) -> AVCaptureVideoOrientation{
        if let orientationReturnValue = self.orientation[orientation] {
            return orientationReturnValue
        } else {
            return AVCaptureVideoOrientation.portrait
        }
    }
    
    public func rotateCamera(_ orientation: String? = nil) {
        if orientation == nil {
            self.previewLayer?.connection?.videoOrientation = getOrientation((UIApplication.shared.windows.first?.windowScene!.interfaceOrientation)!)
            self.videoConnection?.videoOrientation = getOrientation((UIApplication.shared.windows.first?.windowScene!.interfaceOrientation)!)
        } else {
            if let orientationReturnValue = self.orientationWords[orientation!] {
                self.previewLayer?.connection?.videoOrientation = orientationReturnValue
                self.videoConnection?.videoOrientation = orientationReturnValue
            } else {
                print("Wrong orientation key word")
            }
        }
    }
}

@available(macCatalyst 14.0, *)
extension Sketch.Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard   captureCompletionBlock != nil,
                let outputImage = UIImage(sampleBuffer, snapshotImageOrientation) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let captureCompletionBlock = self.captureCompletionBlock{
                captureCompletionBlock(outputImage)
            }
            self.captureCompletionBlock = nil
        }
    }
}

// Navigation

@available(macCatalyst 14.0, *)
extension Sketch.Camera {
    
    private func showDisabledCameraAlert(_ completion: ((Bool) -> Void)?, _ desiredFrameRate: Int? = nil) {
        self.alert = Alert("Enable Camera Access",
                           "Please provide access to your camera",
                           .alert)
        
        self.alert.addAction("Go to Settings", .default, handler: { action in
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(settingsUrl) else { return }
            UIApplication.shared.open(settingsUrl) { [weak self] _ in
                guard let self = self else { return }
                self.prepare(cameraPosition: self.cameraPosition,
                             desiredFrameRate: desiredFrameRate, completion: self.preparingCompletionHandler
                )
            }
        })
        self.alert.addAction("Cancel", .cancel, handler: { _ in completion?(false) })
        self.alert.show()
    }
}

@available(macCatalyst 14.0, *)
extension Sketch.Camera: AVCapturePhotoCaptureDelegate {
    func capturePhoto(completion: ((UIImage) -> Void)?) { captureCompletionBlock = completion }
}

extension UIImage {
    
    convenience init?(_ sampleBuffer: CMSampleBuffer,_ orientation: UIImage.Orientation = .upMirrored) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let context = CGContext(data: baseAddress, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                      space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return nil }
        
        guard let cgImage = context.makeImage() else { return nil }
        self.init(cgImage: cgImage, scale: 1, orientation: orientation)
    }
}

extension Sketch{
    
    @available(macCatalyst 14.0, *)
    open func createCamera(_ position: String = "front", _ desiredFrameRate: Int? = nil) -> Camera{
        let b = Camera(self)
        b.prepare(cameraPosition: b.getCameraPosition(position), desiredFrameRate: desiredFrameRate) { success in
            if success {
                b.start()
            }
            else {
                print("Could not start Camera because could not prepare camera")
            }
        }
        viewRefs[b.id] = b
        return b
    }
    
    @available(macCatalyst 14.0, *)
    open func createCamera(_ desiredFrameRate: Int? = nil) -> Camera{
        return createCamera("front",desiredFrameRate)
    }
}
/*
 * SwiftProcessing: Using GIF-Swift
 *
 * */


//
//  iOSDevCenters+GIF.swift
//  GIF-Swift
//  https://github.com/kiritmodi2702/GIF-Swift
//  Created by iOSDevCenters on 11/12/15.
//  Copyright © 2016 iOSDevCenters. All rights reserved.
//

import UIKit
import ImageIO

/*
 * MARK: - COMPARISON OPERATOR
 */

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
private func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

// =======================================================================
// MARK: - UIImage Extension
// =======================================================================

extension UIImage {

    /*
     * MARK: - WAYS OF IMPORTING GIF IMAGES
     */
    
    public class func gifImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("image doesn't exist")
            return nil
        }

        return UIImage.animatedImageWithSource(source)
    }

    public class func gifImageWithURL(_ gifUrl: String) -> UIImage? {
        guard let bundleURL: URL = URL(string: gifUrl)
            else {
                print("image named \"\(gifUrl)\" doesn't exist")
                return nil
        }
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("image named \"\(gifUrl)\" into NSData")
            return nil
        }

        return gifImageWithData(imageData)
    }

    public class func gifImageWithName(_ name: String) -> UIImage? {
        guard let bundleURL = Bundle.main
            .url(forResource: name, withExtension: "gif") else {
                print("SwiftGif: This image named \"\(name)\" does not exist")
                return nil
        }
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("SwiftGif: Cannot turn image named \"\(name)\" into NSData")
            return nil
        }

        return gifImageWithData(imageData)
    }
    
    class func animatedImageWithSource(_ source: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(source)
        var images = [CGImage]()
        var delays = [Int]()

        for i in 0..<count {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(image)
            }

            let delaySeconds = UIImage.delayForImageAtIndex(Int(i),
                                                            source: source)
            delays.append(Int(delaySeconds * 1000.0)) // Seconds to ms
        }

        let duration: Int = {
            var sum = 0

            for val: Int in delays {
                sum += val
            }

            return sum
        }()

        let gcd = gcdForArray(delays)
        var frames = [UIImage]()

        var frame: UIImage
        var frameCount: Int
        for i in 0..<count {
            frame = UIImage(cgImage: images[Int(i)])
            frameCount = Int(delays[Int(i)] / gcd)

            for _ in 0..<frameCount {
                frames.append(frame)
            }
        }

        let animation = UIImage.animatedImage(with: frames,
                                              duration: Double(duration) / 1000.0)

        return animation
    }
    
    /*
     * MARK: - DELAY
     */

    class func delayForImageAtIndex(_ index: Int, source: CGImageSource!) -> Double {
        var delay = 0.1

        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        let gifProperties: CFDictionary = unsafeBitCast(
            CFDictionaryGetValue(cfProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque()),
            to: CFDictionary.self)

        var delayObject: AnyObject = unsafeBitCast(
            CFDictionaryGetValue(gifProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()),
            to: AnyObject.self)
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                                                             Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: AnyObject.self)
        }

        delay = delayObject as! Double

        if delay < 0.1 {
            delay = 0.1
        }

        return delay
    }

    /*
     * MARK: - GREATEST COMMON DIVISOR
     */
    
    class func gcdForPair(_ a: Int?, _ b: Int?) -> Int {
        // Switch from let to var.
        var a = a
        var b = b
        if b == nil || a == nil {
            if b != nil {
                return b!
            } else if a != nil {
                return a!
            } else {
                return 0
            }
        }

        if a < b {
            let c = a
            a = b
            b = c
        }

        var rest: Int
        while true {
            rest = a! % b!

            if rest == 0 {
                return b!
            } else {
                a = b
                b = rest
            }
        }
    }

    class func gcdForArray(_ array: [Int]) -> Int {
        if array.isEmpty {
            return 1
        }

        var gcd = array[0]

        for val in array {
            gcd = UIImage.gcdForPair(val, gcd)
        }

        return gcd
    }


}
/*
 * SwiftProcessing: Image
 *
 * */

import Foundation
import UIKit

// =======================================================================
// MARK: - Image Class
// =======================================================================

public extension Sketch {
    
    class Image {
        
        /*
         * MARK: - STILL IMAGE PROPERTIES
         */
        
        open var ciContext: CIContext = CIContext()
        open var pixels: [UInt8] = []
        
        /// Width of image.
        
        var width: Double = 0
        
        /// Height of image.
        
        var height: Double = 0
        
        /// Blend mode: Possible values are, .normal, .multiply, .screen, .overlay, .darken, .lighten, .colorDodge, .colorBurn, .softLight, .hardLight, .difference, .exclusion, .hue, .saturation, .color, and .luminosity. There are more availailable as well, which can be found here: https://developer.apple.com/documentation/coregraphics/cgblendmode
        
        open var blendMode: CGBlendMode = .normal
        
        /// Alpha value of the image which specifies it's transparency.
        
        open var alpha: Double = 1.0
        
        /*
         * MARK: - ANIMATED IMAGE PROPERTIES
         */
        
        var uiImage: [UIImage] // An array of images because it may be animated.
        var delay: Double = 0
        var curFrame: Int = 0
        var isPlaying = true
        var lastFrameDrawn: Double = -1
        var deltaTime: Double = 0
        
        open var loop: Double = 0
        open var loopMax: Double = -1
        
        public init(_ image: UIImage) {
            self.width = Double(image.size.width)
            self.height = Double(image.size.height)
            self.uiImage = image.images != nil ? image.images! : [image]
            self.delay = image.duration / 100
        }
        
        /*
         * MARK: - STILL IMAGE METHODS
         */
        
        /// Returns the size of the image in a CGSize object. The width and height of CGSize objects are of the CGFloat type, so to use them in SwiftProcessing you'll need to convert them to Doubles with the `Double()` function.
        
        open func size() -> CGSize {
            return CGSize(width: self.width, height: self.height)
        }
        
        /// Returns the size of the image in a CGSize object. The width and height of CGSize objects are of the CGFloat type, so to use them in SwiftProcessing you'll need to convert them to Doubles with the `Double()` function.
        
        
        open func rawSize() -> CGSize {
            return self.uiImage[curFrame].size
        }
        
        /// Takes a snapshot of the pixel data and saves it as an array of `UInt8`'s. `UInt8` stands for unsigned integer 8-bit and it is one standard method for storing image data. R G B A data is stored in sequence, so one method to access and manipulate this data is with the % operator. This data can be found in the `.pixels` parameter of the image.
        
        open func loadPixels() {
            self.pixels = getPixelData()
        }
        
        func getPixelData() -> [UInt8] {
            let curImage = self.uiImage[curFrame]
            let size = curImage.size
            let dataSize = size.width * size.height * 4
            var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGContext(data: &pixelData,
                                    width: Int(size.width),
                                    height: Int(size.height),
                                    bitsPerComponent: 8,
                                    bytesPerRow: 4 * Int(size.width),
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            context?.draw(curImage.cgImage!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            return pixelData
        }
        
        /// Returns a cropped portion of your sketch as an image. Works similar to the CORNER method of drawing rectangles with x, y, width, and height.
        ///
        /// - Parameters:
        ///     - x: x position of upper-left hand corner.
        ///     - y: y position of upper-left hand corner.
        ///     - w: width of crop.
        ///     - h: height of crop.
        
        open func get<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ x: X, _ y: Y, _ w: W, _ h: H) -> Image {
            var cg_x, cg_y, cg_w, cg_h: CGFloat
            cg_x = x.convert()
            cg_y = y.convert()
            cg_w = w.convert()
            cg_h = h.convert()
            
            UIGraphicsBeginImageContextWithOptions(CGSize(width: cg_w, height: cg_h), false, 1.0)
            let container = CGRect(x: -cg_x, y: -cg_y, width: CGFloat(self.width), height: CGFloat(self.height))
            UIGraphicsGetCurrentContext()!.clip(to: CGRect(x: 0, y: 0,
                                                           width: cg_w, height: cg_h))
            self.uiImage[0].draw(in: container)
            let newImage = Image(UIGraphicsGetImageFromCurrentImageContext()!)
            UIGraphicsEndImageContext()
            
            return newImage
        }
        
        /// Updates the display to reflect changes in pixel data. To be used in conjunction with `loadPixels()`.
        
        @available(iOS 9.0, *)
        open func updatePixels() {
            self.updatePixels(0, 0, uiImage[curFrame].size.width, uiImage[curFrame].size.height)
        }
        
        /// Updates the specified portion of the display to reflect changes in pixel data. To be used in conjunction with `loadPixels()`.
        ///
        /// - Parameters:
        ///     - x: x position of upper-left hand corner.
        ///     - y: y position of upper-left hand corner.
        ///     - w: width of crop.
        ///     - h: height of crop.
        
        @available(iOS 9.0, *)
        open func updatePixels<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ x: X, _ y: Y, _ w: W, _ h: H) {
            //retrieve the current image and apply the current pixels loaded into the pixels array using the x, y, w, h inputs
            var cg_x, cg_y, cg_w, cg_h: CGFloat
            cg_x = x.convert()
            cg_y = y.convert()
            cg_w = w.convert()
            cg_h = h.convert()
            
            var newImage = getPixelData()
            let curImage = self.uiImage[curFrame]
            let size = curImage.size
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            for dy in Int(cg_y)..<Int(cg_h) {
                for dx in Int(cg_x)..<Int(cg_w) {
                    let pixelPos = (dx * 4) + (Int(dy) * 4 * Int(size.width))
                    newImage[pixelPos] = self.pixels[pixelPos]
                    newImage[pixelPos + 1] = self.pixels[pixelPos + 1]
                    newImage[pixelPos + 2] = self.pixels[pixelPos + 2]
                    newImage[pixelPos + 3] = self.pixels[pixelPos + 3]
                }
            }
            
            //create a CGContext and draw the pixels as a CGImage.
            let context = CGContext(data: &newImage,
                                    width: Int(size.width),
                                    height: Int(size.height),
                                    bitsPerComponent: 8,
                                    bytesPerRow: 4 * Int(size.width),
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            UIGraphicsPushContext(context)
            
            //without this clip, the data fails to draw
            context.clip(to: CGRect())
            context.draw(curImage.cgImage!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            
            //         Make an image from the context and set to current frame
            self.uiImage[curFrame] = UIImage(cgImage: (context.makeImage()!))
            UIGraphicsEndImageContext()
            UIGraphicsPopContext()
        }
        
        /// Resizes the image to the new specified size.
        ///
        /// - Parameters:
        ///     - w: new width.
        ///     - h: new height.
        
        open func resize<W: Numeric, H: Numeric>(_ width: W, _ height: H) {
            self.width = width.convert()
            self.height = height.convert()
            
            var cg_width, cg_height: CGFloat
            cg_width = width.convert()
            cg_height = height.convert()
            let newSize = CGSize(width: cg_width, height: cg_height)
            
            self.uiImage = self.uiImage.map({
                UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
                $0.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
                
                let newImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                return newImage!
            })
        }
        
        /// Copies a portion specified of the image to a destination location.
        ///
        /// - Parameters:
        ///     - sx: x position of upper-left hand corner.
        ///     - sy: y position of upper-left hand corner.
        ///     - sw: width of crop.
        ///     - sh: height of crop.
        ///     - dx: x position of upper-left hand corner.
        ///     - dy: y position of upper-left hand corner.
        ///     - dw: width of crop.
        ///     - dh: height of crop.
        
        open func copy<SX: Numeric, SY: Numeric, SW: Numeric, SH: Numeric, DX: Numeric, DY: Numeric, DW: Numeric, DH: Numeric>(_ srcImage: Image, _ sx: SX, _ sy: SY, _ sw: SW, _ sh: SH, _ dx: DX, _ dy: DY, _ dw: DW, _ dh: DH) {
            
            var cg_sx, cg_sy, cg_sw, cg_sh, cg_dx, cg_dy, cg_dw, cg_dh: CGFloat
            cg_sx = sx.convert()
            cg_sy = sy.convert()
            cg_sw = sw.convert()
            cg_sh = sh.convert()
            cg_dx = dx.convert()
            cg_dy = dy.convert()
            cg_dw = dw.convert()
            cg_dh = dh.convert()
            
            UIGraphicsBeginImageContextWithOptions(CGSize(width: self.width, height: self.height), false, 2.0)
            UIGraphicsGetCurrentContext()!.interpolationQuality = .high
            
            self.uiImage[0].draw(in: CGRect(x: 0, y: 0, width: self.width, height: self.height))
            srcImage.get(cg_sx, cg_sy, cg_sw, cg_sh).uiImage[0].draw(in: CGRect(x: cg_dx, y: cg_dy, width: cg_dw, height: cg_dh), blendMode: .normal, alpha: 1.0)
            
            //set to self if nothing is found in the image context... possible when bad parameters are passed into this function
            self.uiImage[0] = UIGraphicsGetImageFromCurrentImageContext() ?? self.uiImage[0]
            UIGraphicsEndImageContext()
        }
        
        /// Masks a portion of the image with a supplied mask.
        ///
        /// - Parameters:
        ///     - srcImage: an image
        
        open func mask(_ srcImage: Image) {
            UIGraphicsBeginImageContextWithOptions(CGSize(width: self.width, height: self.height), false, 2.0)
            let context = UIGraphicsGetCurrentContext()!
            //mask strategy adapted from https://stackoverflow.com/questions/8126276/how-to-convert-uiimage-cgimagerefs-alpha-channel-to-mask
            let decode = [ CGFloat(1), CGFloat(0),
                           CGFloat(0), CGFloat(1),
                           CGFloat(0), CGFloat(1),
                           CGFloat(0), CGFloat(1) ]
            
            let cgImage = srcImage.uiImage[0].cgImage!
            
            // Create the mask `CGImage` by reusing the existing image data
            // but applying a custom decode array.
            let mask =  CGImage(width: cgImage.width,
                                height: cgImage.height,
                                bitsPerComponent: cgImage.bitsPerComponent,
                                bitsPerPixel: cgImage.bitsPerPixel,
                                bytesPerRow: cgImage.bytesPerRow,
                                space: cgImage.colorSpace!,
                                bitmapInfo: cgImage.bitmapInfo,
                                provider: cgImage.dataProvider!,
                                decode: decode,
                                shouldInterpolate: cgImage.shouldInterpolate,
                                intent: cgImage.renderingIntent)
            
            context.saveGState()
            context.translateBy(x: 0.0, y: CGFloat(self.height))
            context.scaleBy(x: 1.0, y: -1.0)
            context.clip(to: CGRect(x: 0, y: 0, width: self.width, height: self.height), mask: mask!)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: 0.0, y: CGFloat(-self.height))
            self.uiImage[0].draw(in: CGRect(x: 0, y: 0, width: self.width, height: self.height))
            context.restoreGState()
            let image = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            
            self.uiImage[0] = image
        }
        
        open func filter(_ filterType:Filter, _ params: Any? = nil){
            for i in 0...uiImage.count - 1{
                guard let currentCGImage = self.uiImage[i].cgImage else { return }
                let currentCIImage = CIImage(cgImage: currentCGImage)
                var filter: CIFilter?
                
                switch filterType {
                case Filter.pixellate:
                    filter = CIFilter(name: "CIPixellate")
                    filter?.setValue(currentCIImage, forKey: kCIInputImageKey)
                    filter?.setValue(params ?? 50, forKey: kCIInputScaleKey)
                case Filter.hue_rotate:
                    filter = CIFilter(name: "CIHueAdjust")
                    filter?.setValue(currentCIImage, forKey: kCIInputImageKey)
                    filter?.setValue(params ?? 50, forKey: kCIInputAngleKey)
                case Filter.sepia_tone:
                    filter = CIFilter(name: "CISepiaTone")
                    filter?.setValue(currentCIImage, forKey: kCIInputImageKey)
                    filter?.setValue(params ?? 1.0, forKey: kCIInputIntensityKey)
                case Filter.tonal:
                    filter = CIFilter(name: "CIPhotoEffectTonal")
                    filter?.setValue(currentCIImage, forKey: kCIInputImageKey)
                case Filter.monochrome:
                    filter = CIFilter(name: "CIColorMonochrome")
                    let c = params as! Color
                    let ciColor = CIColor(red: CGFloat(c.red), green: CGFloat(c.green), blue: CGFloat(c.blue))
                    filter?.setValue(currentCIImage, forKey: kCIInputImageKey)
                    filter?.setValue(ciColor, forKey: kCIInputColorKey)
                case Filter.invert:
                    filter = CIFilter(name: "CIColorInvert")
                    filter?.setValue(currentCIImage, forKey: kCIInputImageKey)
                }
                
                guard let outputImage = filter?.outputImage else { return }
                
                let processedImage = UIImage(cgImage: ciContext.createCGImage(outputImage, from: outputImage.extent)!)
                self.uiImage[i] = processedImage
            }
        }
        
        /*
         * MARK: - ANIMATED IMAGE METHODS
         */
        
        open func delay<D: Numeric>(_ d: D) {
            self.delay = d.convert()
        }
        
        open func numFrames() -> Int {
            return self.uiImage.count
        }
        
        open func getCurrentFrame() -> Int {
            return self.curFrame
        }
        
        open func setFrame(_ index: Int) {
            self.curFrame = index
        }
        
        open func reset() {
            self.curFrame = 0
        }
        
        open func play() {
            self.isPlaying = true
        }
        
        open func pause() {
            self.isPlaying = false
        }
        
        public func frame<D: Numeric, F: Numeric>(_ deltaTime: D, _ frameCount: F) -> UIImage {
            var d_deltaTime, d_frameCount: Double
            d_deltaTime = deltaTime.convert()
            d_frameCount = frameCount.convert()
            
            if uiImage.count == 1 {
                return uiImage[0]
            } else if !isPlaying || d_frameCount == lastFrameDrawn {
                return uiImage[curFrame]
            }
            
            self.lastFrameDrawn = d_frameCount
            self.deltaTime = self.deltaTime + d_deltaTime
            if self.deltaTime > self.delay {
                curFrame = curFrame + Int(self.deltaTime / self.delay)
                self.deltaTime = 0
            }
            if !(loop < loopMax || loopMax == -1){
                curFrame = uiImage.count - 1
            }
            else if curFrame >= uiImage.count {
                //todo simplify this logic
                curFrame = (loop + 1 < loopMax || loopMax == -1) ? 0 : uiImage.count - 1
                loop += 1
            }
            return uiImage[curFrame]
        }
        
        open func currentFrame() -> UIImage{
            return self.uiImage[curFrame]
        }
    }
}

extension UIColor {
    func image(_ size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { rendererContext in
            self.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
/*
 * SwiftProcessing: Image Picker
 *
 * Adapted from https://theswiftdev.com/picking-images-with-uiimagepickercontroller-in-swift-5/
 *
 * */

import UIKit

public extension Sketch {
    
    class ImagePicker: NSObject {
        
        private let pickerController: UIImagePickerController
        private weak var presentationController: UIViewController?
        
        private var sketch: Sketch!
        open var pickedAction: (Image) -> Void = {image in }
        
        
        public init(_ sketch: Sketch, _ presentationController: UIViewController) {
            self.pickerController = UIImagePickerController()
            self.sketch = sketch
            
            super.init()
            
            self.presentationController = presentationController
            
            self.pickerController.delegate = self
            
            self.pickerController.mediaTypes = ["public.image"]
        }
        
        // TO FUTURE CONTRIBUTORS: Add example use case here for docs.
        
        /// Shows an image picker.
        /// ```
        /// //
        /// ```
        /// - Parameters:
        ///      - type: Image Pcker type. Options are `.camera`, `.photo_library` and `.camera_roll`
        ///      - picked: A completion handler telling SwiftProcessing what to do with the image once it's selected.
        
        public func show(_ type: ImagePickerType = .camera_roll, _ picked: @escaping (Image) -> Void) {
            var pickType: UIImagePickerController.SourceType = .photoLibrary
            switch type{
            case ImagePickerType.camera: pickType = .camera
            case ImagePickerType.camera_roll: pickType = .savedPhotosAlbum
            case ImagePickerType.photo_library: pickType = .photoLibrary
            }
            
            guard UIImagePickerController.isSourceTypeAvailable(pickType) else {
                return
            }
            
            pickedAction = picked
            
            self.pickerController.sourceType = pickType
            self.presentationController?.present(self.pickerController, animated: true)
        }
        
        private func pickerController(_ controller: UIImagePickerController, didSelect image: UIImage?) {
            controller.dismiss(animated: true, completion: nil)
            if let i = image {
                UIGraphicsPushContext(sketch.context!)
                sketch.push()
                sketch.scale(UIScreen.main.scale, UIScreen.main.scale)
                pickedAction(Image(i))
                sketch.pop()
                UIGraphicsPopContext()
            }
        }
    }
}

extension Sketch.ImagePicker: UIImagePickerControllerDelegate {

    // Image picker overrides.
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.pickerController(picker, didSelect: nil)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController,
                                      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let image = info[.originalImage] as? UIImage else {
            return self.pickerController(picker, didSelect: nil)
        }
        self.pickerController(picker, didSelect: image)
    }
}

extension Sketch.ImagePicker: UINavigationControllerDelegate {
}

extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder?.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}
extension Sketch{
    
    /// Creates an image picker object.
    /// ```
    /// // Creates a new image picker object and stores it in picker
    /// let picker = createImagePicker()
    /// ```
    
    open func createImagePicker() -> ImagePicker{
        return ImagePicker(self, self.parentViewController!)
    }
}

/*
 * SwiftProcessing: Label
 *
 *
 * */

import Foundation
import UIKit

// =======================================================================
// MARK: - Label Class
// =======================================================================

open class Label : UIKitViewElement {
    
    /*
     * MARK: - INIT
     */
    
    init<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ view: Sketch, _ x: X, _ y: Y, _ width: W, _ height: H) {
        var cg_x, cg_y, cg_width, cg_height: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        cg_width = width.convert()
        cg_height = height.convert()
        
        let label = UILabel(frame: CGRect(x: cg_x, y: cg_y, width: cg_width, height: cg_height))
        super.init(view, label)
        
        // label.textAlignment
        // label.text
        // label.textColor
        // label.backgroundColor
        // label.font
    }
    
    /*
     * MARK: - METHODS
     */
    
    /// Returns the value of the slider.
    
    open func text(_ text: String) {
        (self.element as! UILabel).text = text
    }
    
    /// Sets the text alignment. The values are standard alignment values. Natural may be unfamiliar, but it honors the typing direction of the region the phone is set up in. Natural is the default on iOS.
    ///
    /// - Parameters:
    ///     - alignment: Possible values are TextAlignment.natural, TextAlignment.center, TextAlignment.left, TextAlignment.right, TextAlignment.justified
    
    open func textAlignment(_ alignment: TextAlignment){
        switch alignment {
        case TextAlignment.natural:
            (self.element as! UILabel).textAlignment = NSTextAlignment.natural
        case TextAlignment.center:
            (self.element as! UILabel).textAlignment = NSTextAlignment.center
        case TextAlignment.left:
            (self.element as! UILabel).textAlignment = NSTextAlignment.left
        case TextAlignment.right:
            (self.element as! UILabel).textAlignment = NSTextAlignment.right
        case TextAlignment.justified:
            (self.element as! UILabel).textAlignment = NSTextAlignment.justified
        }
    }
    
    /// Sets the text color.
    ///
    /// - Parameters:
    ///     - gray: A gray value from 0-255.
    
    open func textColor<G: Numeric>(_ gray: G){
        let cg_gray: CGFloat = gray.convert()
        
        (self.element as! UILabel).textColor = UIColor(red: cg_gray, green: cg_gray, blue: cg_gray, alpha: 255)
    }
    
    /// Sets the text color.
    ///
    /// - Parameters:
    ///     - gray: A gray value from 0-255.
    ///     - alpha: A gray value from 0-255.
    
    open func textColor<G: Numeric, A: Numeric>(_ gray: G, _ alpha: A){
        let cg_gray: CGFloat = gray.convert()
        let cg_alpha: CGFloat = alpha.convert()
        
        (self.element as! UILabel).textColor = UIColor(red: cg_gray, green: cg_gray, blue: cg_gray, alpha: cg_alpha)
    }
    
    /// Sets the text color.
    ///
    /// - Parameters:
    ///     - v1: A red value from 0-255.
    ///     - v2: A green value from 0-255.
    ///     - v3: A blue value from 0-255.
    
    open func textColor<V1: Numeric, V2: Numeric, V3: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3){
        var cg_v1, cg_v2, cg_v3: CGFloat
        cg_v1 = v1.convert()
        cg_v2 = v2.convert()
        cg_v3 = v3.convert()
        
        (self.element as! UILabel).textColor = UIColor(red: cg_v1, green: cg_v2, blue: cg_v3, alpha: 255)
    }
    
    /// Sets the text color.
    ///
    /// - Parameters:
    ///     - v1: A red value from 0-255.
    ///     - v2: A green value from 0-255.
    ///     - v3: A blue value from 0-255.
    ///     - alpha: An optional alpha value from 0-255. Defaults to 255.
    
    open func textColor<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ alpha: A){
        var cg_v1, cg_v2, cg_v3, cg_alpha: CGFloat
        cg_v1 = v1.convert()
        cg_v2 = v2.convert()
        cg_v3 = v3.convert()
        cg_alpha = alpha.convert()
        
        (self.element as! UILabel).textColor = UIColor(red: cg_v1, green: cg_v2, blue: cg_v3, alpha: cg_alpha)
    }
    
    /// Sets the font of the text.
    ///
    /// - Parameters:
    ///     - font: A UIFont.
    
    open func font(_ font: UIFont) {
        (self.element as! UILabel).font = font
    }
    
    /// Sets the size of the font.
    ///
    /// - Parameters:
    ///     - size: A UIFont.
    
    open func fontSize<S: Numeric>(_ size: S) {
        let cg_size: CGFloat = size.convert()
        
        (self.element as! UILabel).font = UIFont.systemFont(ofSize: cg_size)
    }
}

// =======================================================================
// MARK: - SwiftProcessing Method to Programmatically Create a Slider
// =======================================================================

extension Sketch {
    
    /// Creates a text label programmatically.
    ///
    /// - Parameters:
    ///     - min: The minimum setting of the slider.
    ///     - max: The maximum setting of the slider.
    ///     - value: The value the slider starts at. Defaults to `nil`
    
    open func createLabel<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ view: Sketch, _ x: X, _ y: Y, _ width: W, _ height: H) -> Label {
        let l = Label(view, x, y, width, height)
        viewRefs[l.self.id] = l.self
        return l
    }
}

// https://stackoverflow.com/questions/38464134/how-to-make-extension-for-multiple-classes-swift

protocol LabelControl {
    
    func setText(_ text: String)
    
    func setFontSize<S: Numeric>(_ size: S)
    
    func setTextAlignment(_ alignment: TextAlignment)
    
    func setTextColor<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ alpha: A)
    
    func setTextColor<V1: Numeric, V2: Numeric, V3: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3)
    
    func setTextColor<G: Numeric, A: Numeric>(_ gray: G, _ alpha: A)
    
    func setTextColor<G: Numeric>(_ gray: G)
    
}

extension LabelControl {
    // If multiple UI elements need labels. I wonder if it's possible to write the function definitions as an extension so we don't have to implement the protocol manually in each class. An extension should work, but I don't have access to the self.label property here. Wonder if there's a workaround.

}
import UIKit
import SceneKit
import Foundation
import SceneKit.ModelIO

public class ModelNode: MDLObject{
    var tag: String = ""
    var mdlOject: MDLObject
    
    init(tag: String, mdlObject: MDLObject){
        self.mdlOject = mdlObject
        self.tag = tag
    }
}
/*
 * Swift Processing: Numeric Protocol Extension
 *
 * In order to facilitate conversions between various data
 * types and avoid early conversations about casting and coersion
 * we use this protocol and extension.
 *
 */

import Foundation
import CoreGraphics

// =======================================================================
// MARK: - NUMERIC MODIFICATION
// =======================================================================

// Source: https://stackoverflow.com/questions/39486362/how-to-cast-generic-number-type-t-to-cgfloat

public protocol Numeric {
    init(_ v:Float)
    init(_ v:Double)
    init(_ v:Int)
    init(_ v:UInt)
    init(_ v:Int8)
    init(_ v:UInt8)
    init(_ v:Int16)
    init(_ v:UInt16)
    init(_ v:Int32)
    init(_ v:UInt32)
    init(_ v:Int64)
    init(_ v:UInt64)
    init(_ v: CGFloat)
}

extension Float   : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}
extension Double  : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}
extension CGFloat : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}
extension Int     : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}
extension Int8    : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}
extension Int16   : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}
extension Int32   : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}
extension Int64   : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}
extension UInt    : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}
extension UInt8   : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}
extension UInt16  : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}
extension UInt32  : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}
extension UInt64  : Numeric {func _asOther<T:Numeric>() -> T { return T(self) }}


extension Numeric {

    func convert<T: Numeric>() -> T {
        switch self {
        case let x as CGFloat:
            return T(x) //T.init(x)
        case let x as Float:
            return T(x)
        case let x as Double:
            return T(x)
        case let x as Int:
            return T(x)
        case let x as UInt:
            return T(x)
        case let x as Int8:
            return T(x)
        case let x as UInt8:
            return T(x)
        case let x as Int16:
            return T(x)
        case let x as UInt16:
            return T(x)
        case let x as Int32:
            return T(x)
        case let x as UInt32:
            return T(x)
        case let x as Int64:
            return T(x)
        case let x as UInt64:
            return T(x)
        default:
            assert(false, "Numeric convert cast failed!")
            return T(0)
        }
    }
}
/*
 * SwiftProcessing
 *
 * */


import UIKit
import SceneKit

// =======================================================================
// MARK: - Delegate/Protocol
// =======================================================================

@objc public protocol SketchDelegate {
    func setup()
    func draw()
    @objc optional func touchStarted()
    @objc optional func touchMoved()
    @objc optional func touchEnded()
}

@IBDesignable open class Sketch: UIView {
    
    // =======================================================================
    // MARK: - Processing Constants
    // =======================================================================
    
    // NOTE: Swift design guidelines implicitly discourage all-caps constants.
    // This is very Java- or JavaScript-ey. A more Swift-ey way of doing this
    // would be to create categorical enums. Enums would also leverage auto-
    // complete in the same way that these constants would. For the constants
    // that have values, another approach would be to create structs.
    
    // https://swift.org/documentation/api-design-guidelines/#conventions
    
    /*
     * MARK: - MATH CONSTANTS
     */
    
    /// The `Math` struct contains all of the constant values that can be used in SwiftProcessing for mathematics. **Note:** Values are returned as Doubles.
    
    public struct Math {
        public static let half_pi = Double.pi / 2
        public static let pi = Double.pi
        public static let quarter_pi = Double.pi / 4
        public static let two_pi = Double.pi * 2
        public static let tau = Double.pi * 2
        public static let e = M_E
    }
    
    /*
     * MARK: - KEYWORD CONSTANTS
     */
    
    /// The `Default` struct contains the defaults for the style states that SwiftProcessing keeps track of.
    
    public struct Default {
        public static let colorMode = ColorMode.rgb
        public static let fill = Color(255)
        public static let stroke = Color(0.0)
        public static let tint = Color(0.0, 0.0)
        public static let strokeWeight = 1.0
        public static let strokeJoin = StrokeJoin.miter
        public static let strokeCap = StrokeCap.round
        public static let rectMode = ShapeMode.corner
        public static let ellipseMode = ShapeMode.center
        public static let imageMode = ShapeMode.corner
        public static let textFont = "HelveticaNeue-Thin"
        public static let textSize = 32.0 // Processing is 12, so let's test this out.
        public static let textLeading = 37.0 // Processing is 14. This is a similar increase.
        public static let textAlign = Alignment.left
        public static let textAlignY = AlignmentY.baseline
        public static let blendMode = CGBlendMode.normal
    }
    
    
    /// The `colorMode()` function enables SwiftProcessing users to switch between
    
    open func colorMode(_ mode: ColorMode) {
        settings.colorMode = mode
    }
    
    /*
     * MARK: - SCREEN / DISPLAY PROPERTIES
     */
    
    public weak var sketchDelegate: SketchDelegate?
    public var width: Double = 0
    public var height: Double = 0
    public var nativeWidth: Double = 0
    public var nativeHeight: Double = 0
    public let deviceWidth = Double(UIScreen.main.bounds.width)
    public let deviceHeight = Double(UIScreen.main.bounds.height)
    
    public var isFaceMode: Bool = false
    public var isFaceFill: Bool = true
    
    public var frameCount: Double = 0
    public var deltaTime: Double = 1/60
    private var lastTime: Double = CACurrentMediaTime()
    
    var fps: Double = 60
    
    var fpsTimer: CADisplayLink?
    
    var isFill: Bool = true
    var isStroke: Bool = true
    var isErase: Bool = false
    
    var isScrollX: Bool = false
    var isScrollY: Bool = true
    var minX: Double = 0
    var maxX: Double = 0
    var minY: Double = 0
    var maxY: Double = 0
    
    public var settingsStack: SketchSettingsStack = SketchSettingsStack()
    public var matrixStack: SketchMatrixStack = SketchMatrixStack()
    public var settings: SketchSettings = SketchSettings()
    
    open var pixels: [UInt8] = []
    
    open var touches: [Vector] = []
    open var touched: Bool = false
    open var touchX: Double = -1
    open var touchY: Double = -1
    
    // This is the last string-based constant in SwiftProcessing. Leaving this here for future contributors. It needs to be converted to an enum but .self cannot be the name of a member of an enum.
    var touchMode: TouchMode = .sketch
    var touchRecongizer: UIGestureRecognizer!
    
    var notificationActionsWithData: [String: (_ data: [AnyHashable : Any]) -> Void] = [:]
    var notificationActions: [String: () -> Void] = [:]
    
    var isSetup: Bool = false
    open var context: CGContext?
    
    /*
     * MARK: - VERTICES
     */

    var vertexMode: VertexMode = .normal
    var isContourStarted: Bool = false
    var contourPoints: [CGPoint] = []
    var shapePoints: [CGPoint] = []
    
    private var curveVertices = [[CGFloat]]()
    private var curveVertexCount: Int = 0
    
    /*
     * MARK: - TRANSFORMATION PROPERTIES
     */
    
    var scene: SCNScene = SCNScene()
    var lightNode: SCNNode = SCNNode()
    var ambientLightNode: SCNNode = SCNNode()
    var cameraNode: SCNNode = SCNNode()
    var lookAtNode: SCNNode = SCNNode()
    var rootNode: TransitionSCNNode = TransitionSCNNode()
    
    var stackOfTransformationNodes: [TransitionSCNNode] = []
    var lastFrameTransformationNodes: [TransitionSCNNode] = []
    var currentTransformationNode: TransitionSCNNode = TransitionSCNNode()
    var currentStack: [TransitionSCNNode] = []
    
    var globalPosition: SIMD4<Float> = simd_float4(0,0,0,0)
    var globalRotation: SIMD4<Float> = simd_float4(0,0,0,0)
    
    var texture: Image? = nil
    var textureID: String = ""
    var textureEnabled: Bool = false
    var scnmat: SCNMaterial = SCNMaterial()
    var enable3DMode: Bool = false
    
    // Used to store references to UIKitViewElements created using SwiftProcessing. Storing references avoids the elements being deallocated from memory. This is needed to have the touch events continue to function
    
    open var viewRefs: [String: UIKitViewElement?] = [:]
    
    // =======================================================================
    // MARK: - INIT
    // =======================================================================
    
    public init() {
        super.init(frame: CGRect())
        initHelper()
    }
    
    required public init(coder: NSCoder) {
        super.init(coder: coder)!
        initHelper()
    }
    
    private func initHelper(){
        initTouch()
        initNotifications()
        sketchDelegate = self as? SketchDelegate
        createCanvas(0.0, 0.0, UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        self.layer.drawsAsynchronously = true
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height), true, 1.0)
        
        self.context = UIGraphicsGetCurrentContext()
        
        UIGraphicsEndImageContext()
        
        self.clearsContextBeforeDrawing = false
        
        loop()
    }
    
    // The graphics context also needs to have all of the initial global states set up. Restore was created to mimic Core Graphics restore function, but it also works perfectly to sync up our default SwiftProcessing global states with Core Graphics' states.
    
    private func initializeGlobalContextStates() {
        Sketch.SketchSettings.defaultSettings(self)
    }
    
    
    // ========================================================
    // MARK: - DRAW LOOP
    // ========================================================
    
    /// `beginDraw()` sets the global state. It ensures that the Core Graphics context and SwiftProcessing's global settings start out in sync. Overridable if anything needs to be done before `setup()` is run.
    
    open func beginDraw() {
        initializeGlobalContextStates()
    }
    
    override public func draw(_ rect: CGRect) {
        // This override is not actually called but required for the UIView to call the display function. This is a reference to the UIView's draw, not Processing's draw loop.
    }
    
    override public func display(_ layer: CALayer) {
        preDraw3D()
        
        updateDimensions()
        updateTimes()

        // Refresh all of the settings just in case to maintain state. At some point, we might be able to remove this. It is here as a precaution for now.
        settings.reapplySettings(self)
        context?.saveGState()
        
        // Having two pushes (.saveGState() and below) might seem redundant, but UIGraphicsPush is necessary for UIImages.
        UIGraphicsPushContext(context!)

        scale(UIScreen.main.scale, UIScreen.main.scale)
        
        // To ensure setup only runs once.
        if !isSetup{
            sketchDelegate?.setup()
            isSetup = true
        }
        
        // Should happen right before draw and inside of the push() and pop().
        updateTouches()
        
        sketchDelegate?.draw() // All instructions go into current context.
        
        postDraw3D()
        
        UIGraphicsPopContext()
        context?.restoreGState()
        
        // This makes the background persist if the background isn't cleared.
        let img = context!.makeImage() // <- This may be a speed bottleneck.
        layer.contents = img
        layer.contentsGravity = .resizeAspect
    }
    
    private func updateDimensions() {
        self.width = Double(self.frame.width)
        self.height = Double(self.frame.height)
        self.nativeWidth = Double(self.frame.width) * Double(UIScreen.main.scale)
        self.nativeHeight = Double(self.frame.height) * Double(UIScreen.main.scale)
        
        //recreate the backing ImageContext when the native dimensions do not match the context dimensions
        if (self.context?.width != Int(nativeWidth)
                || self.context?.height != Int(nativeHeight)) {
            UIGraphicsBeginImageContext(CGSize(width: nativeWidth, height: nativeHeight))
            self.context = UIGraphicsGetCurrentContext()
            UIGraphicsEndImageContext()
        }
    }
    
    private func updateTimes() {
        frameCount =  frameCount + 1
        let newTime = CACurrentMediaTime()
        deltaTime = newTime - lastTime
        lastTime = newTime
    }
    
    /// `endDraw()` is an overridable function that runs after `noLoop()` is run. It can be used for any last minute cleanup after the last `draw()` loop has executed.
    
    open func endDraw() {
    }
    
 
}
/*
 * Swift Processing 2D Primitives w/ Generics
 *
 * A new and complete set of shapes that use generics
 * to ease new users into Swift Processing without
 * deep knowledge of types.
 *
 * To avoid having students and new programmers encounter
 * the difficulties switching between Swift CGFloat/Double
 * we are using generics for user-facing code, and
 * converting everything to CGFloats internally to
 * interface with Core Graphics.
 *
 */

import UIKit
import CoreGraphics

// =======================================================================
// MARK: - GENERIC SHAPES PROTOCOL
// =======================================================================


/// Draw 2D Primitives to the screen
public protocol Shapes: Sketch {
    
    /// Draw an arc to the screen.
    /// - Parameters:
    ///   - x: x-coordinate of the arc's ellipse
    ///   - y:  y-coordinate of the arc's ellipse
    ///   - width: width of the arc's ellipse by default
    ///   - height: height of the arc's ellipse by default
    ///   - start: angle to start the arc, specified in radians
    ///   - stop: angle to stop the arc, specified in radians
    ///   - mode:  optional parameter to determine the way of drawing the arc. either CHORD, PIE or OPEN
    func arc<X: Numeric, Y: Numeric, W: Numeric, H: Numeric, S1: Numeric, S2: Numeric>(_ x: X, _ y: Y, _ width: W, _ height: H, _ start: S1, _ stop: S2, _ mode: ArcMode)
    
    /// Draw an ellipse to the screen.
    /// - Parameters:
    ///   - x: x-coordinate of the center of ellipse.
    ///   - y: y-coordinate of the center of ellipse.
    ///   - width: width of the ellipse.
    ///   - height: height of the ellipse. (optional)
    func ellipse<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ x: X, _ y: Y, _ width: W, _ height: H)
    
    /// Draw a circle to the screen
    /// - Parameters:
    ///   - x: x-coordinate of the centre of the circle.
    ///   - y: y-coordinate of the centre of the circle.
    ///   - diameter: diameter of the circle.
    func circle<X: Numeric, Y: Numeric, D: Numeric>(_ x: X, _ y: Y, _ diameter: D)
    
    /// Draw a line to the screen.
    /// - Parameters:
    ///   - x1: the x-coordinate of the first point
    ///   - y1: the y-coordinate of the first point
    ///   - x2: the x-coordinate of the second point
    ///   - y2: the y-coordinate of the second point
    
    func line<X1: Numeric, Y1: Numeric, X2: Numeric, Y2: Numeric>(_ x1: X1, _ y1: Y1, _ x2: X2, _ y2: Y2)
    
    /// Draws a single point on the screen using the current stroke weight.
    /// - Parameters:
    ///   - x: the x-coordinate
    ///   - y: the y-coordinate
    func point<X: Numeric, Y: Numeric>(_ x: X, _ y: Y)
    
    /// Draws a rectangle on the screen
    /// - Parameters:
    ///   - x: x-coordinate of the rectangle.
    ///   - y: y-coordinate of the rectangle.
    ///   - width: width of the rectangle.
    ///   - height: height of the rectangle. (Optional)
    func rect<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ x: X, _ y: Y, _ width: W, _ height: H)
    
    /// Draws a square to the screen.
    /// - Parameters:
    ///   - x: x-coordinate of the square.
    ///   - y: y-coordinate of the square.
    ///   - size: size of the square.
    func square<X: Numeric, Y: Numeric, S: Numeric>(_ x: X, _ y: Y, _ size: S)
    
    /// Draws a trangle to the screen.
    /// - Parameters:
    ///   - x1: x-coordinate of the first point
    ///   - y1: y-coordinate of the first point
    ///   - x2: x-coordinate of the second point
    ///   - y2: y-coordinate of the second point
    ///   - x3: x-coordinate of the third point
    ///   - y3: y-coordinate of the third point
    func triangle<X1: Numeric, Y1: Numeric, X2: Numeric, Y2: Numeric, X3: Numeric, Y3: Numeric>(_ x1: X1, _ y1: Y1, _ x2: X2, _ y2: Y2, _ x3: X3, _ y3: Y3)
    
    /// Draws a quad to the screen.
    /// - Parameters:
    ///   - x1: x-coordinate of the first point
    ///   - y1: y-coordinate of the first point
    ///   - x2: x-coordinate of the second point
    ///   - y2: y-coordinate of the second point
    ///   - x3: x-coordinate of the third point
    ///   - y3: y-coordinate of the third point
    ///   - x4: x-coordinate of the fourth point
    func quad<X1: Numeric, Y1: Numeric, X2: Numeric, Y2: Numeric, X3: Numeric, Y3: Numeric, X4: Numeric, Y4: Numeric>(_ x1: X1, _ y1: Y1, _ x2: X2, _ y2: Y2, _ x3: X3, _ y3: Y3, _ x4: X4, _ y4: Y4)
}

// =======================================================================
// MARK: - GENERIC SHAPES EXTENSION
// =======================================================================

extension Sketch: Shapes {
    
    public func arc<X: Numeric, Y: Numeric, W: Numeric, H: Numeric, S1: Numeric, S2: Numeric>(_ x: X, _ y: Y, _ width: W, _ height: H, _ start: S1, _ stop: S2, _ mode: ArcMode = .pie) {
        var cg_x, cg_y, cg_w, cg_h, cg_start, cg_stop: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        cg_w = width.convert()
        cg_h = height.convert()
        cg_start = start.convert()
        cg_stop = stop.convert()
        
        let r = cg_w * 0.5
        let t = CGAffineTransform(scaleX: 1.0, y: cg_h / cg_w)
        
        context?.beginPath()
        let path: CGMutablePath = CGMutablePath()
        path.addArc(center: CGPoint(x: cg_x, y: cg_y / t.d), radius: r, startAngle: cg_start, endAngle: cg_stop, clockwise: false, transform: t)
        switch mode{
        case ArcMode.pie:
            path.addLine(to: CGPoint(x: cg_x, y: cg_y))
            path.closeSubpath()
        case ArcMode.chord:
            path.closeSubpath()
        case ArcMode.open:
            // NEEDS TESTING
            break
        }
        context?.addPath(path)
        context?.drawPath(using: .eoFillStroke)
    }
    
    public func ellipse<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ x: X, _ y: Y, _ width: W, _ height: H = -1 as! H ) {
        var cg_x, cg_y, cg_w, cg_h: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        cg_w = width.convert()
        cg_h = height.convert()
        
        // We're going to manipulate the coordinate matrix, so we need to freeze everything.
        context?.saveGState()
        ellipseModeHelper(cg_x, cg_y, cg_w, cg_h)
        
        // Corners adjustment
        var newW = cg_w
        var newH = cg_h
        if settings.ellipseMode == ShapeMode.corners {
            newW = cg_w - cg_x
            newH = cg_h - cg_y
        }
        
        context?.fillEllipse(in: CGRect(x: cg_x, y: cg_y, width: newW, height: newH))
        context?.strokeEllipse(in: CGRect(x: cg_x, y: cg_y, width: newW, height: newH))
        
        // We're going to restore the matrix to the previous state.
        context?.restoreGState()
    }
    
    public func circle<X: Numeric, Y: Numeric, D: Numeric>(_ x: X, _ y: Y, _ diameter: D) {
        ellipse(x, y, diameter, diameter)
    }
    
    // Private methods remain CGFloat.
    private func ellipseModeHelper(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        switch settings.ellipseMode {
        case .center:
            translate(-width * 0.5, -height * 0.5)
        case .radius:
            scale(0.5, 0.5)
        case .corner:
            return
        case .corners:
            return
        }
    }
    
    public func line<X1: Numeric, Y1: Numeric, X2: Numeric, Y2: Numeric>(_ x1: X1, _ y1: Y1, _ x2: X2, _ y2: Y2) {
        var cg_x1, cg_y1, cg_x2, cg_y2: CGFloat
        cg_x1 = x1.convert()
        cg_y1 = y1.convert()
        cg_x2 = x2.convert()
        cg_y2 = y2.convert()
        
        context?.move(to: CGPoint(x: cg_x1, y: cg_y1))
        context?.addLine(to: CGPoint(x: cg_x2, y: cg_y2))
        context?.strokePath()
    }
    
    public func point<X: Numeric, Y: Numeric>(_ x: X, _ y: Y) {
        var cg_x, cg_y: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        
        context?.setLineCap(.round)
        line(cg_x, cg_y, cg_x + CGFloat(settings.strokeWeight), cg_y)
        context?.setLineCap(.square)
    }
    
    public func rect<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ x: X, _ y: Y, _ width: W, _ height: H) {
        var cg_x, cg_y, cg_w, cg_h: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        cg_w = width.convert()
        cg_h = height.convert()
        
        // We're going to manipulate the coordinate matrix, so we need to freeze everything.
        context?.saveGState()
        
        rectModeHelper(cg_x, cg_y, cg_w, cg_h)
        
        var newW = cg_w
        var newH = cg_h
        if settings.rectMode == .corners {
            newW = cg_w - cg_x
            newH = cg_h - cg_y
        }
        
        // Apple recommends doing fill before stroke. This is consistent with how
        // Processing works as well. Using the painting metaphor we imagine that
        // we fill the shape, before stroking it's outline and stroke weights behave
        // and appear how we would expect them to.
        
        context?.fill(CGRect(x: cg_x, y: cg_y, width: newW, height: newH))
        context?.stroke(CGRect(x: cg_x, y: cg_y, width: newW, height: newH))
        
        // We're going to restore the matrix to the previous state.
        context?.restoreGState()
    }
    
    private func rectModeHelper(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        switch settings.rectMode {
        case .center:
            translate(-width * 0.5, -height * 0.5)
        case .radius:
            scale(0.5, 0.5)
        case .corner:
            return
        case .corners:
            return
        }
    }
    
    // A function for use internally. Setting backgroundColor of the view does not seem to work, so we are forced to draw a rectangle to set the background color. That's fine, except that the rect function reads from the Processing graphics state, which is not what we want. We want consistent behavior no matter what API users are setting the state to.
    
    public func internalRect<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ x: X, _ y: Y, _ width: W, _ height: H) {
        var cg_x, cg_y, cg_w, cg_h: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        cg_w = width.convert()
        cg_h = height.convert()
        
        context?.fill(CGRect(x: cg_x, y: cg_y, width: cg_w, height: cg_h))
    }
    
    public func square<X: Numeric, Y: Numeric, S: Numeric>(_ x: X, _ y: Y, _ start: S) {
        rect(x, y, start, start)
    }
    
    public func triangle<X1: Numeric, Y1: Numeric, X2: Numeric, Y2: Numeric, X3: Numeric, Y3: Numeric>(_ x1: X1, _ y1: Y1, _ x2: X2, _ y2: Y2, _ x3: X3, _ y3: Y3) {
        var cg_x1, cg_y1, cg_x2, cg_y2, cg_x3, cg_y3: CGFloat
        cg_x1 = x1.convert()
        cg_y1 = y1.convert()
        cg_x2 = x2.convert()
        cg_y2 = y2.convert()
        cg_x3 = x3.convert()
        cg_y3 = y3.convert()
        
        context?.beginPath()
        context?.move(to: CGPoint(x: cg_x1, y: cg_y1))
        context?.addLine(to: CGPoint(x: cg_x2, y: cg_y2))
        context?.addLine(to: CGPoint(x: cg_x3, y: cg_y3))
        context?.closePath()
        context?.drawPath(using: .eoFillStroke)
    }
    
    public func quad<X1: Numeric, Y1: Numeric, X2: Numeric, Y2: Numeric, X3: Numeric, Y3: Numeric, X4: Numeric, Y4: Numeric>(_ x1: X1, _ y1: Y1, _ x2: X2, _ y2: Y2, _ x3: X3, _ y3: Y3, _ x4: X4, _ y4: Y4) {
        var cg_x1, cg_y1, cg_x2, cg_y2, cg_x3, cg_y3, cg_x4, cg_y4: CGFloat
        cg_x1 = x1.convert()
        cg_y1 = y1.convert()
        cg_x2 = x2.convert()
        cg_y2 = y2.convert()
        cg_x3 = x3.convert()
        cg_y3 = y3.convert()
        cg_x4 = x4.convert()
        cg_y4 = y4.convert()
        
        context?.beginPath()
        context?.move(to: CGPoint(x: cg_x1, y: cg_y1))
        context?.addLine(to: CGPoint(x: cg_x2, y: cg_y2))
        context?.addLine(to: CGPoint(x: cg_x3, y: cg_y3))
        context?.addLine(to: CGPoint(x: cg_x4, y: cg_y4))
        context?.closePath()
        context?.drawPath(using: .eoFillStroke)
    }
}

import UIKit
import SceneKit

public extension Sketch {

    func preDraw3D(){

        self.lastFrameTransformationNodes = self.stackOfTransformationNodes
        self.stackOfTransformationNodes = [self.rootNode]
        self.rootNode.position = SCNVector3(0,0,0)
        self.rootNode.eulerAngles = SCNVector3(0,0,0)
        self.currentTransformationNode = self.rootNode
        for node in lastFrameTransformationNodes {
            node.addTransitionNodes()
            node.removeShapeNodes()
        }


        self.scnmat = SCNMaterial()
    }

    func postDraw3D(){

        for node in lastFrameTransformationNodes {
            node.removeUnusedTransitionNodes()
        }

    }
}

extension SCNVector3 {
    mutating func add(_ v1: SCNVector3){
        self.x += v1.x
        self.y += v1.y
        self.z += v1.z
    }

    func equals(_ vector: SCNVector3)-> Bool {
        return self.x == vector.x && self.y == vector.y && self.z == vector.z
    }
}

extension SCNNode {

    func sameNode(_ vector: SCNVector3, _ property: String) -> Bool{

        if property == "rotation" {

            return vector.equals(self.eulerAngles)

        } else if property == "position" {

            return vector.equals(self.position)

        }

        return false

    }

    func sameNode(_ geometry: SCNGeometry) -> Bool{

        return self.geometry! == geometry

    }

    func cleanup() {
        for child in childNodes {
           child.cleanup()
        }
        self.constraints = []
        self.geometry?.firstMaterial?.diffuse.contents = nil
        self.geometry?.materials = []
        self.geometry = nil
    }
}
import UIKit
import SceneKit
import Foundation


public extension Sketch {

    func camera(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat, _ centerX: CGFloat, _ centerY: CGFloat, _ centerZ: CGFloat, _ upX: CGFloat, _ upY: CGFloat, _ upZ: CGFloat){

        self.cameraNode.position = SCNVector3(x, y, z)
        self.lookAtNode.position = SCNVector3(centerX, centerY, centerZ)

        self.cameraNode.rotation = SCNVector4(upX,upY,upZ,1)

    }

    func setCamera(_ camNode: Camera3D) {

        self.lookAtNode.removeFromParentNode()
        self.cameraNode.removeFromParentNode()
        self.scene.rootNode.addChildNode(camNode.baseNode)
        self.scene.rootNode.addChildNode(camNode.cameraNode)
        self.lookAtNode = camNode.baseNode
        self.cameraNode = camNode.cameraNode

    }

    func createCamera3D() -> Camera3D{
        let cam: Camera3D = Camera3D()
        return cam
    }

}
import UIKit
import SceneKit

public extension Sketch {

    func create3D(){

        let sceneView = SCNView(frame: self.frame)
        self.addSubview(sceneView)

        self.scene = SCNScene()
        sceneView.scene = scene

        self.lookAtNode = SCNNode()
        self.lookAtNode.position = SCNVector3(x: 0, y: 0, z: 0)

        let camera = SCNCamera()
        self.cameraNode = SCNNode()
        self.cameraNode.camera = camera
        self.cameraNode.position = SCNVector3(x: 0, y: 0, z: 100)

        let lookAtConstraint = SCNLookAtConstraint(target: self.lookAtNode)
        self.cameraNode.constraints = [lookAtConstraint]

        let light = SCNLight()
        light.type = SCNLight.LightType.omni
        self.lightNode = SCNNode()
        self.lightNode.light = light
        self.lightNode.position = SCNVector3(x: 0, y: 0, z: 110)
        
        let ambientLight = SCNLight()
        self.ambientLightNode = SCNNode()
        self.ambientLightNode.light = ambientLight
        self.lightNode.position = SCNVector3(x: 0, y: 0, z: 110)

        let baseTransformationNode = TransitionSCNNode()
        self.rootNode = baseTransformationNode

        self.scene.rootNode.addChildNode(baseTransformationNode)
        self.scene.rootNode.addChildNode(lightNode)
        self.scene.rootNode.addChildNode(lookAtNode)
        self.scene.rootNode.addChildNode(cameraNode)
        self.scene.rootNode.addChildNode(ambientLightNode)

        self.enable3DMode = true
    }

}
import SceneKit
import Foundation


public extension Sketch {
    
    func ambientLight(_ v1: CGFloat, _ v2: CGFloat, _ v3: CGFloat, _ alpha: CGFloat = 1){
        self.ambientLightNode.light?.type = SCNLight.LightType.ambient
        self.ambientLightNode.light?.color = CGColor(srgbRed: v1, green: v2, blue: v3, alpha: alpha)
    }
    
    func ambientLight(_ gray: CGFloat, _ alpha: CGFloat = 1){
        self.ambientLightNode.light?.type = SCNLight.LightType.ambient
        self.ambientLightNode.light?.color = CGColor(genericGrayGamma2_2Gray: gray, alpha: alpha)
    }
    
    func createLight(_ tag: String, _ lightSCN: SCNLight, _type: String){
        
        let newtag = tag
        
        if(self.currentTransformationNode.getAvailableShape(newtag) == nil) {

            let node = SCNNode()
            node.position = SCNVector3(x: 0, y: 0, z: 0)

            let constraint = SCNLookAtConstraint(target: node)
            constraint.isGimbalLockEnabled = true
            node.constraints = [constraint]
            
            node.light = lightSCN
            
            self.currentTransformationNode.addShapeNode(node,newtag)

        }
    }
    
    func pointLight(_ v1: CGFloat, _ v2: CGFloat, _ v3: CGFloat, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat){
        let light = SCNLight()
        light.type = SCNLight.LightType.spot
        light.color = CGColor(srgbRed: v1, green: v2, blue: v3, alpha: alpha)
        
        let tag = "SPOT" + "r" + v1.description + "g" + v2.description + "b" + v3.description
        
        let positiontag = "x" + x.description + "y" + y.description + "z" + z.description
        
        let newtag = tag + positiontag
        
        createLight(newtag, light, _type: "SPOT")
    }
    
    func directionalLight(_ v1: CGFloat, _ v2: CGFloat, _ v3: CGFloat, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat){
        let light = SCNLight()
        light.type = SCNLight.LightType.directional
        light.color = CGColor(srgbRed: v1, green: v2, blue: v3, alpha: alpha)
        
        let tag = "SPOT" + "r" + v1.description + "g" + v2.description + "b" + v3.description
        
        let positiontag = "x" + x.description + "y" + y.description + "z" + z.description
        
        let newtag = tag + positiontag
        
        createLight(newtag, light, _type: "DIRECTIONAL")
    }
    
}


import UIKit
import SceneKit
import Foundation
import SceneKit.ModelIO


public extension Sketch {

    func loadModelObj(_ assetName: String, _ extensionName: String) -> ModelNode {
        guard let url = Bundle.main.url(forResource: assetName, withExtension: extensionName)
             else { fatalError("Failed to find model file.") }

        let asset = MDLAsset(url:url)
        guard let object = asset.object(at: 0) as? MDLMesh
             else { fatalError("Failed to get mesh from asset.") }
        let tag = "model" + assetName + extensionName

        let modelObject = ModelNode(tag: tag, mdlObject: object)

        return modelObject
    }

    func model(_ mdlObject: ModelNode){
        if var shapeNode = self.currentTransformationNode.getAvailableShape(mdlObject.tag) {


        } else {
            let node = SCNNode(mdlObject: mdlObject.mdlOject)
            node.position = SCNVector3(x: 0, y: 0, z: 0)

            let constraint = SCNLookAtConstraint(target: node)
            constraint.isGimbalLockEnabled = true
            node.constraints = [constraint]

            self.currentTransformationNode.addShapeNode(node,mdlObject.tag)
        }

    }

}
import UIKit
import SceneKit

public extension Sketch {

    func shapeCreate(_ tag: String, _ geometry: SCNGeometry,_ type: String) {

        var colorTag =  "r" + self.settings.fill.red.description + "g" + self.settings.fill.green.description + "b" + self.settings.fill.blue.description + "a" + self.settings.fill.alpha.description

        var materialTag =  String(UInt(bitPattern: ObjectIdentifier(self.scnmat)))

        var newtag = tag + colorTag + materialTag

        if var shapeNode = self.currentTransformationNode.getAvailableShape(newtag) {

        } else {
            geometry.firstMaterial?.diffuse.contents = UIColor(red: CGFloat(self.settings.fill.red/255.0), green: CGFloat(self.settings.fill.green/255.0), blue: CGFloat(self.settings.fill.blue/255.0), alpha: CGFloat(self.settings.fill.alpha))

            if self.texture != nil && self.textureEnabled {
                geometry.firstMaterial?.diffuse.contents = self.texture!.currentFrame()
                newtag = newtag + self.textureID

            }

            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(x: 0, y: 0, z: 0)

            let constraint = SCNLookAtConstraint(target: node)
            constraint.isGimbalLockEnabled = true
            node.constraints = [constraint]

            self.currentTransformationNode.addShapeNode(node,newtag)

        }

    }

    func sphere(_ radius: CGFloat){

        let tag: String = "Sphere" + radius.description

        let sphereGeometry = SCNSphere(radius: (radius))

        sphereGeometry.isGeodesic = true
        sphereGeometry.segmentCount = 20

        shapeCreate(tag, sphereGeometry, "Sphere")
    }

    func cylinder(_ width: CGFloat, _ height: CGFloat){

        let tag: String = "Cylinder" + "w" + width.description + "h" + height.description

        let cylinderGeometry = SCNCylinder(radius: width,height: height)


        shapeCreate(tag, cylinderGeometry, "Cylinder")

    }

    func cone(_ topRadius: CGFloat, _ bottomRadius: CGFloat, _ height: CGFloat){

        let tag: String = "Cone" + "r" + topRadius.description + "r" + bottomRadius.description + "h" + height.description

        let coneGeometry = SCNCone(topRadius: topRadius,bottomRadius: bottomRadius, height: height)

        shapeCreate(tag, coneGeometry, "Cone")

    }

    func pyramid(_ width: CGFloat, _ height: CGFloat, _ length: CGFloat){

        let tag: String = "Pyramid" + "w" + width.description + "h" + height.description + "l" + length.description

        let pyramidGeometry = SCNPyramid(width: width,height: height,length: length)

        shapeCreate(tag, pyramidGeometry, "Pyramid")

    }

    func capsule(_ radius: CGFloat, _ height: CGFloat, _ length: CGFloat) {

        let tag: String = "Capsule" + "r" + radius.description + "h" + height.description

        let capsuleGeomtry = SCNPyramid(width: radius,height: height, length: length)

        shapeCreate(tag, capsuleGeomtry, "Capsule")

    }

    func torus(_ ringRadius: CGFloat, _ pipeRadius: CGFloat) {

        let tag: String = "Torus" + "rr" + ringRadius.description + "pr" + pipeRadius.description

        let torusGeomtry = SCNTorus(ringRadius: ringRadius,pipeRadius: pipeRadius)

        shapeCreate(tag, torusGeomtry, "Torus")

    }

    func plane(_ width: CGFloat, _ height: CGFloat){

        let tag: String = "Plane" + "w" + width.description + "h" + height.description

        let planeGeometry = SCNPlane(width: width,height: height)

        shapeCreate(tag, planeGeometry, "Plane")
    }

    func box(_ w: CGFloat,_ h: CGFloat,_ l: CGFloat,_ rounded: CGFloat = 0){

        let tag: String = "Cube" + "width" + w.description + "height" + h.description
            + "length" + l.description + "chamfer" + rounded.description

        let boxGeometry = SCNBox(width: w, height: h, length: l, chamferRadius: rounded)

        shapeCreate(tag, boxGeometry, "Box")

    }

}
import UIKit
import SceneKit
import Foundation


public extension Sketch {

    func texture(_ image: Image) {

        self.texture = image
        self.textureEnabled = true
        self.textureID = String(UInt(bitPattern: ObjectIdentifier(self.texture!)))
    }
    
    func shininess(_ shine: CGFloat) {
        self.scnmat.shininess = shine
    }
    
    func specularMaterial(_ grey: CGFloat, _ alpha: CGFloat = 0) {
        self.scnmat.specular.contents = UIColor(white: grey, alpha: alpha)
    }
    
    func specularMaterial(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 0) {
        self.scnmat.specular.contents = UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    func specularMaterial(_ color: UIColor) {
        self.scnmat.specular.contents = color
    }
    
    func ambientMaterial(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 0) {
        self.scnmat.ambient.contents = UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    func ambientMaterial(_ color: UIColor) {
        self.scnmat.ambient.contents = color
    }
    
    func emissiveMaterial(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 0) {
        self.scnmat.emission.contents = UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    func emissiveMaterial(_ color: UIColor) {
        self.scnmat.emission.contents = color
    }
}
import UIKit
import SceneKit

public extension Sketch {

    func translationNode(_ vector: SCNVector3,_ property: String, _ checkNoShapeNodes: Bool = true, _ changeCurrentTransitionNode: Bool = true) {
        let lastNode = currentTransformationNode

        if lastNode.hasAvailableTransitionNodes() {
            // select node from available nodes from last frome branching off
            // current transition node
            let nextNode = lastNode.getNextAvailableTransitionNode()

            switch property {

            case "position":
                nextNode.position = vector
                nextNode.eulerAngles = SCNVector3(0,0,0)

            case "rotation":
                nextNode.eulerAngles = vector
                nextNode.position = SCNVector3(0,0,0)

            default:
                print("Wrong translation property key word")

            }
            self.stackOfTransformationNodes.append(nextNode)

            // changeCurrentTransitionNode enabled default
            // determines if future nodes will branch off this node
            if (changeCurrentTransitionNode){
                self.currentTransformationNode = nextNode
            }

        } else {
            // creating new node because no nodes available
            let newTransformationNode: TransitionSCNNode = TransitionSCNNode()

            lastNode.addChildNode(newTransformationNode)

            switch property {
            case "position":
                newTransformationNode.position = vector

            case "rotation":
                newTransformationNode.eulerAngles = vector
            default:
                print("Wrong translation property key word")
            }
            self.stackOfTransformationNodes.append(newTransformationNode)

            if (changeCurrentTransitionNode){
                self.currentTransformationNode = newTransformationNode
            }

        }

    }

    func translate(_ x: Float, _ y: Float, _ z: Float){

        let tempPosition: SCNVector3 = SCNVector3(x,y,z)

        self.translationNode(tempPosition, "position")

    }
    
    func translate(_ x: Double, _ y: Double, _ z: Double){
        translate(Float(x), Float(y), Float(z))
    }

    func rotate(_ x: Float, _ y: Float, _ z: Float){

        let tempRotation: SCNVector3 = SCNVector3(x,y,z)

        self.translationNode(tempRotation, "rotation")
    }
    
    func rotate(_ x: Double, _ y: Double, _ z: Double){
        rotate(Float(x), Float(y), Float(z))
    }

    func rotateX(_ r: Float){
        rotate(r, 0, 0)
    }
    
    func rotateX(_ r: Double){
        rotateX(Float(r))
    }

    func rotateY(_ r: Float){
        rotate(0, r, 0)
    }
    
    func rotateY(_ r: Double){
        rotateY(Float(r))
    }

    func rotateZ(_ r: Float){
        rotate(0, 0, r)
    }
    
    func rotateZ(_ r: Double){
        rotateZ(Float(r))
    }


}
/*
 * SwiftProcessing: Attributes
 *
 * */

import Foundation
import UIKit

/// Atributes used for drawing
public protocol Attributes: Sketch {
    
    /// Sets the width of the stroke used for lines, points and the border around shapes.
    /// - Parameter weight: the weight of the stroke
    func strokeWeight<W: Numeric>(_ weight: W)
    
    /// Sets how the ends of strokes will behave at their endpoints. `.square` cuts the the line off squarely directly at the endpoint.
    /// - Parameter cap: `.round` rounds the end as if you were to draw a circle with a diameter the size of the `strokeWeight`. `.project` is similar to `.round` except it's as if you draw a square with a centerpoint of your endpoint outward the size of the `strokeWeight`.
    func strokeCap(_ cap: StrokeCap)
    
    /// Sets the way that strokes are joined at each point when the `strokeWeight` is large.
    /// - Parameter join: `.miter` creates an angular joint. `.bevel` bevels off the point using a straight edge`.round` rounds each corner.
    func strokeJoin(_ join: StrokeJoin)
    
    /// Draws all geometry with smooth (anti-aliased) edges
    func smooth()
    
    /// Draws all geometry with jagged (aliased) edges
    func noSmooth()
    
    /// Modifies the location from which ellipses, circles, and arcs are drawn. The default mode is `.center`.
    /// The default mode is `imageMode(.corner)`, which interprets the second and third parameters of `image()` as the upper-left corner of the image. If two additional parameters are specified, they are used to set the image's width and height.
    /// `imageMode(.corners)` interprets the second and third parameters of `image()` as the location of one corner, and the fourth and fifth parameters as the opposite corner.
    /// `imageMode(.center)` interprets the second and third parameters of `image()` as the image's center point. If two additional parameters are specified, they are used to set the image's width and height.
    /// - Parameter eMode: either `.center`, `.radius`, `.corner`, or `.corners`
    func ellipseMode(_ eMode: ShapeMode)
    
    /// Modifies the location from which rectangles are drawn by changing the way in which parameters given to `rect()` are interpreted.
    /// The default mode is `rectMode(.corner)`, which interprets the first two parameters of `rect()` as the upper-left corner of the shape, while the third and fourth parameters are its width and height.
    /// `rectMode(.corners)` interprets the first two parameters of `rect()` as the location of one corner, and the third and fourth parameters as the location of the opposite corner.
    /// `rectMode(.center)` interprets the first two parameters of `rect()` as the shape's center point, while the third and fourth parameters are its width and height.
    /// `rectMode(.radius)` also uses the first two parameters of `rect()` as the shape's center point, but uses the third and fourth parameters to specify half of the shape's width and height.
    /// - Parameter eMode: either `.center`, `.radius`, `.corner`, or `.corners`
    func rectMode(_ rMode: ShapeMode)
    
    /// Modifies the location from which images are drawn by changing the way in which parameters given to `image()` are interpreted.
    /// The default mode is `imageMode(.corner)`, which interprets the second and third parameters of `image()` as the upper-left corner of the image. If two additional parameters are specified, they are used to set the image's width and height.
    /// `imageMode(.corners)` interprets the second and third parameters of image() as the location of one corner, and the fourth and fifth parameters as the opposite corner.
    /// `imageMode(.center)` interprets the second and third parameters of image() as the image's center point. If two additional parameters are specified, they are used to set the image's width and height.
    /// - Parameter eMode: either `.center`, `.radius`, `.corner`, or `.corners`
    func imageMode(_ iMode: ShapeMode)
}

extension Sketch: Attributes {
    public func strokeWeight<T: Numeric>(_ weight: T) {
        context?.setLineWidth(weight.convert())
        settings.strokeWeight = weight.convert()
    }
    
    public func strokeJoin(_ join: StrokeJoin) {
        switch join {
        case .miter:
            context?.setLineJoin(.miter)
        case .bevel:
            context?.setLineJoin(.bevel)
        case .round:
            context?.setLineJoin(.round)
        }
        settings.strokeJoin = join
    }
    
    // It should be noted that Apple's definition of these terms is inconsistent with Processing's. Here's a guide:
    /*
     Processing <-> Quartz
     ---------------------
     project    <-> square
     round      <-> round
     square     <-> butt
     */
    
    public func strokeCap(_ cap: StrokeCap) {
        switch cap {
        case .project:
            context?.setLineCap(.square) // See note above.
        case .round:
            context?.setLineCap(.round)
        case .square:
            context?.setLineCap(.butt) // See note above.
        }
        settings.strokeCap = cap
    }
    
    public func smooth() {
        context?.setShouldAntialias(true)
    }

    public func noSmooth() {
        context?.setShouldAntialias(false)
    }

    public func ellipseMode(_ mode: ShapeMode) {
        settings.ellipseMode = mode
    }
    
    public func rectMode(_ mode: ShapeMode) {
        settings.rectMode = mode
    }
    
    public func imageMode(_ mode: ShapeMode) {
        settings.imageMode = mode
    }
}
/*
 * SwiftProcessing: Augmented Reality
 *
 * */


import Foundation
import UIKit

public extension Sketch {
    func faceMode() {
        self.isFaceMode = true
    }
    func appMode() {
        self.isFaceMode = false
    }
    func faceFill() {
        self.isFaceFill = true
    }
    func noFaceFill() {
        self.isFaceFill = false
    }

}
/*
 * SwiftProcessing: Calculation
 *
 * */


import Foundation
import UIKit

/// Useful functions for common math calculations
public protocol Calculation {
    
    /// Constrains a value between a minimum and maximum value.
    /// - Parameters:
    ///   - n: number to constrain
    ///   - low: minimum limit
    ///   - high: maximum limit
    
    func constrain<N: Numeric, L: Numeric, H: Numeric>(_ n: N,_ low: L, _ high: H) -> Double
    
    /// Calculates the distance between two points
    /// - Parameters:
    ///   - x1: x-coordinate of the first point
    ///   - y1: y-coordinate of the first point
    ///   - x2: x-coordinate of the second point
    ///   - y2: y-coordinate of the second point
    
    func distance<X1: Numeric, Y1: Numeric, X2: Numeric, Y2: Numeric>(_ x1: X1, _ y1: Y1, _ x2: X2, _ y2: Y2) -> Double
    
    /// Calculates a number between two numbers at a specific increment
    /// - Parameters:
    ///   - start: first value
    ///   - stop: second value
    ///   - amount: amount to interpolate between the two values
    
    func lerp<START: Numeric, STOP: Numeric, A: Numeric>(_ start: START, _ stop: STOP, _ amount: A) -> Double
    
    /// Calculates the magnitude (or length) of a vector
    /// - Parameters:
    ///   - a: first value
    ///   - b: second value
    
    func mag<A: Numeric, B: Numeric>(_ a: A, _ b: B) -> Double
    
    /// Re-maps a number from one range to another.
    /// - Parameters:
    ///   - value: the incoming value to be converted
    ///   - start1: lower bound of the value's current range
    ///   - stop1: upper bound of the value's current range
    ///   - start2: lower bound of the value's target range
    ///   - stop2: upper bound of the value's target range
    ///   - withinBounds: constrain the value to the newly mapped range (Optional)
    
    func map<V: Numeric, START1: Numeric, STOP1: Numeric, START2: Numeric, STOP2: Numeric>(_ value: V, _ start1: START1, _ stop1: STOP1, _ start2: START2, _ stop2: STOP2, _ withinBounds: Bool) -> Double
    
    /// Determines the largest value in a sequence of numbers, and then returns that value
    /// - Parameter array: Numbers to compare
    
    func max<A: FloatingPoint>(_ array: [A]) -> A
    
    
    /// Determines the smallest value in a sequence of numbers, and then returns that value
    /// - Parameter array: Numbers to compare
    
    func min<A: FloatingPoint>(_ array: [A]) -> A
    
    /// Normalizes a number from another range into a value between 0 and 1.
    /// - Parameters:
    ///   - num: incoming value to be normalized
    ///   - start: lower bound of the value's current range
    ///   - stop: upper bound of the value's current range
    
    func norm<N: Numeric, START: Numeric, STOP: Numeric>(_ num: N, _ start: START, _ stop: STOP) -> Double
    
    /// Squares a number (multiplies a number by itself).
    /// - Parameter num: number to square
    /// - Returns: squared number
    
    func sq<N: Numeric>(_ num: N) -> N
}

extension Sketch: Calculation {
    
    public func constrain<N: Numeric, L: Numeric, H: Numeric>(_ n: N,_ low: L, _ high: H) -> Double {
        let d_n, d_low, d_high: Double
        d_n = n.convert()
        d_low = low.convert()
        d_high = high.convert()

        return Swift.min(Swift.max(d_n, d_low), d_high)
    }
    
    public func distance<X1: Numeric, Y1: Numeric, X2: Numeric, Y2: Numeric>(_ x1: X1, _ y1: Y1, _ x2: X2, _ y2: Y2) -> Double {
        let d_x1, d_y1, d_x2, d_y2: Double
        d_x1 = x1.convert()
        d_y1 = y1.convert()
        d_x2 = x2.convert()
        d_y2 = y2.convert()
        
        let diffX = d_x2 - d_x1
        let diffY = d_y2 - d_y1
        let distanceSquared = diffX * diffX + diffY * diffY
        return sqrt(distanceSquared)
    }
    
    public func lerp<START: Numeric, STOP: Numeric, A: Numeric>(_ start: START, _ stop: STOP, _ amount: A) -> Double {
        let d_start, d_stop, d_amount: Double
        d_start = start.convert()
        d_stop = stop.convert()
        d_amount = amount.convert()
        
        return d_start + ((d_stop - d_start) * d_amount)
    }
    
    
    public func mag<A: Numeric, B: Numeric>(_ a: A, _ b: B) -> Double {
        let d_a, d_b: Double
        d_a = a.convert()
        d_b = b.convert()
        
        return distance(0, 0, d_a, d_b)
    }
    
    public func map<V: Numeric, START1: Numeric, STOP1: Numeric, START2: Numeric, STOP2: Numeric>(_ value: V, _ start1: START1, _ stop1: STOP1, _ start2: START2, _ stop2: STOP2, _ withinBounds: Bool = true) -> Double {
        let d_value, d_start1, d_stop1, d_start2, d_stop2: Double
        d_value = value.convert()
        d_start1 = start1.convert()
        d_stop1 = stop1.convert()
        d_start2 = start2.convert()
        d_stop2 = stop2.convert()
        
        let newval = (d_value - d_start1) / (d_stop1 - d_start1) * (d_stop2 - d_start2) + d_start2
        if !withinBounds {
            return newval
        }
        if d_start2 < d_stop2 {
            return self.constrain(newval, d_start2, d_stop2)
        } else {
            return self.constrain(newval, d_stop2, d_start2)
        }
    }
    
    public func max<A: FloatingPoint>(_ array: [A]) -> A {
        return array.max() ?? 0
    }
    
    public func min<A: FloatingPoint>(_ array: [A]) -> A {
        return array.min() ?? 0
    }
    
    public func norm<N: Numeric, START: Numeric, STOP: Numeric>(_ num: N, _ start: START, _ stop: STOP) -> Double {
        let d_num, d_start, d_stop: Double
        d_num = num.convert()
        d_start = start.convert()
        d_stop = stop.convert()
        
        return self.map(d_num, d_start, d_stop, 0, 1)
    }
    
    // Relies upon conversion found in Sketch2DPrimitivesGenerics.Swift
    // Returning a Double here because that is what will be required in most
    // use cases for SwiftProcessing and using T creates ambiguity that
    // can't be resolved. Maybe there's a better solution out there?
    
    public func sq<N: Numeric>(_ num: N) -> N {
        return pow(num as! Decimal, 2) as! N
    }
}
/*
 * SwiftProcessing: Canvas
 *
 * */

import Foundation
import CoreGraphics
import UIKit

extension Sketch{
    
    /// Create a new canvas. Sets the size of the canvas that SwiftProcessing will draw to.
    
    open func createCanvas<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ x: X, _ y: Y, _ width: W, _ height: H){
        var cg_x, cg_y, cg_width, cg_height: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        cg_width = width.convert()
        cg_height = height.convert()
        // Changing to true. isOpaque can improve performance.
        self.isOpaque = true
        self.frame = CGRect(x: cg_x, y: cg_y, width: cg_width, height: cg_height)
    }
    
    /// Add a new view to the current sketch. Useful if you need to add another view into your current SwiftProcessing sketch.
    
    open func addSketch(_ s: UIView){
        addSketchHelper(self.superview, s)
    }
    
    func addSketchHelper(_ p: UIView?, _ s: UIView){
        if p?.superview == nil{
            p?.addSubview(s)
        }else{
            addSketchHelper(p?.superview!, s)
        }
    }
    
    /// Add a new sketch to the current sketch. Useful if combining multiple SwiftProcessing sketches into a single view.
    
    open func addChildSketch(_ s: Sketch){
        self.addSubview(s)
    }
}
/*
 * SwiftProcessing: Color
 *
 * */

import UIKit

/*
 * MARK: - UICOLOR EXTENSION FOR PLAYGROUND LITERAL COLOR SUPPORT
 */

// Source: https://theswiftdev.com/uicolor-best-practices-in-swift/

public extension UIColor {
    // Only used internally, so no need to use Doubles.
    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
    
    // To better interface with SwiftProcessing
    var rgba255: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r * 255, g * 255, b * 255, a * 255)
    }
    
    var double_rgba: (red: Double, green: Double, blue: Double, alpha: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
    
    var double_rgba255: (red: Double, green: Double, blue: Double, alpha: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r) * 255, Double(g) * 255, Double(b) * 255, Double(a) * 255)
    }
    
    var hsba: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
    }
    
    var hsba360: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h * 360, s * 100, b * 100, a * 100)
    }
    
    var double_hsba360: (hue: Double, saturation: Double, brightness: Double, alpha: Double) {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h * 360), Double(s * 100), Double(b * 100), Double(a * 100))
    }
}


// =======================================================================
// MARK: - EXTENSION: COLOR
// =======================================================================

public extension Sketch {
    
    /*
     * MARK: - COLOR MODE
     *
     * NOTE: This is an ongoing project that will have multiple steps:
     *
     * STEP 1 – Create a global color mode that will enable users to choose between RGB and HSB modes. Ranges will be fixed at first. In the beginning, we'll start with 0-255 for RGB, 0-360 for H, and 0-100 for SB. [COMPLETE]
     * STEP 2 — Expand Color class to have H, S, and B values and convert easily between HSV <-> RGB within the class. [COMPLETE]
     * Algorithms to use: https://en.wikipedia.org/wiki/HSL_and_HSV#From_HSV
     * STEP 3 – Allow users to set the desired ranges, as they can in Processing. [TO DO]
     *
     */
    
    private func colorModeHelper<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ a: A) -> Color {
        let cg_v1, cg_v2, cg_v3, cg_a: CGFloat
        cg_v1 = v1.convert(); cg_v2 = v2.convert(); cg_v3 = v3.convert(); cg_a = a.convert()
        
        switch settings.colorMode {
        case .rgb:
            return Color(cg_v1, cg_v2, cg_v3, cg_a, .rgb)
        case .hsb:
            return Color(cg_v1, cg_v2, cg_v3, cg_a, .hsb)
        }
    }
    
    /// Clears the background if there is a color.
    ///
    
    func clear() {
        context?.clear(CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
    }
    
    /*
     * MARK: - BACKGROUND
     */
    
    /// Sets the background color with a UIColor.
    /// This enables Xcode and Swift Playground color literals.
    ///
    /// - Parameters:
    ///     - color: A UIColor value.
    func background(_ color: UIColor) {
        switch settings.colorMode {
        case .rgb:
            background(color.rgba255.red, color.rgba255.green, color.rgba255.blue, color.rgba255.alpha)
        case .hsb:
            background(color.hsba360.hue, color.hsba360.saturation, color.hsba360.brightness, color.hsba360.alpha)
        }
        
    }
    
    /// Sets the background color with a SketchProcessing Color object.
    ///
    /// - Parameters:
    ///     - color: A Color value.
    
    func background(_ color: Color) {
        switch settings.colorMode {
        case .rgb:
            background(color.red, color.green, color.blue, color.alpha)
        case .hsb:
            background(color.hue, color.saturation, color.brightness, color.alpha)
        }
    }
    
    /// Sets the background color with an RGB or HSB value. RGB is the default color mode.
    ///
    /// - Parameters:
    ///     - v1: A red value from 0-255 (RGB). A hue value from 0-360 (HSB).
    ///     - v2: A green value from 0-255 (RGB). A saturation value from 0-100 (HSB).
    ///     - v3: A blue value from 0-255 (RGB). A brightness value from 0-100 (HSB).
    ///     - a: An optional alpha value from 0-255. Defaults to 255 (RGB). An alpha value from 0-100. Defaults to 255 (HSB). Defaults to 255.
    
    // Note: It's important to understand why we are *coercing* instead of
    // *type casting* in our generics (eg, T(255) in this definition).
    // Here is more information: https://stackoverflow.com/questions/33973724/typecasting-or-initialization-which-is-better-in-swift
    // Type casting causes runtime errors and should be avoided in generics
    // where integers and floating points are both accepted inputs.
    func background<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ a: A){
        let cg_v1, cg_v2, cg_v3, cg_a: CGFloat
        cg_v1 = v1.convert()
        cg_v2 = v2.convert()
        cg_v3 = v3.convert()
        cg_a = a.convert()
        
        // Internal operations should never affect the user-facing SwiftProcessing settings state. Only API users should be able to change the settings state. And if we touch Core Graphics, we need to save and restore the state.
        // fill(v1, v2, v3, a) - Leaving this as a reminder. Avoid this approach and manipulate Core Graphics context directly when inside the API.
        context?.saveGState()
        context?.setFillColor(colorModeHelper(cg_v1, cg_v2, cg_v3, cg_a).cgColor())
        internalRect(0, 0, CGFloat(width), CGFloat(height))
        context?.restoreGState()
    }
    
    /// Sets the background color with an RGB or HSB value. RGB is the default color mode.
    ///
    /// - Parameters:
    ///     - v1: A red value from 0-255 (RGB). A hue value from 0-360 (HSB).
    ///     - v2: A green value from 0-255 (RGB). A saturation value from 0-100 (HSB).
    ///     - v3: A blue value from 0-255 (RGB). A brightness value from 0-100 (HSB).
    ///     - a: An optional alpha value from 0-255. Defaults to 255 (RGB). An alpha value from 0-100. Defaults to 255 (HSB). Defaults to 255.
    
    func background<V1: Numeric, V2: Numeric, V3: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3){
        background(v1, v2, v3, 255.0)
    }
    
    /// Sets the background color with a system color name.
    ///
    /// - Parameters:
    ///     - systemColorName: A standard system color name, eg: .systemRed
    
    func background(_ systemColorName: Color.SystemColor) {
        let systemColor = systemColorName.rawValue
        switch settings.colorMode {
        case .rgb:
            background(systemColor.rgba255.red, systemColor.rgba255.green, systemColor.rgba255.blue, systemColor.rgba255.alpha)
        case .hsb:
            background(systemColor.hsba360.hue, systemColor.hsba360.saturation, systemColor.hsba360.brightness, systemColor.hsba360.alpha)
        }
    }
    
    /// Sets the background color with gray and alpha values.
    ///
    /// - Parameters:
    ///     - v1: A gray value from 0-255.
    ///     - a: An optional alpha value from 0-255. Defaults to 255.
    
    func background<V1: Numeric, A: Numeric>(_ v1: V1, _ a: A) {
        background(v1, v1, v1, a)
    }
    
    /// Sets the background color with a single gray value.
    ///
    /// - Parameters:
    ///     - v1: A gray value from 0-255.
    
    func background<V1: Numeric>(_ v1: V1) {
        background(v1, v1, v1, 255.0)
    }
    
    /*
     * MARK: FILL
     */
    
    /// Sets the fill color with a UIColor.
    /// This enables Xcode and Swift Playground color literals.
    ///
    /// - Parameters:
    ///     - color: A UIColor value.
    
    func fill(_ color: UIColor) {
        switch settings.colorMode {
        case .rgb:
            fill(color.rgba255.red, color.rgba255.green, color.rgba255.blue, color.rgba255.alpha)
        case .hsb:
            fill(color.hsba360.hue, color.hsba360.saturation, color.hsba360.brightness, color.hsba360.alpha)
        }
    }
    
    /// Sets the fill color with a SwiftProcessing Color object.
    ///
    /// - Parameters:
    ///     - color: A Color value.
    
    func fill(_ color: Color) {
        switch settings.colorMode {
        case .rgb:
            fill(color.red, color.green, color.blue, color.alpha)
        case .hsb:
            fill(color.hue, color.saturation, color.brightness, color.alpha)
        }
    }
    
    /// Sets the fill color with an RGB or HSB value. RGB is the default color mode.
    ///
    /// - Parameters:
    ///     - v1: A red value from 0-255 (RGB). A hue value from 0-360 (HSB).
    ///     - v2: A green value from 0-255 (RGB). A saturation value from 0-100 (HSB).
    ///     - v3: A blue value from 0-255 (RGB). A brightness value from 0-100 (HSB).
    ///     - a: An optional alpha value from 0-255. Defaults to 255 (RGB). An alpha value from 0-100. Defaults to 255 (HSB). Defaults to 255.
    
    func fill<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ a: A) {
        var cg_v1, cg_v2, cg_v3, cg_a: CGFloat
        cg_v1 = v1.convert()
        cg_v2 = v2.convert()
        cg_v3 = v3.convert()
        cg_a = a.convert()
        
        context?.setFillColor(colorModeHelper(cg_v1, cg_v2, cg_v3, cg_a).cgColor())
        settings.fill = Color(cg_v1, cg_v2, cg_v3, cg_a, settings.colorMode)
    }
    
    /// Sets the fill color with an RGB or HSB value. RGB is the default color mode.
    ///
    /// - Parameters:
    ///     - v1: A red value from 0-255 (RGB). A hue value from 0-360 (HSB).
    ///     - v2: A green value from 0-255 (RGB). A saturation value from 0-100 (HSB).
    ///     - v3: A blue value from 0-255 (RGB). A brightness value from 0-100 (HSB).
    
    func fill<V1: Numeric, V2: Numeric, V3: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3) {
        fill(v1, v2, v3, 255.0)
    }
    
    /// Sets the fill color with a system color name.
    ///
    /// - Parameters:
    ///     - systemColorName: A standard system color name, eg: .systemRed
    
    func fill(_ systemColorName: Color.SystemColor) {
        let systemColor = systemColorName.rawValue
        
        context?.setFillColor(red: systemColor.rgba255.red, green: systemColor.rgba255.green, blue: systemColor.rgba255.blue, alpha: systemColor.rgba255.alpha)
        settings.fill = Color(systemColor.rgba255.red, systemColor.rgba255.green, systemColor.rgba255.blue, systemColor.rgba255.alpha, .rgb)
    }
    
    /// Sets the fill color with a gray and alpha values.
    ///
    /// - Parameters:
    ///     - v1: A gray value from 0-255.
    ///     - a: An optional alpha value from 0-255. Defaults to 255.
    
    func fill<V1: Numeric, A: Numeric>(_ v1: V1,_ a: A) {
        var cg_v1, cg_a: CGFloat
        cg_v1 = v1.convert()
        cg_a = a.convert()
        
        context?.setFillColor(red: cg_v1 / 255, green: cg_v1 / 255, blue: cg_v1 / 255, alpha: cg_a / 255)
        settings.fill = Color(cg_v1, cg_v1, cg_v1, cg_a, .rgb) // Single arguments always use .rgb range.
    }
    
    /// Sets the fill color with a single gray value.
    ///
    /// - Parameters:
    ///     - v1: A gray value from 0-255.
    
    func fill<V1: Numeric>(_ v1: V1) {
        fill(v1, 255.0)
    }
    
    /// Sets the fill to be completely clear.
    
    func noFill() {
        fill(0.0, 0.0, 0.0, 0.0) // Same in .rgb or .hsb mode
        // For future contributors: Question here about whether to just toggle the fill on or off rather than changing the state of the fill variable.
    }
    
    /*
     * MARK: STROKE
     */
    
    /// Sets the stroke color with a UIColor.
    /// This enables Xcode and Swift Playground color literals.
    ///
    /// - Parameters:
    ///     - color: A UIColor value.
    
    func stroke(_ color: UIColor) {
        switch settings.colorMode {
        case .rgb:
            stroke(color.rgba255.red, color.rgba255.green, color.rgba255.blue, color.rgba255.alpha)
        case .hsb:
            stroke(color.hsba360.hue, color.hsba360.saturation, color.hsba360.brightness, color.hsba360.alpha)
        }
    }
    
    /// Sets the stroke color with a SwiftProcessing Color object.
    ///
    /// - Parameters:
    ///     - color: A Color value.
    
    func stroke(_ color: Color) {
        switch settings.colorMode {
        case .rgb:
            stroke(color.red, color.green, color.blue, color.alpha)
        case .hsb:
            stroke(color.hue, color.saturation, color.brightness, color.alpha)
        }
    }
    
    /// Sets the stroke color with an RGB or HSB value. RGB is the default color mode.
    ///
    /// - Parameters:
    ///     - v1: A red value from 0-255 (RGB). A hue value from 0-360 (HSB).
    ///     - v2: A green value from 0-255 (RGB). A saturation value from 0-100 (HSB).
    ///     - v3: A blue value from 0-255 (RGB). A brightness value from 0-100 (HSB).
    ///     - a: An optional alpha value from 0-255. Defaults to 255 (RGB). An alpha value from 0-100. Defaults to 255 (HSB). Defaults to 255.
    
    func stroke<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ a: A) {
        var cg_v1, cg_v2, cg_v3, cg_a: CGFloat
        cg_v1 = v1.convert()
        cg_v2 = v2.convert()
        cg_v3 = v3.convert()
        cg_a = a.convert()
        
        context?.setStrokeColor(colorModeHelper(cg_v1, cg_v2, cg_v3, cg_a).cgColor())
        settings.stroke = Color(cg_v1, cg_v2, cg_v3, cg_a, settings.colorMode)
    }
    
    /// Sets the stroke color with an RGB or HSB value. RGB is the default color mode.
    ///
    /// - Parameters:
    ///     - v1: A red value from 0-255 (RGB). A hue value from 0-360 (HSB).
    ///     - v2: A green value from 0-255 (RGB). A saturation value from 0-100 (HSB).
    ///     - v3: A blue value from 0-255 (RGB). A brightness value from 0-100 (HSB).
    
    func stroke<V1: Numeric, V2: Numeric, V3: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3) {
        stroke(v1, v2, v3, 255.0)
    }
    
    /// Sets the stroke color with a system color name.
    ///
    /// - Parameters:
    ///     - systemColorName: A standard system color name, eg: .systemRed
    
    func stroke(_ systemColorName: Color.SystemColor) {
        let systemColor = systemColorName.rawValue
        context?.setStrokeColor(red: systemColor.rgba255.red, green: systemColor.rgba255.green / 255, blue: systemColor.rgba255.blue / 255, alpha: systemColor.rgba255.alpha / 255)
        settings.stroke = Color(systemColor.rgba255.red, systemColor.rgba255.green, systemColor.rgba255.blue, systemColor.rgba255.alpha, .rgb)
    }
    
    /// Sets the fill color with a gray and alpha values.
    ///
    /// - Parameters:
    ///     - v1: A gray value from 0-255.
    ///     - a: An optional alpha value from 0-255. Defaults to 255.
    
    func stroke<V1: Numeric, A: Numeric>(_ v1: V1,_ a: A) {
        var cg_v1, cg_a: CGFloat
        cg_v1 = v1.convert()
        cg_a = a.convert()
        
        context?.setStrokeColor(red: cg_v1 / 255, green: cg_v1 / 255, blue: cg_v1 / 255, alpha: cg_a / 255)
        settings.stroke = Color(cg_v1, cg_v1, cg_v1, cg_a, .rgb) // Single arguments always use .rgb range.
    }
    
    /// Sets the stroke color with a single gray value.
    ///
    /// - Parameters:
    ///     - v1: A gray value from 0-255.
    
    func stroke<V1: Numeric>(_ v1: V1) {
        stroke(v1, 255.0)
    }
    
    /// Sets the stroke to be completely clear.
    
    func noStroke() {
        stroke(0.0, 0.0, 0.0, 0.0)
        // Same question as noFill()
    }
    
    /*
     * MARK: ERASE
     */
    
    /// Sets subsequent shapes drawn to the screen to erase each other.
    
    func erase() {
        context?.setBlendMode(CGBlendMode.clear)
    }
    
    /// Sets the compositing mode to normal.
    
    func noErase() {
        context?.setBlendMode(CGBlendMode.normal)
    }
    
    /*
     * MARK: COLOR
     */
    
    /// Returns a color object that can be stored in a variable.
    ///
    /// - Parameters:
    ///     - color: A UIColor value.
    
    func color(_ c: UIColor) -> Color {
        switch settings.colorMode {
        case .rgb:
            return Color(c.rgba255.red, c.rgba255.green, c.rgba255.blue, c.rgba255.alpha, .rgb)
        case .hsb:
            return Color(c.hsba360.hue, c.hsba360.saturation, c.hsba360.brightness, c.hsba360.alpha, .hsb)
        }
    }
    
    /// Returns a color object that can be stored in a variable using RGB or HSB values. RGB is the default color mode.
    ///
    /// - Parameters:
    ///     - v1: A red value from 0-255 (RGB). A hue value from 0-360 (HSB).
    ///     - v2: A green value from 0-255 (RGB). A saturation value from 0-100 (HSB).
    ///     - v3: A blue value from 0-255 (RGB). A brightness value from 0-100 (HSB).
    ///     - a: An optional alpha value from 0-255. Defaults to 255 (RGB). An alpha value from 0-100. Defaults to 255 (HSB). Defaults to 255.
    
    func color<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ a: A) -> Color {
        return Color(v1, v2, v3, a, settings.colorMode)
    }
    
    /// Returns a color object that can be stored in a variable using RGB or HSB values. RGB is the default color mode.
    ///
    /// - Parameters:
    ///     - v1: A red value from 0-255 (RGB). A hue value from 0-360 (HSB).
    ///     - v2: A green value from 0-255 (RGB). A saturation value from 0-100 (HSB).
    ///     - v3: A blue value from 0-255 (RGB). A brightness value from 0-100 (HSB).
    
    func color<V1: Numeric, V2: Numeric, V3: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3) -> Color {
        return Color(v1, v2, v3, 255.0, settings.colorMode)
    }
    
    /// Returns a color object that can be stored in a variable.
    ///
    /// - Parameters:
    ///     - v1: A gray value from 0-255.
    ///     - a: An optional alpha value from 0-255. Defaults to 255.
    
    func color<V1: Numeric, A: Numeric>(_ v1: V1, _ a: A) -> Color {
        return Color(v1, v1, v1, a, .rgb) // Single arguments always use .rgb range.
    }
    
    /// Returns a color object that can be stored in a variable.
    ///
    /// - Parameters:
    ///     - v1: A gray value from 0-255.
    
    func color<V1: Numeric>(_ v1: V1) -> Color {
        return Color(v1, v1, v1, 255.0, .rgb) // Single arguments always use .rgb range.
    }
    
    /// Returns a color object that can be stored in a variable.
    ///
    /// - Parameters:
    ///     - value: hex string for a color.
    
    func color(_ value: String) -> Color {
        return hexStringToUIColor(hex: value)
    }
    
    /*
     * MARK: COMPONENT-WISE COLOR
     */
    
    /// Returns the red value of a SwiftProcessing color object.
    ///
    /// - Parameters:
    ///     - color: A SwiftProcessing color object.
    
    func red(_ color: Color) -> Double {
        return color.red
    }
    
    /// Returns the red value of a color stored in an array
    ///
    /// - Parameters:
    ///     - color: A color stored in an array, e.g. [R, G, B, A].
    
    func red<T: Numeric>(_ color: [T]) -> Double {
        return color[0].convert()
    }
    
    /// Returns the green value of a SwiftProcessing color object.
    ///
    /// - Parameters:
    ///     - color: A SwiftProcessing color object.
    
    func green(_ color: Color) -> Double {
        return color.green
    }
    
    /// Returns the green value of a color stored in an array
    ///
    /// - Parameters:
    ///     - color: A color stored in an array, e.g. [R, G, B, A].
    
    func green<T: Numeric>(_ color: [T]) -> Double {
        return color[1].convert()
    }
    
    /// Returns the blue value of a SwiftProcessing color object.
    ///
    /// - Parameters:
    ///     - color: A SwiftProcessing color object.
    
    func blue(_ color: Color) -> Double {
        return color.blue
    }
    
    /// Returns the blue value of a color stored in an array
    ///
    /// - Parameters:
    ///     - color: A color stored in an array, e.g. [R, G, B, A].
    
    func blue<T: Numeric>(_ color: [T]) -> Double {
        return color[2].convert()
    }
    
    /// Returns the alpha value of a SwiftProcessing color object.
    ///
    /// - Parameters:
    ///     - color: A SwiftProcessing color object.
    
    func alpha(_ color: Color) -> Double {
        return color.alpha
    }
    
    /// Returns the alpha value of a color stored in an array
    ///
    /// - Parameters:
    ///     - color: A color stored in an array, e.g. [R, G, B, A] or [H, S, B, A].
    
    func alpha<T: Numeric>(_ color: [T]) -> Double {
        return color[3].convert()
    }
    
    /// Returns the hue value of a SwiftProcessing color object.
    ///
    /// - Parameters:
    ///     - color: A SwiftProcessing color object.
    
    func hue(_ color: Color) -> Double {
        return color.hue
    }
    
    /// Returns the hue value of a color stored in an array
    ///
    /// - Parameters:
    ///     - color: A color stored in an array, e.g. [H, S, B, A].
    
    func hue<T: Numeric>(_ color: [T]) -> Double {
        return color[0].convert()
    }
    
    /// Returns the saturation value of a SwiftProcessing color object.
    ///
    /// - Parameters:
    ///     - color: A SwiftProcessing color object.
    
    func saturation(_ color: Color) -> Double {
        return color.saturation
    }
    
    /// Returns the saturation value of a color stored in an array
    ///
    /// - Parameters:
    ///     - color: A color stored in an array, e.g. [H, S, B, A].
    
    func saturation<T: Numeric>(_ color: [T]) -> Double {
        return color[1].convert()
    }
    
    /// Returns the brightness value of a SwiftProcessing color object.
    ///
    /// - Parameters:
    ///     - color: A SwiftProcessing color object.
    
    func brightness(_ color: Color) -> Double {
        return color.brightness
    }
    
    /// Returns the brightness value of a color stored in an array
    ///
    /// - Parameters:
    ///     - color: A color stored in an array, e.g. [H, S, B, A].
    
    func brightness<T: Numeric>(_ color: [T]) -> Double {
        return color[2].convert()
    }
    
    // Source: https://stackoverflow.com/questions/24263007/how-to-use-hex-color-values
    private func hexStringToUIColor (hex: String) -> Color {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }
        
        if (cString.count) != 6 {
            assertionFailure("Invalid hex color")
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        
        return Color(
            CGFloat((rgbValue & 0xFF0000) >> 16),
            CGFloat((rgbValue & 0x00FF00) >> 8),
            CGFloat(rgbValue & 0x0000FF),
            CGFloat(1.0),
            .rgb
        )
    }
}

// =======================================================================
// MARK: - CLASS: COLOR
// =======================================================================

public extension Sketch {
    class Color {
        
        public var red: Double
        public var green: Double
        public var blue: Double
        
        public var hue: Double
        public var saturation: Double
        public var brightness: Double
        
        public var alpha: Double
        
        private var mode: ColorMode
        
        convenience init<V1: Numeric, A: Numeric>(_ v1: V1, _ a: A) {
            self.init(v1, v1, v1, a, .rgb)
        }
        
        convenience init<V1: Numeric>(_ v1: V1) {
            self.init(v1, v1, v1, 255.0, .rgb)
        }
        
        convenience init<V1: Numeric, V2: Numeric, V3: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3) {
            self.init(v1, v2, v3, 255.0, .rgb)
        }
        
        public init<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ a: A, _ mode: ColorMode = .rgb) {
            self.mode = mode
            
            var d_v1, d_v2, d_v3, d_a: Double
            d_v1 = v1.convert(); d_v2 = v2.convert(); d_v3 = v3.convert(); d_a = a.convert()
            
            // Set everything to zero so we have access to self to use clamp.
            // There may be a more optimized way of doing this.
            self.red = 0; self.green = 0; self.blue = 0; self.alpha = 0; self.hue = 0.0; self.saturation = 0.0; self.brightness = 0.0
            
            switch mode {
            case .rgb:
                // Set RGB
                self.red = clamp(value: d_v1, minimum: 0.0, maximum: 255.0)
                self.green = clamp(value: d_v2, minimum: 0.0, maximum: 255.0)
                self.blue = clamp(value: d_v3, minimum: 0.0, maximum: 255.0)
                self.alpha = clamp(value: d_a, minimum: 0.0, maximum: 255.0)
                
                // Extract and Set HSB
                // Doesn't feel right to create a temporary UIColor here.
                // For future contributors: Is further optimization necessary/possible here?
                let temp = UIColor(red: CGFloat(self.red / 255), green: CGFloat(self.green) / 255, blue: CGFloat(self.blue / 255), alpha: CGFloat(self.alpha / 255))

                self.hue = temp.double_hsba360.hue
                self.saturation = temp.double_hsba360.saturation
                self.brightness = temp.double_hsba360.brightness
            case .hsb:
                // Set HSB
                self.hue = clamp(value: d_v1, minimum: 0.0, maximum: 360.0)
                self.saturation = clamp(value: d_v2, minimum: 0.0, maximum: 100)
                self.brightness = clamp(value: d_v3, minimum: 0.0, maximum: 100)
                self.alpha = clamp(value: d_a, minimum: 0.0, maximum: 100)
                
                // Extract and Set RGB
                // Doesn't feel right to create a temporary UIColor here.
                // For future contributors: Is further optimization necessary/possible here?
                let temp = UIColor(hue: CGFloat(self.hue / 360), saturation: CGFloat(self.saturation / 100), brightness: CGFloat(self.brightness / 100), alpha: CGFloat(self.alpha / 100))

                // Extract and Set RGB
                self.red = temp.double_rgba255.red
                self.green = temp.double_rgba255.green
                self.blue = temp.double_rgba255.blue
            }
        }

        
        public init(_ color: UIColor) {
            self.mode = .rgb // RGB will be the default value here. It matters because alpha will range from 0-255.
            
            self.red = color.double_rgba255.red
            self.green = color.double_rgba255.green
            self.blue = color.double_rgba255.blue
            self.alpha = color.double_rgba255.alpha
            
            self.hue = Double(color.hsba360.hue)
            self.saturation = Double(color.hsba.saturation)
            self.brightness = Double(color.hsba.brightness)
        }
        
        func setRed<T: Numeric>(_ red: T) {
            self.red = red.convert()
        }
        
        func setGreen<T: Numeric>(_ green: T) {
            self.green = green.convert()
        }
        
        func setBlue<T: Numeric>(_ blue: T) {
            self.blue = blue.convert()
        }
        
        func setAlpha<T: Numeric>(_ alpha: T) {
            self.alpha = alpha.convert()
        }
        
        func setHue<T: Numeric>(_ hue: T) {
            self.hue = hue.convert()
        }
        
        func setSaturation<T: Numeric>(_ saturation: T) {
            self.saturation = saturation.convert()
        }
        
        func setBrightness<T: Numeric>(_ brightness: T) {
            self.brightness = brightness.convert()
        }
        
        func uiColor() -> UIColor {
            switch mode {
            case .rgb:
                return UIColor(red: self.red.convert() / 255.0, green: self.green.convert() / 255.0, blue: self.blue.convert() / 255.0, alpha: self.alpha.convert() / 255.0)
            case .hsb:
                return UIColor(red: self.red.convert() / 255.0, green: self.green.convert() / 255.0, blue: self.blue.convert() / 255.0, alpha: self.alpha.convert() / 100.0)
            }
        }
        
        func cgColor() -> CGColor {
            switch mode {
            case .rgb:
                return CGColor(red: self.red.convert() / 255.0, green: self.green.convert() / 255.0, blue: self.blue.convert() / 255.0, alpha: self.alpha.convert() / 255.0)
            case .hsb:
                return CGColor(red: self.red.convert() / 255.0, green: self.green.convert() / 255.0, blue: self.blue.convert() / 255.0, alpha: self.alpha.convert() / 100.0)
            }
        }
        
        func toString() -> String {
            return """
                rgba: (\(self.red),\(self.green),\(self.blue),\(self.alpha))
                hsba: (\(self.hue),\(self.saturation),\(self.brightness),\(self.alpha))
                """
        }
        
        func toArrayRGB() -> [Double] {
            return [red, green, blue, alpha]
        }
        
        func toArrayHSB() -> [Double] {
            return [hue, saturation, brightness, alpha]
        }
        
        // https://developer.apple.com/library/archive/samplecode/AppChat/Listings/AppChat_MathUtilities_swift.html#//apple_ref/doc/uid/TP40017298-AppChat_MathUtilities_swift-DontLinkElementID_18
        private func clamp<T: Comparable>(value: T, minimum: T, maximum: T) -> T {
            return Swift.min(Swift.max(value, minimum), maximum)
        }
        
        open func debugPrint() {
            if mode == .rgb {
            print("initialized rgb:\r\n" + self.toString())
            } else {
                print("initialized hsb:\r\n" + self.toString())
            }
        }

    }
    
}

// =======================================================================
// MARK: - COLOR EXTENSION FOR CONSTANTS
// =======================================================================

extension Sketch.Color {
    
    public enum SystemColor {
        case systemRed
        case systemBlue
        case systemPink
        case systemTeal
        case systemGreen
        case systemGray
        case systemGray2
        case systemGray3
        case systemGray4
        case systemGray5
        case systemGray6
        case systemOrange
        case systemYellow
        case systemPurple
        case systemIndigo
    }
}

extension Sketch.Color.SystemColor: RawRepresentable {
    public typealias RawValue = UIColor
    
    public init?(rawValue: RawValue) {
        
        switch rawValue {
        case UIColor.systemRed: self = .systemRed
        case UIColor.systemBlue: self = .systemBlue
        case UIColor.systemPink: self = .systemPink
        case UIColor.systemTeal: self = .systemTeal
        case UIColor.systemGreen: self = .systemGreen
        case UIColor.systemGray: self = .systemGray
        case UIColor.systemGray2: self = .systemGray2
        case UIColor.systemGray3: self = .systemGray3
        case UIColor.systemGray4: self = .systemGray4
        case UIColor.systemGray5: self = .systemGray5
        case UIColor.systemGray6: self = .systemGray6
        case UIColor.systemOrange: self = .systemOrange
        case UIColor.systemYellow: self = .systemYellow
        case UIColor.systemPurple: self = .systemPurple
        case UIColor.systemIndigo: self = .systemIndigo
        default:
            return nil
        }
    }
    
    public var rawValue: RawValue {
        switch self {
        case .systemRed: return UIColor.systemRed
        case .systemBlue: return UIColor.systemBlue
        case .systemPink: return UIColor.systemPink
        case .systemTeal: return UIColor.systemTeal
        case .systemGreen: return UIColor.systemGreen
        case .systemGray: return UIColor.systemGray
        case .systemGray2: return UIColor.systemGray2
        case .systemGray3: return UIColor.systemGray3
        case .systemGray4: return UIColor.systemGray4
        case .systemGray5: return UIColor.systemGray5
        case .systemGray6: return UIColor.systemGray6
        case .systemOrange: return UIColor.systemOrange
        case .systemYellow: return UIColor.systemYellow
        case .systemPurple: return UIColor.systemPurple
        case .systemIndigo: return UIColor.systemIndigo
        }
    }
}


/*
 * SwiftProcessing: Data
 *
 * */

import Foundation

public extension Sketch {
    
    func storeItem(_ key: String, _ value: String) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key)
    }
    
    func storeItem(_ key: String, _ value: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key)
    }
    
    func storeItem(_ key: String, _ value: Double) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key)
    }
    
    func storeItem(_ key: String, _ value: Float) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key)
    }
    
    func storeItem(_ key: String, _ value: Int) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key)
    }
    
    func getItem(_ key: String) -> String? {
        let defaults = UserDefaults.standard
        return defaults.string(forKey: key)
    }
    
    func getItem(_ key: String) -> Bool? {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: key)
    }
    
    func getItem(_ key: String) -> Double? {
        let defaults = UserDefaults.standard
        return defaults.double(forKey: key)
    }
    
    func getItem(_ key: String) -> Float? {
        let defaults = UserDefaults.standard
        return defaults.float(forKey: key)
    }
    
    func getItem(_ key: String) -> Int? {
        let defaults = UserDefaults.standard
        return defaults.integer(forKey: key)
    }
    
    func clearStorage() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
    
    func removeItem(_ key: String) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: key)
    }
}
/*
 * SwiftProcessing: Enums
 *
 * This deviates from Processing because of a difference
 * in the Java, JavaScript, and Swift design guidelines.
 * Regarding naming conventions for enums and constants.
 * Although it's different, the thought here is to honor
 * Swift's design guidelines while taking advantage of code
 * completion and context-specific suggestions.
 *
 * Strings could also be used, but they are prone to error
 * and don't give new learners access to auto-complete.
 *
 * Source: https://stackoverflow.com/questions/24244326/swift-global-constant-naming-convention
 *
 * */

import Foundation

extension Sketch {
    // Not currently implemented but leaving hear as a placeholder for future contributors.
    // Reference: https://p5js.org/reference/#/p5/angleMode
    
    /*
    public enum AngleMode {
        case degrees
        case radians
    }
    */
    
    /// The `ShapeMode` enum affects how the shape parameters are used when they are drawn to the screen. `.corner` interprets the first two parameters as the x and y position of the shape. The third and fourth parameters are the width and height of the shape. `.corners` interprets the first two parameters as the upper left- hand corner and the third and fourth parameters as the lower right-hand corner. `.center` interprets the first two parameters as the center of the shape and the third and fourth parameters as the width and height. `.radius` interprets the first two parameters as the center of the shape and the third and fourth half of the width and height of the shape.
    
    public enum ShapeMode {
        case radius
        case corner
        case corners
        case center
    }
    
    /// The `ArcMode` enum determins how arcs are drawn. `.open` will only draw the exterior of the arc and fill whatever shpae remains. The space between the endpoints will not be stroked. `.chord` is the same as `.open` but will stroke the distance between the two endpoints. `.pie` will treat our arc like a pie and stroke the exterior of the arc as well as from each endpoint to the center.
    
    public enum ArcMode {
        case pie
        case chord
        case open
    }
    
    /// The `ShapePath` enum specifies whether a vertex shape should be open (`.open`) or closed (`.close`). An open shape does not add a line connecting the first and last points. A closed shape forms a loop, connecting the first and last point.

    public enum ShapePath {
        case open
        case close
    }
    
    /// The `VertexMode` enum specifies the type of curve being created. `.normal` creates a hard-edged polygon. `.curve` creates a Catmull-Rom spline. This is a type of curve that conforms to the points given, i.e. the points you supply will be on the curve itself and the curve will be calculated to automatically conform to your points. `.bezier` creates  Bezier curve, which is a curve commonly used in computer graphics. SwiftProcessing uses cubic Bezier curves, in which each point supplied also has an additional control point. The angle of the control point in relation to the curve point is what determines the curvature.

    public enum VertexMode {
        case normal
        case curve
        case bezier
    }
    
    /// The `StrokeJoin` enum specifies the way that strokes are joined at each point when the `strokeWeight` is large. `.miter` creates an angular joint. `.bevel` bevels off the point using a straight edge`.round` rounds each corner.
    
    public enum StrokeJoin {
        case miter
        case bevel
        case round
    }
    
    /// The `StrokeCap` enum specifies how the ends of strokes will behave at their endpoints. `.square` cuts the the line off squarely directly at the endpoint. `.round` rounds the end as if you were to draw a circle with a diameter the size of the `strokeWeight`. `.project` is similar to `.round` except it's as if you draw a square with a centerpoint of your endpoint outward the size of the `strokeWeight`.
    
    public enum StrokeCap {
        case square
        case project
        case round
    }

    public enum Filter {
        case pixellate
        case hue_rotate
        case sepia_tone
        case tonal
        case monochrome
        case invert
    }

    /// The `Alignment` enum specifies the alignment for common procedures that require alignments like the `textAlign()` function. Common alignments are used like `.left`, `.center`, and `.right`.
    
    public enum Alignment {
        case left
        case right
        case center
    }
    
    /// The `AlignmentY` enum specifies the vertical alignment for common procedures that require alignments like the optional second parameter of the `textAlign()` function. Common alignments are used like `.top`, `.bottom`, and `.baseline`.
    
    public enum AlignmentY {
        case top
        case bottom
        case baseline
    }

    
    /// The `CameraPosition` enum specifies whether you would like to use the front (`.front`) or back (`.back`) camera.
    
    public enum CameraPosition {
        case front
        case back
    }
    
    /// The `ImageQuality` enum specifies the image quality of images captured with SwiftProcessing.
    
    public enum ImageQuality {
        case high
        case medium
        case low
        case vga
        case hd
        case qhd
    }
    
    public enum VideoOrientation {
        case up
        case upsidedown
    }
    
    /// The `ImagePickerType` enum specifies the type of image picker you'd like to use when importing images into SwiftProcessing.
    
    public enum ImagePickerType {
        case camera
        case photo_library
        case camera_roll
    }

    public enum TouchMode {
        case sketch
        case all
    }
    
    /*
     * MARK: - COLOR MODE
     */

    // NOTE: Consider putting all SwiftProcessing enums in a separate .swift file.

    public enum ColorMode {
        case rgb
        case hsb
    }

}

// NOTE TO FUTURE CONTRIBUTORS: Leaving this out here because of a quirk with how Label was created. Might be a quick fix. Should really be up with the other enums. This was created to accommodate UIKit's text alignment, which is different from Core Graphics' alignment options.

public enum TextAlignment {
    case natural
    case left
    case center
    case right
    case justified
}
/*
 * SwiftProcessing: Environment
 *
 * */

import UIKit

public extension Sketch {
    
    func frameRate() -> Double {
        return fps
    }
    
    func frameRate<T: Numeric>(_ fps: T) {
        self.fps = fps.convert()
        fpsTimer?.preferredFramesPerSecond = fps.convert()
    }
}

/*
 LEAVING HERE FOR FUTURE CONTRIBUTORS:
 
 It would be convenient for performance testing to create a getter for a frameRate variable that calculates current frames per second. This is done in the Processing source code like this:
 
 // Calculate frameRate through average frame times, not average fps, e.g.:
 //
 // Alternating 2 ms and 20 ms frames (JavaFX or JOGL sometimes does this)
 // is around 90.91 fps (two frames in 22 ms, one frame 11 ms).
 //
 // However, averaging fps gives us: (500 fps + 50 fps) / 2 = 275 fps.
 // This is because we had 500 fps for 2 ms and 50 fps for 20 ms, but we
 // counted them with equal weight.
 //
 // If we average frame times instead, we get the right result:
 // (2 ms + 20 ms) / 2 = 11 ms per frame, which is 1000/11 = 90.91 fps.
 //
 // The counter below uses exponential moving average. To do the
 // calculation, we first convert the accumulated frame rate to average
 // frame time, then calculate the exponential moving average, and then
 // convert the average frame time back to frame rate.
 {
   // Get the frame time of the last frame
   double frameTimeSecs = (now - frameRateLastNanos) / 1e9;
   // Convert average frames per second to average frame time
   double avgFrameTimeSecs = 1.0 / frameRate;
   // Calculate exponential moving average of frame time
   final double alpha = 0.05;
   avgFrameTimeSecs = (1.0 - alpha) * avgFrameTimeSecs + alpha * frameTimeSecs;
   // Convert frame time back to frames per second
   frameRate = (float) (1.0 / avgFrameTimeSecs);
 }
 */
import UIKit

public extension Sketch {

    // FOR FUTURE CONTRIBUTORS: There is currently a bug that prevents animated gifs from loading if their extension is in the file name. A little string modification should be able to fix this bug.
    
    // Adjust so that it takes the file type into account.
    // https://github.com/jjkaufman/SwiftProcessing/issues/95
    
    /// Loads an image to be stored in a variable. Images must be located within the project of an Xcode project or in the Resources folder of a Playground.
    /// ```
    /// let image = loadImage("myjpeg")
    /// ```
    /// - Parameters:
    ///   - name: The file name. Leave off the file extension.
    
    func loadImage(_ name: String) -> Image {
        var image = UIImage(named: name)
        if image == nil {
            image = UIImage.gifImageWithName(name)
        }
        return Image(image!)
    }
    
    // FOR FUTURE CONTRIBUTORS: UIImage must be supported to accept image literals in Playgrounds.
    /*
    func loadImage(_ image: UIImage) -> Image {
        var out_image = UIImage.gifImageWithData(image.data)
        return Image(out_image!)
    }
    */
    
    // FOR FUTURE CONTRIBUTORS: The basic infrastructure for tinting images and the sketch view is here, but it has not been implemented.
    
    /// Tints an image to a color or makes the image transparent. NOT IMPLEMENTED.
    /// ```
    /// // Tints the image to a red color with 50% tranparency if in RGB mode.
    /// tint(127,0,0, 127)
    /// image(image, 0, 0)
    /// ```
    /// - Parameters:
    ///     - v1: A red value from 0-255 (RGB). A hue value from 0-360 (HSB).
    ///     - v2: A green value from 0-255 (RGB). A saturation value from 0-100 (HSB).
    ///     - v3: A blue value from 0-255 (RGB). A brightness value from 0-100 (HSB).
    ///     - a: An optional alpha value from 0-255. Defaults to 255 (RGB). An alpha value from 0-100. Defaults to 255 (HSB). Defaults to 255.
    
    func tint<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ a: A) {
        let cg_v1, cg_v2, cg_v3, cg_a: CGFloat
        cg_v1 = v1.convert()
        cg_v2 = v2.convert()
        cg_v3 = v3.convert()
        cg_a = a.convert()
        settings.tint = Color(cg_v1, cg_v2, cg_v3, cg_a, settings.colorMode)
    }
    
    /// Tints an image to a color. NOT IMPLEMENTED.
    /// ```
    /// // Tints the image to a red color if in RGB mode.
    /// tint(127,0,0)
    /// image(image, 0, 0)
    /// ```
    /// - Parameters:
    ///     - v1: A red value from 0-255 (RGB). A hue value from 0-360 (HSB).
    ///     - v2: A green value from 0-255 (RGB). A saturation value from 0-100 (HSB).
    ///     - v3: A blue value from 0-255 (RGB). A brightness value from 0-100 (HSB).
    
    func tint<V1: Numeric, V2: Numeric, V3: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3) {
        let cg_v1, cg_v2, cg_v3, cg_a: CGFloat
        cg_v1 = v1.convert()
        cg_v2 = v2.convert()
        cg_v3 = v3.convert()
        cg_a = 255.0
        settings.tint = Color(cg_v1, cg_v2, cg_v3, cg_a, settings.colorMode)
    }
    
    /// Tints an image to a gray value or makes the image transparent. NOT IMPLEMENTED.
    /// ```
    /// // Tints the image to a gray color and 50% transparency.
    /// tint(127,127)
    /// image(image, 0, 0)
    /// ```
    /// - Parameters:
    ///     - v1: A red value from 0-255 (RGB). A hue value from 0-360 (HSB).
    ///     - a: An optional alpha value from 0-255.
    
    func tint<V1: Numeric, A: Numeric>(_ v1: V1, _ a: A) {
        let cg_v1, cg_a: CGFloat
        cg_v1 = v1.convert()
        cg_a = a.convert()
        settings.tint = Color(cg_v1, cg_v1, cg_v1, cg_a, .rgb)
    }
    
    /// Tints an image to a gray value. NOT IMPLEMENTED.
    /// ```
    /// // Tints the image to a gray color.
    /// tint(127)
    /// image(image, 0, 0)
    /// ```
    /// - Parameters:
    ///     - v1: A gray value from 0-255.
    
    func tint<V1: Numeric>(_ v1: V1) {
        let cg_v1, cg_a: CGFloat
        cg_v1 = v1.convert()
        cg_a = 255.0
        settings.tint = Color(cg_v1, cg_v1, cg_v1, cg_a, .rgb)
    }
    
    /// Tints an image to a color or makes the image transparent. NOT IMPLEMENTED.
    /// ```
    /// // Tints the image to a gray color.
    /// myColor = Color(127, 0, 0, 127)
    /// tint(myColor)
    /// image(image, 0, 0)
    /// ```
    /// - Parameters:
    ///     - color: A Color instance.
    
    func tint(_ color: Color) {
        settings.tint = color
    }
    
    /// Tints an image to a color or makes the image transparent. NOT IMPLEMENTED.
    /// ```
    /// // Tints the image to a UIColor, which is useful for color literals.
    /// tint(ColorLiteral) // Typing ColorLiteral will bring up a color picker.
    /// image(image, 0, 0)
    /// ```
    /// - Parameters:
    ///     - color: A UIColor or Color Literal
    
    func tint(_ color: UIColor) {
        settings.tint = Color(color)
    }
    
    /// Places an image in a sketch with an x and y position. Image placement is partially controlled by the `imageMode()` function. By default the x and y values are the upper-left- and upper-right-hand corner of the image.
    /// ```
    /// // Tints the image to a UIColor, which is useful for color literals.
    /// tint(ColorLiteral) // Typing ColorLiteral will bring up a color picker.
    /// image(image, 0, 0)
    /// ```
    /// - Parameters:
    ///     - image: Image instance
    ///     - x: x position
    ///     - y: y position
    
    func image<X: Numeric, Y: Numeric>(_ image: Image, _ x: X, _ y: Y) {
        self.image(image, x, y, nil as Double?, nil as Double?)
    }
    
    /// Places an image in a sketch with an x, y, width, and height. Image placement is partially controlled by the `imageMode()` function. By default the x and y values are the upper-left- and upper-right-hand corner of the image.
    /// ```
    /// // Tints the image to a UIColor, which is useful for color literals.
    /// tint(ColorLiteral) // Typing ColorLiteral will bring up a color picker.
    /// image(image, 0, 0)
    /// ```
    /// - Parameters:
    ///     - image: Image instance
    ///     - x: x position
    ///     - y: y position
    ///     - width: width of the image
    ///     - height: height of the image

    func image<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ image: Image, _ x: X, _ y: Y, _ width: W? = nil, _ height: H? = nil) {
        let cg_x, cg_y: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        
        let cg_w:CGFloat = width == nil ? CGFloat(image.width) : width!.convert()
        let cg_h:CGFloat = height == nil ? CGFloat(image.height) : height!.convert()
                
        image.width = Double(cg_w)
        image.height = Double(cg_h)
        
        // We're going to manipulate the coordinate matrix, so we need to freeze everything.
        context?.saveGState()
        
        imageModeHelper(cg_x, cg_y, cg_w, cg_h)
        
        // Corners adjustment
        var newW = cg_w
        var newH = cg_h
        if settings.imageMode == .corners {
            newW = cg_w - cg_x
            newH = cg_h - cg_y
        }
        
        image.frame(CGFloat(deltaTime), CGFloat(frameCount)).draw(in: CGRect(x: cg_x, y: cg_y, width: newW, height: newH), blendMode: image.blendMode, alpha: CGFloat(image.alpha))
        
        // We're going to restore the matrix to the previous state.
        context?.restoreGState()
    }
    
    private func imageModeHelper(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        switch settings.ellipseMode {
        case .center:
            translate(-w * 0.5, -h * 0.5)
        case .radius:
            scale(0.5, 0.5)
        case .corner:
            return
        case .corners:
            return
        }
    }
    
    /// Saves an image of your sketch to your photo album. This should probably be placed within a touch responder or a button. Don't place this in `draw()`.
    /// ```
    /// func touchStarted() {
    ///   saveSketch()
    /// }
    /// ```
    
    func saveSketch() {
        UIGraphicsBeginImageContext(self.frame.size)
        self.layer.render(in:UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        UIImageWriteToSavedPhotosAlbum(image!, self, nil, nil)
    }
}
/*
 * SwiftProcessing: Notifications
 *
 * */

import Foundation

extension Notification.Name{
    static let sketchEvent = Notification.Name("sketchEvent")
}

public extension Sketch{
    func initNotifications(){
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(genericSelector(_:)),
            name: .sketchEvent,
            object: nil)
    }
    
    func broadcast(_ eventName: String, _ data: [AnyHashable : Any]? = [:]){
        var newData = data
        newData!["eventName"] = eventName
        NotificationCenter.default.post(name: .sketchEvent, object: nil, userInfo: newData)
    }
    
    func listen(_ eventName: String, _ action: @escaping (_ data: [AnyHashable : Any]) -> Void){
        self.notificationActionsWithData[eventName] = action
    }
    
    func listen(_ eventName: String, _ action: @escaping () -> Void){
        self.notificationActions[eventName] = action
    }
    
    @objc func genericSelector(_ notification: Notification){
        if let eventName = notification.userInfo?["eventName"] as? String{
            self.notificationActionsWithData[eventName]?(notification.userInfo ?? [:])
            self.notificationActions[eventName]?()
        }
    }
    
}
/*
 * SwiftProcessing: Operator Overloads
 *
 * This is to restore a more simple Double modulo
 * for learning basic coding. Since SwiftProcessing
 * is designed around Doubles, it's important to be
 * able to support a basic modulo that replicates
 * the standard behavior of a modulo operator.
 *
 * We are choosing to go with Swift's static
 * truncating remainder method, which gives the
 * behavior we would expect for modulo in Processing.
 * */

// =======================================================================
// MARK: - % OPERATOR OVERLOAD
// =======================================================================

public func % <L: Numeric, R: Numeric>(left: L, right: R) -> Double {
    let d_left: Double = left.convert()
    let d_right: Double = right.convert()
    return d_left.truncatingRemainder(dividingBy: d_right)
}

// =======================================================================
// MARK: - ARITHMETIC OPERATOR OVERLOADS
// =======================================================================

public func - <L: Numeric, R: Numeric>(left: L, right: R) -> Double {
    let d_left: Double = left.convert()
    let d_right: Double = right.convert()
    return d_left - d_right
}

public func + <L: Numeric, R: Numeric>(left: L, right: R) -> Double {
    let d_left: Double = left.convert()
    let d_right: Double = right.convert()
    return d_left + d_right
}

public func * <L: Numeric, R: Numeric>(left: L, right: R) -> Double {
    let d_left: Double = left.convert()
    let d_right: Double = right.convert()
    return d_left * d_right
}

public func / <L: Numeric, R: Numeric>(left: L, right: R) -> Double {
    let d_left: Double = left.convert()
    let d_right: Double = right.convert()
    return d_left / d_right
}

// =======================================================================
// MARK: - COMPARISON OPERATOR OVERLOADS
// =======================================================================

public func < <L: Numeric, R: Numeric>(left: L, right: R) -> Bool {
    let d_left: Double = left.convert()
    let d_right: Double = right.convert()
    return d_left < d_right
}

public func <= <L: Numeric, R: Numeric>(left: L, right: R) -> Bool {
    let d_left: Double = left.convert()
    let d_right: Double = right.convert()
    return d_left <= d_right
}

public func > <L: Numeric, R: Numeric>(left: L, right: R) -> Bool {
    let d_left: Double = left.convert()
    let d_right: Double = right.convert()
    return d_left > d_right
}

public func >= <L: Numeric, R: Numeric>(left: L, right: R) -> Bool {
    let d_left: Double = left.convert()
    let d_right: Double = right.convert()
    return d_left >= d_right
}
/*
 * SwiftProcessing: Pixels
 *
 * */

import Foundation
import UIKit

@available(iOS 10.0, *)
public extension Sketch {

    // FUTURE CONTRIBUTORS: Verify that load and update pixels works.
    
    ///  Refreshes the current SwiftProcessing pixel buffer.
    ///  ````
    ///  loadPixels()
    ///  ````
    /// - parameter at: a CGPoint.
    
    func updatePixels<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ x: X, _ y: Y, _ w: W, _ h: H) {
        var cg_x, cg_y, cg_w, cg_h: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        cg_w = w.convert()
        cg_h = h.convert()
        
        let curImage = Image(UIImage(cgImage: context!.makeImage()!))
        curImage.loadPixels()
        curImage.pixels = self.pixels
        curImage.updatePixels(cg_x, cg_y, cg_w, cg_h)
        curImage.loadPixels()
        image(curImage, 0, 0, CGFloat(self.width), CGFloat(self.height))
    }

    ///  Loads current screen into SwiftProcessing's pixels buffer.
    ///  ````
    ///  loadPixels()
    ///  ````
    /// - parameter at: a CGPoint.
    
    func loadPixels() {
        let image = get()
        image.loadPixels()
        self.pixels = image.pixels
    }

    // The following strategy is adapted from C4iOS with some modifications.
    // Source: https://github.com/C4Labs/C4iOS/blob/master/C4/UI/Image%2BColorAt.swift
    
    ///  Initializes and returns a new cgimage from the color at a specified point in the receiver.
    ///  ````
    ///  let image = cgimage(at: CGPoint())
    ///  ````
    /// - parameter at: a CGPoint.
    
    private func cgimage(at point: CGPoint) -> CGImage? {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)

        guard let offscreenContext = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo.rawValue) else {
            print("Could not create offscreenContext")
            return nil
        }

        offscreenContext.translateBy(x: CGFloat(-point.x), y: CGFloat(-point.y))

        layer.render(in: offscreenContext)

        guard let image = offscreenContext.makeImage() else {
            print("Could not create pixel image")
            return nil
        }
        return image
    }
    
    ///  Initializes and returns a new Color from an x and y coordinate.
    ///  ````
    ///  let color = img.color(at: Point())
    ///  ````
    /// - parameter x: x-position.
    /// - parameter y: y-position.
    
    func get<X: Numeric, Y: Numeric>(_ x: X, _ y: Y) -> Color {
        
        var cg_x, cg_y: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        
        let point = CGPoint(x: cg_x, y: cg_y)
        
        guard bounds.contains(point) else {
            // print("Point is outside the image bounds")
            return Color(0, 0 ,0)
        }

        guard let pixelImage = cgimage(at: point) else {
            // print("Could not create pixel Image from CGImage")
            return Color(0, 0 ,0)
        }

        let imageProvider = pixelImage.dataProvider
        let imageData = imageProvider?.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(imageData)

        return Color(data[1],
                     data[2],
                     data[3],
                     data[0])
    }
    
    ///  Initializes and returns a new image.
    ///  ````
    ///  let image = get()
    ///  ````
    
    func get() -> Image {
        get(0, 0, CGFloat(self.width), CGFloat(self.height))
    }
    
    ///  Initializes and returns a new image from a rectangular portion of the screen.
    ///  ````
    ///  let color = img.color(at: Point())
    ///  ````
    /// - parameter x: x-position
    /// - parameter y: y-position
    /// - parameter w: width
    /// - parameter H: height

    func get<X: Numeric, Y: Numeric, W: Numeric, H: Numeric>(_ x: X, _ y: Y, _ w: W, _ h: H) -> Image {
        var cg_x, cg_y, cg_w, cg_h: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        cg_w = w.convert()
        cg_h = h.convert()

        var image = context!.makeImage()
        let screenScale = UIScreen.main.scale
        image = image?.cropping(to: CGRect(x: cg_x * CGFloat(self.scale.x) * screenScale, y: cg_y * CGFloat(self.scale.y) * screenScale, width: cg_w * CGFloat(self.scale.x) * screenScale, height: cg_h * CGFloat(self.scale.y) * screenScale))
        return Image(UIImage(cgImage: image!))
    }
}
/*
 * SwiftProcessing: Push, Pop
 *
 * */

import SceneKit

extension Sketch {
    
    // NOTE FOR FUTURE CONTRIBUTORS: There needs to be a check done at each draw cycle for whether there are any push(), pushStyle(), or pushMatrix() calls that are unaccompanied by a corresponding pop(), popStyle(), or popMatrix call. This can easily be done by comparing the size of the stacks and throwing a meaningful error that explains that all pushes require a corresponding pop. This will prevent the accumulation of states in the stack which could lead to memory leaks.

    // =======================================================================
    // MARK: - PUSH AND POP MATRIX
    // =======================================================================

    /// Resets the current transformation matrix to the identity. Used internally.
    
    public func resetMatrixToIdentity() {
        //Get current transformation matrix via CGContextGetCTM, invert it with CGAffineTransformInvert and multiply the current matrix by the inverted one (that's important!) with CGContextConcatCTM. CTM is now identity.
        
        // Source: https://stackoverflow.com/questions/469505/how-to-reset-to-identity-the-current-transformation-matrix-with-some-cgcontext
        
        let inverted = context?.ctm.inverted()
        context?.concatenate(inverted!)
    }
    
    ///  `pushMatrix()` saves the current transformation matrix of the graphics context and pushes it onto the matrix stacks. **Note:** Each `pushMatrix()` must be accompanied by a `popMatrix()`.
    ///  ````
    ///  pushMatrix()
    ///  ````
    /// - parameter at: a CGPoint.
    
    open func pushMatrix() {
        let currentTransformation = (context?.ctm)!
        matrixStack.push(matrix: currentTransformation)
    }
    
    open func popMatrix() {
        resetMatrixToIdentity()
        context?.concatenate(matrixStack.pop()!)
    }
    
    // =======================================================================
    // MARK: - PUSH AND POP STYLE
    // =======================================================================

    open func pushStyle() {
        settingsStack.push(settings: settings)
    }
    
    open func popStyle() {
        settings = settingsStack.pop()!
        settings.reapplySettings(self)
    }
    
    // =======================================================================
    // MARK: - PUSH AND POP
    // =======================================================================

    /// `push()` saves the current style and matrix state of the graphics context and pushes it onto the style and matrix stacks. SwiftProcessing saves the following style states: `colorMode`, `fill`, `stroke`, `tint`, `strokeWeight`, `strokeJoin`, `strokeCap`, `rectMode`, `ellipseMode`, `imageMode`, `textFont`, `textSize`, `textLeading`, `textAlign`, `textAlignY`, and `blendMode`. It also stores the current transformation matrix, including any `scale()`, `translate()`, or `rotate()`'s that have been applied. **Note:** For every `push()`, there must be a corresponding `pop()`.
    
    open func push() {
        pushStyle()
        pushMatrix()
        
        if (self.enable3DMode) {
            let rootTransformationNode = self.currentTransformationNode
            
            let newTransformationNode = rootTransformationNode.addNewTransitionNode()
            
            self.currentStack.append(newTransformationNode)
            self.stackOfTransformationNodes.append(newTransformationNode)
            
            self.translationNode(SCNVector3(0,0,0), "position", false)
        }
    }
    
    /// `pop()` restores the current style and matrix state of the graphics context and removes it from the style and matrix stacks. SwiftProcessing saves the following style states: `colorMode`, `fill`, `stroke`, `tint`, `strokeWeight`, `strokeJoin`, `strokeCap`, `rectMode`, `ellipseMode`, `imageMode`, `textFont`, `textSize`, `textLeading`, `textAlign`, `textAlignY`, and `blendMode`. It also stores the current transformation matrix, including any `scale()`, `translate()`, or `rotate()`'s that have been applied. **Note:** For every `push()`, there must be a corresponding `pop()`.
    
    open func pop() {
        popStyle()
        popMatrix()
        
        if(self.enable3DMode){
            self.currentTransformationNode = self.currentStack.popLast()!
        }
    }
}
/*
 * SwiftProcessing: Random
 *
 * */

import Foundation
import UIKit

// =======================================================================
// MARK: - RANDOM/NOISE FUNCTIONS
// =======================================================================

public extension Sketch {
    
    /*
     * MARK: - RANDOM
     */
    
    /// Generate a random number from low and high value (inclusive).
    ///  ```
    ///  // Below generates a random number between 10 and 100.
    ///  let number = random(10, 100)
    ///  ```
    /// - Parameters:
    ///   - low: lower bound of random value
    ///   - high: upper bound of the random value
    
    func random<L: Numeric, H: Numeric>(_ low: L = L(0), _ high: H = H(1)) -> Double {
        return Double.random(in: low.convert()...high.convert())
    }
    
    /// Generate a random number from 0 and high value (inclusive).
    ///  ```
    ///  // Below generates a random number up to and including 100.
    ///  let number = random(100)
    ///  // Below generates a random number up to 1.0.
    ///  let newNumber = random()
    ///  ```
    /// - Parameters:
    ///   - high: upper bound of the value's current range
    
    func random<T: Numeric>(_ high: T = T(1)) -> T {
        return T(CGFloat.random(in: 0.0...high.convert()))
    }
    
    /*
     * MARK: - NOISE
     */
    
    /*
     FOR FUTURE CONTRIBUTORS:
     
     From Wikipedia: https://en.wikipedia.org/wiki/Perlin_noise#Algorithm_detail
     
     An implementation typically involves three steps:
     1 — defining a grid of random gradient vectors.
     2 — computing the dot product between the gradient vectors and their offsets
     3 — and interpolation between these values.
     */
    
    /// Perlin Noise
    /// ```
    /// // Example
    /// ```
    /// - Parameters:
    ///   - tk: tk

}


/*
 * SwiftProcessing: Scroll
 *
 * */

import UIKit

// FOR FUTURE CONTRIBUTORS:
// Scroll logic is too glitchy. Commenting out for now as it is experimental

//public extension Sketch {
//
//    func scroll() {
//        self.scrollX()
//        self.scrollY()
//    }
//
//    func scrollX() {
//        self.isScrollX = true
//    }
//
//    func scrollY() {
//        self.isScrollY = true
//    }
//
//    func noScroll() {
//        self.noScrollX()
//        self.noScrollY()
//    }
//
//    func noScrollX() {
//        self.isScrollX = false
//    }
//
//    func noScrollY() {
//        self.isScrollY = false
//    }
//
//    func updateDims(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat){
//        let offsetX = context == nil ? 0 : max([0, (context?.ctm.tx)! / UIScreen.main.scale - contentOffset.x])
//        let offsetY = context == nil ? 0 : max([0, -(context?.ctm.ty)! / UIScreen.main.scale + frame.height - contentOffset.y])
//
//        minX = min([minX + offsetX, x + offsetX])
//        minY = min([minY, y + offsetY])
//        maxX = max([maxX, x + offsetX + w])
//        maxY = max([maxY, y + offsetY + h])
//    }
//
//    func updateScrollView(){
//        var size = CGSize()
//        size.width = isScrollX ? maxX: 0
//        size.height = isScrollY ? maxY: 0
//        self.contentSize = size
//    }
//
//    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        if !isScrollX{
//            scrollView.contentOffset.x = 0.0
//        }
//        if !isScrollY{
//            scrollView.contentOffset.y = 0.0
//        }
//    }
//}
/*
 * SwiftProcessing: Sketch Settings
 *
 * SwiftProcessing and Apple's Core Graphics both have push and pop
 * functions that overlap somewhat, but SwiftProcessing includes many
 * other things. For this reason it's necessary to create this
 * structure. Care should be made to ensure that these settings are
 * in sync with their Core Graphics counterparts within the context.
 *
 * This struct only contains the settings which Core Graphics lacks
 * or where the defaults deviate from SwiftProcessing's desired
 * defaults.
 *
 * */

import UIKit

public extension Sketch{

    struct SketchSettings {
        // Source: https://processing.org/reference/push_.html
        // push() stores information related to the current transformation state and style settings controlled by the following functions: rotate(), translate(), scale(), fill(), stroke(), tint(), strokeWeight(), strokeCap(), strokeJoin(), imageMode(), rectMode(), ellipseMode(), colorMode(), textAlign(), textFont(), textMode(), textSize(), textLeading().
        // The source code has a more comprehensive list of states.
        
        var colorMode = Default.colorMode
        var fill = Default.fill
        var stroke = Default.stroke
        var tint = Default.tint
        var strokeWeight = Default.strokeWeight
        var strokeJoin = Default.strokeJoin
        var strokeCap = Default.strokeCap
        var rectMode = Default.rectMode
        var ellipseMode = Default.ellipseMode
        var imageMode = Default.imageMode
        var textFont = Default.textFont
        var textSize = Default.textSize
        var textLeading = Default.textLeading
        var textAlign = Default.textAlign
        var textAlignY = Default.textAlignY
        var blendMode = Default.blendMode
        
        // Re: textMode – A bitmap mode could be done using CTLineDraw from Core Text.
        // Source 1: https://developer.apple.com/documentation/coretext/1511145-ctlinedraw
        // Source 2: https://blog.krzyzanowskim.com/2020/07/13/coretext-swift-academy-part-3/
        
        static func defaultSettings(_ sketch: Sketch) {
            sketch.settings.reapplySettings(sketch)
        }
        
        public func reapplySettings(_ sketch: Sketch) {
            sketch.colorMode(colorMode)
            sketch.fill(fill)
            sketch.stroke(stroke)
            sketch.tint(tint)
            sketch.strokeWeight(strokeWeight)
            sketch.strokeJoin(strokeJoin)
            sketch.strokeCap(strokeCap)
            sketch.rectMode(rectMode)
            sketch.ellipseMode(ellipseMode)
            sketch.imageMode(imageMode)
            sketch.textFont(textFont)
            sketch.textSize(textSize)
            sketch.textLeading(textLeading)
            sketch.textAlign(textAlign)
        }
        
        public func debugSettings() {
            print("""
            colorMode = \(colorMode)
            fill = \(fill.toString())
            stroke = \(stroke.toString())
            tint = \(tint.toString())
            strokeWeight = \(strokeWeight)
            strokeJoin = \(strokeJoin)
            strokeCap = \(strokeCap)
            rectMode = \(rectMode)
            ellipseMode = \(ellipseMode)
            imageMode = \(imageMode)
            textFont = \(textFont)
            textSize = \(textSize)
            textLeading = \(textLeading)
            textAlign = \(textAlign)
            """
            )
        }
    }
}

// NOTES FOR FUTURE CONTRIBUTORS:

// Core Graphics .saveGState() and .restoreGState() are similar to push and pop.

// Core Graphics .saveGState() pushes all the settings from the current context to the graphics stack. The graphics state parameters that are saved are:

// CTM (current transformation matrix), clip region***, image interpolation quality***, line width, line join, miter limit***, line cap, line dash***, flatness***, should anti-alias***, rendering intent***, fill color space***, stroke color space***, fill color, stroke color, alpha value***, font, font size, character spacing, text drawing mode***, shadow parameters***, the pattern phase***, the font smoothing parameter***, blend mode***

// Source: https://developer.apple.com/documentation/coregraphics/cgcontext/1456156-savegstate

// Processing push() and pop() work similarly, but have a different set of states. The states affected by Processing's push() and pop() are:

// push() stores information related to the current transformation state and style settings controlled by the following functions: rotate(), translate(), scale(), fill(), stroke(), tint()***, strokeWeight(), strokeCap(), strokeJoin(), imageMode()***, rectMode()***, ellipseMode()***, colorMode()***, textAlign()***, textFont(), textMode()***, textSize(), textLeading().

// *** – Inconsistencies.

// NOTE: Reminder that defaults for Apple's Quartz/Core Graphics are inconsistent with Processing's defaults in many situations. State needs to be set up.

// Processing maintains two classes: PStyle and PMatrix

// From Processing source code's PStyle constant:

/*
 public int imageMode;
 public int rectMode;
 public int ellipseMode;
 public int shapeMode;
 
 public int blendMode;
 
 public int colorMode;
 public float colorModeX;
 public float colorModeY;
 public float colorModeZ;
 public float colorModeA;
 
 public boolean tint;
 public int tintColor;
 public boolean fill;
 public int fillColor;
 public boolean stroke;
 public int strokeColor;
 public float strokeWeight;
 public int strokeCap;
 public int strokeJoin;
 */


/*
 *              GRAPHICS STATES ON BOTH PLATFORMS
 *----------------------------------------------------------------
 *      Apple Core Graphics      |          Processing           |
 *----------------------------------------------------------------
 * Current Transformation Matrix | rotate(), translate(), scale()|
 * line width                    | strokeWeight()                |
 * line join                     | strokeJoin()                  |
 * line cap                      | strokeCap()                   |
 * fill color                    | fill()                        |
 * stroke color                  | stroke()                      |
 * font                          | textFont()                    |
 * font size                     | textSize()                    |
 * character spacing             | textLeading()                 |
 * ---------------------------------------------------------------
 *
 *  INCONSISTENT GRAPHICS STATES
 *--------------------------------
 *      Apple Core Graphics      |
 *--------------------------------
 * clip region                   |
 * image interpolation quality   |
 * miter limit                   |
 * line dash                     |
 * flatness                      |
 * should anti-alias             |
 * rendering intent              |
 * fill color space              |
 * stroke color space            |
 * alpha value                   |
 * text drawing mode             |
 * shadow parameters             |
 * the pattern phase             |
 * font smoothing paramters      |
 * blend mode                    |
 *--------------------------------
 *
 *--------------------------------
 *          Processing           |
 *--------------------------------
 * tint()                        |
 * imageMode()                   |
 * rectMode()                    |
 * ellipseMode()                 |
 * colorMode()                   |
 * textAlign()                   |
 * textMode()                    |
 * -------------------------------
 */



/*
 * SwiftProcessing: Sketch Stacks
 *
 * These two stack structs are used to store SwiftProcessing's
 * style and matrix settings. Decoupling the style and matrix
 * settings helps separate internal and external push and pop
 * operations. It also helps us maintain state between Apple's
 * Quartz/Core Graphics framework and Processing's own graphics
 * state.
 *
 * */

/*
 https://github.com/raywenderlich/swift-algorithm-club
 */

import CoreGraphics

public extension Sketch {
    
    struct SketchSettingsStack {
        fileprivate var array = [SketchSettings]()
        
        var isEmpty: Bool {
            return array.isEmpty
        }
        
        var count: Int {
            return array.count
        }
        
        mutating func push(settings: SketchSettings) {
            array.append(settings)
        }
        
        mutating func pop() -> SketchSettings? {
            if array.count == 0 {
                assertionFailure("Error: invalid call to pop")
            }
            return array.popLast()
        }
        
        var top: SketchSettings? {
            return array.last
        }
        
        // For debugging.
        func printStackSize() {
            print("Stack size is \(array.count)")
        }
    }
    
    struct SketchMatrixStack {
        fileprivate var array = [CGAffineTransform]()
        
        var isEmpty: Bool {
            return array.isEmpty
        }
        
        var count: Int {
            return array.count
        }
        
        mutating func push(matrix: CGAffineTransform) {
            array.append(matrix)
        }
        
        mutating func pop() -> CGAffineTransform? {
            if array.count == 0 {
                assertionFailure("Error: invalid call to pop")
            }
            return array.popLast()
        }
        
        var top: CGAffineTransform? {
            return array.last
        }
        
        // For debugging.
        func printStackSize() {
            print("Stack size is \(array.count)")
        }
    }
    
}
/*
 * SwiftProcessing: Structure
 *
 * This is where the draw loop is structured using CADisplayLink.
 * This is also where beginDraw() and endDraw() are called.
 *
 * */

import UIKit

public extension Sketch {
    
    /// Tells to SwiftProcessing to loop the draw cycle at the frame rate (default is 60).
    
    func loop() {
        beginDraw()
        if #available(iOS 10.0, *) {
            
            fpsTimer = CADisplayLink(target: self,
                                     selector: #selector(nextFrame))
            fpsTimer?.preferredFramesPerSecond = Int(fps)
            fpsTimer!.add(to: .main, forMode: RunLoop.Mode.default)
            fpsTimer!.add(to: .main, forMode: RunLoop.Mode.tracking)
        } else {
            // Note for future contributors:
            // Unimplemented for earlier versions.
        }
    }
    
    @objc func nextFrame(displaylink: CADisplayLink) {
        self.setNeedsDisplay()
    }
    
    /// Tells SwiftProcessing not to loop. Can be used to stop looping at any time in branching logic.
    
    func noLoop() {
        fpsTimer!.invalidate()
        // Clean up stack. At this point the stack size should be 0.
        endDraw()
    }
    
    /// Notifies the graphics context that a change has been made and that the screen needs to be refreshed.
    
    func redraw() {
        self.setNeedsDisplay()
    }
}
/*
 * SwiftProcessing: Touch
 *
 * */

import Foundation
import UIKit

extension Sketch: UIGestureRecognizerDelegate {
    
    open func touchMode(_ mode: TouchMode) {
        self.touchMode = mode
    }
    
    func initTouch() {
        isMultipleTouchEnabled = true
        touchRecongizer = UIGestureRecognizer()
        touchRecongizer.delegate = self
        touchRecongizer.cancelsTouchesInView = false
        addGestureRecognizer(touchRecongizer)
    }
    
    // This helps distinguish between touches on the sketch and ui elements.
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touchMode == .sketch {
            return touch.view == gestureRecognizer.view
        } else if (touch.view as? UIControl) != nil {
            return false
        } else {
            return true
        }
    }
    
    func updateTouches(){
        var isTouchStarted: Bool = false
        var isTouchEnded: Bool = false
        touchRecongizer.cancelsTouchesInView = false
        
        if touchRecongizer.numberOfTouches > touches.count {
            isTouchStarted = true
        }
        
        if touchRecongizer.numberOfTouches < touches.count {
            isTouchEnded = true
        }
        
        // Step 1: Let's check if the touch has ended,
        // because if it's ended, we can just stop here.
        if isTouchEnded {
            sketchDelegate?.touchEnded?()
        }
        
        if touchRecongizer.numberOfTouches == 0 {
            touches = []
            touched = false
            return // This cuts out of the function.
        }
        
        let newTouches = (0...touchRecongizer.numberOfTouches - 1)
            .map({touchRecongizer.location(ofTouch: $0, in: self)})
            .map({createVector($0.x, $0.y)})
        
        // Step 2: If a touch started, then execute touchStarted()
        if isTouchStarted {
            sketchDelegate?.touchStarted?()
        }
        
        // Step 3: If the touch is moving, then execute touchMoved()
        let moveThreshold: Double = 1.0
        if newTouches.count == touches.count {
            var totalDiff: Double = 0
            for (i, oldTouch) in touches.enumerated() {
                totalDiff += oldTouch.dist(newTouches[i])
            }
            if totalDiff > moveThreshold{
                sketchDelegate?.touchMoved?()
            }
        }
        
        touches = newTouches
        
        touched =  touches.count > 0
        if let t = touches.first {
            touchX = Double(t.x)
            touchY = Double(t.y)
        }
    }
    
}
/*
 * SwiftProcessing: Transform
 *
 * */

import UIKit

public extension Sketch {
    
    // Note for future contributors: p5.js has implemented a global angle mode state. This could easily be added to SwiftProcessing as well. Creating a helper function with a switch inside that checks the current state would be a good approach. See colorModeHelper for an example of this approach.
    
    var translation: Vector{
        get{
            let translationX = context == nil ? 0 : (context?.ctm.tx)! / UIScreen.main.scale
            let translationY = context == nil ? 0 :  -(context?.ctm.ty)! / UIScreen.main.scale + frame.height
            return createVector(translationX, translationY)
        }
    }
    
    var scale: Vector{
        get{
            let scaleX = context == nil ? 1 : (context?.ctm.a)! / UIScreen.main.scale
            let scaleY = context == nil ? 1 :  -(context?.ctm.d)! / UIScreen.main.scale
            return createVector(scaleX, scaleY)
        }
    }
    
    /// Rotates the coordinate system using radians.
    /// ```
    /// // Below rotates π or 180°.
    /// rotate(Math.pi)
    /// ```
    /// - Parameters:
    ///     - angle: Usually a number from 0 to 2*PI. Numbers beyond that will just repeat the rotation.
    
    func rotate<T: Numeric>(_ angle: T) {
        context?.rotate(by: angle.convert())
    }
    
    /// Translates (shifts or moves) the coordinate system in the x and y direction.
    /// ```
    /// // Below translates by 50 in the x and 100 in the y direction°.
    /// translate(50, 100)
    /// ```
    /// - Parameters:
    ///     - x: The number of points to move the coordinate system in the x direction.
    ///     - y: The number of points to move the coordinate system in the y direction.

    func translate<T: Numeric>(_ x: T, _ y: T) {
        context?.translateBy(x: x.convert(), y: y.convert())
    }
    
    /// Scales the coordinate system (i.e. makes it smaller or larger).
    /// ```
    /// // Below scales by a factor of 2.5 in both x and y directions.
    /// scale(2.5)
    /// ```
    /// - Parameters:
    ///     - factor: A uniform scaling factor that simultaneously affects the scale of both x and y.
    
    func scale<T: Numeric>(_ factor: T) {
        context?.scaleBy(x: factor.convert(), y: factor.convert())
    }
    
    /// Scales the coordinate system (i.e. makes it smaller or larger).
    /// ```
    /// // Below scales by a factor of 2.5 in the x and 1.5 in the y directions.
    /// scale(2.5, 1.5)
    /// ```
    /// - Parameters:
    ///     - x: The scaling magnitude in the x direction.
    ///     - y: The scaling magnitude in the y direction.
    
    func scale<T: Numeric>(_ x: T, _ y: T) {
        context?.scaleBy(x: x.convert(), y: y.convert())
    }
}
/*
 * SwiftProcessing: Typography
 *
 * */


import UIKit

public extension Sketch {
    
    /// Sets the text size.
    /// ```
    /// // Below sets the text size to 12 points.
    /// textSize(12)
    /// ```
    /// - Parameters:
    ///     - size: font size in points.
    
    func textSize<S: Numeric>(_ size: S) {
        settings.textSize = size.convert()
    }
    
    /// Sets the text font. For a list of pre-installed fonts on iOS, see here: https://developer.apple.com/fonts/system-fonts/#preinstalled
    /// ```
    /// // Below sets font to Courier.
    /// textFont("Courier")
    /// ```
    /// - Parameters:
    ///     - name: font name as a string.
    
    func textFont(_ name: String) {
        settings.textFont = name
    }
    
    /// Sets the text alignment horizontally and, optionally, vertically.
    /// ```
    /// // Below sets the horizontal alignment to be centered.
    /// textAlign(.center)
    /// // Below sets the horizontal alignment to be right and the vertical alignment to be bottom.
    /// textAlign(.right, .bottom)
    /// ```
    /// - Parameters:
    ///     - alignX: horizontal alignment. Possible values are `.center`, `.right`, and `.left`.
    ///     - alignY: vertical alignment. Possible values are `.top`, `.bottom`, and `.baseline`. `.baseline` is the default.
    
    func textAlign(_ alignX: Alignment, _ alignY: AlignmentY = Default.textAlignY){
        settings.textAlign = alignX
        settings.textAlignY = alignY
    }
    
    /// Sets the text leading, i.e. the space between lines of text.
    /// ```
    /// // Below sets the leading to 36 points.
    /// textLeading(36)
    /// // Below sets the horizontal alignment to be right and the vertical alignment to be bottom.
    /// textAlign(.right, .bottom)
    /// ```
    /// - Parameters:
    ///     - leading: space between lines in points
    
    func textLeading<L: Numeric>(_ leading: L) {
        settings.textLeading = leading.convert()
    }
    
    /// Draws a string of text to the screen using an x and y coordinate. Optionally you can specify a second x and y to draw within a rectangular space.
    /// ```
    /// // Draws "Hello world" at 100, 100
    /// text("Hello world", 100, 100)
    /// // Draws "Boxed in!" within the rectangular space between (200, 200) and (500, 500)
    /// text("Boxed in!", 200, 200, 500, 500)
    /// ```
    /// - Parameters:
    ///     - string: string you'd like to display on your sketch.
    ///     - x: x-position of string
    ///     - y: y-position of string
    ///     - x1: x-position of the lower-right hand corner of the string
    ///     - y2: y-positin of the lower-right hand corner of the string
    
    func text<X: Numeric, Y: Numeric, X2: Numeric, Y2: Numeric>(_ string: String, _ x: X, _ y: Y, _ x2: X2?, _ y2: Y2?) {
        let cg_x, cg_y: CGFloat
        let cg_x2, cg_y2: CGFloat?
        cg_x = x.convert()
        cg_y = y.convert()
        cg_x2 = x2?.convert()
        cg_y2 = y2?.convert()
        
        let paragraphStyle = NSMutableParagraphStyle()
        
        var align: NSTextAlignment!
        switch settings.textAlign {
        case .left:
            align = .left
        case .right:
            align = .right
        case .center:
            align = .center
        }
        paragraphStyle.alignment = align
        paragraphStyle.lineSpacing = CGFloat(settings.textLeading)
        
        
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .font: UIFont(name: settings.textFont, size: CGFloat(settings.textSize))!,
            .foregroundColor: settings.fill.uiColor(),
            .strokeWidth: -settings.strokeWeight,
            .strokeColor: settings.stroke.uiColor()
        ]
        
        if cg_x2 == nil {
            string.draw(at: CGPoint(x: cg_x, y: cg_y), withAttributes: attributes)
        } else {
            string.draw(with: CGRect(x: cg_x, y: cg_y, width: (cg_x2 != nil) ? cg_x2! : CGFloat(width), height: (cg_y2 != nil) ? cg_y2! : CGFloat(height)), options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        }
    }
    
    /// Draws a string of text to the screen using an x and y coordinate.
    /// ```
    /// // Draws "Hello world" at 100, 100
    /// text("Hello world", 100, 100)
    /// ```
    /// - Parameters:
    ///     - string: string you'd like to display on your sketch.
    ///     - x: x-position of string
    ///     - y: y-position of string
    
    func text<X: Numeric, Y: Numeric>(_ string: String, _ x: X, _ y: Y) {
        let cg_x1 = nil as CGFloat?
        let cg_x2 = nil as CGFloat?
        text(string, x, y, cg_x1, cg_x2)
    }
}
/*
 * SwiftProcessing: Vector
 *
 * */

import Foundation
import UIKit

public extension Sketch {
    
    /// Returns a 3-dimensional vector object with x, y, and z values.
    /// ```
    /// // Creates a vector at (30, 20, 10) and assigns it to vector
    /// let vector = createVector(30, 20, 10)
    /// ```
    /// - Parameters:
    ///     - x: x-position
    ///     - y: y-position
    ///     - z: z-position
    
    func createVector<X: Numeric, Y: Numeric, Z: Numeric>(_ x: X, _ y: Y, _ z: Z) -> Vector {
        return Vector(x, y, z)
    }
    
    /// Returns a 2-dimensional vector object with x and y values.
    /// ```
    /// // Creates a vector at (30, 20) and assigns it to vector
    /// let vector = createVector(30, 20)
    /// ```
    /// - Parameters:
    ///     - x: x-position
    ///     - y: y-position
    
    func createVector<X: Numeric, Y: Numeric>(_ x: X, _ y: Y) -> Vector {
        return Vector(x, y)
    }
    
    open class Vector: CustomStringConvertible {
        public var description: String {
            if z != nil{
                return "(\(x), \(y), \(String(describing: z)))"
            }else{
                return "(\(x), \(y))"
            }
        }
        
        open var x: Double
        open var y: Double
        open var z: Double?
        
        public init<X: Numeric, Y: Numeric>(_ x: X, _ y: Y) {
            self.x = x.convert()
            self.y = y.convert()
            self.z = nil as Double?
        }
        
        public init<X: Numeric, Y: Numeric, Z: Numeric>(_ x: X, _ y: Y, _ z: Z?) {
            self.x = x.convert()
            self.y = y.convert()
            self.z = z?.convert()
        }
        
        /// Sets the vector object to a 2-dimensional vector with x and y values.
        /// ```
        /// // Sets myVector to (30, 20)
        /// myVector.set(30, 20)
        /// ```
        /// - Parameters:
        ///     - x: x-position
        ///     - y: y-position
        
        open func set<X:Numeric, Y: Numeric>(_ x: X, _ y: Y) {
            self.x = x.convert()
            self.y = y.convert()
            self.z = nil as Double?
        }
        
        /// Sets the vector object to a 3-dimensional vector with x, y, and z values.
        /// ```
        /// // Sets myVector to (30, 20, 10)
        /// myVector.set(30, 20, 10)
        /// ```
        /// - Parameters:
        ///     - x: x-position
        ///     - y: y-position
        ///     - z: z-position
        
        open func set<X:Numeric, Y: Numeric, Z: Numeric>(_ x: X, _ y: Y, _ z: Z?) {
            self.x = x.convert()
            self.y = y.convert()
            self.z = z?.convert()
        }
        
        /// Sets the vector object to be a copy of another vector object.
        /// ```
        /// // Sets myVector to anotherVector
        /// myVector.set(anotherVector)
        /// ```
        /// - Parameters:
        ///     - v: vector
        
        open func set(_ v: Vector) {
            self.x = v.x
            self.y = v.y
            self.z = v.z
        }
        
        /// Returns a copy of a vector object. This is useful if you want to create a copy as opposed to creating a reference, which is the default behavior of Swift when using the = sign with objects. For example, `myVector = anotherVector` would copy a reference, rather than a copy. If you changed values in `myVector`, they would be changed in `anotherVector` too. This is a common source of bugs.
        /// ```
        /// // Sets myVector to anotherVector
        /// myVector = anotherVector.copy()
        /// ```
        
        open func copy() -> Vector {
            return Vector(self.x, self.y, self.z)
        }
        
        /// + operator adds two vectors together.
        /// ```
        /// // Adds myVector to anotherVector and assigns it to newVector
        /// let newVector = myVector + anotherVector
        /// ```
        /// - Parameters:
        ///      - left: left operand
        ///      - right: right operand
        
        public static func + (left: Vector, right: Vector) -> Vector {
            return Vector(left.x + right.x, left.y + right.y, left.z != nil ? (left.z! + right.z!) : nil)
        }
        
        /// Adds two vectors together.
        /// ```
        /// // Adds myVector to anotherVector and assigns it to newVector
        /// let newVector = Vector.add(myVector, anotherVector)
        /// ```
        /// - Parameters:
        ///      - v1: vector 1
        ///      - v2: vector 2
        
        public static func add (_ v1: Vector, _ v2: Vector) -> Vector {
            return Vector(v1.x + v2.x, v1.y + v2.y,  v1.z != nil ? (v1.z! + v2.z!) : nil)
        }
        
        /// Adds two vectors together.
        /// ```
        /// // Adds anotherVector to myVector
        /// myVector.add(anotherVector)
        /// ```
        /// - Parameters:
        ///      - v: vector  to add
        
        open func add(_ v: Vector) -> Vector {
            let result = Vector.add(self, v)
            self.set(result)
            return self
        }
        
        /// Adds an x, y, and z value to an existing vector.
        /// ```
        /// // Adds (30, 20, 10) to myVector
        /// myVector.add(30, 20, 10)
        /// ```
        /// - Parameters:
        ///      - x: x  to add
        ///      - y: y  to add
        ///      - z: z  to add
        
        open func add<X: Numeric, Y: Numeric, Z: Numeric>(_ x: X, _ y: Y, _ z: Z?) -> Vector {
            return Vector.add(self, Vector(x, y, z))
        }
        
        /// Adds an x and y values to an existing vector.
        /// ```
        /// // Adds (30, 20, 10) to myVector
        /// myVector.add(30, 20, 10)
        /// ```
        /// - Parameters:
        ///      - x: x  to add
        ///      - y: y  to add
        
        open func add<X: Numeric, Y: Numeric>(_ x: X, _ y: Y) -> Vector {
            return Vector.add(self, Vector(x, y))
        }
        
        /// - operator subtracts two vectors from each other.
        /// ```
        /// // Subtracts myVector from anotherVector and assigns it to newVector
        /// let newVector = myVector - anotherVector
        /// ```
        /// - Parameters:
        ///      - left: left operand
        ///      - right: right operand
        
        public static func - (left: Vector, right: Vector) -> Vector {
            return Vector(left.x - right.x, left.y - right.y, left.z != nil ? (left.z! - right.z!) : nil)
        }
        
        /// Subtracts two vectors from each other.
        /// ```
        /// // Adds myVector to anotherVector and assigns it to newVector
        /// let newVector = Vector.sub(myVector, anotherVector)
        /// ```
        /// - Parameters:
        ///      - v1: vector 1
        ///      - v2: vector 2
        
        public static func sub (_ v1: Vector, _ v2: Vector) -> Vector {
            return Vector(v1.x - v2.x, v1.y - v2.y, v1.z != nil ? (v1.z! - v2.z!) : nil)
        }
        
        /// Subtracts one vector from another.
        /// ```
        /// // Subtracts anotherVector from myVector
        /// myVector.sub(anotherVector)
        /// ```
        /// - Parameters:
        ///      - v: vector  to add
        
        open func sub(_ v: Vector) -> Vector {
            let result = Vector.sub(self, v)
            self.set(result)
            return self
        }
        
        /// Subtracts an x and y values from an existing vector.
        /// ```
        /// // Adds (30, 20, 10) to myVector
        /// myVector.add(30, 20, 10)
        /// ```
        /// - Parameters:
        ///      - x: x  to add
        ///      - y: y  to add
        
        open func sub<T: Numeric>(_ x: T, _ y: T) -> Vector {
            return Vector.sub(self, Vector(x, y))
        }
        
        /// * operator multiplies a vector by a factor.
        /// ```
        /// // Multiplies myVector by 5 and assigns it to newVector
        /// let newVector = myVector * 5
        /// ```
        /// - Parameters:
        ///      - vector: vector to be multiplied
        ///      - factor: factor to multiply the vector by
        
        public static func * <F: Numeric>(_ vector: Vector, _ factor: F) -> Vector {
            return Vector.mult(vector, factor)
        }
        
        /// Multiplies a vector by a factor.
        /// ```
        /// // Multiplies myVector by 5 and assigns it to newVector
        /// let newVector = Vector.mult(myVector, 5)
        /// ```
        /// - Parameters:
        ///      - vector: vector to be multiplied
        ///      - factor: factor to multiply the vector by
        
        public static func mult<F: Numeric>(_ vector: Vector, _ factor: F) -> Vector {
            return Vector(vector.x * factor.convert(), vector.y * factor.convert(), vector.z != nil ? (vector.z! * factor.convert()) : nil)
        }
        
        /// Multiplies a vector by a factor.
        /// ```
        /// // Multiplies myVector by 5
        /// myVector.mult(5)
        /// ```
        /// - Parameters:
        ///      - vector: vector to be multiplied
        ///      - factor: factor to multiply the vector by
        
        open func mult<F: Numeric>(_ factor: F) -> Vector {
            let result = Vector.mult(self, factor)
            self.set(result)
            return self
        }
        
        /// / operator divides a vector by a divisor.
        /// ```
        /// // Divides myVector by 5 and assigns it to newVector
        /// let newVector = myVector / 5
        /// ```
        /// - Parameters:
        ///      - vector: vector to be divided
        ///      - factor: divisor to divide the vector by
        
        public static func / <D: Numeric>(_ vector: Vector, _ divisor: D) -> Vector {
            return Vector.div(vector, divisor)
        }
        
        /// Divides a vector by a divisor.
        /// ```
        /// // Divides myVector by 5 and assigns it to newVector
        /// let newVector = Vector.div(myVector, 5)
        /// ```
        /// - Parameters:
        ///      - vector: vector to be multiplied
        ///      - divisor: divisor to divide the vector by
        
        public static func div<D: Numeric>(_ vector: Vector, _ divisor: D) -> Vector {
            return Vector(vector.x / divisor.convert(), vector.y / divisor.convert(), vector.z != nil ? (vector.z! / divisor.convert()) : nil)
        }
        
        /// Divides a vector by a divisor.
        /// ```
        /// // Divides myVector by 5
        /// myVector.div(5)
        /// ```
        /// - Parameters:
        ///      - divisor: factor to multiply the vector by
        
        open func div<D: Numeric>(_ divisor: D) -> Vector {
            let result = Vector.div(self, divisor)
            self.set(result)
            return self
        }
        
        /// Returns the magnitude of the vector. Uses the distance formula. **Note:** If you are just trying to assess if something is more or less distant than something else and don't need exact values, then use `magSq()` instead. It will do the same thing and does not rely upon a square root, which slows things down in computing.
        /// ```
        /// // Assigns the magnitude of myVector to magnitude
        /// let magnitude = myVector.mag()
        /// ```
        
        open func mag() -> Double {
            return sqrt(self.magSq())
        }
        
        /// Returns the magnitude squared of the vector. Uses the distance formula minus the square root. **Note:** This is faster than `mag()` if you are just trying to compare whether one object is farther than another and don't need exact distances.
        /// ```
        /// // Assigns the magnitude squared of myVector to magnitude
        /// let magnitudeSquared = myVector.magSq()
        /// ```
        
        open func magSq() -> Double  {
            return x * x + y * y + (z != nil ? z! * z! : 0)
        }
        
        /// Returns the dot product of two vectors.
        /// ```
        /// // Assigns the dot product of myVector and anotherVector to dotProduct
        /// let dotProduct = Vector.dot(myVector, anotherVector)
        /// ```
        /// - Parameters:
        ///      - v1: vector 1
        ///      - v2: vector 2
        
        public static func dot(_ v1: Vector, _ v2: Vector) -> Double {
            return v1.x * v2.x + v2.y * v2.y + (v1.z != nil ? (v1.z! * v2.z!) : 0)
        }
        
        /// Returns the dot product of a vector with itself, which is the square of its magnitude.
        /// ```
        /// // Assigns the dot product of myVector with itself to dotProduct
        /// let dotProduct = Vector.dot(myVector)
        /// ```
        /// - Parameters:
        ///      - v1: vector 1
        ///      - v2: vector 2
        
        open func dot(_ v: Vector) -> Double {
            return Vector.dot(v, self)
        }
        
        /// Returns the distance betwen two vectors.
        /// ```
        /// // Assigns the distance between myVector and anotherVector to distance
        /// let distance = dist(myVector, anotherVector)
        /// ```
        /// - Parameters:
        ///      - v1: vector 1
        ///      - v2: vector 2
        
        public static func dist(_ v1: Vector, _ v2: Vector) -> Double {
            return sqrt(pow(v2.x - v1.x, 2) + pow(v2.y - v1.y, 2) + (v1.z != nil ? pow(v2.z! - v1.z!, 2) : 0))
        }
        
        /// Returns the distance betwen two vectors.
        /// ```
        /// // Assigns the distance between myVector and anotherVector to distance
        /// let distance = myVector.dist(anotherVector)
        /// ```
        /// - Parameters:
        ///      - v: vector
        
        open func dist(_ v: Vector) -> Double {
            return Vector.dist(v, self)
        }
        
        /// Returns a normalized vector which describes the direction of a vector without taking its length into account.
        /// ```
        /// // Normalizes a vector.
        /// let normalized = myVector.normalize()
        /// ```
        /// - Parameters:
        ///      - v1: vector 1
        ///      - v2: vector 2
        
        open func normalize() -> Vector {
            let len = self.mag()
            if (len != 0){
                return self.mult(1 / len)
            }
            return self
        }
        
        /// Returns the heading of a vector as an angle. This is useful when thinking about objects that need to aim or point. Uses `atan2()`.
        /// ```
        /// // Assigns the heading angle to angle
        /// let angle = myVector.heading()
        /// ```
        /// - Parameters:
        ///      - v1: vector 1
        ///      - v2: vector 2
        
        open func heading() -> Double {
            let h = atan2(self.y, self.x)
            return h
        }
        
        /// Returns a vector rotated by the angle theta.
        /// ```
        /// // Assigns the vector created by rotating myVector by Math.pi
        /// let rotated = myVector.rotate(Math.pi)
        /// ```
        /// - Parameters:
        ///      - v1: vector 1
        ///      - v2: vector 2
        
        open func rotate<T: Numeric>(_ theta: T) -> Vector {
            var newHeading = self.heading()
            newHeading += theta.convert();
            let mag = self.mag();
            self.x = cos(newHeading) * mag;
            self.y = sin(newHeading) * mag;
            return self;
        }
    }
}
/*
 * SwiftProcessing: Vertex
 *
 * */


import UIKit

// =======================================================================
// MARK: - Vertex Sketch Extension
// =======================================================================

public extension Sketch {

    /*
     * MARK: - BEGINSHAPE / ENDSHAPE
     */
    
    // NOTE TO FUTURE CONTRIBUTORS: There really should be a check to make sure that beginShape() is never called without an endShape(). It should gracefully throw an error that is meaningful and explains the issue.
    
    /// Marks the beginning of a vertex shape.
    /// ```
    /// // Creates a square shape with 4 vertex points
    /// beginShape()
    /// vertex(10, 10)
    /// vertex(90, 10)
    /// vertex(90, 90)
    /// vertex(10, 90)
    /// endShape(.close)
    /// ```
    
    func beginShape() {
        shapePoints = []
    }
    
    /// Marks the beginning of a vertex shape.
    /// ```
    /// // Creates a square shape with 4 vertex points
    /// beginShape()
    /// vertex(10, 10)
    /// vertex(90, 10)
    /// vertex(90, 90)
    /// vertex(10, 90)
    /// endShape(.close)
    /// ```
    /// - Parameters:
    ///      - mode: Shape path mode. Options are `.open` for an open shape and `.close` with a shape that is closed between its first and last points.
    
    func endShape(_ mode: ShapePath = .open) {
        context?.beginTransparencyLayer(auxiliaryInfo: .none)
        
        if vertexMode == VertexMode.normal {
            
            // DRAW SHAPE
            context?.beginPath()
            context?.move(to: shapePoints.first!)
            for p in shapePoints {
                context?.addLine(to: p)
            }
            
            if mode == ShapePath.close {
                context?.closePath()
            }
            context?.drawPath(using: .fillStroke)
            
            // NOTE FOR FUTURE CONTRIBUTORS: This approach *simulates* the behavior of beginContour, but is not actually how it works. Quartz (and Java 2D) use the non-zero winding number rule. This means that clockwise winding are beginShape and counter-clockwise winding are beginContour. This happens under the hood and that's how we should be implementing beginContour().
            // RESOURCE: https://en.wikipedia.org/wiki/Nonzero-rule
            
            // TO BE FIXED.
            
            // DRAW CONTOUR AS AN ERASE
            if contourPoints.count > 0 {
                context?.beginPath()
                context?.setBlendMode(CGBlendMode.clear)
                context?.move(to: contourPoints.first!)
                for p in contourPoints {
                    context?.addLine(to: p)
                }
                context?.drawPath(using: .fillStroke)
                // STROKE CONTOUR
                context?.setBlendMode(CGBlendMode.normal)
                context?.beginPath()
                context?.move(to: contourPoints.first!)
                for p in contourPoints {
                    context?.addLine(to: p)
                }
                context?.strokePath()
            }
            
        } else if vertexMode == VertexMode.curve {

            context?.beginPath()
            let curveDetail = 20.0
            let curvePath = CurvePath(points: shapePoints)
            
            context?.move(to: curvePath.points.first!)
            
            if mode == ShapePath.close {
                for p in stride(from: 0.0, to: Double(curvePath.points.count), by: 1.0/curveDetail) {
                    let curvePoint = (curvePath.getSplinePoint(u: CGFloat(p), closed: true))
                    // NOTE FOR FUTURE CONTRIBUTORS: This may be a place where multithreading could speed up execution. Async would be the thing to research. You could turn this into a closure, precompute the values, and then put them back together with another array.
                    context?.addLine(to: curvePoint)
                }
                context?.closePath()
            } else {
                for p in stride(from: 0.0, to: Double(curvePath.points.count) - 3.0, by: 1.0/curveDetail) {
                    let curvePoint = (curvePath.getSplinePoint(u: CGFloat(p), closed: false))
                    context?.addLine(to: curvePoint)
                }
            }
            context?.drawPath(using: .fillStroke)
            
        } else if vertexMode == VertexMode.bezier {
            context?.move(to: shapePoints.first!)
            var z = 1
            while z < shapePoints.count {
                context?.addCurve(to: shapePoints[z + 2], control1: shapePoints[z], control2: shapePoints[z + 1])
                z = z + 3
            }
            context?.drawPath(using: .fillStroke)
        }
        context?.endTransparencyLayer()
        
        shapePoints = []
        contourPoints = []
        vertexMode = VertexMode.normal
    }
    
    /*
     * MARK: - BEGINCONTOUR / ENDCONTOUR
     */
    
    // NOTE TO FUTURE CONTRIBUTORS: We really should be checking whether every beginContour() corresponds to an endContour(). If any calls don't correspond, then we should throw a meaningful error.
    
    /// Marks the beginning of a vertex contour. A contour is distinct from a shape in that it is a shape that cuts out of another shape. **Note:** Contour shapes are always 'closed'. A `beginContour()` call must always be accompanied by an `endContour()` call.
    /// ```
    /// // Creates a square shape with 4 vertex points
    /// beginShape()
    /// vertex(10, 10)
    /// vertex(90, 10)
    /// vertex(90, 90)
    /// vertex(10, 90)
    /// endShape(.close)
    ///
    ///// Cuts a smaller shape out of the larger shape
    /// beginContour()
    /// vertex(20, 20)
    /// vertex(80, 20)
    /// vertex(80, 80)
    /// vertex(20, 80)
    /// endContour()
    /// ```
    
    func beginContour() {
        isContourStarted = true
        contourPoints = []
    }
    
    /// Marks the end of a vertex contour. A contour is distinct from a shape in that it is a shape that cuts out of another shape. **Note:** Contour shapes are always 'closed'. A `beginContour()` call must always be accompanied by an `endContour()` call.
    /// ```
    /// // Creates a square shape with 4 vertex points
    /// beginShape()
    /// vertex(10, 10)
    /// vertex(90, 10)
    /// vertex(90, 90)
    /// vertex(10, 90)
    /// endShape(.close)
    ///
    ///// Cuts a smaller shape out of the larger shape
    /// beginContour()
    /// vertex(20, 20)
    /// vertex(80, 20)
    /// vertex(80, 80)
    /// vertex(20, 80)
    /// endContour()
    /// ```
    
    func endContour() {
        isContourStarted = false
        contourPoints.append(contourPoints.first!)
    }
    
    /*
     * MARK: - VERTEX FUNCTIONS
     */
    
    /// Creates a vertex point for creating shapes or contours.
    /// ```
    /// // Creates a square shape with 4 vertex points
    /// beginShape()
    /// vertex(10, 10)
    /// vertex(90, 10)
    /// vertex(90, 90)
    /// vertex(10, 90)
    /// endShape(.close)
    /// ```
    /// - Parameters:
    ///      - x: x-position of point
    ///      - x: y-position of point
    
    func vertex<X: Numeric, Y: Numeric>(_ x: X, _ y: Y) {
        let cg_x, cg_y: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        
        let point = CGPoint(x: cg_x, y: cg_y)
        
        if isContourStarted {
            contourPoints.append(point)
        } else {
            shapePoints.append(point)
        }
    }
    
    /// Creates a curve vertex point for creating curved shapes or contours.
    /// ```
    /// // Creates a rounded square shape with 4 vertex points
    /// beginShape()
    /// curveVertex(10, 10)
    /// curveVertex(90, 10)
    /// curveVertex(90, 90)
    /// curveVertex(10, 90)
    /// endShape(.close)
    /// ```
    /// - Parameters:
    ///      - x: x-position of point
    ///      - x: y-position of point
    
    func curveVertex<X: Numeric, Y: Numeric>(_ x: X, _ y: Y) {
        let cg_x, cg_y: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        
        vertexMode = VertexMode.curve
        
        vertex(cg_x, cg_y)
    }
    
    /// Creates a bezier curve vertex point for creating curved shapes or contours.
    /// ```
    /// // Creates a rounded square shape with 4 vertex points
    /// beginShape()
    /// vertex(120, 80);
    /// bezierVertex(320, 0, 320, 300, 90, 300);
    /// bezierVertex(200, 320, 240, 100, 120, 80);
    /// endShape(.close)
    /// ```
    /// - Parameters:
    ///      - x: x-position of point
    ///      - x: y-position of point
    
    func bezierVertex(_ x2: CGFloat, _ y2: CGFloat, _ x3: CGFloat, _ y3: CGFloat, _ x4: CGFloat, _ y4: CGFloat) {
        vertexMode = VertexMode.bezier
        vertex(x2, y2)
        vertex(x3, y3)
        vertex(x4, y4)
    }
    
    /*
     * MARK: - CATMULL-ROM SPLINE IMPLEMENTATION
     */
    
    // NOTE FOR FUTURE CONTRIBUTORS: The behavior of open and closed Catmull-Rom Spline curves is slightly different in SwiftProessing than Processing. The behavior of Processing is the correct behavior according to the algorithm. The curve should really begin at the second point and end at the 2nd to last point. That's how these curves are supposed to work. This is TO BE FIXED.
    
    private struct CurvePath {
        var points = [CGPoint]()

        // Source: https://en.wikipedia.org/wiki/Cubic_Hermite_spline#Interpolation_on_the_unit_interval_with_matched_derivatives_at_endpoints
        // https://www.youtube.com/watch?v=9_aJGUTePYo
        // https://lucidar.me/en/mathematics/catmull-rom-splines/
        // https://www.mvps.org/directx/articles/catmull/

        func getSplinePoint(u: CGFloat, closed: Bool) -> CGPoint{
            let p0, p1, p2, p3: Int
            
            // Curve tightness is not implemented yet. See Processing source code and Catmull-Rom info for more details. Tightness would be an additional way of controlling the curve.
            
            if (!closed) {
                p1 = Int(u) + 1
                p2 = p1 + 1
                p3 = p2 + 1
                p0 = p1 - 1
            } else {
                p1 = Int(u)
                p2 = (p1 + 1) % points.count
                p3 = (p2 + 1) % points.count
                p0 = p1 >= 1 ? p1 - 1 : points.count - 1
            }
            
            let u = u - floor(u)
            
            let uu = u * u
            let uuu = uu * u
            
            let q1 = -uuu + 2.0*uu - u
            let q2 = 3.0*uuu - 5.0*uu + 2.0
            let q3 = -3.0*uuu + 4.0*uu + u
            let q4 = uuu - uu

            let tx = 0.5 * (points[p0].x * q1 + points[p1].x * q2 + points[p2].x * q3 + points[p3].x * q4)
            let ty = 0.5 * (points[p0].y * q1 + points[p1].y * q2 + points[p2].y * q3 + points[p3].y * q4)
            
            return CGPoint(x: tx, y: ty)
        }
    }
}
/*
 * SwiftProcessing: Visibility
 *
 * */

public extension Sketch {
    
    /// Shows the sketch, i.e. turns the sketch's view's visibility on. This can be useful if you have a toggle or are handling multiple views.
    /// ```
    /// // Shows current sketch.
    /// show()
    /// ```
    
    func show(){
        self.isHidden = false
    }
    
    /// Hide's the sketch, i.e. turns the sketch's view's visibility off. This can be useful if you have a toggle or are handling multiple views.
    /// ```
    /// // Hide current sketch.
    /// hide()
    /// ```
    
    func hide(){
        self.isHidden = true
    }

}
/*
 * SwiftProcessing: Slider
 *
 *
 * */

import Foundation
import UIKit

// =======================================================================
// MARK: - Slider Class
// =======================================================================

public extension Sketch {
    
    class Slider : UIKitControlElement, LabelControl {
        
        
        /*
         * MARK: - LABEL PROTOCOL FUNCTIONS
         */
        
        func setText(_ text: String) {
            self.label.text(text)
        }
        
        func setFontSize<S>(_ size: S) where S : Numeric {
            self.label.fontSize(size)
        }
        
        func setTextAlignment(_ alignment: TextAlignment) {
            self.label.textAlignment(alignment)
        }
        
        func setTextColor<V1, V2, V3, A>(_ v1: V1, _ v2: V2, _ v3: V3, _ alpha: A) where V1 : Numeric, V2 : Numeric, V3 : Numeric, A : Numeric {
            let cg_v1, cg_v2, cg_v3, cg_alpha: CGFloat
            cg_v1 = v1.convert()
            cg_v2 = v2.convert()
            cg_v3 = v3.convert()
            cg_alpha = alpha.convert()
            
            self.label.textColor(cg_v1, cg_v2, cg_v3, cg_alpha)
        }
        
        func setTextColor<V1, V2, V3>(_ v1: V1, _ v2: V2, _ v3: V3) where V1 : Numeric, V2 : Numeric, V3 : Numeric {
            let cg_v1, cg_v2, cg_v3: CGFloat
            cg_v1 = v1.convert()
            cg_v2 = v2.convert()
            cg_v3 = v3.convert()
            
            self.label.textColor(cg_v1, cg_v2, cg_v3)
        }
        
        func setTextColor<G, A>(_ gray: G, _ alpha: A) where G : Numeric, A : Numeric {
            let cg_gray, cg_alpha: CGFloat
            cg_gray = gray.convert()
            cg_alpha = alpha.convert()
            
            self.label.textColor(cg_gray, cg_alpha)
        }
        
        func setTextColor<G>(_ gray: G) where G : Numeric {
            let cg_gray: CGFloat
            cg_gray = gray.convert()
            
            self.label.textColor(cg_gray)
        }
        
        
        /*
         * MARK: - CONSTANTS
         */
        
        let THUMB_SIZE: CGFloat = 32
        
        /*
         * MARK: - PROPERTIES
         */
        
        open var label: Label!
        
        // Added these overrides to update the label position.
        // Unsure whether there's a better way to do this.
        // For example, is possible to add the label to the slider's
        // view hierarchy to avoid this kind of setting and getting?
        
        override open var x: Double {
            get {
                return Double(self.element.layer.position.x)
            }
            set(x) {
                element.layer.position.x = CGFloat(x)
                self.label.position(CGFloat(x), element.layer.position.y + 20)
            }
        }
        
        override open var y: Double {
            get {
                return Double(self.element.layer.position.y)
            }
            set(y) {
                element.layer.position.y = CGFloat(y)
                self.label.position(element.layer.position.x, CGFloat(y) + 20)
            }
        }
        
        // Keeping here in case slider values ever want to be changed to be accessed by property instead of method. p5.js and Processing both use methods.
        
        /*
         open var value: Double {
         get {
         return Double((self.element as! UISlider).value)
         }
         set(value) {
         (self.element as! UISlider).value = Float(value)
         }
         }
         */
        
        /*
         * MARK: - INIT
         */
        
        init<MIN: Numeric, MAX: Numeric, V: Numeric>(_ view: Sketch, _ min: MIN, _ max: MAX, _ value: V?) {
            var f_min, f_max: Float
            f_min = min.convert()
            f_max = max.convert()
            
            let slider = UISlider()
            slider.minimumValue = f_min
            slider.maximumValue = f_max
            if let f_value: Float = value?.convert() {
                slider.value = f_value
            }
            
            super.init(view, slider)
            
            label = Label(view, self.x, self.y, width, height)
            
            // Set default size values.
            x = 50.0
            y = 17.0
            width = 100.0
            height = 34.0
        }
        
        /*
         * MARK: - METHODS
         */
        
        /// Returns the value of the slider.
        
        open func value() -> Double{
            return Double((self.element as! UISlider).value)
        }
        
        /// Sets the value of the slider.
        ///
        /// - Parameters:
        ///     - value: value to set the slider to.
        
        open func value<V: Numeric>(_ value: V){
            let f_value: Float = value.convert()
            
            (self.element as! UISlider).value = f_value
        }
        
        /// Sets the thumb color.
        ///
        /// - Parameters:
        ///     - v1: A red value from 0-255.
        ///     - v2: A green value from 0-255.
        ///     - v3: A blue value from 0-255.
        ///     - a: An optional alpha value from 0-255. Defaults to 255.
        
        open func thumbColor<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ a: A = A(255)){
            let cg_v1, cg_v2, cg_v3, cg_a: CGFloat
            cg_v1 = v1.convert()
            cg_v2 = v2.convert()
            cg_v3 = v3.convert()
            cg_a = a.convert()
            
            (self.element as! UISlider).thumbTintColor = UIColor(red: cg_v1 / 255, green: cg_v2 / 255, blue: cg_v3 / 255, alpha: cg_a / 255)
        }
        
        /// Sets the thumb image.
        ///
        /// - Parameters:
        ///     - image: A SwiftProcessing Image object.
        ///     - resize: A boolean value that either resizes or keeps the existing image size. Defaults to `true`.
        
        open func thumbImage(_ i: Image, _ resize: Bool = true){
            if resize && (i.width != Double(THUMB_SIZE) || i.height != Double(THUMB_SIZE)){
                i.resize(THUMB_SIZE, THUMB_SIZE)
            }
            (self.element as! UISlider).setThumbImage(i.currentFrame(), for: .normal)
        }
        
        /// Sets the color of the slider bar uniformly.
        ///
        /// - Parameters:
        ///     - v1: A red value from 0-255.
        ///     - v2: A green value from 0-255.
        ///     - v3: A blue value from 0-255.
        ///     - a: An optional alpha value from 0-255. Defaults to 255.
        
        open func color<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ a: A = A(255)){
            let cg_v1, cg_v2, cg_v3, cg_a: CGFloat
            cg_v1 = v1.convert()
            cg_v2 = v2.convert()
            cg_v3 = v3.convert()
            cg_a = a.convert()
            
            minColor(cg_v1, cg_v2, cg_v3, cg_a)
            maxColor(cg_v1, cg_v2, cg_v3, cg_a)
        }
        
        /// Sets the min side's color.
        ///
        /// - Parameters:
        ///     - v1: A red value from 0-255.
        ///     - v2: A green value from 0-255.
        ///     - v3: A blue value from 0-255.
        ///     - a: An optional alpha value from 0-255. Defaults to 255.
        
        open func minColor<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ a: A = A(255)){
            let cg_v1, cg_v2, cg_v3, cg_a: CGFloat
            cg_v1 = v1.convert()
            cg_v2 = v2.convert()
            cg_v3 = v3.convert()
            cg_a = a.convert()
            
            (self.element as! UISlider).minimumTrackTintColor = UIColor(red: cg_v1 / 255, green: cg_v2 / 255, blue: cg_v3 / 255, alpha: cg_a / 255)
        }
        
        /// Sets the max side's color.
        ///
        /// - Parameters:
        ///     - v1: A red value from 0-255.
        ///     - v2: A green value from 0-255.
        ///     - v3: A blue value from 0-255.
        ///     - a: An optional alpha value from 0-255. Defaults to 255.
        
        open func maxColor<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ a: A = A(255)){
            let cg_v1, cg_v2, cg_v3, cg_a: CGFloat
            cg_v1 = v1.convert()
            cg_v2 = v2.convert()
            cg_v3 = v3.convert()
            cg_a = a.convert()
            
            (self.element as! UISlider).maximumTrackTintColor = UIColor(red: cg_v1 / 255, green: cg_v2 / 255, blue: cg_v3 / 255, alpha: cg_a / 255)
        }
    }
    
    // =======================================================================
    // MARK: - SwiftProcessing Method to Programmatically Create a Slider
    // =======================================================================
    
    /// Creates a slider programmatically.
    ///
    /// - Parameters:
    ///     - min: The minimum setting of the slider.
    ///     - max: The maximum setting of the slider.
    
    func createSlider<MIN: Numeric, MAX: Numeric>(_ min: MIN, _ max: MAX) -> Slider {
        let s = Slider(self, min, max, Optional<Double>.none)
        viewRefs[s.self.id] = s.self
        return s
    }
    
    /// Creates a slider programmatically.
    ///
    /// - Parameters:
    ///     - min: The minimum setting of the slider.
    ///     - max: The maximum setting of the slider.
    ///     - value: The value the slider starts at. Defaults to `nil`
    
    func createSlider<MIN: Numeric, MAX: Numeric, V: Numeric>(_ min: MIN, _ max: MAX, _ value: V) -> Slider {
        let s = Slider(self, min, max, value)
        viewRefs[s.self.id] = s.self
        return s
    }
}
/*
 * SwiftProcessing: Stepper
 *
 *
 * */


import Foundation
import UIKit

public extension Sketch {
    class Stepper: UIKitControlElement {
        
        init(_ view: Sketch, _ min: Float, _ max: Float, _ value: Float?, _ step: Float?) {
            let stepper = UIStepper()
            stepper.minimumValue = Double(min)
            stepper.maximumValue = Double(max)
            if let v = value{
                stepper.value = Double(v)
            }
            if let s = step{
                stepper.stepValue = Double(s)
            }
            super.init(view, stepper)
        }
        
        open func value() -> Double{
            return (element as! UIStepper).value
        }
        
        open func value(_ v: Double){
            (element as! UIStepper).value = v
        }
        
        open func plusImage(_ i: Image){
            (self.element as! UIStepper).setIncrementImage(i.currentFrame(), for: .normal)
        }
        
        open func minusImage(_ i: Image){
            (self.element as! UIStepper).setDecrementImage(i.currentFrame(), for: .normal)
        }
    }
    
    func createStepper(_ min: Float, _ max: Float, _ value: Float? = nil, _ step: Float? = nil) -> Stepper{
        let s = Stepper(self, min, max, value, step)
        viewRefs[s.id] = s
        return s
    }
}
/*
 * SwiftProcessing: Switch
 *
 *
 * */

import Foundation
import UIKit

open class Switch: UIKitControlElement {
    init(_ view: Sketch) {
        let s = UISwitch()
        super.init(view, s)
    }
    
    open func on(){
        return (element as! UISwitch).setOn(true, animated: false)
    }
    
    open func off(){
        return (element as! UISwitch).setOn(false, animated: false)
    }
    
    open func isOn() -> Bool{
        return (element as! UISwitch).isOn
    }
}

extension Sketch{
    open func createSwitch() -> Switch{
        let s = Switch(self)
        viewRefs[s.id] = s
        return s
    }
}
/*
 * SwiftProcessing: TextField
 *
 * */

import Foundation
import UIKit

open class TextField: UIKitControlElement {
    
    init(_ view: Sketch, _ title: String) {
        let textField = UITextField()
        textField.placeholder = title
        textField.sizeToFit()
        super.init(view, textField)
        textField.addTarget(self, action: #selector(valueChangedHelper(_:)), for: .editingChanged)
    }
    
    open func textColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat){
        (self.element as? UITextField)?.textColor = UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a / 255)
    }
    
    open func textColor(_ r: Double, _ g: Double, _ b: Double, _ a: Double){
        (self.element as? UITextField)?.textColor = UIColor(red: CGFloat(r / 255), green: CGFloat(g / 255), blue: CGFloat(b / 255), alpha: CGFloat(a / 255))
    }
    
    open func textFont(_ name: String){
        (self.element as! UITextField).font = UIFont(name: name, size: (self.element as! UITextField).font!.pointSize)
    }
    
    open func textSize(_ size: CGFloat){
        (self.element as! UITextField).font = UIFont(name: (self.element as! UITextField).font!.fontName, size: size)
    }
    
    open func textSize(_ size: Double){
        (self.element as! UITextField).font = UIFont(name: (self.element as! UITextField).font!.fontName, size: CGFloat(size))
    }
    
    open func text() -> String {
        return (self.element as! UITextField).text ?? ""
    }
    
    open func text(_ newText: String) {
        (self.element as! UITextField).text = newText
    }
    
}

extension Sketch{
    open func createTextField(_ t: String = "") -> TextField{
        let t = TextField(self, t)
        viewRefs[t.id] = t
        return t
    }
}
import UIKit
import SceneKit

class TransitionSCNNode: SCNNode {

    var parentTransitionNodeTag: String = ""
    var tag: String = ""
    var availabletransitionNodes: [TransitionSCNNode] = []
    var currentShapes: [SCNNode] = []
    var availableShapeNodes: [String : [SCNNode]] = [:]
    var currentShapeNodes: [String : [SCNNode]] = [:]

    func hasNoShapeNodes() -> Bool {
        return self.currentShapes.count == 0
    }

    func hasAvailableTransitionNodes() -> Bool {
        return self.availabletransitionNodes.count > 0
    }

    func getNextAvailableTransitionNode() -> TransitionSCNNode {
        return self.availabletransitionNodes.popLast()!
    }

    func deleteTransitionNode() {
        for node in self.availabletransitionNodes {
            node.deleteTransitionNode()
        }
        self.availabletransitionNodes = []
        self.removeFromParentNode()
        self.removeShapeNodes()
    }

    func removeUnusedTransitionNodes() {
        for node in self.availabletransitionNodes {
            node.deleteTransitionNode()
        }

        availabletransitionNodes = []
    }

    func addTransitionNodes() {
        for node in self.childNodes {
            if node is TransitionSCNNode {
                self.availabletransitionNodes.append(node as! TransitionSCNNode)
            }
        }
    }

    func addShapeNode(_ node: SCNNode, _ tag: String) {
        self.addChildNode(node)
        self.currentShapes.append(node)
        if var arrayOfAvailableShapes = self.currentShapeNodes[tag] {
            arrayOfAvailableShapes.append(node)
        } else {
            self.currentShapeNodes[tag] = [node]
        }
    }

    func hasAvailableShape(_ tag: String) -> Bool{
        return self.availableShapeNodes[tag]!.count > 0
    }

    func getAvailableShape(_ tag: String) -> SCNNode? {
        if self.availableShapeNodes[tag] != nil && self.availableShapeNodes[tag]!.count > 0 {
            let usedNode = self.availableShapeNodes[tag]!.popLast()
            if var arrayOfAvailableShapes = self.currentShapeNodes[tag] {
                arrayOfAvailableShapes.append(usedNode!)
            } else {
                self.currentShapeNodes[tag] = [usedNode!]
            }
            self.currentShapes.append(usedNode!)
            return usedNode
        }
        return nil
    }

    func removeShapeNodes() {
        for (_, arrayOfShapes) in self.availableShapeNodes {
            for shapes in arrayOfShapes {
                shapes.cleanup()
                shapes.removeFromParentNode()
            }
        }
        self.availableShapeNodes = self.currentShapeNodes
        self.currentShapeNodes = [:]
        self.currentShapes = []
    }

    func addNewTransitionNode() -> TransitionSCNNode{

        if self.hasAvailableTransitionNodes() {

            let nextNode = self.getNextAvailableTransitionNode()

            nextNode.position = SCNVector3(0,0,0)
            nextNode.eulerAngles = SCNVector3(0,0,0)

            return nextNode

        } else {


            let newTransitionNode = TransitionSCNNode()

            self.addChildNode(newTransitionNode)

            newTransitionNode.position = SCNVector3(0,0,0)
            newTransitionNode.eulerAngles = SCNVector3(0,0,0)

            return newTransitionNode
        }
    }
}
/*
 * SwiftProcessing: UIApplication Extensions
 *
 *
 * */


import Foundation
import UIKit

extension UIApplication {
    
    // keyWindow replacement source: https://stackoverflow.com/questions/57134259/how-to-resolve-keywindow-was-deprecated-in-ios-13-0/57899013
    private class func topViewController(controller: UIViewController? =
                                            UIApplication
                                            .shared
                                            .connectedScenes
                                            .filter({$0.activationState == .foregroundActive})
                                            .map({$0 as? UIWindowScene})
                                            .compactMap({$0})
                                            .first?.windows
                                            .filter({$0.isKeyWindow}).first!
                                            .rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
    
    class var topViewController: UIViewController? { return topViewController() }
    
}
/*
 * SwiftProcessing: UIKitControlElement
 *
 * This SwiftProcessing class consolidates many operations of
 * UIKit view elements and simplifies access to them.
 *
 * */


import Foundation
import UIKit

open class UIKitControlElement : UIKitViewElement, UIGestureRecognizerDelegate{
    open var touchUpAction: () -> Void = {}
    open var touchDownAction: () -> Void = {}
    open var valueChangedAction: () -> Void = {}
    
    override init(_ view: Sketch, _ element: UIView) {
        super.init(view, element)
        
        (element as! UIControl).addTarget(self, action: #selector(valueChangedHelper(_:)), for: .valueChanged)
        #if targetEnvironment(macCatalyst)
        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(touchUpInsideHelper))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.delegate = self
        singleTapGesture.cancelsTouchesInView = false
        element.addGestureRecognizer(singleTapGesture)
        #else
        (element as! UIControl).addTarget(self, action: #selector(touchUpInsideHelper(_:)), for: .touchUpInside)
        #endif
    }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if (touch.view as? UIControl) != nil{
            return true
        }else{
            return false
        }
    }
    
    @objc func touchUpInsideHelper(_ sender: UIView) {
        touchUpAction()
    }
    
    @objc func valueChangedHelper(_ sender: UIView) {
        valueChangedAction()
    }
    
    
    open func touchEnded(_ touchUpClosure: @escaping () -> Void){
        self.touchUpAction = touchUpClosure
    }
    
    open func tapped(_ touchUpClosure: @escaping () -> Void){
        self.touchUpAction = touchUpClosure
    }
    
    open func valueChanged(_ valueChangedClosure: @escaping () -> Void){
        self.valueChangedAction = valueChangedClosure
    }
    
}
/*
 * SwiftProcessing: UIKitViewElement
 *
 * A simplified interface for modifying the layer and visibility
 * of a UIKit element for SwiftProcessing
 *
 * */

import Foundation
import UIKit

// =======================================================================
// MARK: - UIKitViewElement Class
// =======================================================================

open class UIKitViewElement: NSObject{
    
    /*
     * MARK: - PROPERTIES
     */
    
    open var id: String = UUID().uuidString
    
    open var x: Double {
         get {
            return Double(self.element.layer.position.x)
         }
         set(x) {
            element.layer.position.x = CGFloat(x)
         }
     }
    
    open var y: Double {
        get {
           return Double(self.element.layer.position.y)
        }
        set(y) {
           element.layer.position.y = CGFloat(y)
        }
    }
    
    open var width: Double  {
        get {
            return Double(self.element.layer.frame.width)
        }
        set(width) {
            let frame = element.layer.frame
            element.layer.frame = CGRect(x: frame.minX, y: frame.minY, width: CGFloat(width), height: frame.height)
        }
    }
    
    open var height: Double  {
        get {
           return Double(self.element.layer.position.x)
        }
        set(height) {
            let frame = element.layer.frame
            element.layer.frame = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: CGFloat(height))
        }
    }
    
    open var element: UIView!
    
    open var sketch: Sketch!
    
    /*
     * MARK: - INIT
     */
    
    init(_ view: Sketch, _ element: UIView) {
        self.element = element
        view.addSubview(element)
        element.layer.anchorPoint = CGPoint(x: 0,y: 0)
        sketch = view
    }
    
    /*
     * MARK: - METHODS
     */
    
    /// Sets the border color with red, green, blue, and, optionally, alpha values.
    ///
    /// - Parameters:
    ///     - gray: A gray value between 0–255.
    ///     - a: An optional alpha value from 0–255. Defaults to 255.
    

    open func borderColor<G: Numeric, A: Numeric>(_ gray: G, _ alpha: A = A(255)){
        var cg_gray, cg_a: CGFloat
        cg_gray = gray.convert()
        cg_a = alpha.convert()
        
        self.element.layer.borderColor = CGColor(srgbRed: cg_gray / 255, green: cg_gray / 255, blue: cg_gray / 255, alpha: cg_a / 255)
    }
    
    /// Sets the border color with red, green, blue, and, optionally, alpha values.
    ///
    /// - Parameters:
    ///     - v1: A red value from 0–255.
    ///     - v2: A green value from 0–255.
    ///     - v3: A blue value from 0–255.
    ///     - a: An optional alpha value from 0–255. Defaults to 255.
    

    open func borderColor<V1: Numeric, V2: Numeric, V3: Numeric, A: Numeric>(_ v1: V1, _ v2: V2, _ v3: V3, _ alpha: A = A(255)){
        var cg_v1, cg_v2, cg_v3, cg_a: CGFloat
        cg_v1 = v1.convert()
        cg_v2 = v2.convert()
        cg_v3 = v3.convert()
        cg_a = alpha.convert()
        
        self.element.layer.borderColor = CGColor(srgbRed: cg_v1 / 255, green: cg_v2 / 255, blue: cg_v3 / 255, alpha: cg_a / 255)
    }
    
    /// Sets the border width. Borders expand from the border on both sides.
    ///
    /// - Parameters:
    ///     - w: width of border.
    
    open func borderWidth<T: Numeric>(_ width: T){
        let cg_w:CGFloat = width.convert()
        self.element.layer.borderWidth = cg_w
    }
    
    /// Sets the background color with red, green, blue, and, optionally, alpha values.
    ///
    /// - Parameters:
    ///     - gray: A gray value between 0–255.
    ///     - a: An optional alpha value from 0–255. Defaults to 255.
    
    open func backgroundColor<G: Numeric, A: Numeric>(_ gray: G, _ alpha: A = A(255)){
        var cg_gray, cg_a: CGFloat
        cg_gray = gray.convert()
        cg_a = alpha.convert()
        
        self.element.layer.backgroundColor = CGColor(srgbRed: cg_gray / 255, green: cg_gray / 255, blue: cg_gray / 255, alpha: cg_a / 255)
    }
    
    /// Sets the background color with red, green, blue, and, optionally, alpha values.
    ///
    /// - Parameters:
    ///     - v1: A red value from 0-255.
    ///     - v2: A green value from 0-255.
    ///     - v3: A blue value from 0-255.
    ///     - a: An optional alpha value from 0-255. Defaults to 255.
    
    open func backgroundColor<T: Numeric>(_ v1: T, _ v2: T, _ v3: T, _ alpha: T = T(255)){
        var cg_v1, cg_v2, cg_v3, cg_a: CGFloat
        cg_v1 = v1.convert()
        cg_v2 = v2.convert()
        cg_v3 = v3.convert()
        cg_a = alpha.convert()
        
        self.element.layer.backgroundColor = CGColor(srgbRed: cg_v1 / 255, green: cg_v2 / 255, blue: cg_v3 / 255, alpha: cg_a / 255)
    }
   
    /// Sets the opacity.
    ///
    /// - Parameters:
    ///     - o: Opacity value from 0 to 1.0, 1.0 being completely opaque.
    
    open func opacity<O: Numeric>(_ opacity: O){
        let f_o: Float = opacity.convert()
        
        self.element.layer.opacity = f_o
    }
    
    /// Sets the corner radius, which affects the rounding of corners.
    ///
    /// - Parameters:
    ///     - r: A positive value will round the corners.
    
    open func cornerRadius<R: Numeric>(_ radius: R){
        let cg_r: CGFloat = radius.convert()
        
        self.element.layer.cornerRadius = cg_r
    }
    
    /// Sets the size of the element.
    ///
    /// - Parameters:
    ///     - w: Width of the element.
    ///     - h: Height of the element.

    open func size<W: Numeric, H: Numeric>(_ width: W, _ height: H){
        var cg_w, cg_h: CGFloat
        cg_w = width.convert()
        cg_h = height.convert()
        
        let s = sketch.scale
        element.frame = CGRect(x: element.frame.minX, y: element.frame.minY, width: cg_w * CGFloat(s.x), height: cg_h * CGFloat(s.y))
    }
    
    /// Sets the position of the element.
    ///
    /// - Parameters:
    ///     - x: Width of the element.
    ///     - y: Height of the element.
    
    open func position<W: Numeric, H: Numeric>(_ x: W, _ y: H){
        var cg_x, cg_y: CGFloat
        cg_x = x.convert()
        cg_y = y.convert()
        
        let t = sketch.translation
        element.layer.position = CGPoint(x: cg_x + CGFloat(t.x) , y: cg_y + CGFloat(t.y))
    }
    
    /// Hides the element.

    open func hide(){
        element.isHidden = true
    }
    
    /// Shows the element.
    
    open func show(){
        element.isHidden = false
    }
    
    /// Removes the element from the view. This can be seen as erasing.
    
    open func remove(){
        element.removeFromSuperview()
    }
}
