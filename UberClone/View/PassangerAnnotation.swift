//
//  PassangerAnnotation.swift
//  UberClone
//
//  Created by Peter Bassem on 3/28/19.
//  Copyright © 2019 Peter Bassem. All rights reserved.
//

import Foundation
import MapKit

class PassangerAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var key: String
    
    init(coordinate: CLLocationCoordinate2D, key: String) {
        self.coordinate = coordinate
        self.key = key
        super.init()
    }
}
