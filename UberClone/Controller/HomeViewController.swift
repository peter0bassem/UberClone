//
//  HomeViewController.swift
//  UberClone
//
//  Created by Peter Bassem on 3/21/19.
//  Copyright © 2019 Peter Bassem. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import RevealingSplashView
import Firebase

enum AnnotationType {
    case pickup
    case destination
    case driver
}

enum ButtonAction {
    case requestRide
    case getDirectionsToPassenger
    case getDirectionsToDestination
    case startTrip
    case endTrip
}

class HomeViewController: UIViewController, Alertable {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var destinationCircle: CircleView!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var centerMapButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var actionButton: RoundedShadowButton!
    
    var delegate: CenterViewControllerDelegate?
    
    var manager: CLLocationManager?
    var currentUserId: String?
    var regionRadius: CLLocationDistance = 1000
    
    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!, iconInitialSize: CGSize(width: 80, height: 80), backgroundColor: UIColor.white)
    var tableView = UITableView()
    
    var matchingItems: [MKMapItem] = [MKMapItem]()
    var selectedItemPlaceMark: MKPlacemark? = nil
    
    var actionForButton: ButtonAction = ButtonAction.requestRide
    
    var route: MKRoute!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        currentUserId = Auth.auth().currentUser?.uid
        
        manager = CLLocationManager()
        manager?.delegate = self
        manager?.desiredAccuracy = kCLLocationAccuracyBest
        
        checkLocationAuthStatus()
        mapView.delegate = self
        destinationTextField.delegate = self
        centerMapOnUserLocation()
        DataService.instance.REF_DRIVERS.observe(DataEventType.value) { (dataSnapshot) in
            self.loadDriverAnnotationsFromFirebase()
            
            DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                }
            })
        }
        
        cancelButton.alpha = 0.0
        
        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()
        
        UpdateService.instance.observeTrips { (tripDictionary) in
            if let tripDictionary = tripDictionary {
                let pickupCoordinate = tripDictionary[USER_PICKUP_COORDINATE] as! NSArray
                let tripKey = tripDictionary[USER_PASSENGER_KEY] as! String
                let acceptanceStatus = tripDictionary[TRIP_IS_ACCEPTED] as! Bool
                
                if !acceptanceStatus {
                    DataService.instance.driverIsAvailable(key: self.currentUserId!, handler: { (available) in
                        if let available = available {
                            if available {
                                if let pickupViewController = UIStoryboard(name: MAIN_STORYBOARD, bundle: Bundle.main).instantiateViewController(withIdentifier: VIEW_CONTROLLER_PICKUP) as? PickupViewController {
                                    pickupViewController.initData(coordinate: CLLocationCoordinate2D(latitude: pickupCoordinate[0] as! CLLocationDegrees, longitude: pickupCoordinate[1] as! CLLocationDegrees), passangerKey: tripKey)
                                        self.present(pickupViewController, animated: true, completion: nil)
                                }
                            }
                        }
                    })
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DataService.instance.userIsDriver(userKey: currentUserId!) { (status) in
            if status == true {
                self.buttonsForDriver(areHidden: true)
            }
        }
        
        DataService.instance.REF_TRIPS.observe(DataEventType.childRemoved) { (removedTripSnapshot) in
            let removedTripDictionary = removedTripSnapshot.value as? [String: AnyObject]
            if removedTripDictionary?[DRIVER_KEY] != nil {
                DataService.instance.REF_DRIVERS.child(removedTripDictionary?[DRIVER_KEY] as! String).updateChildValues([DRIVER_IS_ON_TRIP: false])
            }
            
            DataService.instance.userIsDriver(userKey: self.currentUserId!, handler: { (isDriver) in
                if isDriver == true {
                    // Remove overlays and annotations
                    // Hide request ride and cancel buttons
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                } else {
                    self.cancelButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                    self.actionButton.animateButton(shouldLoad: false, withMessage: MESSAGE_REQUEST_RIDE)
                    self.destinationTextField.isUserInteractionEnabled = true
                    self.destinationTextField.text = ""
                    
                    // Remove all maps annotations and overlays
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                    self.centerMapOnUserLocation()
                }
            })
        }
        
        DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                DataService.instance.REF_TRIPS.observeSingleEvent(of: DataEventType.value, with: { (tripSnapshot) in
                    if let tripSnapshot = tripSnapshot.children.allObjects as? [DataSnapshot] {
                        for trip in tripSnapshot {
                            if trip.childSnapshot(forPath: DRIVER_KEY).value as? String == self.currentUserId! {
                                let pickupCoordinateArray = trip.childSnapshot(forPath: USER_PICKUP_COORDINATE).value as! NSArray
                                let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                                let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                                
                                self.dropPinFor(placeMark: pickupPlacemark)
                                self.searchMapKitResultsWithPolyine(forOriginMapItem: nil, withDestinationMapItem: MKMapItem(placemark: pickupPlacemark))
                                
                                self.setCustomRegion(forAnnotationType: AnnotationType.pickup, withCoordinate: pickupCoordinate)
                                
                                self.actionForButton = ButtonAction.getDirectionsToPassenger
                                self.actionButton.setTitle(MESSAGE_GET_DIRECTIONS, for: UIControl.State.normal)
                                
                                // Fade in the action button for the driver
                                self.buttonsForDriver(areHidden: false)
                            }
                        }
                    }
                })
            }
        }
        
        connectUserAndDriverForTrip()
    }
    
    func checkLocationAuthStatus() {
        if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways {
            manager?.startUpdatingLocation()
        } else {
            manager?.requestAlwaysAuthorization()
        }
    }
    
    func buttonsForDriver(areHidden: Bool) {
        if areHidden {
            self.actionButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.actionButton.isHidden = true
            self.cancelButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.cancelButton.isHidden = true
            self.centerMapButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.centerMapButton.isHidden = true
        } else {
            self.actionButton.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.actionButton.isHidden = false
            self.cancelButton.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.cancelButton.isHidden = false
            self.centerMapButton.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.centerMapButton.isHidden = false
        }
    }
    
    func loadDriverAnnotationsFromFirebase() {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: DataEventType.value) { (dataSnapshot) in
            if let driverSnapshot = dataSnapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapshot {
                    if driver.hasChild(USER_IS_DRIVER) {
                        if driver.hasChild(COORDINATE) {
                            if driver.childSnapshot(forPath: ACCOUNT_PICKUP_MODE_ENABLED).value as? Bool == true {
                                if let driverDictionary = driver.value as? [String: AnyObject] {
                                    let coordinateArray = driverDictionary[COORDINATE] as! NSArray
                                    let driverCoordinate = CLLocationCoordinate2D(latitude: coordinateArray[0] as! CLLocationDegrees, longitude: coordinateArray[1] as! CLLocationDegrees)
                                    
                                    let annotation = DriverAnnotation(coordinate: driverCoordinate, withKey: driver.key)
                                    
                                    var driverIsVisible: Bool {
                                        return self.mapView.annotations.contains(where: { (annotation) -> Bool in
                                            if let driverAnnotation = annotation as? DriverAnnotation {
                                                if driverAnnotation.key == driver.key {
                                                    driverAnnotation.update(annotaionPosition: driverAnnotation, withCoordinate: driverCoordinate)
                                                    return true
                                                }
                                            }
                                            return false
                                        })
                                    }
                                    if !driverIsVisible {
                                        self.mapView.addAnnotation(annotation)
                                    }
                                }
                            } else {
                                for annotation in self.mapView.annotations {
                                    if annotation.isKind(of: DriverAnnotation.self) {
                                        if let annotaion = annotation as? DriverAnnotation {
                                            if annotaion.key == driver.key {
                                                self.mapView.removeAnnotation(annotation)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        revealingSplashView.heartAttack = true
    }
    
    func connectUserAndDriverForTrip() {
        DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                
                DataService.instance.REF_TRIPS.child(tripKey!).observeSingleEvent(of: DataEventType.value, with: { (tripSnapshot) in
                    let tripDictionary = tripSnapshot.value as? [String: AnyObject]
                    let driverId = tripDictionary?[DRIVER_KEY] as! String
                    
                    let pickupCoordinateArray = tripDictionary?[USER_PICKUP_COORDINATE] as! NSArray
                    let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                    let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                    let pickupMapItem = MKMapItem(placemark: pickupPlacemark)

                    DataService.instance.REF_DRIVERS.child(driverId).child(COORDINATE).observeSingleEvent(of: DataEventType.value, with: { (coordinateSnapshot) in
                        let coordinateSnapshot = coordinateSnapshot.value as! NSArray
                        let driverCoordinate = CLLocationCoordinate2D(latitude: coordinateSnapshot[0] as! CLLocationDegrees, longitude: coordinateSnapshot[1] as! CLLocationDegrees)
                        let driverPlacemark = MKPlacemark(coordinate: driverCoordinate)
                        let driverMapItem = MKMapItem(placemark: driverPlacemark)
                        
                        let passengerAnnotation = PassangerAnnotation(coordinate: pickupCoordinate, key: self.currentUserId!)
                        self.mapView.addAnnotation(passengerAnnotation)
                        
                        self.searchMapKitResultsWithPolyine(forOriginMapItem: driverMapItem, withDestinationMapItem: pickupMapItem)
                        self.actionButton.animateButton(shouldLoad: false, withMessage: MESSAGE_DRIVER_COMING)
                        self.actionButton.isUserInteractionEnabled = false
                    })
                    
                    DataService.instance.REF_TRIPS.child(tripKey!).observeSingleEvent(of: DataEventType.value, with: { (tripSnapshot) in
                        if tripDictionary?[TRIP_IN_PROGRESS] as? Bool == true {
                            self.removeOverlaysAndAnnotations(forDrivers: true, forPassengers: true)
                            
                            let destinationCoordinateArray = tripDictionary?[USER_DESTINATION_COORDINATE] as! NSArray
                            let destinationCoordimate = CLLocationCoordinate2D(latitude: destinationCoordinateArray[0] as! CLLocationDegrees, longitude: destinationCoordinateArray[1] as! CLLocationDegrees)
                            let destinationPlacemark = MKPlacemark(coordinate: destinationCoordimate)
                            
                            self.dropPinFor(placeMark: destinationPlacemark)
                            self.searchMapKitResultsWithPolyine(forOriginMapItem: pickupMapItem, withDestinationMapItem: MKMapItem(placemark: destinationPlacemark))
                            
                            self.actionButton.setTitle(MESSAGE_ON_TRIP, for: UIControl.State.normal)
                        }
                    })
                })
            }
        }
    }
    
//    func connectUserAndDriverForTrip() {
//        DataService.instance.userIsDriver(userKey: currentUserId!) { (status) in
//            if status == false { //user is passenger
//                DataService.instance.REF_TRIPS.child(self.currentUserId!).observe(DataEventType.value, with: { (tripSnapshot) in
//                    let tripDictionary = tripSnapshot.value as? [String: AnyObject]
//                    if tripDictionary?["tripIsAccepted"] as? Bool == true {
//                        self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
//
//                        let driverId = tripDictionary?["driverKey"] as! String
//                        let pickupCoordinateArray = tripDictionary?["pickupCoordinate"] as! NSArray
//                        let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
//                        let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
//                        let pickupMapItem = MKMapItem(placemark: pickupPlacemark)
//
//                        DataService.instance.REF_DRIVERS.observeSingleEvent(of: DataEventType.value, with: { (driverSnapshot) in
//                            if let driverSnapshot = driverSnapshot.children.allObjects as? [DataSnapshot] {
//                                for driver in driverSnapshot {
//                                    if driver.key == driverId {
//                                        let driverCoordinateArray = driver.childSnapshot(forPath: "coordinate").value as! NSArray
//                                        let driverCoordinate = CLLocationCoordinate2D(latitude: driverCoordinateArray[0] as! CLLocationDegrees, longitude: driverCoordinateArray[1] as! CLLocationDegrees)
//                                        let driverPlacemark = MKPlacemark(coordinate: driverCoordinate)
//                                        let driverMapItem = MKMapItem(placemark: driverPlacemark)
//
//                                        let passengerAnnotation = PassangerAnnotation(coordinate: pickupCoordinate, key: self.currentUserId!)
//                                        let driverAnnotation = DriverAnnotation(coordinate: driverCoordinate, withKey: driverId)
//                                        self.mapView.addAnnotation(passengerAnnotation)
//                                        self.searchMapKitResultsWithPolyine(forOriginMapItem: driverMapItem, withDestinationMapItem: pickupMapItem)
//                                        self.actionButton.animateButton(shouldLoad: false, withMessage: "DRIVER COMING")
//                                        self.actionButton.isUserInteractionEnabled = false
//                                    }
//                                }
//                            }
//                        })                    }
//                })
//            }
//        }
//    }
    
    func centerMapOnUserLocation() {
        let coordinateRegion = MKCoordinateRegion(center: mapView.userLocation.coordinate, latitudinalMeters: regionRadius * 2.0, longitudinalMeters: regionRadius * 2)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func animateTableView(shouldShow: Bool) {
        if shouldShow {
            UIView.animate(withDuration: 0.2) {
                self.tableView.frame = CGRect(x: 20, y: 170, width: self.view.frame.width - 40, height: self.view.frame.height - 170)
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.tableView.frame = CGRect(x: 20, y: self.view.frame.height, width: self.view.frame.width - 40, height: self.view.frame.height - 170)
            }) { (finished) in
                if finished {
                    for subview in self.view.subviews {
                        if subview.tag == 18 {
                            subview.removeFromSuperview()
                        }
                    }
                }
            }
        }
    }
    
    func performSearch() {
        matchingItems.removeAll()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = destinationTextField.text
        request.region = mapView.region
        
        let search = MKLocalSearch(request: request)
        search.start { (localSearchResponse, error) in
            if let error = error {
                self.showAlert(ERROR_MESSAGE_UNEXPECTED_ERROR)
            } else {
                if localSearchResponse?.mapItems.count == 0 {
                    self.showAlert(ERROR_MESSAGE)
                } else {
                    for mapItem in localSearchResponse!.mapItems {
                        self.matchingItems.append(mapItem)
                        self.tableView.reloadData()
                        self.shouldPresentLoadingView(false)
                    }
                }
            }
        }
    }
    
    func dropPinFor(placeMark: MKPlacemark) {
        selectedItemPlaceMark = placeMark
        
        for annotation in mapView.annotations {
            if annotation.isKind(of: MKPointAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = placeMark.coordinate
        mapView.addAnnotation(annotation)
    }
    
    func searchMapKitResultsWithPolyine(forOriginMapItem originMapItem: MKMapItem?, withDestinationMapItem destinationMapItem: MKMapItem) {
        let request = MKDirections.Request()
        if originMapItem == nil {
            request.source = MKMapItem.forCurrentLocation()
        } else {
            request.source = originMapItem
        }
        request.destination = destinationMapItem
        request.transportType = MKDirectionsTransportType.automobile
        
        self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)
        
        let directions = MKDirections(request: request)
        directions.calculate { (directionsResponse, error) in
            guard let directionsResponse = directionsResponse else { self.showAlert((error?.localizedDescription)!); return }
            self.route = directionsResponse.routes[0]
            self.mapView.addOverlay(self.route.polyline)
            
            self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)
            
            let delegate = AppDelegate.getAppDelegate()
            delegate.window?.rootViewController?.shouldPresentLoadingView(false)
        }
    }
    
    func zoom(toFitAnnotationsFromMapView mapview: MKMapView, forActiveTripWithDriver: Bool, withKey key: String?) {
        if mapView.annotations.count == 0 {
            return
        }
        var topLeftCoordinate = CLLocationCoordinate2D(latitude: -90, longitude: 180)
        var bottomRightCoordinate = CLLocationCoordinate2D(latitude: 90, longitude: -180)
        
        if forActiveTripWithDriver {
            for annotation in mapview.annotations {
                if let annotation = annotation as? DriverAnnotation {
                    if annotation.key == key {
                        topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                        topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                        bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                        bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
                    }
                } else {
                    topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                    topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                    bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                    bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
                }
            }
        }
        
        for annotation in mapview.annotations where !annotation.isKind(of: DriverAnnotation.self) {
            topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
            topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
            bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
            bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
        }
        var  region = MKCoordinateRegion(center: CLLocationCoordinate2DMake(topLeftCoordinate.latitude - (topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 0.5, topLeftCoordinate.longitude + (bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 0.5), span: MKCoordinateSpan(latitudeDelta: fabs(topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 2.0, longitudeDelta: fabs(bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 2.0))
        
        region = mapview.regionThatFits(region)
        mapview.setRegion(region, animated: true)
    }
    
    func removeOverlaysAndAnnotations(forDrivers: Bool?, forPassengers: Bool?) {
        for annotation in mapView.annotations {
            if let annotation = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(annotation)
            }
            if forPassengers! {
                if let annotation = annotation as? PassangerAnnotation {
                    mapView.removeAnnotation(annotation)
                }
            }
            if forDrivers! {
                if let annotation = annotation as? DriverAnnotation {
                    mapView.removeAnnotation(annotation)
                }
            }
        }
        
        for overlay in mapView.overlays {
            if overlay is MKPolyline {
                mapView.removeOverlay(overlay)
            }
        }
    }
    
    func setCustomRegion(forAnnotationType type: AnnotationType, withCoordinate coordinate: CLLocationCoordinate2D) {
        if type == AnnotationType.pickup {
            let pickupRegion = CLCircularRegion(center: coordinate, radius: 100, identifier: REGION_PICKUP)
            manager?.startMonitoring(for: pickupRegion)
        } else if type == AnnotationType.destination {
            let destinationRegion = CLCircularRegion(center: coordinate, radius: 100, identifier: REGION_DESTINATION)
            manager?.startMonitoring(for: destinationRegion)
        }
    }
    
    @IBAction func menuButtonWasPressed(_ sender: UIButton) {
        delegate?.toggleLeftPanel() 
    }
    
    @IBAction func centerMapButtonWasPressed(_ sender: UIButton) {
        DataService.instance.REF_USERS.observeSingleEvent(of: DataEventType.value) { (dataSnapshot) in
            if let userSnapshot = dataSnapshot.children.allObjects as? [DataSnapshot] {
                for user in userSnapshot {
                    if user.key == self.currentUserId! {
                        if user.hasChild(TRIP_COORDINATE) {
                            self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)
                            self.centerMapButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                        } else {
                            self.centerMapOnUserLocation()
                            self.centerMapButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                        }
                    }
                }
            }
        }
    }
    
    func buttonSelector(forAction action: ButtonAction) {
        switch action {
        case ButtonAction.requestRide:
            if destinationTextField.text != "" {
                UpdateService.instance.updateTripsWithCoordinatesUponRequest()
                actionButton.animateButton(shouldLoad: true, withMessage: nil)
                cancelButton.fadeTo(alphaValue: 1.0, withDuration: 0.2)
                
                self.view.endEditing(true)
                destinationTextField.isUserInteractionEnabled = false
            }
        case ButtonAction.getDirectionsToPassenger:
            DataService.instance.driverIsOnTrip(driverKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    DataService.instance.REF_TRIPS.child(tripKey!).observe(DataEventType.value, with: { (tripSnapshot) in
                        let tripDictionary = tripSnapshot.value as? [String: AnyObject]
                        let pickupCoordinateArray = tripDictionary?[USER_PICKUP_COORDINATE] as! NSArray
                        let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                        let pickupMapItem = MKMapItem(placemark: MKPlacemark(coordinate: pickupCoordinate))
                        pickupMapItem.name = MESSAGE_PASSENGER_PICKUP
                        pickupMapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    })
                }
            }
        case ButtonAction.startTrip:
            DataService.instance.driverIsOnTrip(driverKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: false)
                    
                    DataService.instance.REF_TRIPS.child(tripKey!).updateChildValues([TRIP_IN_PROGRESS: true])
                    
                    DataService.instance.REF_TRIPS.child(tripKey!).child(USER_DESTINATION_COORDINATE).observeSingleEvent(of: DataEventType.value, with: { (coordinateSnapshot) in
                        let destinationCoordinateArray = coordinateSnapshot.value as! NSArray
                        let destinationCoordinate = CLLocationCoordinate2D(latitude: destinationCoordinateArray[0] as! CLLocationDegrees,  longitude: destinationCoordinateArray[1] as! CLLocationDegrees)
                        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
                        
                        self.dropPinFor(placeMark: destinationPlacemark)
                        self.searchMapKitResultsWithPolyine(forOriginMapItem: nil, withDestinationMapItem: MKMapItem(placemark: destinationPlacemark))
                        self.setCustomRegion(forAnnotationType: AnnotationType.destination, withCoordinate: destinationCoordinate)
                        
                        self.actionForButton = ButtonAction.getDirectionsToDestination
                        self.actionButton.setTitle(MESSAGE_GET_DIRECTIONS, for: UIControl.State.normal)
                    })
                }
            }
        case ButtonAction.getDirectionsToDestination:
            DataService.instance.driverIsOnTrip(driverKey: currentUserId!) { (driverIsOnTrip, driverKey, tripKey) in
                if driverIsOnTrip == true {
                    DataService.instance.REF_TRIPS.child(tripKey!).child(USER_DESTINATION_COORDINATE).observe(DataEventType.value, with: { (snapshot) in
                        let destinationCoordinateArray = snapshot.value as! NSArray
                        let destinationCoordinate = CLLocationCoordinate2D(latitude: destinationCoordinateArray[0] as! CLLocationDegrees, longitude: destinationCoordinateArray[1] as! CLLocationDegrees)
                        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
                        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
                        
                        destinationMapItem.name = USER_DESTINATION_COORDINATE
                        destinationMapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    })
                }
            }
        case ButtonAction.endTrip:
            DataService.instance.driverIsOnTrip(driverKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    UpdateService.instance.cancelTrip(withPassangerKey: tripKey!, forDriverKey: driverKey!)
                    self.buttonsForDriver(areHidden: true)
                }
            }
        }
    }
    
    @IBAction func cancelButtonWasPressed(_ sender: UIButton) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                UpdateService.instance.cancelTrip(withPassangerKey: tripKey!, forDriverKey: driverKey!)
            }
        }
        
        DataService.instance.passengerIsOnTrip(passengerKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                UpdateService.instance.cancelTrip(withPassangerKey: self.currentUserId!, forDriverKey: driverKey)
            } else {
                UpdateService.instance.cancelTrip(withPassangerKey: self.currentUserId!, forDriverKey: driverKey)
            }
        }
        
        actionButton.isUserInteractionEnabled = true
    }
    
    @IBAction func actionButtonWasPressed(_ sender: RoundedShadowButton) {
        buttonSelector(forAction: actionForButton)
    }
}

