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

@objc
class CBSpriteNode: SKSpriteNode {

    // MARK: - Properties
    @objc var spriteObject: SpriteObject
    @objc var currentLook: Look? {
        didSet {
            guard let stage = self.scene as? StageProtocol else { return }
            if !self.spriteObject.isBackground() { return }
            stage.notifyBackgroundChange()
        }
    }
    @objc var currentUIImageLook: UIImage?

    var rotationStyle: RotationStyle
    var rotationDegreeOffset = 90.0
    var penConfiguration: PenConfiguration
    var embroideryStream: EmbroideryStream

    @objc var filterDict = ["brightness": false, "color": false]
    @objc var ciBrightness = CGFloat(BrightnessSensor.defaultRawValue) // CoreImage specific brightness
    @objc var ciHueAdjust = CGFloat(ColorSensor.defaultRawValue) // CoreImage specific hue adjust

    // MARK: Custom getters and setters
    @objc func setPositionForCropping(_ position: CGPoint) {
        self.position = position
    }

    // MARK: - Initializers
    @objc required init(spriteObject: SpriteObject) {
        let color = UIColor.clear
        self.spriteObject = spriteObject
        self.rotationStyle = SpriteKitDefines.defaultRotationStyle
        self.embroideryStream = EmbroideryStream(projectWidth: self.spriteObject.scene.project?.header.screenWidth as? CGFloat,
                                                 projectHeight: self.spriteObject.scene.project?.header.screenHeight as? CGFloat)

        self.penConfiguration = PenConfiguration(projectWidth: self.spriteObject.scene.project?.header.screenWidth as? CGFloat,
                                                 projectHeight: self.spriteObject.scene.project?.header.screenHeight as? CGFloat)

        if let firstLook = spriteObject.lookList.firstObject as? Look,
            let filePathForLook = firstLook.path(for: spriteObject.scene),
            let image = UIImage(contentsOfFile: filePathForLook) {
            let texture = SKTexture(image: image)
            let textureSize = texture.size()
            super.init(texture: texture, color: color, size: textureSize)
            self.currentLook = firstLook
            self.currentLook = firstLook

           // setPhyicsBody(size: texture.size())
            setPhyicsBody(image: image)
        } else {
            super.init(texture: nil, color: color, size: CGSize.zero)
        }

        self.spriteObject.spriteNode = self
        self.name = spriteObject.name
        self.isUserInteractionEnabled = false

        setLook()
    }

    @objc required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func update(_ currentTime: TimeInterval) {
        self.drawPenLine()
        self.drawEmbroidery()

        for script in self.spriteObject.scriptList where ((script as? WhenConditionScript) != nil) {
            guard let stage = self.scene as? StageProtocol else { return }
            stage.notifyWhenCondition()
        }
    }

    // MARK: - Operations
    func returnFilterInstance(_ filterName: String, image: CIImage) -> CIFilter? {
        var filter: CIFilter?
        if filterName == "brightness" {
            filter = CIFilter(name: "CIColorControls", parameters: [kCIInputImageKey: image, "inputBrightness": self.ciBrightness])
        }
        if filterName == "color" {
            filter = CIFilter(name: "CIHueAdjust", parameters: [kCIInputImageKey: image, "inputAngle": self.ciHueAdjust])
        }
        return filter
    }

    @objc func executeFilter(_ inputImage: UIImage?) {
        guard let lookImage = inputImage?.cgImage else { preconditionFailure() }

        var ciImage = CIImage(cgImage: lookImage)
        let context = CIContext(options: nil)

        if Double(self.ciBrightness) != BrightnessSensor.defaultRawValue {
            self.filterDict["brightness"] = true
        } else {
            self.filterDict["brightness"] = false
        }

        if Double(self.ciHueAdjust) != ColorSensor.defaultRawValue {
            self.filterDict["color"] = true
        } else {
            self.filterDict["color"] = false
        }

        for (filterName, isActive) in filterDict {
            if isActive, let outputImage = returnFilterInstance(filterName, image: ciImage)?.outputImage {
                ciImage = outputImage
            }
        }

        let outputImage = ciImage
        // 2
        guard let cgimg = context.createCGImage(outputImage, from: outputImage.extent) else { preconditionFailure() }

        // 3
        let newImage = UIImage(cgImage: cgimg)
        self.currentUIImageLook = newImage
        let texture = SKTexture(image: newImage)
        let xScale = self.xScale
        let yScale = self.yScale

        let defaultSize = CGFloat(SizeSensor.defaultRawValue)
        self.xScale = defaultSize
        self.yScale = defaultSize
        self.size = texture.size()

        self.texture = texture
        if xScale != defaultSize {
            self.xScale = xScale
        }
        if yScale != defaultSize {
            self.yScale = yScale
        }

      //  setPhyicsBody(size: texture.size())
        setPhyicsBody(image: self.currentUIImageLook!)
    }

