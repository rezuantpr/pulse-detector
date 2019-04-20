//
//  HeartRateKitCustomController.swift
//  PulseDetectorTest
//
//  Created by  Rezuan on 19/04/2019.
//  Copyright © 2019  Rezuan. All rights reserved.
//

import Foundation
import UIKit
@objc protocol HeartRateKitCustomControllerDelegate: AVCaptureVideoDataOutputSampleBufferDelegate {

    @objc optional func heartRateKitController(_ controller: HeartRateKitCustomController?, didFinishWith result: HeartRateKitResult?)
    @objc optional func heartRateKitControllerDidCancel(_ controller: HeartRateKitCustomController?)
}

class HeartRateKitCustomController: UIViewController {

    weak var delegate: HeartRateKitCustomControllerDelegate?

    let kShouldAbortAfterSeconds = 20
    let kTimeToDetermineBPMFinalResultInSeconds = 20
    private let HRKLabelFontSize: Int = 20
    private let HRKTopButtonsVerticalPadding: CGFloat = 8.0
    private let HRKLabelToLabelTopPadding: CGFloat = 8.0
    // AVFoundation
    private var session: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var frameOutput: AVCaptureVideoDataOutput?
    // Algorithm
    private var algorithm: HeartRateKitAlgorithm?
    private var algorithmStartTime: Date?
    private var bpmFinalResultFirstTimeDetected: Date?
    private var statusLabel = UILabel()
    private var bpmLabel  = UILabel()
    private var cancelButton = UIButton()
    private var imageView = UIImageView()
    private var result: HeartRateKitResult?

//    var prefersStatusBarHidden: Bool {
//        return true
//    }
//
    func getAlgorithmStartTime() -> Date? {
        if algorithmStartTime == nil {
            algorithmStartTime = Date()
        }
        return algorithmStartTime
    }

    func getBpmFinalResultFirstTimeDetected() -> Date? {
        if bpmFinalResultFirstTimeDetected == nil {
            bpmFinalResultFirstTimeDetected = Date()
        }
        return bpmFinalResultFirstTimeDetected
    }

    func getAlgorithm() -> HeartRateKitAlgorithm? {
        if algorithm == nil {
            algorithm = HeartRateKitAlgorithm()
            algorithm!.windowSize = 9
            algorithm!.filterWindowSize = 45
        }
        return algorithm
    }

    func getResult() -> HeartRateKitResult? {
        if result != nil {
            result = HeartRateKitResult.create()
        }
        return result
    }

    func startRunningSession() {
        let sessionQ = DispatchQueue(label: "start running session thread")

        sessionQ.async(execute: {
            // turn flash on
            if let videoDevice = self.videoDevice {
                if videoDevice.hasTorch && videoDevice.hasFlash {
                    do {
                        try videoDevice.lockForConfiguration()
                    } catch {
                    }
                    videoDevice.torchMode = .on

                    //  #if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
                    let set = AVCapturePhotoSettings()
                    set.flashMode = .on
                    //   #else
                    //  self.videoDevice.flashMode = .on
                    //  #endif

                    videoDevice.unlockForConfiguration()
                }
                if let session = self.session {
                    session.startRunning()
                }
            }

        })
    }

    func stopRunningSession() {
        let sessionQ = DispatchQueue(label: "stop running session thread")

        sessionQ.async(execute: {
            if let session = self.session {
                session.stopRunning()
                // turn flash off (maybe unnecessary because stopRunning do this)
                if let videoDevice = self.videoDevice {
                    if videoDevice.hasTorch && videoDevice.hasFlash {
                        do {
                            try videoDevice.lockForConfiguration()
                        } catch {
                        }
                        videoDevice.torchMode = .off

                        //   #if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
                        let set = AVCapturePhotoSettings()
                        set.flashMode = .off
                        // #else
                        //  self.videoDevice.flashMode = .off
                        //#endif

                        videoDevice.unlockForConfiguration()
                    }
                }

            }
        })
    }

