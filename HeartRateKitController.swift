//
//  HeartRateKitController.swift
//  PulseDetectorTest
//
//  Created by  Rezuan on 19/04/2019.
//  Copyright © 2019  Rezuan. All rights reserved.
//

import Foundation
import UIKit



class HeartRateKitController1: AVCaptureVideoDataOutputSampleBufferDelegate {
    let kShouldAbortAfterSeconds = 20
    let kTimeToDetermineBPMFinalResultInSeconds = 20
    private let HRKLabelFontSize: Int = 14
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
    private var statusLabel: UILabel?
    private var bpmLabel: UILabel?
    private var cancelButton: UIButton?
    private var result: HeartRateKitResult?
    
    var prefersStatusBarHidden: Bool {
        return true
    }
    
    func algorithmStartTime() -> Date? {
        if !algorithmStartTime {
            algorithmStartTime = Date()
        }
        return algorithmStartTime
    }
    
    func bpmFinalResultFirstTimeDetected() -> Date? {
        if !bpmFinalResultFirstTimeDetected {
            bpmFinalResultFirstTimeDetected = Date()
        }
        return bpmFinalResultFirstTimeDetected
    }
    
    func algorithm() -> HeartRateKitAlgorithm? {
        if !algorithm {
            algorithm = HeartRateKitAlgorithm()
            algorithm.windowSize = 9
            algorithm.filterWindowSize = 45
        }
        return algorithm
    }
    
    func result() -> HeartRateKitResult? {
        if !result {
            result = HeartRateKitResult.create()
        }
        return result
    }
    
    func startRunningSession() {
        let sessionQ = DispatchQueue(label: "start running session thread")
        
        sessionQ.async(execute: {
            // turn flash on
            if self.videoDevice.hasTorch && self.videoDevice.hasFlash {
                do {
                    try self.videoDevice.lockForConfiguration()
                } catch {
                }
                self.videoDevice.torchMode = .on
                
              //  #if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
                let set = AVCapturePhotoSettings()
                set.flashMode = .on
             //   #else
              //  self.videoDevice.flashMode = .on
              //  #endif
                
                self.videoDevice.unlockForConfiguration()
            }
            self.session.startRunning()
        })
    }
    
    func stopRunningSession() {
        let sessionQ = DispatchQueue(label: "stop running session thread")
        
        sessionQ.async(execute: {
            self.session.stopRunning()
            // turn flash off (maybe unnecessary because stopRunning do this)
            if self.videoDevice.hasTorch && self.videoDevice.hasFlash {
                do {
                    try self.videoDevice.lockForConfiguration()
                } catch {
                }
                self.videoDevice.torchMode = .off
                
             //   #if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
                let set = AVCapturePhotoSettings()
                set.flashMode = .off
               // #else
              //  self.videoDevice.flashMode = .off
                //#endif
                
                self.videoDevice.unlockForConfiguration()
            }
        })
    }
    
    func resetAlgorithm() {
        algorithmStartTime = nil
        bpmFinalResultFirstTimeDetected = nil
        algorithm = nil
    }
    
