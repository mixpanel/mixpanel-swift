//
//  SwizzledTouchInterceptor.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

#if os(iOS)
  import ObjectiveC
  import UIKit

  /// Intercepts touch events globally by swizzling UIApplication.sendEvent(_:).
  ///
  /// This approach captures touches on ALL windows including:
  /// - Main app window
  /// - UIAlertController
  /// - Action sheets
  /// - Modal presentations
  /// - Popovers
  /// - Multi-window iPad
  ///
  /// The interceptor is installed once and delegates touch processing to the AutocaptureManager.
  final class SwizzledTouchInterceptor {
    // MARK: - Singleton

    static let shared = SwizzledTouchInterceptor()

    // MARK: - State

    private var isSwizzled = false
    private weak var manager: AutocaptureManager?
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Install the touch interceptor by swizzling UIApplication.sendEvent(_:).
    ///
    /// - Parameter manager: The AutocaptureManager to delegate touch events to
    func install(manager: AutocaptureManager) {
      lock.lock()
      defer { lock.unlock() }

      guard !isSwizzled else {
        // Already swizzled, just update the manager reference
        self.manager = manager
        MixpanelLogger.debug(message: "SwizzledTouchInterceptor: updated manager reference")
        return
      }

      self.manager = manager

      // Perform swizzling
      let originalSelector = #selector(UIApplication.sendEvent(_:))
      let swizzledSelector = #selector(UIApplication.mp_sendEvent(_:))

      guard let originalMethod = class_getInstanceMethod(UIApplication.self, originalSelector),
        let swizzledMethod = class_getInstanceMethod(UIApplication.self, swizzledSelector)
      else {
        MixpanelLogger.error(message: "SwizzledTouchInterceptor: failed to get methods for swizzling"
        )
        return
      }

      // Check if another SDK has already swizzled
      let originalImp = method_getImplementation(originalMethod)
      let swizzledImp = method_getImplementation(swizzledMethod)

      // Try to add the swizzled method first
      let didAddMethod = class_addMethod(
        UIApplication.self,
        originalSelector,
        swizzledImp,
        method_getTypeEncoding(swizzledMethod)
      )

      if didAddMethod {
        // Method was added, replace the implementation
        class_replaceMethod(
          UIApplication.self,
          swizzledSelector,
          originalImp,
          method_getTypeEncoding(originalMethod)
        )
      } else {
        // Method exists, exchange implementations
        method_exchangeImplementations(originalMethod, swizzledMethod)
      }

      isSwizzled = true
      MixpanelLogger.info(message: "SwizzledTouchInterceptor: installed successfully")
    }

    /// Uninstall the touch interceptor (for cleanup).
    ///
    /// Note: Swizzling cannot be safely unswizzled if other SDKs have chained,
    /// so this just clears the manager reference.
    func uninstall() {
      lock.lock()
      defer { lock.unlock() }
      manager = nil
      MixpanelLogger.info(message: "SwizzledTouchInterceptor: uninstalled (manager cleared)")
    }

    // MARK: - Touch Processing

    /// Called by the swizzled sendEvent method to process touch events.
    func handleEvent(_ event: UIEvent) {
      // Only process touch events
      guard event.type == .touches else { return }

      // Get touches that just ended (tap completed)
      guard let touches = event.allTouches else { return }

      for touch in touches where touch.phase == .ended {
        processTouchEnded(touch)
      }
    }

    private func processTouchEnded(_ touch: UITouch) {
      guard let manager = manager else { return }

      let location = touch.location(in: touch.window)
      let view = touch.view

      // Delegate to manager on main thread
      if Thread.isMainThread {
        manager.handleTouch(at: location, view: view, window: touch.window)
      } else {
        DispatchQueue.main.async {
          manager.handleTouch(at: location, view: view, window: touch.window)
        }
      }
    }
  }

  // MARK: - UIApplication Extension

  extension UIApplication {
    /// Swizzled sendEvent implementation.
    ///
    /// This method intercepts all events, processes touches for autocapture,
    /// then calls the original implementation.
    @objc func mp_sendEvent(_ event: UIEvent) {
      // Process touches for autocapture
      SwizzledTouchInterceptor.shared.handleEvent(event)

      // Call original implementation (swizzled, so this calls the real sendEvent)
      mp_sendEvent(event)
    }
  }
#endif
