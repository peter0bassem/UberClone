//
//  LeftSidePanelViewController.swift
//  UberClone
//
//  Created by Peter Bassem on 3/25/19.
//  Copyright © 2019 Peter Bassem. All rights reserved.
//

import UIKit
import Firebase

class LeftSidePanelViewController: UIViewController {
    
    @IBOutlet weak var pickupModeSwitch: UISwitch!
    @IBOutlet weak var pickupModeLabel: UILabel!
    @IBOutlet weak var userImageView: RoundImageView!
    @IBOutlet weak var userEmailLabel: UILabel!
    @IBOutlet weak var userAccountTypeLabel: UILabel!
    @IBOutlet weak var loginOutButton: UIButton!
    
    let currentUserId = Auth.auth().currentUser?.uid
    
    let appDelegate = AppDelegate.getAppDelegate()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pickupModeSwitch.isOn = false
        pickupModeSwitch.isHidden = true
        pickupModeLabel.isHidden = true
        
        observePassengersAndDrivers()
        
        if Auth.auth().currentUser == nil {
            userEmailLabel.text = nil
            userAccountTypeLabel.text = nil
            userImageView.isHidden = true
            loginOutButton.setTitle(MESSAGE_SIGN_UP_SIGN_IN, for: UIControl.State.normal)
        } else {
            userEmailLabel.text = Auth.auth().currentUser?.email
            userAccountTypeLabel.text = ""
            userImageView.isHidden = false
            loginOutButton.setTitle(MESSAGE_SIGN_OUT, for: UIControl.State.normal)
        }
    }
    
    func observePassengersAndDrivers() {
        DataService.instance.REF_USERS.observeSingleEvent(of: DataEventType.value) { (dataSnapshot) in
            if let dataSnapshot = dataSnapshot.children.allObjects as? [DataSnapshot] {
                for snap in dataSnapshot {
                    if snap.key == Auth.auth().currentUser?.uid {
                        self.userAccountTypeLabel.text = ACCOUNT_TYPE_PASSENGER
                    }
                }
            }
        }
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: DataEventType.value) { (dataSnapshot) in
            if let dataSnapshot = dataSnapshot.children.allObjects as? [DataSnapshot] {
                for snap in dataSnapshot {
                    if snap.key == Auth.auth().currentUser?.uid {
                        self.userAccountTypeLabel.text = ACCOUNT_TYPE_DRIVER
                        self.pickupModeSwitch.isHidden = false
                        
                        let switchStatus = snap.childSnapshot(forPath: ACCOUNT_PICKUP_MODE_ENABLED).value as! Bool
                        self.pickupModeSwitch.isOn = switchStatus
                        self.pickupModeLabel.isHidden = false
                        
                    }
                }
            }
        }
    }
    
    @IBAction func signUpLoginButtonWasPressed(_ sender: UIButton) {
        if Auth.auth().currentUser == nil {
            if let loginViewController = UIStoryboard(name: MAIN_STORYBOARD, bundle: Bundle.main).instantiateViewController(withIdentifier: VIEW_CONTROLLER_LOGIN) as? LoginViewController {
                present(loginViewController, animated: true, completion: nil)
            }
        } else {
            do {
                try Auth.auth().signOut()
                userEmailLabel.text = nil
                userAccountTypeLabel.text = nil
                userImageView.isHidden = true
                pickupModeLabel.text = nil
                pickupModeSwitch.isHidden = true
                loginOutButton.setTitle(MESSAGE_SIGN_UP_SIGN_IN, for: UIControl.State.normal)
            } catch(let error) {
                print(error.localizedDescription)
            }
        }
    }
    
    @IBAction func switchWasToggled(_ sender: UISwitch) {
        if sender.isOn {
            pickupModeLabel.text = MESSAGE_PICKUP_MODE_ENABLED
            appDelegate.menuContainerViewController.toggleLeftPanel()
            DataService.instance.REF_DRIVERS.child(currentUserId!).updateChildValues([ACCOUNT_PICKUP_MODE_ENABLED: true])
        } else {
            pickupModeLabel.text = MESSAGE_PICKUP_MODE_DISABLED
            appDelegate.menuContainerViewController.toggleLeftPanel()
            DataService.instance.REF_DRIVERS.child(currentUserId!).updateChildValues([ACCOUNT_PICKUP_MODE_ENABLED: false])
        }
    }
}
