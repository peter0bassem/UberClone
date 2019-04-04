//
//  UpdateService.swift
//  UberClone
//
//  Created by Peter Bassem on 3/27/19.
//  Copyright © 2019 Peter Bassem. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import Firebase

class UpdateService {
    static var instance = UpdateService()
    
    func updateUserLocation(withCoordinate coordinate: CLLocationCoordinate2D) {
        DataService.instance.REF_USERS.observeSingleEvent(of: DataEventType.value) { (dataSnapshot) in
            if let userDataSnapshot = dataSnapshot.children.allObjects as? [DataSnapshot] {
                for user in userDataSnapshot {
                    if user.key == Auth.auth().currentUser?.uid {
                        DataService.instance.REF_USERS.child(user.key).updateChildValues(["coordinate": [coordinate.latitude, coordinate.longitude]])
                    }
                }
            }
        }
    }
    
    func updateDriverLocation(withCoordinate coordinate: CLLocationCoordinate2D) {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: DataEventType.value) { (dataSnapshot) in
            if let driverDataSnapshot = dataSnapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverDataSnapshot {
                    if driver.key == Auth.auth().currentUser?.uid {
                        if driver.childSnapshot(forPath: "isPickupModeEnabled").value as? Bool == true {
                            DataService.instance.REF_DRIVERS.child(driver.key).updateChildValues(["coordinate": [coordinate.latitude, coordinate.longitude]])
                        }
                    }
                }
            }
        }
    }
    
    func observeTrips(handler: @escaping (_ coordinateDictinary: Dictionary<String, AnyObject>?) -> Void) {
        DataService.instance.REF_TRIPS.observe(DataEventType.value) { (dataSnapshot) in
            if let tripSnapshot = dataSnapshot.children.allObjects as? [DataSnapshot] {
                for trip in tripSnapshot {
                    if trip.hasChild("passangerKey") && trip.hasChild("tripIsAccepted") {
                        if let tripDictionary = trip.value as? [String: AnyObject] {
                            handler(tripDictionary)
                        }
                    }
                }
            }
        }
    }
    
    func updateTripsWithCoordinatesUponRequest() {
        DataService.instance.REF_USERS.observeSingleEvent(of: DataEventType.value) { (dataSnapshot) in
            if let userSnapshot = dataSnapshot.children.allObjects as? [DataSnapshot] {
                for user in userSnapshot {
                    if user.key == Auth.auth().currentUser?.uid {
                        if !user.hasChild("userIsDriver") {
                            if let userDictionary = user.value as? [String: AnyObject] {
                                let pickupArray = userDictionary["coordinate"] as! NSArray
                                let destinationArray = userDictionary["tripCoordinate"] as! NSArray
                                
                                DataService.instance.REF_TRIPS.child(user.key).updateChildValues(["pickupCoordinate": [pickupArray[0], pickupArray[1]], "destinationCoordinate": [destinationArray[0], destinationArray[1]], "passangerKey": user.key, "tripIsAccepted": false])
                            }
                        }
                    }
                }
            }
        }
    }
    
    func acceptTrip(withPassangerKey passangerKey: String, forDriverKey driverKey: String) {
        DataService.instance.REF_TRIPS.child(passangerKey).updateChildValues(["driverKey": driverKey, "tripIsAccepted": true])
        DataService.instance.REF_DRIVERS.child(driverKey).updateChildValues(["driverIsOnTrip": true])
    }
    
    func cancelTrip(withPassangerKey passangerKey: String, forDriverKey driverKey: String?) {
        DataService.instance.REF_TRIPS.child(passangerKey).removeValue()
        DataService.instance.REF_USERS.child(passangerKey).child("tripCoordinate").removeValue()
        if driverKey != nil {
            DataService.instance.REF_DRIVERS.child(driverKey!).updateChildValues(["driverIsOnTrip": false])
        }
    }
}