    func resetAlgorithm() {
        algorithmStartTime = nil
        bpmFinalResultFirstTimeDetected = nil
        algorithm = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        resetAlgorithm()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        startRunningSession()

        UIApplication.shared.isIdleTimerDisabled = true // prevent the iphone from sleeping
        /////////////
        statusLabel.text = "Place the finger of the hand to the camera so that it covers the camera and the flash."
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        stopRunningSession()

    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        UIApplication.shared.isIdleTimerDisabled = false // enable sleeping

    }

    @objc func applicationWillEnterForeground() {
        if isViewLoaded && (view!.window != nil) {
            resetAlgorithm()
        }
    }

    @objc func applicationEnteredForeground() {
        if isViewLoaded && (view!.window != nil) {
            startRunningSession()
        }
    }

    @objc func applicationEnteredBackground() {
        if isViewLoaded && (view!.window != nil) {
            stopRunningSession()
        }
    }


    @objc func cancelButtonAction(_ sender: UIButton?) {
        delegate?.heartRateKitControllerDidCancel!(self)
    }

    func dismiss(with result: HeartRateKitResult?) {
        delegate?.heartRateKitController!(self, didFinishWith: result)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationEnteredForeground), name: UIApplication.didBecomeActiveNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationEnteredBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)


        // Create the session
        session = AVCaptureSession()

        // Configure the session to produce lower resolution video frames

        // Find a suitable AVCaptureDevice
        videoDevice = AVCaptureDevice.default(for: .video)

        // Create a device input with the device and add it to the session.
        // Create a VideoDataOutput and add it to the session
        frameOutput = AVCaptureVideoDataOutput()

        // Configure your output.
        // Specify the pixel format
        frameOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey : NSNumber(value: Int32(kCVPixelFormatType_32BGRA))] as? [String : Any]

        // shouldn't throw away frames
        frameOutput!.alwaysDiscardsLateVideoFrames = false

        let queue = DispatchQueue(label: "frameOutputQueue")
        frameOutput!.setSampleBufferDelegate(self, queue: queue)

        //session!.add(frameOutput!)

        view.backgroundColor = UIColor.black





        view.backgroundColor = UIColor.black

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        statusLabel.textAlignment = .center
        statusLabel.textColor = UIColor.green
        statusLabel.font = UIFont.systemFont(ofSize: CGFloat(HRKLabelFontSize))
        statusLabel.numberOfLines = 3
        view.addSubview(statusLabel)

        statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        statusLabel.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        statusLabel.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true




        bpmLabel = UILabel()
        bpmLabel.translatesAutoresizingMaskIntoConstraints = false
        bpmLabel.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        bpmLabel.textAlignment = .center
        bpmLabel.textColor = UIColor.green
        bpmLabel.font = UIFont.systemFont(ofSize: CGFloat(HRKLabelFontSize))
        bpmLabel.text = "BPM: 70.1"
        view.addSubview(bpmLabel)
        bpmLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 5).isActive = true
        bpmLabel.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        bpmLabel.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        cancelButton.tintColor = .green
        cancelButton.setImage(UIImage(named: "dismiss"), for: .normal)
        cancelButton.addTarget(self, action: #selector(self.cancelButtonAction(_:)), for: .touchUpInside)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)
        cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8).isActive = true
        cancelButton.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -8).isActive = true
        cancelButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        cancelButton.heightAnchor.constraint(equalToConstant: 40).isActive = true

        imageView.image = UIImage(named: "cardiogram")
        imageView.tintColor = .green
        imageView.frame.size = CGSize(width: 120, height: 120)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -200).isActive = true
        animate()

    }

    func animate() {
        UIView.animate(withDuration: 0.9, delay: 0, options: [.autoreverse, .repeat], animations: {
            self.imageView.frame.size = CGSize(width: 140, height: 140)
        })
    }

    func nukeAllAnimations() {
        self.view.subviews.forEach({$0.layer.removeAllAnimations()})
        self.view.layer.removeAllAnimations()
        self.view.layoutIfNeeded()
    }

}

extension HeartRateKitCustomController: HeartRateKitCustomControllerDelegate {
    func heartRateKitControllerDidCancel(_ controller: HeartRateKitController?) {

    }
    func heartRateKitController(_ controller: HeartRateKitController?, didFinishWith result: HeartRateKitResult?) {

    }
}

