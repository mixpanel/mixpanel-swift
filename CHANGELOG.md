#

## [v4.2.1](https://github.com/mixpanel/mixpanel-swift/tree/v4.2.1) (2024-03-14)

### Enhancements

- Add privacy manifest [\#633](https://github.com/mixpanel/mixpanel-swift/pull/633)
- visionOS Operating System & Version along with Automatic Events [\#627](https://github.com/mixpanel/mixpanel-swift/pull/627)

### Fixes

- Prevent crashes in unregisterSuperProperty [\#623](https://github.com/mixpanel/mixpanel-swift/pull/623)

#

## [v4.2.0](https://github.com/mixpanel/mixpanel-swift/tree/v4.2.0) (2023-11-13)

### Enhancements

- add a new property 'flushBatchSize' for fine tuning the network request [\#617](https://github.com/mixpanel/mixpanel-swift/pull/617)

### Fixes

- Fixes so project builds for visionOS [\#618](https://github.com/mixpanel/mixpanel-swift/pull/618)

#

## [v4.1.4](https://github.com/mixpanel/mixpanel-swift/tree/v4.1.4) (2023-07-19)

### Fixes

- Re-work thread safety mechanisms for flush process [\#611](https://github.com/mixpanel/mixpanel-swift/pull/611)

#

## [v4.1.3](https://github.com/mixpanel/mixpanel-swift/tree/v4.1.3) (2023-06-16)

### Fixes

- Fix potential crash automatic properties [\#608](https://github.com/mixpanel/mixpanel-swift/pull/608)

#

## [v4.1.2](https://github.com/mixpanel/mixpanel-swift/tree/v4.1.2) (2023-05-17)

### Fixes

- Replace deprecated archiving methods [\#603](https://github.com/mixpanel/mixpanel-swift/pull/603)
- Fix Xcode 14.3 heterogeneous collection warnings [\#602](https://github.com/mixpanel/mixpanel-swift/pull/602)

#

## [v4.1.1](https://github.com/mixpanel/mixpanel-swift/tree/v4.1.1) (2023-04-28)

### Enhancements

- create indexes and enable WAL journal\_mode [\#600](https://github.com/mixpanel/mixpanel-swift/pull/600)

#

## [v4.1.0](https://github.com/mixpanel/mixpanel-swift/tree/v4.1.0) (2023-03-23)

### NOTE:

Starting from this version, we have added a new optional boolean parameter performFullFlush to the flush() method. Default to `false`, a partial flush will be executed for reducing memory footprint. The updated flush() is as follows:
```
    /*
    - parameter performFullFlush: A optional boolean value indicating whether a full flush should be performed. If `true`, a full flush will be triggered, sending all events to the server. Default to `false`, a partial flush will be executed for reducing memory footprint.
    - parameter completion: an optional completion handler for when the flush has completed.
    */
    public func flush(performFullFlush: Bool = false, completion: (() -> Void)? = nil) 
```


### Enhancements

- Set the number of events per flush to 1,000 to reduce memory footprint [\#596](https://github.com/mixpanel/mixpanel-swift/pull/596)
- Fix CI pod lint: no longer need to exclude watchos  [\#593](https://github.com/mixpanel/mixpanel-swift/pull/593)

#

## [v4.0.6](https://github.com/mixpanel/mixpanel-swift/tree/v4.0.6) (2023-03-15)

### Enhancements

- bump the versions to ios11, tvOS11, macOS1013 and watchOS4 [\#592](https://github.com/mixpanel/mixpanel-swift/pull/592)

#

## [v4.0.5](https://github.com/mixpanel/mixpanel-swift/tree/v4.0.5) (2023-03-01)

### Enhancements

- Various Community PRs [\#589](https://github.com/mixpanel/mixpanel-swift/pull/589)
- Identity v3 changes for swift sdk [\#586](https://github.com/mixpanel/mixpanel-swift/pull/586)
- Delete .travis.yml [\#573](https://github.com/mixpanel/mixpanel-swift/pull/573)

### Fixes

- Access the timedEvents property inside of a readWriteLock. [\#588](https://github.com/mixpanel/mixpanel-swift/pull/588)
- Disable watchOS builds in CI [\#587](https://github.com/mixpanel/mixpanel-swift/pull/587)
- Check flush interval \> 0 inside the dispatch block [\#583](https://github.com/mixpanel/mixpanel-swift/pull/583)
- SwiftUI preview fix [\#581](https://github.com/mixpanel/mixpanel-swift/pull/581)
- Setting explicit autorelease frequency [\#579](https://github.com/mixpanel/mixpanel-swift/pull/579)
- Update iOS.yml [\#577](https://github.com/mixpanel/mixpanel-swift/pull/577)
- bump podspec deployment targets [\#575](https://github.com/mixpanel/mixpanel-swift/pull/575)

#

## [v4.0.4](https://github.com/mixpanel/mixpanel-swift/tree/v4.0.4) (2022-11-02)

### Enhancements

- Fix broken link to the advanced guide on README [\#567](https://github.com/mixpanel/mixpanel-swift/pull/567)
- Fix typos in log [\#562](https://github.com/mixpanel/mixpanel-swift/pull/562)

### Fixes

- Fix Xcode 14 warnings [\#568](https://github.com/mixpanel/mixpanel-swift/pull/568)
- Only use alphanumerics in MPDB token strings [\#566](https://github.com/mixpanel/mixpanel-swift/pull/566)

#

## [v4.0.3](https://github.com/mixpanel/mixpanel-swift/tree/v4.0.3) (2022-09-19)

### Enhancements

- Mark final attribute in MixpanelManager [\#553](https://github.com/mixpanel/mixpanel-swift/pull/553)
- add an option for 'createAlias' for not calling identify [\#547](https://github.com/mixpanel/mixpanel-swift/pull/547)

### Fixes

- strip whitespace in MPDB token [\#561](https://github.com/mixpanel/mixpanel-swift/pull/561)

#

## [v4.0.2](https://github.com/mixpanel/mixpanel-swift/tree/v4.0.2) (2022-09-13)

### Fixes

- always use serverURL [\#560](https://github.com/mixpanel/mixpanel-swift/pull/560)

#

## [v4.0.1](https://github.com/mixpanel/mixpanel-swift/tree/v4.0.1) (2022-09-09)

### Fixes

- dont initialize AutomaticEvents if trackAutomaticEvents is false [\#559](https://github.com/mixpanel/mixpanel-swift/pull/559)

#

## [v4.0.0](https://github.com/mixpanel/mixpanel-swift/tree/v4.0.0) (2022-08-16)

### Enhancements

- Remove Decide and make trackAutomaticEvents required parameter [\#545](https://github.com/mixpanel/mixpanel-swift/pull/545)

#

## [v3.5.1](https://github.com/mixpanel/mixpanel-swift/tree/v3.5.1) (2022-07-18)

### Fixes

- Send time as Decimal to avoid 32-bit max int [\#551](https://github.com/mixpanel/mixpanel-swift/pull/551)

#

## [v3.5.0](https://github.com/mixpanel/mixpanel-swift/tree/v3.5.0) (2022-07-06)

### Enhancements

- add support for multiple instances under the same token [\#549](https://github.com/mixpanel/mixpanel-swift/pull/549)

#

## [v3.4.0](https://github.com/mixpanel/mixpanel-swift/tree/v3.4.0) (2022-06-30)

### Enhancements

- add an option for 'createAlias' for not calling identify [\#547](https://github.com/mixpanel/mixpanel-swift/pull/547)

When you call the API `createAlias`, there is an implicit `identify` call inside the API done for you. This will keep your signup funnels working correctly in most cases. However, if that is not what you want, this PR will allow you to not call `identify` by specifying `andIdentify` to `false`.

 Please also note: With Mixpanel Identity Merge enabled, calling alias is no longer required but can be used to merge two IDs in scenarios where `identify` would fail.

#

## [v3.3.0](https://github.com/mixpanel/mixpanel-swift/tree/v3.3.0) (2022-06-24)

### Enhancements

- use millisecond precision for event time property [\#546](https://github.com/mixpanel/mixpanel-swift/pull/546)

#

## [v3.2.6](https://github.com/mixpanel/mixpanel-swift/tree/v3.2.6) (2022-05-20)

### Enhancements

- remove survey [\#544](https://github.com/mixpanel/mixpanel-swift/pull/544)

#

## [v3.2.5](https://github.com/mixpanel/mixpanel-swift/tree/v3.2.5) (2022-05-06)

### Fixes

- get lib name and version from super props [\#543](https://github.com/mixpanel/mixpanel-swift/pull/543)

#

## [v3.2.4](https://github.com/mixpanel/mixpanel-swift/tree/v3.2.4) (2022-05-05)

### Enhancements

- track implementation and each launch [\#541](https://github.com/mixpanel/mixpanel-swift/pull/541)

### Fixes

- pass completion handler to flush on background [\#542](https://github.com/mixpanel/mixpanel-swift/pull/542)

#

## [v3.2.3](https://github.com/mixpanel/mixpanel-swift/tree/v3.2.3) (2022-04-29)

### Enhancements

- Add additional SDK internal tracking [\#540](https://github.com/mixpanel/mixpanel-swift/pull/540)

#

## [v3.2.2](https://github.com/mixpanel/mixpanel-swift/tree/v3.2.2) (2022-04-26)

### Fixes

- only put $distinct\_id on People records [\#539](https://github.com/mixpanel/mixpanel-swift/pull/539)

#

## [v3.2.1](https://github.com/mixpanel/mixpanel-swift/tree/v3.2.1) (2022-04-21)

### Enhancements

- Add Dev NPS Survey Log & semaphore.signal\(\) in Decide [\#537](https://github.com/mixpanel/mixpanel-swift/pull/537)

#

## [v3.2.0](https://github.com/mixpanel/mixpanel-swift/tree/v3.2.0) (2022-04-11)

### Enhancements

- Allow setting server URL during initialization [\#530](https://github.com/mixpanel/mixpanel-swift/pull/530)
- check for ios app on mac in automatic props [\#521](https://github.com/mixpanel/mixpanel-swift/pull/521)

#

## [v3.1.7](https://github.com/mixpanel/mixpanel-swift/tree/v3.1.7) (2022-03-23)

### Fixes

- Check if automatic events flag is set before flushing [\#526](https://github.com/mixpanel/mixpanel-swift/pull/526)

#

## [v3.1.6](https://github.com/mixpanel/mixpanel-swift/tree/v3.1.6) (2022-03-09)

### Fixes

- Fix deadlock in initialization [\#525](https://github.com/mixpanel/mixpanel-swift/pull/525)

#

## [v3.1.5](https://github.com/mixpanel/mixpanel-swift/tree/v3.1.5) (2022-02-19)

### Fixes

- Fix `disk I/O error` caused by race condition from multiple initializations with the same token [\#519](https://github.com/mixpanel/mixpanel-swift/pull/519)

#

## [v3.1.4](https://github.com/mixpanel/mixpanel-swift/tree/v3.1.4) (2022-02-11)

### Fixes

- Fixes for several race conditions and sqlite warnings [\#517](https://github.com/mixpanel/mixpanel-swift/pull/517)

#

## [v3.1.3](https://github.com/mixpanel/mixpanel-swift/tree/v3.1.3) (2022-02-03)

### Fixes

- Fix automatic events settings [\#511](https://github.com/mixpanel/mixpanel-swift/pull/511)

#

## [v3.1.2](https://github.com/mixpanel/mixpanel-swift/tree/v3.1.2) (2022-01-26)

### Fixes

- Fix unit tests and remove outdated 'Nocilla' stub server [\#509](https://github.com/mixpanel/mixpanel-swift/pull/509)
- fix build issue in JSONHandler [\#508](https://github.com/mixpanel/mixpanel-swift/pull/508)

#
## [v3.1.1](https://github.com/mixpanel/mixpanel-swift/tree/v3.1.1) (2022-01-21)

## What's Changed
* Fix the reset completion block not being triggered by @zihejia in https://github.com/mixpanel/mixpanel-swift/pull/505
* Set content-type to application/json by @jaredmixpanel in https://github.com/mixpanel/mixpanel-swift/pull/506
  This will avoid events being rejected by the server if any string contains "& % ".


**Full Changelog**: https://github.com/mixpanel/mixpanel-swift/compare/v3.1.0...v3.1.1

## [v3.1.0](https://github.com/mixpanel/mixpanel-swift/tree/v3.1.0) (2022-01-13)
## Caution: In this version, we have a bug that event names with `&` or `%` will be rejected by the server. We recommend you update to 3.1.1 or above. 


### Enhancements

- Add useUniqueDistinctId parameter to initialize [\#500](https://github.com/mixpanel/mixpanel-swift/pull/500)
- Remove base64 encoding [\#499](https://github.com/mixpanel/mixpanel-swift/pull/499)
- Add superProperties param to initialize [\#498](https://github.com/mixpanel/mixpanel-swift/pull/498)

### Fixes

- Fix incorrect app version property [\#497](https://github.com/mixpanel/mixpanel-swift/pull/497)
- Fix  `First App Open` not always being able to be triggered [\#496](https://github.com/mixpanel/mixpanel-swift/pull/496)

**Merged pull requests:**

- Add completion closure to async apis `reset\(\)`, `identify\(\)` and `createAlias\(\)`  [\#468](https://github.com/mixpanel/mixpanel-swift/pull/468)

#

## [v3.0.0](https://github.com/mixpanel/mixpanel-swift/tree/v3.0.0) (2022-01-02)

-  Messages & Experiments feature removal, for more detail, please check this [post](https://mixpanel.com/blog/why-were-sunsetting-messaging-and-experiments/#:~:text=A%20year%20from%20now%2C%20on,offering%20discounts%20for%20getting%20started):

- Upgrade offline tracking storage with SQLite, it will:
  - Reduce crashes caused by race conditions for serializing data
  - Greatly improve the performance for intensive tracking needs
  - Fix the memory leaks
  - Be a non-functional change and transparent to all users, the new version will take care of migrating data from the NSKeyedArchiver files to SQLite DBs, no data will be lost.

## [v2.10.4](https://github.com/mixpanel/mixpanel-swift/tree/v2.10.4) (2021-12-14)

**Closed issues:**

- Stop serialize data through NSKeyedArchiver [\#433](https://github.com/mixpanel/mixpanel-swift/issues/433)
- Sending many events in a row causes OOM crash [\#429](https://github.com/mixpanel/mixpanel-swift/issues/429)




































































