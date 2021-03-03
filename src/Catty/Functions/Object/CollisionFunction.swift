/**
 *  Copyright (C) 2010-2020 The Catrobat Team
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

import UIKit

@objc class CollisionFunction: NSObject, SingleParameterDoubleObjectFunction {

    @objc static var tag = "COLLISION_FORMULA"
    static var name = kUIFEObjectActorObjectTouch
    static var defaultValue = 0.0
    static var requiredResource = ResourceType.noResources
    static var isIdempotent = true
    static let position = 130

    var spriteObject_ : SpriteObject? = nil

    func tag() -> String {
        type(of: self).tag
    }

    func firstParameter() -> FunctionParameter {
        .string(defaultValue: "Green")
    }

    func value(parameter: AnyObject?, spriteObject: SpriteObject) -> Double {
        guard let value = parameter as? String else { return type(of: self).defaultValue }
        if !spriteObject.scene.objectExists(withName: value) {
            return 0.0
        }

        for obj in spriteObject.scene.objects() where obj.name == value && obj.spriteNode.catrobatTransparency == 100 {
            return 0.0
        }
        if spriteObject.spriteNode.catrobatTransparency == 100 {
            return 0.0
        }

        spriteObject_ = spriteObject

        if let unwrapped_allContactedBodies = spriteObject.spriteNode.physicsBody?.allContactedBodies() {
            if spriteObject.spriteNode.physicsBody?.allContactedBodies().count ?? 0 > 0 {
                return checkForContact(contactedBodies: unwrapped_allContactedBodies, parameter: value)
            } else {
                return 0.0
            }
        } else {
            return 0.0
        }
    }

    func formulaEditorSections() -> [FormulaEditorSection] {
        [.object(position: (type(of: self).position))]
    }

    func checkForContact(contactedBodies: [SKPhysicsBody], parameter: String) -> Double {
        for index in 0...(contactedBodies.count - 1) where contactedBodies[index].node?.name == parameter {
            guard let node = contactedBodies[index].node
            else { return 0.0 }
            let touchLocation = node.position
            let image = spriteObject_?.spriteNode.currentUIImageLook
            let imagesize = image?.size
            let imagePosition = spriteObject_?.spriteNode.position
            let xPos = touchLocation.x - (((spriteObject_?.spriteNode.position.x)!))
            let yPos = touchLocation.y - (((spriteObject_?.spriteNode.position.y)!))
            //NSLog("touch location: \(touchLocation) obj1_transp: \(            spriteObject_!.spriteNode.currentUIImageLook?.isTransparentPixel(at: CGPoint(x: xPos, y: yPos)))")
           // NSLog("transparen 0/0: \(image?.isTransparentPixel(at: CGPoint(x: 0,y: 0)))")
           // NSLog("transparen 144/144: \(image?.isTransparentPixel(at: CGPoint(x: 144,y: 144)))")
            return 1.0
        }
        return 0.0
    }

    @objc(xmlElementForFormula: withContext:)
    static func xmlElement(for formulaElement: FormulaElement, context: CBXMLSerializerContext) -> GDataXMLElement? {
        let objectName = formulaElement.leftChild?.value
        let formulaElement = GDataXMLElement(name: "formulaElement", context: context)
        let typeElement = GDataXMLElement(name: "type", stringValue: self.tag, context: context)
        let valueElement = GDataXMLElement(name: "value", stringValue: objectName, context: context)

        formulaElement?.addChild(typeElement)
        formulaElement?.addChild(valueElement)

        return formulaElement
    }

    @objc(parseFromElement: withContext:)
    static func parseFromElement(_ xmlElement: GDataXMLElement, context: CBXMLSerializerContext) -> FormulaElement? {
        let valueElement = xmlElement.child(withElementName: "value")?.stringValue()
        let formulaElement = FormulaElement(elementType: .FUNCTION, value: self.tag)
        let leftChild = FormulaElement(elementType: .STRING, value: valueElement)

        formulaElement?.leftChild = leftChild
        leftChild?.parent = formulaElement

        return formulaElement
    }
}
