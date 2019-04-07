//
//  ContainerViewController.swift
//  UberClone
//
//  Created by Peter Bassem on 3/25/19.
//  Copyright © 2019 Peter Bassem. All rights reserved.
//

import UIKit
import QuartzCore

enum SlideOutState {
    case collapsed
    case leftPanelExpanded
}

enum showWhichViewController {
    case homeViewController
}

var showViewController: showWhichViewController = showWhichViewController.homeViewController

class ContainerViewController: UIViewController {

    var homeViewController: HomeViewController!
    var leftViewController: LeftSidePanelViewController!
    var centerController: UIViewController!
    var currentState: SlideOutState = SlideOutState.collapsed {
        didSet {
            let shouldShowShadow = (currentState != SlideOutState.collapsed)
            shouldShowShadowForCenteredViewController(status: shouldShowShadow)
        }
    }
    
    var isHidden: Bool = false
    let centerPanelExpendedOffset: CGFloat = 120 //160
    
    var tap: UITapGestureRecognizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        initCenter(screen: showViewController)
    }
    
    func initCenter(screen: showWhichViewController) {
        var presentingController: UIViewController
        showViewController = screen
        if homeViewController == nil {
            homeViewController = UIStoryboard.homeViewController()
            homeViewController.delegate = self
        }
        presentingController = homeViewController
        if let con = centerController {
            con.view.removeFromSuperview()
            con.removeFromParent()
        }
        centerController = presentingController
        view.addSubview(centerController.view)
        addChild(centerController)
        centerController.didMove(toParent: self)
    }
    
    func addChildSidePanelViewController(_ sidePanelController: LeftSidePanelViewController) {
        view.insertSubview(sidePanelController.view, at: 0)
        addChild(sidePanelController)
        sidePanelController.didMove(toParent: self)
    }
    
    func animateCenterPanelXPosition(targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: UIView.AnimationOptions.curveEaseInOut, animations: {
            self.centerController.view.frame.origin.x = targetPosition
        }, completion: completion)
    }
    
    func animateStatusBar() {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: UIView.AnimationOptions.curveEaseInOut, animations: {
            self.setNeedsStatusBarAppearanceUpdate()
        })
    }
    
    func setupWhiteCoverView() {
        let whiteCoverView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        whiteCoverView.alpha = 0.0
        whiteCoverView.backgroundColor = UIColor.white
        whiteCoverView.tag = 25
        self.centerController.view.addSubview(whiteCoverView)
        whiteCoverView.fadeTo(alphaValue: 0.75, withDuration: 0.2)
        
        tap = UITapGestureRecognizer(target: self, action: #selector(animateLeftPanel(shoulExpand:)))
        tap.numberOfTapsRequired = 1
        self.centerController.view.addGestureRecognizer(tap)
    }
    
    func hideWhiteCoverView() {
        centerController.view.removeGestureRecognizer(tap)
        for subview in self.centerController.view.subviews {
            if subview.tag == 25 {
                UIView.animate(withDuration: 0.2, animations: {
                    subview.alpha = 0.0
                }) { (finished) in
                    if finished {
                        subview.removeFromSuperview()
                    }
                }
            }
        }
    }
    
    func shouldShowShadowForCenteredViewController(status: Bool) {
        if status {
            centerController.view.layer.shadowOpacity = 0.6
        } else {
            centerController.view.layer.shadowOpacity = 0.0
        }
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return UIStatusBarAnimation.slide
    }
    
    override var prefersStatusBarHidden: Bool {
        return isHidden
    }
}

extension ContainerViewController: CenterViewControllerDelegate {
    func toggleLeftPanel() {
        let notAlreadyExpanded = (currentState != SlideOutState.leftPanelExpanded)
        if notAlreadyExpanded {
            addLeftPanelViewController()
        }
        animateLeftPanel(shoulExpand: notAlreadyExpanded)
    }
    
    func addLeftPanelViewController() {
        if leftViewController == nil {
            leftViewController = UIStoryboard.leftViewController()
            addChildSidePanelViewController(leftViewController!)
        }
    }
    
    @objc func animateLeftPanel(shoulExpand: Bool) {
        if shoulExpand {
            isHidden = !isHidden
            animateStatusBar()
            setupWhiteCoverView()
            currentState = SlideOutState.leftPanelExpanded
            
            animateCenterPanelXPosition(targetPosition: centerController.view.frame.width - centerPanelExpendedOffset)
        } else {
            isHidden = !isHidden
            animateStatusBar()
            hideWhiteCoverView()
            
            animateCenterPanelXPosition(targetPosition: 0) { (finished) in
                if finished {
                    self.currentState = SlideOutState.collapsed
                    self.leftViewController = nil
                }
            }
        }
    }
}

private extension UIStoryboard {
    class func mainStoryboard() -> UIStoryboard {
        return UIStoryboard(name: "Main", bundle: Bundle.main)
    }
    
    class func leftViewController() -> LeftSidePanelViewController? {
        return mainStoryboard().instantiateViewController(withIdentifier: VIEW_CONTROLLER_LEFT_PANEL) as? LeftSidePanelViewController
    }
    
    class func homeViewController() -> HomeViewController? {
        return mainStoryboard().instantiateViewController(withIdentifier: VIEW_CONTROLLER_HOME) as? HomeViewController
    }
}
