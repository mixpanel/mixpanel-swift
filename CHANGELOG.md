#

## [v3.0.0](https://github.com/mixpanel/mixpanel-swift/tree/v3.0.0) (2022-01-02)
-  Messages & Experiments feature removal, for more detail, please check this [post](https://mixpanel.com/blog/why-were-sunsetting-messaging-and-experiments/#:~:text=A%20year%20from%20now%2C%20on,offering%20discounts%20for%20getting%20started):

- Upgrade offline tracking storage with SQLite, it will:
  - Reduce crashes caused by race conditions for serializing data
  - Greatly improve the performance for intensive tracking needs
  - Fix the memory leaks
  - Be a non-functional change and transparent to all users, the new version will take care of migrating data from the NSKeyedArchiver files to SQLite DBs, no data will be lost.


## [3.0.0.rc.1](https://github.com/mixpanel/mixpanel-swift/tree/3.0.0.rc.1) (2021-12-16)

## [v2.10.4](https://github.com/mixpanel/mixpanel-swift/tree/v2.10.4) (2021-12-14)

**Closed issues:**

- Stop serialize data through NSKeyedArchiver [\#433](https://github.com/mixpanel/mixpanel-swift/issues/433)
- Sending many events in a row causes OOM crash [\#429](https://github.com/mixpanel/mixpanel-swift/issues/429)

#

## [v3.0.0.beta.3](https://github.com/mixpanel/mixpanel-swift/tree/v3.0.0.beta.3) (2021-06-26)

**Closed issues:**

- Opt-out Race Condition in 3.0.0.beta [\#458](https://github.com/mixpanel/mixpanel-swift/issues/458)
- Opt-out Persistence Broken in 3.0.0.beta [\#457](https://github.com/mixpanel/mixpanel-swift/issues/457)

**Merged pull requests:**

- Improve README for quick start guide [\#464](https://github.com/mixpanel/mixpanel-swift/pull/464)
- remove github actions for uploading Carthage artifact [\#462](https://github.com/mixpanel/mixpanel-swift/pull/462)
- enable github actions automatically upload Carthage artifact [\#461](https://github.com/mixpanel/mixpanel-swift/pull/461)