    @objc func nextLook() -> Look? {
        guard let currentLook = currentLook
            else { return nil }

        let currentIndex = spriteObject.lookList.index(of: currentLook)
        let nextIndex = (currentIndex + 1) % spriteObject.lookList.count
        return spriteObject.lookList[nextIndex] as? Look
    }

    @objc func previousLook() -> Look? {
        if currentLook == nil {
            return nil
        }

        var index = spriteObject.lookList.index(of: currentLook!)
        index -= 1
        index = index < 0 ? spriteObject.lookList.count - 1 : index
        return spriteObject.lookList[index] as? Look
    }

    @objc func getLookList() -> NSMutableArray? {
        spriteObject.lookList
    }

    @objc func changeLook(_ look: Look?) {
        guard let look = look,
            let filePathForLook = look.path(for: spriteObject.scene),
            let image = UIImage(contentsOfFile: filePathForLook)
            else { return }

        let texture = SKTexture(image: image)
        self.currentUIImageLook = image
        self.size = texture.size()
        let xScale = self.xScale
        let yScale = self.yScale
        let defaultSize = CGFloat(SizeSensor.defaultRawValue)
        self.xScale = defaultSize
        self.yScale = defaultSize
        self.size = texture.size()

        self.texture = texture
        self.currentLook = look

        if xScale != defaultSize {
            self.xScale = xScale
        }
        if yScale != defaultSize {
            self.yScale = yScale
        }
    }

    @objc func setLook() {
        // swiftlint:disable:next empty_count
        if spriteObject.lookList.count > 0, let look = spriteObject.lookList[0] as? Look {
            changeLook(look)
        }
    }

    // MARK: Events
    @objc func start(_ zPosition: CGFloat) {

        self.catrobatPosition = CBPosition(x: PositionXSensor.defaultRawValue, y: PositionYSensor.defaultRawValue)

        self.zRotation = CGFloat(RotationSensor.defaultRawValue)
        self.xScale = CGFloat(SizeSensor.defaultRawValue)
        self.yScale = CGFloat(SizeSensor.defaultRawValue)

        self.ciBrightness = CGFloat(BrightnessSensor.defaultRawValue)

        if self.spriteObject.isBackground() == true {
            self.zPosition = CGFloat(LayerSensor.defaultRawValue)
        } else {
            self.zPosition = zPosition
        }
    }

    @objc func touchedWithTouch(_ touch: UITouch, atPosition position: CGPoint) -> Bool {
        guard let playerStage = (scene as? Stage) else { return false }

        let scheduler = playerStage.scheduler

        guard let imageLook = currentUIImageLook, scheduler.running else { return false }

        guard let spriteName = spriteObject.name
            else { preconditionFailure("Invalid SpriteObject!") }
        let touchedPoint = touch.location(in: self)

        if imageLook.isTransparentPixel(atScenePoint: touchedPoint) {
            print("\(spriteName): \"I'm transparent at this point\"")
            return false
        }

        scheduler.startWhenContextsOfSpriteNodeWithName(spriteName)

        return true
    }

    @objc func isFlipped() -> Bool {
        if self.xScale < 0 {
            return true
        }
        return false
    }

