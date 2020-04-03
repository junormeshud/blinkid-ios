//
//  ViewController.swift
//  BlinkID-sample-Swift
//
//  Created by Dino on 22/12/15.
//  Copyright © 2015 Dino. All rights reserved.
//

import UIKit
import Microblink

class ViewController: UIViewController {
    
    var blinkIdRecognizer : MBBlinkIdCombinedRecognizer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Valid until: 2020-06-26
        MBMicroblinkSDK.sharedInstance().setLicenseResource("blinkid-license", withExtension: "txt", inSubdirectory: "", for: Bundle.main)
    }

    @IBAction func didTapScan(_ sender: AnyObject) {
        self.startScanWithDefaultUI()
    }

    func startScanWithDefaultUI() {

        /** Create BlinkID recognizer */
        self.blinkIdRecognizer = MBBlinkIdCombinedRecognizer()
        self.blinkIdRecognizer?.returnFullDocumentImage = true;

        /** Create settings */
        let settings : MBBlinkIdOverlaySettings = MBBlinkIdOverlaySettings()

        /** Crate recognizer collection */
        let recognizerList = [self.blinkIdRecognizer!]
        let recognizerCollection : MBRecognizerCollection = MBRecognizerCollection(recognizers: recognizerList)

        /** Create your overlay view controller */
        let blinkIdOverlayViewController : MBBlinkIdOverlayViewController = MBBlinkIdOverlayViewController(settings: settings, recognizerCollection: recognizerCollection, delegate: self)

        /** Create recognizer view controller with wanted overlay view controller */
        let recognizerRunneViewController : UIViewController = MBViewControllerFactory.recognizerRunnerViewController(withOverlayViewController: blinkIdOverlayViewController)
        recognizerRunneViewController.modalPresentationStyle = .fullScreen

        /** Present the recognizer runner view controller. You can use other presentation methods as well (instead of presentViewController) */
        self.present(recognizerRunneViewController, animated: true, completion: nil)
    }
    
    @IBAction func didTapCustomUI(_ sender: Any) {

        /** Create BlinkID recognizer */
        self.blinkIdRecognizer = MBBlinkIdCombinedRecognizer()

        /** Crate recognizer collection */
        let recognizerList = [self.blinkIdRecognizer!]
        let recognizerCollection : MBRecognizerCollection = MBRecognizerCollection(recognizers: recognizerList)

        /** Create your overlay view controller */
        let customOverlayViewController : CustomOverlay = CustomOverlay.initFromStoryboardWith()

        /** This has to be called for custom controller */
        customOverlayViewController.reconfigureRecognizers(recognizerCollection)

        /** Create recognizer view controller with wanted overlay view controller */
        let recognizerRunneViewController : UIViewController = MBViewControllerFactory.recognizerRunnerViewController(withOverlayViewController: customOverlayViewController)
        recognizerRunneViewController.modalPresentationStyle = .fullScreen

        /** Present the recognizer runner view controller. You can use other presentation methods as well (instead of presentViewController) */
        self.present(recognizerRunneViewController, animated: true, completion: nil)
    }
}

extension ViewController: MBBlinkIdOverlayViewControllerDelegate {


    func blinkIdOverlayViewControllerDidFinishScanning(_ blinkIdOverlayViewController: MBBlinkIdOverlayViewController, state: MBRecognizerResultState) {

        // We use the guard to grab the result of the BlinkID Combined Recognizer
        guard let blinkIdCombinedRecognizerResult = self.blinkIdRecognizer?.result else {
            return
        }

        // We use another guard to check if the result state is valid. If not, we continue scanning
        guard blinkIdCombinedRecognizerResult.resultState == MBRecognizerResultState.valid else {
            return
        }

        /** We pause scanning to handle the UI after the successful scan */
        blinkIdOverlayViewController.recognizerRunnerViewController?.pauseScanning()
        
        if (!isDataMatching(blinkIdCombinedRecognizerResult)) {
            // We want to show the message that the result data is not matching and instruct the user to scan again
            showRepeatScanningAlert("Cannot match data from the front and the back", overlayViewController: blinkIdOverlayViewController)
        } else if (!isDataValid(blinkIdCombinedRecognizerResult)) {
            // We want to show the message that the result data cannot be validated and instruct the user to scan again
            showRepeatScanningAlert("Cannot validate the data", overlayViewController: blinkIdOverlayViewController)
        } else {
            showSuccessfulResultAlert(blinkIdCombinedRecognizerResult, overlayViewController: blinkIdOverlayViewController)
        }
    }

    func isDataMatching(_ result: MBBlinkIdCombinedRecognizerResult) -> Bool {

        // PIN contains dashes, so we need to remove them before comparing it with the data from the back
        let cleanedPIN = result.personalIdNumber?.replacingOccurrences(of: "-", with: "")

        // to check whether the data matches, we just compare Personal ID number with OPT1 in the MRZ
        return cleanedPIN == result.mrzResult.opt1
    }

    func isDataValid(_ result: MBBlinkIdCombinedRecognizerResult) -> Bool {

        // We need to have a full name in the result
        guard let fullName = result.fullName else {
            return false
        }

        // Full name can contain just these characters
        let nameCharset = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz- \n")

        // If we got characters that are not in the above defined set, we cannot validate the data
        return fullName.rangeOfCharacter(from: nameCharset.inverted) == nil
    }

    func showSuccessfulResultAlert(_ result: MBBlinkIdCombinedRecognizerResult, overlayViewController: MBBlinkIdOverlayViewController) {

        /** Needs to be called on main thread */
        DispatchQueue.main.async {
            let alertController: UIAlertController = UIAlertController.init(title: "Success", message: result.description, preferredStyle: UIAlertController.Style.alert)

            let okAction: UIAlertAction = UIAlertAction.init(title: "OK", style: UIAlertAction.Style.default,
                                                             handler: { (action) -> Void in
                                                                self.dismiss(animated: true, completion: nil)
            })
            alertController.addAction(okAction)

            overlayViewController.present(alertController, animated: true, completion: nil)
        }
    }

    func showRepeatScanningAlert(_ message: String, overlayViewController: MBBlinkIdOverlayViewController) {

        /** Needs to be called on main thread */
        DispatchQueue.main.async {

            let alertController: UIAlertController = UIAlertController.init(title: "Scan unsuccessful", message: message, preferredStyle: UIAlertController.Style.alert)

            let okAction: UIAlertAction = UIAlertAction.init(title: "Retry", style: UIAlertAction.Style.default,
                                                             handler: { (action) -> Void in
                                                                self.dismiss(animated: true) {
                                                                    self.startScanWithDefaultUI()
                                                                }
            })
            alertController.addAction(okAction)

            overlayViewController.present(alertController, animated: true, completion: nil)
        }
    }
    
    func blinkIdOverlayViewControllerDidTapClose(_ blinkIdOverlayViewController: MBBlinkIdOverlayViewController) {
        self.dismiss(animated: true, completion: nil)
    }
}



