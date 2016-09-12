//
//  CodelessPlaygroundViewController.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 9/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit

class CodelessPlaygroundViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var button1: UIButton!
    @IBOutlet weak var button2: UIButton!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var switchControl: UISwitch!
    @IBOutlet weak var textField: UITextField!


    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") else {
            return UITableViewCell()
        }

        for subview in cell.subviews {
            if let label = subview as? UILabel {
                label.text = "Cell #\(indexPath.item)"
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        print("Tapped playground cell!")
    }

}
