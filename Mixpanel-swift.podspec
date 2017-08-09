
Pod::Spec.new do |s|
  s.name = 'Mixpanel-swift'
  s.version = '2.2.1'
  s.module_name = 'Mixpanel' 
  s.license = 'Apache License, Version 2.0'
  s.summary = 'Mixpanel tracking library for iOS (Swift)'
  s.homepage = 'https://mixpanel.com'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-swift.git',
                     :tag => "v#{s.version}" }
  s.ios.deployment_target = '8.0'
  s.ios.source_files = 'Mixpanel/*.swift'
  s.ios.resources = ['Mixpanel/**/*.{png,xib,storyboard}']
  s.ios.frameworks = 'UIKit', 'Foundation', 'CoreTelephony'
  s.ios.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '$(inherited) -D DECIDE'
  }
  s.tvos.deployment_target = '9.0'
  s.tvos.source_files = ['Mixpanel/Network.swift', 'Mixpanel/FlushRequest.swift', 'Mixpanel/PrintLogging.swift', 'Mixpanel/FileLogging.swift',
      'Mixpanel/Logger.swift', 'Mixpanel/JSONHandler.swift', 'Mixpanel/Error.swift', 'Mixpanel/AutomaticProperties.swift',
      'Mixpanel/Constants.swift', 'Mixpanel/MixpanelType.swift', 'Mixpanel/Mixpanel.swift', 'Mixpanel/MixpanelInstance.swift',
      'Mixpanel/Persistence.swift', 'Mixpanel/Flush.swift','Mixpanel/Track.swift', 'Mixpanel/People.swift', 'Mixpanel/AutomaticEvents.swift']
  s.tvos.frameworks = 'UIKit', 'Foundation'
  s.tvos.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '$(inherited) -D TV_OS'
  }
  s.osx.deployment_target = '10.10'
  s.osx.source_files = ['Mixpanel/Network.swift', 'Mixpanel/FlushRequest.swift', 'Mixpanel/PrintLogging.swift', 'Mixpanel/FileLogging.swift',
      'Mixpanel/Logger.swift', 'Mixpanel/JSONHandler.swift', 'Mixpanel/Error.swift', 'Mixpanel/AutomaticProperties.swift',
      'Mixpanel/Constants.swift', 'Mixpanel/MixpanelType.swift', 'Mixpanel/Mixpanel.swift', 'Mixpanel/MixpanelInstance.swift',
      'Mixpanel/Persistence.swift', 'Mixpanel/Flush.swift','Mixpanel/Track.swift', 'Mixpanel/People.swift', 'Mixpanel/AutomaticEvents.swift']
  s.osx.frameworks = 'Cocoa', 'Foundation'
  s.osx.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '$(inherited) -D MAC_OS'
  }
end
