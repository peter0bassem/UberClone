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
                        DataService.instance.REF_USERS.child(user.key).updateChildValues([COORDINATE: [coordinate.latitude, coordinate.longitude]])
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
                        if driver.childSnapshot(forPath: ACCOUNT_PICKUP_MODE_ENABLED).value as? Bool == true {
                            DataService.instance.REF_DRIVERS.child(driver.key).updateChildValues([COORDINATE: [coordinate.latitude, coordinate.longitude]])
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
                    if trip.hasChild(USER_PASSENGER_KEY) && trip.hasChild(TRIP_IS_ACCEPTED) {
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
                        if !user.hasChild(USER_IS_DRIVER) {
                            if let userDictionary = user.value as? [String: AnyObject] {
                                let pickupArray = userDictionary[COORDINATE] as! NSArray
                                let destinationArray = userDictionary[TRIP_COORDINATE] as! NSArray
                                
                                DataService.instance.REF_TRIPS.child(user.key).updateChildValues([USER_PICKUP_COORDINATE: [pickupArray[0], pickupArray[1]], USER_DESTINATION_COORDINATE: [destinationArray[0], destinationArray[1]], USER_PASSENGER_KEY: user.key, TRIP_IS_ACCEPTED: false])
                            }
                        }
                    }
                }
            }
        }
    }
    
    func acceptTrip(withPassangerKey passangerKey: String, forDriverKey driverKey: String) {
        DataService.instance.REF_TRIPS.child(passangerKey).updateChildValues([DRIVER_KEY: driverKey, TRIP_IS_ACCEPTED: true])
        DataService.instance.REF_DRIVERS.child(driverKey).updateChildValues([DRIVER_IS_ON_TRIP: true])
    }
    
    func cancelTrip(withPassangerKey passangerKey: String, forDriverKey driverKey: String?) {
        DataService.instance.REF_TRIPS.child(passangerKey).removeValue()
        DataService.instance.REF_USERS.child(passangerKey).child(TRIP_COORDINATE).removeValue()
        if driverKey != nil {
            DataService.instance.REF_DRIVERS.child(driverKey!).updateChildValues([DRIVER_IS_ON_TRIP: false])
        }
    }
}
