//
//  ViewController.swift
//  PulseDetectorTest
//
//  Created by  Rezuan on 19/04/2019.
//  Copyright © 2019  Rezuan. All rights reserved.
//

import UIKit


class ViewController: UIViewController {

    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    @IBAction func startMonitor(_ sender: Any) {
    
            let controller = HeartRateKitController()
            controller.delegate = self
            present(controller, animated: true)
        
    }

    func presentAlert(_ message: String?) {
        
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default, handler: { action in
            self.dismiss(animated: true)
            
        })
        alert.addAction(ok)
        
        present(alert, animated: true)
    }

}

extension ViewController: HeartRateKitControllerDelegate {
    func heartRateKitController(_ controller: HeartRateKitController, didFinishWith result: HeartRateKitResult) {
        var messageToDisplay: String? = nil
        messageToDisplay = String(format: "BPM : %.01f", result.bpm)
        dismiss(animated: true) {
            self.presentAlert(messageToDisplay)
        }
    }
    
    func heartRateKitControllerDidCancel(_ controller: HeartRateKitController) {
        dismiss(animated: true)
    }}
