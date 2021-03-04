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
            setPhyicsBody(texture: texture)
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
        setPhyicsBody(texture: texture)
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

    func setPhyicsBody(texture: SKTexture) {
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

}

//Swift 4 modifications for this gist: https://gist.github.com/krooked/9c4c81557fc85bc61e51c0b4f3301e6e

extension UIImage {
    func cropImageByAlpha() -> UIImage {
        let cgImage = self.cgImage
        let context = createARGBBitmapContextFromImage(inImage: cgImage!)
        let height = cgImage!.height
        let width = cgImage!.width

        var rect : CGRect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        context?.draw(cgImage!, in: rect)

        let pixelData = self.cgImage!.dataProvider!.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)

        var minX = width
        var minY = height
        var maxX: Int = 0
        var maxY: Int = 0

        //Filter through data and look for non-transparent pixels.
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (width * y + x) * 4 /* 4 for A, R, G, B */

                if data[Int(pixelIndex)] != 0 { //Alpha value is not zero pixel is not transparent.
                    if x < minX {
                        minX = x
                    }
                    if x > maxX {
                        maxX = x
                    }
                    if y < minY {
                        minY = y
                    }
                    if y > maxY {
                        maxY = y
                    }
                }
            }
        }
        rect = CGRect( x: CGFloat(minX), y: CGFloat(minY), width: CGFloat(maxX-minX), height: CGFloat(maxY-minY))
        let imageScale : CGFloat = self.scale
        let cgiImage = self.cgImage?.cropping(to: rect)
        return UIImage(cgImage: cgiImage!, scale: imageScale, orientation: self.imageOrientation)
    }

    private func createARGBBitmapContextFromImage(inImage: CGImage) -> CGContext? {

        let width = cgImage!.width
        let height = cgImage!.height

        let bitmapBytesPerRow = width * 4
        let bitmapByteCount = bitmapBytesPerRow * height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if colorSpace == nil {
            return nil
        }

        let bitmapData = malloc(bitmapByteCount)
        if bitmapData == nil {
            return nil
        }

        let context = CGContext (data: bitmapData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bitmapBytesPerRow,
                                 space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)

        return context
    }
}