extension HomeViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        UpdateService.instance.updateUserLocation(withCoordinate: userLocation.coordinate)
        UpdateService.instance.updateDriverLocation(withCoordinate: userLocation.coordinate)
        
        DataService.instance.userIsDriver(userKey: currentUserId!) { (isDriver) in
            if isDriver == true {
                DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                    if isOnTrip == true {
                        self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                    } else {
                        self.centerMapOnUserLocation()
                    }
                })
            } else {
                DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                    if isOnTrip == true {
                        self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                    } else {
                        self.centerMapOnUserLocation()
                    }
                })
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            let identifier = ACCOUNT_TYPE_DRIVER
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: ANNOTATION_DRIVER)
            return view
        } else if let annotation = annotation as? PassangerAnnotation {
            let identifier = ACCOUNT_TYPE_PASSENGER
            let view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: ANNOTATION_PICKUP)
            return view
        } else if let annotation = annotation as? MKPointAnnotation {
            let identifier = REGION_DESTINATION
            var annotatinView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotatinView == nil {
                annotatinView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotatinView?.annotation = annotation
            }
            annotatinView?.image = UIImage(named: ANNOTATION_DESTINATION)
            return annotatinView
        }
        return nil
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
         centerMapButton.fadeTo(alphaValue: 1.0, withDuration: 0.2)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let lineRender = MKPolylineRenderer(overlay: self.route.polyline)
        lineRender.strokeColor = UIColor(red: 216/255, green: 71/255, blue: 30/255, alpha: 0.75)
        lineRender.lineWidth = 3
        
        shouldPresentLoadingView(false)
        return lineRender
    }
}

