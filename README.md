

<p align="center">
  <img src="https://user-images.githubusercontent.com/71290498/231855731-2d3774c3-dc41-4595-abfb-9c49f5f84103.png" alt="Mixpanel Swift Library" height="150"/>
</p>


[![Average time to resolve an issue](http://isitmaintained.com/badge/resolution/mixpanel/mixpanel-swift.svg)](http://isitmaintained.com/project/mixpanel/mixpanel-swift "Average time to resolve an issue")
[![Percentage of issues still open](http://isitmaintained.com/badge/open/mixpanel/mixpanel-swift.svg)](http://isitmaintained.com/project/mixpanel/mixpanel-swift "Percentage of issues still open")
[![CocoaPods Compatible](http://img.shields.io/cocoapods/v/Mixpanel-swift.svg)](https://mixpanel.com)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg)](https://github.com/Carthage/Carthage)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Apache License](http://img.shields.io/cocoapods/l/Mixpanel-swift.svg)](https://mixpanel.com)
[![Documentation](https://mixpanel.github.io/mixpanel-swift/badge.svg)](https://mixpanel.github.io/mixpanel-swift)
# Table of Contents

<!-- MarkdownTOC -->

- [Overview](#overview)
- [Quick Start Guide](#quick-start-guide)
    - [Install Mixpanel](#1-install-mixpanel)
    - [Initialize Mixpanel](#2-initialize-mixpanel)
    - [Send Data](#3-send-data)
    - [Check for Success](#4-check-for-success)
    - [Complete Code Example](#complete-code-example)
- [FAQ](#faq)
- [I want to know more!](#i-want-to-know-more)

<!-- /MarkdownTOC -->


<a name="introduction"></a>
# Overview

Welcome to the official Mixpanel Swift Library

The Mixpanel Swift library for iOS is an open-source project, and we'd love to see your contributions!
We'd also love for you to come and work with us! Check out **[Jobs](https://mixpanel.com/jobs/#openings)** for details.

If you are using Objective-C, we recommend using our **[Objective-C Library](https://github.com/mixpanel/mixpanel-iphone)**.

Check out our [Advanced iOS Swift Guide](https://developer.mixpanel.com/docs/swift) for additional advanced configurations and use cases, like setting up your project with European Union data storage.

# Quick Start Guide
Our master branch and our releases are on Swift 5. If you wish to use our Swift 4.2 implementation, please point to the v2.6.1 release. For Swift 4/4.1 implementation, please point to the v2.4.5 release. For Swift 3 implementation, please point to the v2.2.3 release.

## 1. Install Mixpanel
You will need your project token for initializing your library. You can get your project token from [project settings](https://mixpanel.com/settings/project).

### Installation Option 1: Swift Package Manager (v2.8.0+)
The easiest way to get Mixpanel into your iOS project is to use Swift Package Manager.
1. In Xcode, select File > Add Packages...
2. Enter the package URL for this repository [Mixpanel Swift library](https://github.com/mixpanel/mixpanel-swift).

### Installation Option 2: CocoaPods
1. If this is your first time using CocoaPods, Install CocoaPods using `gem install cocoapods`. Otherwise, continue to Step 3.
2. Run `pod setup` to create a local CocoaPods spec mirror.
3. Create a Podfile in your Xcode project directory by running `pod init` in your terminal, edit the Podfile generated, and add the following line: `pod 'Mixpanel-swift'`.
4. Run `pod install` in your Xcode project directory. CocoaPods should download and install the Mixpanel library, and create a new Xcode workspace. Open up this workspace in Xcode or typing `open *.xcworkspace` in your terminal.

### Installation Option 3: Carthage
Mixpanel supports Carthage to package your dependencies as a framework. Include the following dependency in your Cartfile:
```swift
github "mixpanel/mixpanel-swift"
```
Check out the [Carthage docs](https://github.com/Carthage/Carthage#if-youre-building-for-ios-tvos-or-watchos) for more info.

## 2. Initialize Mixpanel
Import Mixpanel into AppDelegate.swift, and initialize Mixpanel within application:didFinishLaunchingWithOptions:
```swift
import Mixpanel

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    ...
    Mixpanel.initialize(token: "MIXPANEL_TOKEN", trackAutomaticEvents: true)
    ...
}
```
[See all configuration options](https://mixpanel.github.io/mixpanel-swift/Classes/MixpanelInstance.html)

## 3. Send Data
Let's get started by sending event data. You can send an event from anywhere in your application. Better understand user behavior by storing details that are specific to the event (properties). After initializing the library, Mixpanel will [automatically collect common mobile events](https://mixpanel.com/help/questions/articles/which-common-mobile-events-can-mixpanel-collect-on-my-behalf-automatically). You can enable/disable automatic collection through your [project settings](https://help.mixpanel.com/hc/en-us/articles/115004596186#enable-or-disable-common-mobile-events). Also, Mixpanel automatically tracks some properties by default. [learn more](https://help.mixpanel.com/hc/en-us/articles/115004613766-Default-Properties-Collected-by-Mixpanel#iOS)
```swift
Mixpanel.mainInstance().track(event: "Sign Up", properties: [
   "source": "Pat's affiliate site",
   "Opted out of email": true
])
```
In addition to event data, you can also send [user profile data](https://developer.mixpanel.com/docs/swift#storing-user-profiles). We recommend this after completing the quickstart guide.

## 4. Check for Success
[Open up Events in Mixpanel](http://mixpanel.com/report/events) to view incoming events. 

Once data hits our API, it generally takes ~60 seconds for it to be processed, stored, and queryable in your project.

👋 👋  Tell us about the Mixpanel developer experience! [https://www.mixpanel.com/devnps](https://www.mixpanel.com/devnps) 👍  👎

## Complete Code Example
Here's a runnable code example that covers everything in this quickstart guide.
```swift
import Mixpanel

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    ...
    Mixpanel.initialize(token: "MIXPANEL_TOKEN", trackAutomaticEvents: true)
    Mixpanel.mainInstance().track(event: "Sign Up", properties: [
       "source": "Pat's affiliate site",
       "Opted out of email": true
    ])
    ...
}
```

# FAQ
**I want to stop tracking an event/event property in Mixpanel. Is that possible?**

Yes, in Lexicon, you can intercept and drop incoming events or properties. Mixpanel won’t store any new data for the event or property you select to drop. [See this article for more information](https://help.mixpanel.com/hc/en-us/articles/360001307806#dropping-events-and-properties).

**I have a test user I would like to opt out of tracking. How do I do that?**

Mixpanel’s client-side tracking library contains the [optOutTracking()](https://mixpanel.github.io/mixpanel-swift/Classes/MixpanelInstance.html#/s:8Mixpanel0A8InstanceC14optOutTrackingyyF) method, which will set the user’s local opt-out state to “true” and will prevent data from being sent from a user’s device. More detailed instructions can be found in the section, [Opting users out of tracking](https://developer.mixpanel.com/docs/swift#opting-users-out-of-tracking).

**Why aren't my events showing up?**

First, make sure your test device has internet access. To preserve battery life and customer bandwidth, the Mixpanel library doesn't send the events you record immediately. Instead, it sends batches to the Mixpanel servers every 60 seconds while your application is running, as well as when the application transitions to the background. You can call [flush()](https://mixpanel.github.io/mixpanel-swift/Classes/MixpanelInstance.html#/s:8Mixpanel0A8InstanceC5flush10completionyyycSg_tF) manually if you want to force a flush at a particular moment.
```swift
Mixpanel.mainInstance().flush()
```
If your events are still not showing up after 60 seconds, check if you have opted out of tracking. You can also enable Mixpanel debugging and logging, it allows you to see the debug output from the Mixpanel library. To enable it, set [loggingEnabled](https://mixpanel.github.io/mixpanel-swift/Classes/MixpanelInstance.html#/s:8Mixpanel0A8InstanceC14loggingEnabledSbvp) to true.
```swift
Mixpanel.mainInstance().loggingEnabled = true
```
**Starting with iOS 14.5, do I need to request the user’s permission through the AppTrackingTransparency framework to use Mixpanel?**

No, Mixpanel does not use IDFA so it does not require user permission through the AppTrackingTransparency(ATT) framework.

**If I use Mixpanel, how do I answer app privacy questions for the App Store?**

Please refer to our [Apple App Developer Privacy Guidance](https://mixpanel.com/legal/app-store-privacy-details/)


## I want to know more!

No worries, here are some links that you will find useful:
* **[Advanced iOS - Swift Guide](https://developer.mixpanel.com/docs/swift)**
* **[Sample app](https://github.com/mixpanel/mixpanel-swift/tree/master/MixpanelDemo)**
* **[Full API Reference](https://mixpanel.github.io/mixpanel-swift)**

Have any questions? Reach out to Mixpanel [Support](https://help.mixpanel.com/hc/en-us/requests/new) to speak to someone smart, quickly.

