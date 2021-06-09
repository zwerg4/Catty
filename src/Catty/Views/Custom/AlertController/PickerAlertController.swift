/**
 *  Copyright (C) 2010-2021 The Catrobat Team
 *  (http://developer.catrobat.org/credits)
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Affero General Public License as
 *  published by the Free Software Foundation, either version 3 of the
 *  License, or (at your option) any later version.
 *
 *  An additional term exception under section 7 of the GNU Affero
 *  General Public License, version 3, is available at
 *  (http://developer.catrobat.org/license_additional_term)
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU Affero General Public License for more details.
 *
 *  You should have received a copy of the GNU Affero General Public License
 *  along with this program.  If not, see http://www.gnu.org/licenses/.
 */

import Foundation
import UIKit

class PickerAlertController: BaseAlertController, AlertControllerBuilding, UIPickerViewDelegate, UIPickerViewDataSource {
    @objc(addCancelActionWithTitle:handler:)
    func addCancelAction(title: String, handler: (() -> Void)?) -> AlertControllerBuilding {
        alertController.addAction(UIAlertAction(title: title, style: .cancel) { _ in handler?() })
        return self
    }

    @objc(addDefaultActionWithTitle:handler:)
    func addDefaultAction(title: String, handler: (() -> Void)?) -> AlertControllerBuilding {
        alertController.addAction(UIAlertAction(title: title, style: .default) { _ in handler?() })
        return self
    }

    @objc(addDefaultActionWithTitle:handlerString:)
    func addDefaultAction(title: String, handler: ((String) -> Void)?) -> AlertControllerBuilding {
        let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
            guard let `self` = self else { return }

            let inputText = self.alertController.textFields?.first?.text ?? ""
            handler?(inputText)
        }
        alertController.addAction(action)
        return self
    }

    @objc(addDestructiveActionWithTitle:handler:)
    func addDestructiveAction(title: String, handler: (() -> Void)?) -> AlertControllerBuilding {
        alertController.addAction(UIAlertAction(title: title, style: .destructive) { _ in handler?() })
        return self
    }

    private let pickerList: [String]

    init(title: String?, message: [String]?) {
        if ((message?.isNotEmpty) != nil) {
            pickerList = message!
        } else {
            pickerList = []
        }
        super.init(title: title, message: "\n\n\n\n\n\n", style: .actionSheet)

        alertController.isModalInPopover = true

        let pickerFrame = UIPickerView(frame: CGRect(x: 5, y: 20, width: 250, height: 140))

        alertController.view.addSubview(pickerFrame)
        pickerFrame.dataSource = self
        pickerFrame.delegate = self

    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        pickerList.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        pickerList[row]
    }

}