extension HomeViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == CLAuthorizationStatus.authorizedAlways {
            mapView.showsUserLocation = true
            mapView.userTrackingMode = MKUserTrackingMode.follow
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!) { (isOnTrip, driverKey, passengerKey) in
            if isOnTrip == true {
                if region.identifier == REGION_PICKUP {
                    self.actionForButton = ButtonAction.startTrip
                    self.actionButton.setTitle(MESSAGE_START_TRIP, for: UIControl.State.normal)
                    print("driver entered region")
                } else if region.identifier == REGION_DESTINATION {
                    self.cancelButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                    self.cancelButton.isHidden = true
                    self.actionForButton = ButtonAction.endTrip
                    self.actionButton.setTitle(MESSAGE_END_TRIP, for: UIControl.State.normal)
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                if region.identifier == REGION_PICKUP {
                    // call an action on the button that will load driections to passenger pickup
                    self.actionButton.setTitle(MESSAGE_GET_DIRECTIONS, for: UIControl.State.normal)
                    print("driver exited region")
                } else if region.identifier == REGION_DESTINATION {
                    // call an action on the button that will load directions to destination
                    self.actionButton.setTitle(MESSAGE_GET_DIRECTIONS, for: UIControl.State.normal)
                }
            }
        }
    }
}

