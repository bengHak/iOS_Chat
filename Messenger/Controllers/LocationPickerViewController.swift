//
//  LocationPickerViewController.swift
//  Messenger
//
//  Created by byunghak on 2021/08/26.
//

import UIKit
import CoreLocation
import MapKit

final class LocationPickerViewController: UIViewController {
    
    public var completion: ((CLLocationCoordinate2D) -> Void)?
    
    private var coordinate: CLLocationCoordinate2D?
    
    private var isPickable = true
    
    private let map: MKMapView = {
        let map = MKMapView()
        return map
    }()
    
    init(coordinates: CLLocationCoordinate2D?) {
        self.coordinate = coordinates
        self.isPickable = false
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pick Location"
        view.backgroundColor = .systemBackground
        if isPickable {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send",
                                                                style: .done,
                                                                target: self,
                                                                action: #selector(sendButtonTapped))
            let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapMap))
            gesture.numberOfTouchesRequired = 1
            gesture.numberOfTapsRequired = 1
            map.addGestureRecognizer(gesture)
        } else {
            guard let coordinates = self.coordinate else {
                return
            }
            let pin = MKPointAnnotation()
            pin.coordinate = coordinates
            map.addAnnotation(pin)
        }
        map.isUserInteractionEnabled = true
        view.addSubview(map)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
    }
    
    @objc func didTapMap(_ gesture: UITapGestureRecognizer) {
        let locationInView = gesture.location(in: map)
        let coordinate = map.convert(locationInView, toCoordinateFrom: map)
        self.coordinate = coordinate
        
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        map.removeAnnotations(map.annotations)
        map.addAnnotation(pin)
    }
    
    @objc func sendButtonTapped() {
        guard let coordinate = coordinate else {
            return
        }
        navigationController?.popViewController(animated: true)
        completion?(coordinate)
    }
}
