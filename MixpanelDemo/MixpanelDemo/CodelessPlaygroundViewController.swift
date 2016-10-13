//
//  CodelessPlaygroundViewController.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 9/12/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit
import Mixpanel

class CodelessPlaygroundViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var button1: UIButton!
    @IBOutlet weak var button2: UIButton!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var switchControl: UISwitch!

    @IBOutlet weak var label1: UILabel!
    @IBOutlet weak var label2: UILabel!
    @IBOutlet weak var label3: UILabel!
    @IBOutlet weak var label4: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self

        MixpanelTweaks.bind(MixpanelTweaks.floatTweak, binding: { self.label1.text = "\($0)" })
        MixpanelTweaks.bind(MixpanelTweaks.intTweak, binding: { self.label2.text = "\($0)" })
        MixpanelTweaks.bind(MixpanelTweaks.stringTweak, binding: { self.label3.text = $0 })

        if MixpanelTweaks.assign(MixpanelTweaks.boolTweak) {
            self.label4.text = "SUCCESS"
        }

    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") else {
            return UITableViewCell()
        }

        for subview in cell.contentView.subviews {
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
