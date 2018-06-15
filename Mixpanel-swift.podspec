Pod::Spec.new do |s|
  s.name = 'Mixpanel-swift'
  s.version = '2.4.3'
  s.module_name = 'Mixpanel'
  s.license = 'Apache License, Version 2.0'
  s.summary = 'Mixpanel tracking library for iOS (Swift)'
  s.homepage = 'https://mixpanel.com'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-swift.git',
                     :tag => "v#{s.version}" }
  s.ios.deployment_target = '8.0'
  s.ios.resources = ['Mixpanel/**/*.{png,xib,storyboard}']
  s.ios.frameworks = 'UIKit', 'Foundation', 'CoreTelephony'
  s.default_subspec = 'Complete'
  base_source_files = ['Mixpanel/Network.swift', 'Mixpanel/FlushRequest.swift', 'Mixpanel/PrintLogging.swift', 'Mixpanel/FileLogging.swift',
    'Mixpanel/Logger.swift', 'Mixpanel/JSONHandler.swift', 'Mixpanel/Error.swift', 'Mixpanel/AutomaticProperties.swift',
    'Mixpanel/Constants.swift', 'Mixpanel/MixpanelType.swift', 'Mixpanel/Mixpanel.swift', 'Mixpanel/MixpanelInstance.swift',
    'Mixpanel/Persistence.swift', 'Mixpanel/Flush.swift','Mixpanel/Track.swift', 'Mixpanel/People.swift', 'Mixpanel/AutomaticEvents.swift',
    'Mixpanel/ReadWriteLock.swift', 'Mixpanel/SessionMetadata.swift']
  s.tvos.deployment_target = '9.0'
  s.tvos.frameworks = 'UIKit', 'Foundation'
  s.tvos.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '$(inherited) -D TV_OS'
  }
  s.osx.deployment_target = '10.10'
  s.osx.frameworks = 'Cocoa', 'Foundation'
  s.osx.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '$(inherited) -D MAC_OS'
  }

  s.subspec 'Complete' do |ss|
    ss.ios.pod_target_xcconfig = {
      'OTHER_SWIFT_FLAGS' => '$(inherited) -D DECIDE'
    }
    ss.ios.source_files = 'Mixpanel/*.swift'
    ss.tvos.source_files = base_source_files
    ss.osx.source_files = base_source_files
  end

  s.subspec 'Core' do |ss|
    ss.ios.source_files = base_source_files
    ss.tvos.source_files = base_source_files
    ss.osx.source_files = base_source_files
  end
end
