Pod::Spec.new do |s|
  s.name = 'Mixpanel-swift'
  s.version = '6.4.1'
  s.module_name = 'Mixpanel'
  s.license = 'Apache License, Version 2.0'
  s.summary = 'Mixpanel tracking library for iOS (Swift)'
  s.swift_version = '5.0'
  s.homepage = 'https://mixpanel.com'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-swift.git',
                     :tag => "#{s.version}" }
  s.resource_bundles = {'Mixpanel' => ['Sources/Mixpanel/Mixpanel/PrivacyInfo.xcprivacy']}
  s.dependency 'jsonlogic', '~> 1.2.0'
  s.dependency 'MixpanelSwiftCommon', '~> 1.0.0'
  s.ios.deployment_target = '12.0'
  s.ios.frameworks = 'UIKit', 'Foundation', 'CoreTelephony'
  s.ios.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) IOS',
    'HEADER_SEARCH_PATHS' => '$(inherited) ${PODS_TARGET_SRCROOT}/Sources/MixpanelObjC/include'
  }
  s.default_subspec = 'Complete'

  # Objective-C exception handler
  objc_source_files = [
    'Sources/MixpanelObjC/JSONExceptionHandler.m',
    'Sources/MixpanelObjC/include/JSONExceptionHandler.h'
  ]

  objc_public_headers = [
    'Sources/MixpanelObjC/include/JSONExceptionHandler.h'
  ]

  # Swift source files
  base_source_files = [
    'Sources/Mixpanel/Autocapture.swift',
    'Sources/Mixpanel/Network.swift',
    'Sources/Mixpanel/FlushRequest.swift',
    'Sources/Mixpanel/PrintLogging.swift',
    'Sources/Mixpanel/FileLogging.swift',
    'Sources/Mixpanel/MixpanelLogger.swift',
    'Sources/Mixpanel/JSONHandler.swift',
    'Sources/Mixpanel/Error.swift',
    'Sources/Mixpanel/AutomaticProperties.swift',
    'Sources/Mixpanel/Constants.swift',
    'Sources/Mixpanel/MixpanelType.swift',
    'Sources/Mixpanel/Mixpanel.swift',
    'Sources/Mixpanel/MixpanelInstance.swift',
    'Sources/Mixpanel/Flush.swift',
    'Sources/Mixpanel/Track.swift',
    'Sources/Mixpanel/People.swift',
    'Sources/Mixpanel/AutomaticEvents.swift',
    'Sources/Mixpanel/Group.swift',
    'Sources/Mixpanel/ReadWriteLock.swift',
    'Sources/Mixpanel/SessionMetadata.swift',
    'Sources/Mixpanel/MPDB.swift',
    'Sources/Mixpanel/MixpanelPersistence.swift',
    'Sources/Mixpanel/Data+Compression.swift',
    'Sources/Mixpanel/MixpanelOptions.swift',
    'Sources/Mixpanel/FeatureFlags.swift'
  ] + objc_source_files

  s.tvos.deployment_target = '12.0'
  s.tvos.frameworks = 'UIKit', 'Foundation'
  s.tvos.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) TV_OS',
    'HEADER_SEARCH_PATHS' => '$(inherited) ${PODS_TARGET_SRCROOT}/Sources/MixpanelObjC/include'
  }
  s.osx.deployment_target = '10.13'
  s.osx.frameworks = 'Cocoa', 'Foundation'
  s.osx.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) MAC_OS',
    'HEADER_SEARCH_PATHS' => '$(inherited) ${PODS_TARGET_SRCROOT}/Sources/MixpanelObjC/include'
  }

  s.watchos.deployment_target = '4.0'
  s.watchos.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) WATCH_OS',
    'HEADER_SEARCH_PATHS' => '$(inherited) ${PODS_TARGET_SRCROOT}/Sources/MixpanelObjC/include'
  }

  s.subspec 'Complete' do |ss|
    ss.ios.source_files = ['Sources/Mixpanel/*.swift'] + objc_source_files
    ss.tvos.source_files = base_source_files
    ss.osx.source_files = base_source_files
    ss.watchos.source_files = base_source_files
    ss.public_header_files = objc_public_headers
  end

  s.subspec 'Core' do |ss|
    ss.ios.source_files = base_source_files
    ss.tvos.source_files = base_source_files
    ss.osx.source_files = base_source_files
    ss.watchos.source_files = base_source_files
    ss.public_header_files = objc_public_headers
  end
end