extension HomeViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == destinationTextField {
            tableView.frame = CGRect(x: 20, y: view.frame.height, width: view.frame.width - 40, height: view.frame.height - 170)
            tableView.layer.cornerRadius = 5.0
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: TABLEVIEW_LOCATION_CELL)
            tableView.delegate = self
            tableView.dataSource = self
            tableView.tag = 18
            tableView.rowHeight = 60
            tableView.tableFooterView = UIView()
            view.addSubview(tableView)
            animateTableView(shouldShow: true)
            
            UIView.animate(withDuration: 0.2) {
                self.destinationCircle.backgroundColor = UIColor.red
                self.destinationCircle.borderColor = UIColor.init(red: 199/255, green: 0/255, blue: 0/255, alpha: 1.0)
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == destinationTextField {
            performSearch()
            shouldPresentLoadingView(true)
            view.endEditing(true)
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == destinationTextField {
            if destinationTextField.text == "" {
                UIView.animate(withDuration: 0.2) {
                    self.destinationCircle.backgroundColor = UIColor.lightGray
                    self.destinationCircle.borderColor = UIColor.darkGray
                }
            }
        }
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        matchingItems = []
        tableView.reloadData()
        
        view.endEditing(true)
        animateTableView(shouldShow: false)
        DataService.instance.REF_USERS.child(currentUserId!).child(TRIP_COORDINATE).removeValue()
        mapView.removeOverlays(mapView.overlays)
        for annotation in mapView.annotations {
            if let annotaion = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(annotaion)
            } else if annotation.isKind(of: PassangerAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }
        
        centerMapOnUserLocation()
        return true
    }
}

extension HomeViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: TABLEVIEW_LOCATION_CELL)
        let mapItem = matchingItems[indexPath.row]
        cell.textLabel?.text = mapItem.name
        cell.detailTextLabel?.text = mapItem.placemark.title
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        shouldPresentLoadingView(true)
        let passangerCoordinate = manager?.location?.coordinate
        let passangerAnnotation = PassangerAnnotation(coordinate: passangerCoordinate!, key: currentUserId!)
        mapView.addAnnotation(passangerAnnotation)
        destinationTextField.text = tableView.cellForRow(at: indexPath)?.textLabel?.text
        let selectedMapItem = matchingItems[indexPath.row]
        DataService.instance.REF_USERS.child(currentUserId!).updateChildValues([TRIP_COORDINATE: [selectedMapItem.placemark.coordinate.latitude, selectedMapItem.placemark.coordinate.longitude]])
        dropPinFor(placeMark: selectedMapItem.placemark)
        searchMapKitResultsWithPolyine(forOriginMapItem: nil, withDestinationMapItem: selectedMapItem)
        animateTableView(shouldShow: false)
        print("selected")
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if destinationTextField.text == "" {
            animateTableView(shouldShow: false)
        }
    }
}
