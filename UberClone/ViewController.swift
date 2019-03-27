//
//  ViewController.swift
//  UberClone
//
//  Created by Peter Bassem on 3/21/19.
//  Copyright © 2019 Peter Bassem. All rights reserved.
//

import UIKit
import MapKit

class HomeViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var actionButton: RoundedShadowButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        mapView.delegate = self
    }
    
    @IBAction func actionButtonWasPressed(_ sender: RoundedShadowButton) {
        actionButton.animateButton(shouldLoad: true, withMessage: nil)
    }
}

extension HomeViewController: MKMapViewDelegate {
    
}
