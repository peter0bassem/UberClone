//
//  LoginViewController.swift
//  UberClone
//
//  Created by Peter Bassem on 3/26/19.
//  Copyright © 2019 Peter Bassem. All rights reserved.
//

import UIKit
import Firebase

class LoginViewController: UIViewController, UITextFieldDelegate, Alertable {
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var emailTextField: RoundedCornerTextField!
    @IBOutlet weak var passwordTextField: RoundedCornerTextField!
    @IBOutlet weak var authButton: RoundedShadowButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        emailTextField.delegate = self
        passwordTextField.delegate = self
        view.bindToKeyboard()
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap(sender:)))
        self.view.addGestureRecognizer(tap)
    }
    
    @objc func handleScreenTap(sender: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    @IBAction func cancelButtonWasPressed(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func authButtonWasPressed(_ sender: RoundedShadowButton) {
        if emailTextField.text != nil && passwordTextField.text != nil {
            authButton.animateButton(shouldLoad: true, withMessage: nil)
            self.view.endEditing(true)
            if let email = emailTextField.text, let password = passwordTextField.text {
                Auth.auth().signIn(withEmail: email, password: password) { (dataResult, error) in
                    if let error = error {
                        if let errorCode = AuthErrorCode(rawValue: error._code) {
                            switch errorCode {
                            case AuthErrorCode.emailAlreadyInUse:
                                print("Email is already in use, Please try again")
                            case AuthErrorCode.wrongPassword:
                                self.showAlert("Whooops! That was the wrong password!")
                            default:
                                self.showAlert("An unexpeted error occured. Please try again.")
                            }
                        }
                        Auth.auth().createUser(withEmail: email, password: password, completion: { (dataResult, error) in
                            if let error = error {
                                if let errorCode = AuthErrorCode(rawValue: error._code) {
                                    switch errorCode {
                                    case AuthErrorCode.invalidEmail:
                                        self.showAlert("That is an invalid email. Please try again.")
                                    default:
                                        self.showAlert("An unexpeted error occured. Please try again.")
                                    }
                                }
                            } else {
                                if let dataResult = dataResult {
                                    if self.segmentedControl.selectedSegmentIndex == 0 {
                                        let userData = ["provider": dataResult.user.providerID] as [String: Any]
                                        DataService.instance.createFirebaseDBUSer(uid: dataResult.user.uid, userData: userData, isDriver: false)
                                    } else {
                                        let userData = ["provider": dataResult.user.providerID, "userIsDriver": true, "isPickupModeEnabled": false, "driverIsOnTrip": false] as [String: Any]
                                        DataService.instance.createFirebaseDBUSer(uid: dataResult.user.uid, userData: userData, isDriver: true)
                                    }
                                }
                                self.dismiss(animated: true, completion: nil)
                            }
                        })
                    } else {
                        if let dataResult = dataResult {
                            if self.segmentedControl.selectedSegmentIndex == 0 {
                                let userData = ["provider": dataResult.user.providerID] as [String: Any]
                                DataService.instance.createFirebaseDBUSer(uid: dataResult.user.uid, userData: userData, isDriver: false)
                            } else {
                                let userData = ["provider": dataResult.user.providerID, "userIsDriver": true, "isPickupModeEnabled": false, "driverIsOnTrip": false] as [String: Any]
                                DataService.instance.createFirebaseDBUSer(uid: dataResult.user.uid, userData: userData, isDriver: true)
                            }
                        }
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }
}
