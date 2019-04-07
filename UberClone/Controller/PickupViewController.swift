//
//  PickupViewController.swift
//  UberClone
//
//  Created by Peter Bassem on 4/1/19.
//  Copyright © 2019 Peter Bassem. All rights reserved.
//

import UIKit
import MapKit
import Firebase

class PickupViewController: UIViewController {
    
    @IBOutlet weak var pickupMapView: RoundMapView!
    
    var pickupCoordinate: CLLocationCoordinate2D!
    var passangerKey: String!
    
    var regionRadius: CLLocationDistance = 2000
    var pin: MKPlacemark? = nil
    var locationPlacemark: MKPlacemark!
    
    var currentUserId: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        currentUserId = Auth.auth().currentUser?.uid
        pickupMapView.delegate = self
        
        locationPlacemark = MKPlacemark(coordinate: pickupCoordinate)
        dropPinFor(placemark: locationPlacemark)
        centerMapOnLocation(location: locationPlacemark.location!)
        
        DataService.instance.REF_TRIPS.child(passangerKey).observe(DataEventType.value) { (dataSnapshot) in
            if dataSnapshot.exists() {
                if dataSnapshot.childSnapshot(forPath: "tripIsAccepted").value as? Bool == true {
                    self.dismiss(animated: true, completion: nil)
                }
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func initData(coordinate: CLLocationCoordinate2D, passangerKey: String) {
        self.pickupCoordinate = coordinate
        self.passangerKey = passangerKey
    }
    
    @IBAction func cancelButtonWasPressed(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func acceptTripButtonWasPressed(_ sender: RoundedShadowButton) {
        UpdateService.instance.acceptTrip(withPassangerKey: passangerKey, forDriverKey: currentUserId!)
        presentingViewController?.shouldPresentLoadingView(true)
        
    }
}

extension PickupViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let identifier = ANNOTATION_PICKUP_POINT
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        } else {
            annotationView?.annotation = annotation
        }
        annotationView?.image = UIImage(named: ANNOTATION_DESTINATION)
        return annotationView
    }
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
        pickupMapView.setRegion(coordinateRegion, animated: true)
    }
    
    func dropPinFor(placemark: MKPlacemark) {
        pin = placemark
        
        for annotation in pickupMapView.annotations {
            pickupMapView.removeAnnotation(annotation)
        }
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        pickupMapView.addAnnotation(annotation)
    }
}