    func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        resetAlgorithm()
    }
    
    func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        startRunningSession()
        
        UIApplication.shared.isIdleTimerDisabled = true // prevent the iphone from sleeping
        
        statusLabel.text = "Please place your finger on the front camera"
    }
    
    func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        stopRunningSession()
        
    }
    
    func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = false // enable sleeping
        
    }
    
    func applicationWillEnterForeground() {
        if isViewLoaded && view.window {
            resetAlgorithm()
        }
    }
    
    func applicationEnteredForeground() {
        if isViewLoaded && view.window {
            startRunningSession()
        }
    }
    
    func applicationEnteredBackground() {
        if isViewLoaded && view.window {
            stopRunningSession()
        }
    }


    func cancelButtonAction(_ sender: UIButton?) {
        if delegate.responds(to: #selector(self.heartRateKitControllerDidCancel(_:))) {
            delegate.heartRateKitControllerDidCancel(self)
        }
    }
    
    func dismiss(with result: HeartRateKitResult?) {
        if delegate.responds(to: #selector(self.heartRateKitController(_:didFinishWithResult:))) {
            delegate.heartRateKitController(self, didFinishWith: result)
        }
    }

    func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationEnteredForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationEnteredBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        
        // Create the session
        session = AVCaptureSession()
        
        // Configure the session to produce lower resolution video frames
        session.sessionPreset = .cif352x288
        
        // Find a suitable AVCaptureDevice
        videoDevice = AVCaptureDevice.default(for: .video)
        
        // Create a device input with the device and add it to the session.
        var error: Error? = nil
        do {
            videoInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
        }
        
        if !videoInput {
            // Handling the error appropriately.
        }
        session.add(videoInput)
        
        // Create a VideoDataOutput and add it to the session
        frameOutput = AVCaptureVideoDataOutput()
        
        // Configure your output.
        // Specify the pixel format
        frameOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey : NSNumber(value: Int32(kCVPixelFormatType_32BGRA))] as? [String : Any]
        
        // shouldn't throw away frames
        frameOutput.alwaysDiscardsLateVideoFrames = false
        
        let queue = DispatchQueue(label: "frameOutputQueue")
        frameOutput.setSampleBufferDelegate(self, queue: queue)
        
        session.add(frameOutput)
        
        view.backgroundColor = UIColor.black
        
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        statusLabel.textAlignment = .left
        statusLabel.textColor = UIColor.white
        statusLabel.font = UIFont.systemFont(ofSize: CGFloat(HRKLabelFontSize))
        view.addSubview(statusLabel)
        
        view.hrkPinAttribute(NSLayoutConstraint.Attribute.centerX, to: NSLayoutConstraint.Attribute.centerX, ofItem: statusLabel)
        view.hrkPinAttribute(NSLayoutConstraint.Attribute.centerY, to: NSLayoutConstraint.Attribute.centerY, ofItem: statusLabel)

        
        bpmLabel = UILabel()
        bpmLabel.translatesAutoresizingMaskIntoConstraints = false
        bpmLabel.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        bpmLabel.textAlignment = .left
        bpmLabel.textColor = UIColor.white
        bpmLabel.font = UIFont.systemFont(ofSize: CGFloat(HRKLabelFontSize))
        view.addSubview(bpmLabel)
        view.hrkPinAttribute(NSLayoutConstraint.Attribute.centerX, to: NSLayoutConstraint.Attribute.centerX, ofItem: bpmLabel)
        bpmLabel.hrkPinAttribute(NSLayoutConstraint.Attribute.top, to: NSLayoutConstraint.Attribute.bottom, ofItem: statusLabel, withConstant: HRKLabelToLabelTopPadding)
        
        cancelButton = UIButton(type: .roundedRect)
        cancelButton.setTitleColor(UIColor.white, for: .normal)
        cancelButton.setTitle("Dismiss", for: .normal)
        
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        cancelButton.addTarget(self, action: #selector(self.cancelButtonAction(_:)), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        view.hrkPinAttribute(NSLayoutConstraint.Attribute.top, to: NSLayoutConstraint.Attribute.top, ofItem: cancelButton, withConstant: -HRKTopButtonsVerticalPadding)
        view.hrkPinAttribute(NSLayoutConstraint.Attribute.left, to: NSLayoutConstraint.Attribute.left, ofItem: cancelButton, withConstant: -HRKTopButtonsVerticalPadding)
        
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Create a UIImage from the sample buffer data
        let image: UIImage? = self.image(from: sampleBuffer)
        
        // dispatch all the algorithm functionality to another thread
        let algorithmQueue = DispatchQueue(label: "algorithm thread")
        algorithmQueue.async(execute: {
            
            let dominantColor: UIColor? = image?.hrkAverageColorPrecise() // get the average color from the image
            var red: CGFloat
            var green: CGFloat
            var blue: CGFloat
            var alpha: CGFloat
            dominantColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            blue = blue * 255.0
            green = green * 255.0
            red = red * 255.0
            
            self.algorithm.newFrameDetected(withAverageColor: dominantColor)
            
            DispatchQueue.main.sync(execute: {
                
                if self.algorithm.shouldShowLatestResult {
                    let timeTillResult: TimeInterval = kTimeToDetermineBPMFinalResultInSeconds - Date().timeIntervalSince(self.bpmFinalResultFirstTimeDetected)
                    
                    if timeTillResult >= 0 {
                        self.statusLabel.text = String(format: "Time till result: %.01fs", timeTillResult)
                    }
                }
                
                if self.algorithm.isFinalResultDetermined {
                    if kTimeToDetermineBPMFinalResultInSeconds <= Date().timeIntervalSince(self.bpmFinalResultFirstTimeDetected) {
                        
                        
                        self.result.markBPM(self.algorithm.bpmLatestResult)
                        self.dismiss(withResult: self.result)
                        self.algorithm = nil
                    }
                } else {
                    self.bpmFinalResultFirstTimeDetected = nil
                }
                
                if red < 210 {
                    //finger isn't on camera
                    
                    if kShouldAbortAfterSeconds > 0 {
                        if Date().timeIntervalSince(self.algorithmStartTime) > kShouldAbortAfterSeconds {
                            if self.algorithm.isFinalResultDetermined {
                                
                                self.result.markBPM(self.algorithm.bpmLatestResult)
                                self.dismiss(withResult: self.result)
                                self.algorithm = nil
                                self.algorithmStartTime = nil
                                self.bpmFinalResultFirstTimeDetected = nil
                                
                                return // stop execution
                            }
                        }
                    } else {
                        if self.algorithm.isFinalResultDetermined {
                            
                            self.result.markBPM(self.algorithm.bpmLatestResult)
                            self.dismiss(withResult: self.result)
                            self.algorithm = nil
                            self.algorithmStartTime = nil
                            self.bpmFinalResultFirstTimeDetected = nil
                            
                            return // stop execution
                        }
                    }
                    self.bpmLabel.text = ""
                    self.algorithm = nil
                    self.algorithmStartTime = nil
                    self.bpmFinalResultFirstTimeDetected = nil
                    return // stop execution
                }
                
                if self.algorithm.shouldShowLatestResult {
                    self.bpmLabel.text = String(format: "BPM : %.01f", self.algorithm.bpmLatestResult)
                } else {
                    self.bpmLabel.text = "Waiting for BPM results..."
                }
                
            })
        })
    }
    
    //  Converted to Swift 5 by Swiftify v5.0.25037 - https://objectivec2swift.com/
    // Create a UIImage from sample buffer data
    
    func image(from sampleBuffer: CMSampleBuffer?) -> UIImage? {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, 0)
        
        // Get the number of bytes per row for the pixel buffer
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        
        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        
        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        // Create a device-dependent RGB color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create a bitmap graphics context with the sample buffer data
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: .premultipliedLast)
        
        // Create a Quartz image from the pixel data in the bitmap graphics context
        let quartzImage = context.makeImage()
        
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0)
        
        // Free up the context and color space
        CGContextRelease(context)
        
        // Create an image object from the Quartz image
        let image = UIImage(cgImage: quartzImage)
        
        // Release the Quartz image
        CGImageRelease(quartzImage)
        
        return image
    }

}