    func setPhyicsBody(image: UIImage) {

        let entireImage = image.alpha(0.1)

        var physicsBodyList: [SKPhysicsBody] = []
        for y in 0...4 {
            for x in 0...4 {
                var imageNew = image.cropOut(coodinate: CGPoint(x: (image.size.width / 5.0) * CGFloat(x),
                                                                y: (image.size.height / 5) * CGFloat(y)),
                                             size: CGSize(width: image.size.width / 5,
                                                          height: image.size.height / 5))
                imageNew = imageNew.overlapImage(image: entireImage, coordinate: CGPoint(x: (image.size.width / 5.0) * CGFloat(x), y: (image.size.height / 5) * CGFloat(y)))
                let physicsbodyCrop = SKPhysicsBody.init(texture: SKTexture(image: imageNew), alphaThreshold: 0.2, size: imageNew.size)
                if isObjectNotNil(object: physicsbodyCrop) {
                    physicsBodyList.append(physicsbodyCrop)
                }
            }
        }

  /*      var leftImage = image.leftHalf
        var rightImage = image.rightHalf

        leftImage = leftImage?.overlapImage(image: entireImage, coordinate: CGPoint(x: 0, y: 0))
        rightImage = rightImage?.overlapImage(image: entireImage, coordinate: CGPoint(x: entireImage.size.width / 2, y: 0))

        let leftImageTexture = SKTexture(image: leftImage!)
        let rightImageTexture = SKTexture(image: rightImage!)

        let physicsBodyLeftImage = SKPhysicsBody.init(texture: SKTexture(image: leftImage!), alphaThreshold: 0.2, size: leftImage!.size)
        let physicsBodyRightImage = SKPhysicsBody.init(texture: SKTexture(image: rightImage!), alphaThreshold: 0.2, size: rightImage!.size)

        NSLog("setPhysicsbody: \(physicsBodyLeftImage)")
        NSLog("setPhysicsbody: \(physicsBodyRightImage)") */

        let physicsBodyJoint = SKPhysicsBody.init(bodies: physicsBodyList)

        NSLog("setPhysicsbodyJoint: \(physicsBodyJoint)")

        self.physicsBody = physicsBodyJoint
        self.physicsBody?.collisionBitMask = 0
        self.physicsBody?.categoryBitMask = 1
        self.physicsBody?.contactTestBitMask = 1
        self.physicsBody?.isDynamic = true
        self.physicsBody?.affectedByGravity = false
       // self.isUserInteractionEnabled = false

        /*
        NSLog("setPhysicsbody for: \(self.currentLook?.fileName)")
        if catrobatSize < 100.0 {
            let resized = CGSize(width: size.width * CGFloat(catrobatSize / 100), height: size.height * CGFloat(catrobatSize / 100))
            self.physicsBody = SKPhysicsBody.init(rectangleOf: resized)
        } else {
            self.physicsBody = SKPhysicsBody.init(rectangleOf: size)
        }
        self.physicsBody?.collisionBitMask = 0
        self.physicsBody?.categoryBitMask = 1
        self.physicsBody?.contactTestBitMask = 1
        self.physicsBody?.isDynamic = false
        self.physicsBody?.affectedByGravity = false
       // self.isUserInteractionEnabled = false
       // guard let stage = self.scene. as? Stage else { return }
        NSLog("after RETURN")
       // self.stage.addChild(self)
        self.scene?.addChild(self)
        self.scene?.physicsWorld.contactDelegate = self.scene as! SKPhysicsContactDelegate */
      //  let cropedImage = self.currentUIImageLook?.cropImageByAlpha()
/*
        self.physicsBody = SKPhysicsBody.init(texture: texture, alphaThreshold: 0.1, size: texture.size())

        self.physicsBody?.collisionBitMask = 0
        self.physicsBody?.categoryBitMask = 1
        self.physicsBody?.contactTestBitMask = 1
        //self.physicsBody?.isDynamic = false
        self.physicsBody?.affectedByGravity = false */

    }

    func isObjectNotNil(object: AnyObject!) -> Bool {
        if let _: AnyObject = object {
            return true
        }
        return false
    }

}

extension UIImage {
    func cropOut(coodinate: CGPoint, size: CGSize) -> UIImage {
        guard let image = cgImage?
            .cropping(to: CGRect(origin: coodinate,
                                 size: size))
        else { return self }
        return UIImage(cgImage: image, scale: 1, orientation: imageOrientation)
    }

    var topHalf: UIImage? {
        guard let image = cgImage?
            .cropping(to: CGRect(origin: .zero,
                                 size: CGSize(width: size.width, height: size.height / 2 )))
        else { return nil }
        return UIImage(cgImage: image, scale: 1, orientation: imageOrientation)
    }
    var bottomHalf: UIImage? {
        guard let image = cgImage?
            .cropping(to: CGRect(origin: CGPoint(x: 0,
                                                 y: size.height - (size.height / 2).rounded()),
                                 size: CGSize(width: size.width,
                                              height: size.height -
                                                      (size.height / 2).rounded())))
        else { return nil }
        return UIImage(cgImage: image)
    }
    var leftHalf: UIImage? {
        guard let image = cgImage?
            .cropping(to: CGRect(origin: .zero,
                                 size: CGSize(width: size.width / 2,
                                              height: size.height)))
        else { return nil }
        return UIImage(cgImage: image)
    }
    var rightHalf: UIImage? {
        guard let image = cgImage?
            .cropping(to: CGRect(origin: CGPoint(x: size.width - (size.width / 2).rounded(), y: 0),
                                 size: CGSize(width: size.width - (size.width / 2).rounded(),
                                              height: size.height)))
        else { return nil }
        return UIImage(cgImage: image)
    }

    func alpha(_ value: CGFloat) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: CGPoint.zero, blendMode: .normal, alpha: value)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }

    func overlapImage(image: UIImage, coordinate: CGPoint) -> UIImage {
        let newSize = CGSize(width: image.size.width, height: image.size.height)
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        self.draw(in: CGRect(x: coordinate.x, y: coordinate.y, width: self.size.width, height: self.size.height), blendMode: CGBlendMode.normal, alpha: 1.0)
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}
