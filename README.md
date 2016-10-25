<p align="center">
  <img src="https://github.com/mixpanel/mixpanel-swift/blob/assets/mixpanelswift.png?raw=true" alt="Mixpanel Swift Library" height="200"/>
</p>


[![Build Status](https://travis-ci.org/mixpanel/mixpanel-swift.svg)](https://travis-ci.org/mixpanel/mixpanel-swift)
[![Average time to resolve an issue](http://isitmaintained.com/badge/resolution/mixpanel/mixpanel-swift.svg)](http://isitmaintained.com/project/mixpanel/mixpanel-swift "Average time to resolve an issue")
[![Percentage of issues still open](http://isitmaintained.com/badge/open/mixpanel/mixpanel-swift.svg)](http://isitmaintained.com/project/mixpanel/mixpanel-swift "Percentage of issues still open")
[![CocoaPods Compatible](http://img.shields.io/cocoapods/v/Mixpanel-swift.svg)](https://mixpanel.com)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg)](https://github.com/Carthage/Carthage)
[![Apache License](http://img.shields.io/cocoapods/l/Mixpanel-swift.svg)](https://mixpanel.com)

# Introduction

Welcome to the official Mixpanel Swift Library

The Mixpanel Swift library for iOS is an open source project, and we'd love to see your contributions! 
We'd also love for you to come and work with us! Check out **[Jobs](http://boards.greenhouse.io/mixpanel/jobs/25226#.U_4JXEhORKU)** for details.

If you are using Objective-C, we recommend using our **[Objective-C Library](https://github.com/mixpanel/mixpanel-iphone)**.

## Current supported features

**Our master branch and our 2.x releases are now in Swift 3. If you wish to use our Swift 2.3 implementation, please point to our v1.0.1 release.**

| Feature      | Swift 3 | [Swift 2.3](https://github.com/mixpanel/mixpanel-swift/tree/swift2.3) |
| -------      | ------------- | -------------                                                            |
| Tracking API |       ✔       |       ✔       |
| People API   |       ✔       |       ✔       |
| [Documentation](https://mixpanel.github.io/mixpanel-swift)|       ✔       |        ✔       |
| tvOS Support |       ✔        |              |
| In-app Notifications |       ✔        |              |
| Codeless Tracking |       ✔        |              |
| A/B Testing |       ✔        |              |
# Installation

## CocoaPods

**Our current release only supports Cocoapods version 1.1.0+**

Mixpanel supports `CocoaPods` for easy installation.
To Install, see our **[swift integration guide »](https://mixpanel.com/help/reference/swift)**

`pod 'Mixpanel-swift'`

## Carthage

Mixpanel also supports `Carthage` to package your dependencies as a framework. Include the following dependency in your Cartfile:

`github "mixpanel/mixpanel-swift"`

Check out the **[Carthage docs »](https://github.com/Carthage/Carthage#if-youre-building-for-ios-tvos-or-watchos)** for more info. 

## Manual Installation

To help users stay up to date with the latests version of our Swift SDK, we always recommend integrating our SDK via CocoaPods, which simplifies version updates and dependency management. However, there are cases where users can't use CocoaPods. Not to worry, just follow these manual installation steps and you'll be all set.

### Step 1: Add as a Submodule

Add Mixpanel as a submodule to your local git repo like so:

```
git submodule add git@github.com:mixpanel/mixpanel-swift.git
```

Now the Mixpanel project and its files should be in your project folder! 

### Step 2: Drag Mixpanel to your project

Drag the Mixpanel.xcodeproj inside your sample project under the main sample project file:

![alt text](http://images.mxpnl.com/docs/2016-07-19%2023:34:02.724663-Screen%20Shot%202016-07-19%20at%204.33.34%20PM.png)

### Step 3: Embed the framework

Select your app .xcodeproj file. Under "General", add the Mixpanel framework as an embedded binary:

![alt text](http://images.mxpnl.com/docs/2016-07-19%2023:31:29.237158-add_framework.png)

### Step 4: Integrate!

Import Mixpanel into AppDelegate.swift, and initialize Mixpanel within `application:didFinishLaunchingWithOptions:`
![alt text](http://images.mxpnl.com/docs/2016-07-19%2023:27:03.724972-Screen%20Shot%202016-07-18%20at%207.16.51%20PM.png)

```
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    Mixpanel.initialize(token: "MIXPANEL_TOKEN")
}
```

# Initializing and Usage

By calling:
```
let mixpanel = Mixpanel.initialize(token: "MIXPANEL_TOKEN")
```

You initialize your mixpanel instance with the token provided to you on mixpanel.com.
To interact with the instance and start tracking, you can either use the mixpanel instance given when initializing:
```
mixpanel.track(event: "Tracked Event!")
```
or you can directly fetch the instance and use it from the Mixpanel object:
```
Mixpanel.mainInstance().track(event: "Tracked Event!")
```

## Start tracking

You're done! You've successfully integrated the Mixpanel Swift SDK into your app. To stay up to speed on important SDK releases and updates, star or watch our repository on [Github](https://github.com/mixpanel/mixpanel-swift).

Have any questions? Reach out to [support@mixpanel.com](mailto:support@mixpanel.com) to speak to someone smart, quickly.