extension HeartRateKitCustomController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        // Create a UIImage from the sample buffer data
//        let image: UIImage? = self.image(from: sampleBuffer)
//
//        // dispatch all the algorithm functionality to another thread
//        let algorithmQueue = DispatchQueue(label: "algorithm thread")
//        algorithmQueue.async(execute: {
//
//            let dominantColor: UIColor? = image?.hrkAverageColorPrecise() // get the average color from the image
//            var red: CGFloat
//            var green: CGFloat
//            var blue: CGFloat
//            var alpha: CGFloat
////            dominantColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
////            blue = blue * 255.0
////            green = green * 255.0
////            red = red * 255.0
//
//            self.getAlgorithm()!.newFrameDetected(withAverageColor: dominantColor)
//
//            DispatchQueue.main.sync(execute: {
//
//                if self.getAlgorithm()!.shouldShowLatestResult {
//                    let timeTillResult: TimeInterval = Double(self.kTimeToDetermineBPMFinalResultInSeconds) - Date().timeIntervalSince(self.getBpmFinalResultFirstTimeDetected()!)
//
//                    if timeTillResult >= 0 {
//                        self.statusLabel.text = String(format: "Time till result: %.01fs", timeTillResult)
//                    }
//                }
//
//                if self.getAlgorithm()!.isFinalResultDetermined {
//                    if self.kTimeToDetermineBPMFinalResultInSeconds <= Int(Date().timeIntervalSince(self.getBpmFinalResultFirstTimeDetected()!)) {
//
//
//                        self.getResult()!.markBPM(self.getAlgorithm()!.bpmLatestResult)
//                        self.dismiss(with: self.getResult())
//                        self.algorithm = nil
//                    }
//                } else {
//                    self.bpmFinalResultFirstTimeDetected = nil
//                }
//
//
//                if red < 210 {
//                    //finger isn't on camera
//
//                    if self.kShouldAbortAfterSeconds > 0 {
//                        if Int(Date().timeIntervalSince(self.algorithmStartTime!)) > self.kShouldAbortAfterSeconds {
//                            if self.getAlgorithm()!.isFinalResultDetermined {
//
//                                self.getResult()!.markBPM(self.getAlgorithm()!.bpmLatestResult)
//                                self.dismiss(with: self.getResult()!)
//                                self.algorithm = nil
//                                self.algorithmStartTime = nil
//                                self.bpmFinalResultFirstTimeDetected = nil
//
//                                return // stop execution
//                            }
//                        }
//                    } else {
//                        if self.getAlgorithm()!.isFinalResultDetermined {
//
//                            self.getResult()!.markBPM(self.getAlgorithm()!.bpmLatestResult)
//                            self.dismiss(with: self.getResult()!)
//                            self.algorithm = nil
//                            self.algorithmStartTime = nil
//                            self.bpmFinalResultFirstTimeDetected = nil
//
//                            return // stop execution
//                        }
//                    }
//
//                    self.bpmLabel.text = ""
//                    self.algorithm = nil
//                    self.algorithmStartTime = nil
//                    self.bpmFinalResultFirstTimeDetected = nil
//                    return // stop execution
//                }
//
//                if self.algorithm!.shouldShowLatestResult {
//                    self.bpmLabel.text = String(format: "BPM : %.01f", self.getAlgorithm()!.bpmLatestResult)
//                } else {
//                    self.bpmLabel.text = "Waiting for BPM results..."
//                }
//
//            })
//        })
    }

    func image(from sampleBuffer: CMSampleBuffer?) -> UIImage? {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer!)

        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer!, [])

        // Get the number of bytes per row for the pixel buffer
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!)

        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)

        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imageBuffer!)
        let height = CVPixelBufferGetHeight(imageBuffer!)

        // Create a device-dependent RGB color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Create a bitmap graphics context with the sample buffer data
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: .zero)

        // Create a Quartz image from the pixel data in the bitmap graphics context
        let quartzImage = context!.makeImage()

        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer!, [])

        // Free up the context and color space
        //CGContextRelease(context!)

        // Create an image object from the Quartz image
        let image = UIImage(cgImage: quartzImage!)

        // Release the Quartz image
       // CGImageRelease(quartzImage!)

        return image
    }



}
