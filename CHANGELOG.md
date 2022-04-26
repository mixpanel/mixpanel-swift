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
























