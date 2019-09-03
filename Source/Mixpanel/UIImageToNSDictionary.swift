//
//  UIImageToDictionary.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

@objc(UIImageToNSDictionary) class UIImageToNSDictionary: ValueTransformer {

    static var imageCache = [String: UIImage]()

    override class func transformedValueClass() -> AnyClass {
        return NSDictionary.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let image = value as? UIImage else {
            return NSDictionary()
        }
        let sizeValue = NSValue(cgSize: image.size)
        guard let sizeTransformer = ValueTransformer(forName:
            NSValueTransformerName(rawValue: NSStringFromClass(CGSizeToNSDictionary.self))),
            let size = sizeTransformer.transformedValue(sizeValue) as? NSDictionary else {
                return NSDictionary()
        }
        let capInsetsValue = NSValue(uiEdgeInsets: image.capInsets)
        guard let insetsTransformer = ValueTransformer(forName:
            NSValueTransformerName(rawValue: NSStringFromClass(UIEdgeInsetsToNSDictionary.self))),
            let capInsets = insetsTransformer.transformedValue(capInsetsValue) as? NSDictionary else {
                return NSDictionary()
        }
        let alignmentRectInsetsValue = NSValue(uiEdgeInsets: image.alignmentRectInsets)
        guard let alignmentRectInsets = insetsTransformer.transformedValue(alignmentRectInsetsValue) as? NSDictionary else {
            return NSDictionary()
        }

        let images = image.images ?? [image]
        var imageDictionaries = [NSDictionary]()
        for img in images {
            if let imageData = img.pngData() {
                let imageDataString = imageData.base64EncodedString(options: [.lineLength64Characters])
                let imageDictionary = ["scale": image.scale,
                                       "mime_type": "image/png",
                                       "data": imageDataString] as NSDictionary
                imageDictionaries.append(imageDictionary)
            }
        }

        return ["imageOrientation": image.imageOrientation.rawValue,
                "size": size,
                "renderingMode": image.renderingMode.rawValue,
                "resizingMode": image.resizingMode.rawValue,
                "duration": image.duration,
                "capInsets": capInsets,
                "alignmentRectInsets": alignmentRectInsets,
                "images": imageDictionaries]

    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        if let dictionaryValue = value as? NSDictionary {
            let insetsTransformer = ValueTransformer(forName:
                NSValueTransformerName(rawValue: NSStringFromClass(UIEdgeInsetsToNSDictionary.self)))
            let capInsets = insetsTransformer?.reverseTransformedValue(dictionaryValue["capInsets"]) as? UIEdgeInsets

            var images = [UIImage]()
            if let imagesDictionary = dictionaryValue["images"] as? [[String: Any]] {
                for imageDictionary in imagesDictionary {
                    guard let scale = (imageDictionary["scale"] as? NSNumber)?.floatValue else {
                        return UIImage()
                    }
                    var image: UIImage? = nil
                    if let imageStr = imageDictionary["url"] as? String {
                        image = UIImageToNSDictionary.imageCache[imageStr]
                        if image == nil {
                            if let imageURL = URL(string: imageStr) {
                                do {
                                    let imageData = try Data(contentsOf: imageURL)
                                    image = UIImage(data: imageData, scale: min(1.0, CGFloat(scale)))
                                    if let image = image {
                                        UIImageToNSDictionary.imageCache[imageStr] = image
                                    }
                                } catch {
                                    Logger.debug(message: "couldn't transform imageURL to Data")
                                }
                            }
                        }
                        if image != nil,
                            let dimensions = imageDictionary["dimensions"] as? [String: Any],
                            let width = (dimensions["Width"] as? NSNumber)?.floatValue,
                            let height = (dimensions["Height"] as? NSNumber)?.floatValue {
                            let size = CGSize(width: CGFloat(width), height: CGFloat(height))
                            UIGraphicsBeginImageContext(size)
                            image?.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                            image = UIGraphicsGetImageFromCurrentImageContext()!
                            UIGraphicsEndImageContext()
                        }
                    } else if let imageDataString = imageDictionary["data"] as? String {
                        if let imageData = Data(base64Encoded: imageDataString, options: [.ignoreUnknownCharacters]) {
                            image = UIImage(data: imageData, scale: min(1.0, CGFloat(scale)))
                        }
                    }

                    if let image = image {
                        images.append(image)
                    }
                }
            }
            var image: UIImage? = nil
            if let duration = dictionaryValue["duration"] as? Double, images.count > 1 {
                image = UIImage.animatedImage(with: images, duration: duration)
            } else if !images.isEmpty {
                image = images[0]
            }

            if let capInsets = capInsets {
                if image != nil && !(capInsets == UIEdgeInsets.zero) {
                    if let resizingMode = dictionaryValue["resizingMode"] as? UIImage.ResizingMode {
                        image = image?.resizableImage(withCapInsets: capInsets, resizingMode: resizingMode)
                    } else {
                        image = image?.resizableImage(withCapInsets: capInsets)
                    }
                }
            }
            if image == nil {
                return UIImage()
            }
            return image
        }
        return UIImage()
    }



}
