//
//  Constants.swift
//  UberClone
//
//  Created by Peter Bassem on 4/7/19.
//  Copyright © 2019 Peter Bassem. All rights reserved.
//

import Foundation

// Account
let ACCOUNT_IS_DRIVER = "isDriver"
let ACCOUNT_PICKUP_MODE_ENABLED = "isPickupModeEnabled"
let ACCOUNT_TYPE_PASSENGER = "PASSENGER"
let ACCOUNT_TYPE_DRIVER = "DRIVER"
let ACCOUNT_PROVIDER = "provider"

// Location
let COORDINATE = "coordinate"

// Trip
let TRIP_IS_ACCEPTED = "tripIsAccepted"
let TRIP_IN_PROGRESS = "tripIsInProgress"
let TRIP_COORDINATE = "tripCoordinate"

// User
let USER_PICKUP_COORDINATE = "pickupCoordinate"
let USER_DESTINATION_COORDINATE = "destinationCoordinate"
let USER_PASSENGER_KEY = "passengerKey"
let USER_IS_DRIVER = "userIsDriver"

// Driver
let DRIVER_KEY = "driverKey"
let DRIVER_IS_ON_TRIP = "driverIsOnTrip"

// MAp Annotations
let ANNOTATION_DRIVER = "driverAnnotation"
let ANNOTATION_PICKUP = "currentLocationAnnotation"
let ANNOTATION_DESTINATION = "destinationAnnotation"
let ANNOTATION_PICKUP_POINT = "pickupPoint"

// Map Regions
let REGION_PICKUP = "pickup"
let REGION_DESTINATION = "destination"

// Storyboard
let MAIN_STORYBOARD = "Main"

// ViewControllers
let VIEW_CONTROLLER_LEFT_PANEL = "left_side_panel_view_controller"
let VIEW_CONTROLLER_HOME = "home_view_controller"
let VIEW_CONTROLLER_LOGIN = "login_view_controller"
let VIEW_CONTROLLER_PICKUP = "pickup_view_controller"

// TableView Cells
let TABLEVIEW_LOCATION_CELL = "location_cell"

// UI Messaging
let MESSAGE_SIGN_UP_SIGN_IN = "Sign Up / Login"
let MESSAGE_SIGN_OUT = "Sign Out"
let MESSAGE_PICKUP_MODE_ENABLED = "PICKUP MODE ENABLED"
let MESSAGE_PICKUP_MODE_DISABLED = "PICKUP MODE DISABLED"
let MESSAGE_REQUEST_RIDE = "REQUEST RIDE"
let MESSAGE_START_TRIP = "START TRIP"
let MESSAGE_END_TRIP = "END TRIP"
let MESSAGE_GET_DIRECTIONS = "GET DIRECTIONS"
let MESSAGE_CANCEL_TRIP = "CANCEL TRIP"
let MESSAGE_DRIVER_COMING = "DRIVER_COMING"
let MESSAGE_ON_TRIP = "ON TRIP"
let MESSAGE_PASSENGER_PICKUP = "Passenger Pickup Point"
let MESSAGE_PASSENGER_DESTINATION = "Passenger Destination"

// Error Messages
let ERROR_MESSAGE = "No matches found. Please try again."
let ERROR_MESSAGE_INVALID_EMAIL = "Sorry the email you've entered is not valid. Please try another email."
let ERROR_MESSAGE_EMAIL_ALREADY_IN_USE = "It appears that the email is already in use by another user. Please try again."
let ERROR_MESSAGE_WRONG_PASSWORD = "The password you tried is incorrect. Please try again."
let ERROR_MESSAGE_UNEXPECTED_ERROR = "There has been an expected error. Please try again."
