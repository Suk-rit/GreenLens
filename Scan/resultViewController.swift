//
//  resultViewController.swift
//  Scan
//
//  Created by SUKRIT RAJ on 12/02/25.
//

import UIKit

class resultViewController: UIViewController {

    @IBOutlet weak var ResultImage: UIImageView!
    
    @IBOutlet weak var ResultLabel: UILabel!
    
    static var result:String = ""
    static var image:UIImage = UIImage(named: "plant.fill")!
    override func viewDidLoad() {
        super.viewDidLoad()
        ResultImage.image = resultViewController.image
        ResultLabel.text = resultViewController.result
        // Do any additional setup after loading the view.
    }
    

    

}
