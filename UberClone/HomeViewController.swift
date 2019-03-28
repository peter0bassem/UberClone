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

class HomeViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var destinationCircle: CircleView!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var centerMapButton: UIButton!
    @IBOutlet weak var actionButton: RoundedShadowButton!
    
    var delegate: CenterViewControllerDelegate?
    
    var manager: CLLocationManager?
//    var currentUserId = Auth.auth().currentUser?.uid
    var regionRadius: CLLocationDistance = 1000
    
    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!, iconInitialSize: CGSize(width: 80, height: 80), backgroundColor: UIColor.white)
    var tableView = UITableView()
    
    var matchingItems: [MKMapItem] = [MKMapItem]()
    var selectedItemPlaceMark: MKPlacemark? = nil
    
    var route: MKRoute!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        manager = CLLocationManager()
        manager?.delegate = self
        manager?.desiredAccuracy = kCLLocationAccuracyBest
        
        checkLocationAuthStatus()
        mapView.delegate = self
        destinationTextField.delegate = self
        centerMapOnUserLocation()
        DataService.instance.REF_DRIVERS.observe(DataEventType.value) { (dataSnapshot) in
            self.loadDriverAnnotationsFromFirebase()
        }
        
        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()
        revealingSplashView.heartAttack = true
    }
    
    func checkLocationAuthStatus() {
        if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways {
            manager?.startUpdatingLocation()
        } else {
            manager?.requestAlwaysAuthorization()
        }
    }
    
    func loadDriverAnnotationsFromFirebase() {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: DataEventType.value) { (dataSnapshot) in
            if let driverSnapshot = dataSnapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapshot {
                    if driver.hasChild("userIsDriver") {
                        if driver.hasChild("coordinate") {
                            if driver.childSnapshot(forPath: "isPickupModeEnabled").value as? Bool == true {
                                if let driverDictionary = driver.value as? [String: AnyObject] {
                                    let coordinateArray = driverDictionary["coordinate"] as! NSArray
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
    }
    
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
                print(error.localizedDescription)
            } else {
                if localSearchResponse?.mapItems.count == 0 {
                    print("no results")
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
    
    func searchMapKitResultsWithPolyine(forMapItem mapItem: MKMapItem) {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = mapItem
        request.transportType = MKDirectionsTransportType.automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { (directionsResponse, error) in
            guard let directionsResponse = directionsResponse else { print(error?.localizedDescription); return }
            self.route = directionsResponse.routes[0]
            self.mapView.addOverlay(self.route.polyline)
            self.shouldPresentLoadingView(false)
        }
    }
    
    @IBAction func menuButtonWasPressed(_ sender: UIButton) {
        delegate?.toggleLeftPanel() 
    }
    
    @IBAction func centerMapButtonWasPressed(_ sender: UIButton) {
        centerMapOnUserLocation()
        centerMapButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
    }
    
    @IBAction func actionButtonWasPressed(_ sender: RoundedShadowButton) {
        actionButton.animateButton(shouldLoad: true, withMessage: nil)
    }
}

extension HomeViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        UpdateService.instance.updateUserLocation(withCoordinate: userLocation.coordinate)
        UpdateService.instance.updateDriverLocation(withCoordinate: userLocation.coordinate)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            let identifier = "driver"
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: "driverAnnotation")
            return view
        } else if let annotation = annotation as? PassangerAnnotation {
            let identifier = "passanger"
            let view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: "currentLocationAnnotation")
            return view
        } else if let annotation = annotation as? MKPointAnnotation {
            let identifier = "destination"
            var annotatinView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotatinView == nil {
                annotatinView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotatinView?.annotation = annotation
            }
            annotatinView?.image = UIImage(named: "destinationAnnotation")
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
}

extension HomeViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == destinationTextField {
            tableView.frame = CGRect(x: 20, y: view.frame.height, width: view.frame.width - 40, height: view.frame.height - 170)
            tableView.layer.cornerRadius = 5.0
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "location_cell")
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
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: "location_cell")
        let mapItem = matchingItems[indexPath.row]
        cell.textLabel?.text = mapItem.name
        cell.detailTextLabel?.text = mapItem.placemark.title
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        shouldPresentLoadingView(true)
        let passangerCoordinate = manager?.location?.coordinate
        var currentUserId = Auth.auth().currentUser?.uid
        let passangerAnnotation = PassangerAnnotation(coordinate: passangerCoordinate!, key: currentUserId!)
        mapView.addAnnotation(passangerAnnotation)
        destinationTextField.text = tableView.cellForRow(at: indexPath)?.textLabel?.text
        let selectedMapItem = matchingItems[indexPath.row]
        DataService.instance.REF_USERS.child(currentUserId!).updateChildValues(["tripCoordinate": [selectedMapItem.placemark.coordinate.latitude, selectedMapItem.placemark.coordinate.longitude]])
        dropPinFor(placeMark: selectedMapItem.placemark)
        searchMapKitResultsWithPolyine(forMapItem: selectedMapItem)
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
