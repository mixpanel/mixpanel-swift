# /new-api

Implement a new public API method for the Mixpanel SDK.

## Usage
```
/new-api trackPurchase(amount: Double, currency: String, properties: Properties?)
```

## Implementation Steps

1. **Add to `Mixpanel.swift`** (static interface)
   ```swift
   @discardableResult
   public static func trackPurchase(amount: Double, 
                                  currency: String = "USD",
                                  properties: Properties? = nil) -> MixpanelInstance {
       return mainInstance().trackPurchase(amount: amount, 
                                          currency: currency, 
                                          properties: properties)
   }
   ```

2. **Implement in `MixpanelInstance.swift`**
   ```swift
   @discardableResult
   public func trackPurchase(amount: Double,
                           currency: String = "USD", 
                           properties: Properties? = nil) -> MixpanelInstance {
       var purchaseProps = properties ?? [:]
       purchaseProps["$amount"] = amount
       purchaseProps["$currency"] = currency
       
       // Thread-safe implementation
       trackingQueue.async { [weak self, purchaseProps] in
           self?.track(event: "$purchase", properties: purchaseProps)
       }
       
       return self
   }
   ```

3. **Add Objective-C Support** (if needed)
   ```swift
   @objc public func trackPurchase(amount: NSNumber,
                                 currency: String,
                                 properties: [String: Any]?) {
       let validProps = properties?.compactMapValues { $0 as? MixpanelType } ?? [:]
       _ = trackPurchase(amount: amount.doubleValue,
                        currency: currency,
                        properties: validProps)
   }
   ```

4. **Documentation**
   ```swift
   /// Tracks a purchase event with amount and currency.
   ///
   /// - Parameters:
   ///   - amount: The purchase amount
   ///   - currency: ISO 4217 currency code (default: "USD")
   ///   - properties: Additional event properties
   /// - Returns: This instance for method chaining
   ///
   /// Example:
   /// ```swift
   /// Mixpanel.mainInstance()
   ///     .trackPurchase(amount: 29.99, currency: "EUR", properties: [
   ///         "product_id": "sku_123",
   ///         "product_name": "Premium Subscription"
   ///     ])
   /// ```
   ```

5. **Write Tests**
   ```swift
   func testTrackPurchase() {
       let amount = 99.99
       let currency = "GBP"
       let props: Properties = ["product": "widget"]
       
       instance.trackPurchase(amount: amount, currency: currency, properties: props)
       waitForTrackingQueue(instance)
       
       XCTAssertEqual(instance.eventsQueue.count, 1)
       let event = instance.eventsQueue.first
       XCTAssertEqual(event?["event"] as? String, "$purchase")
       XCTAssertEqual(event?["properties"]?["$amount"] as? Double, amount)
       XCTAssertEqual(event?["properties"]?["$currency"] as? String, currency)
       XCTAssertEqual(event?["properties"]?["product"] as? String, "widget")
   }
   ```

## Checklist
- [ ] Thread safety with ReadWriteLock
- [ ] Property type validation
- [ ] Default parameter values
- [ ] Return self for chaining
- [ ] Comprehensive documentation
- [ ] Unit tests with edge cases
- [ ] Objective-C compatibility
- [ ] Update CHANGELOG.md