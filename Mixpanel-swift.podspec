
Pod::Spec.new do |s|
  s.name = 'Mixpanel-swift'
  s.version = '2.1.3'
  s.license = 'Apache License, Version 2.0'
  s.summary = 'Mixpanel tracking library for iOS (Swift)'
  s.homepage = 'https://mixpanel.com'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-swift.git', :tag => "v#{s.version}" }
  s.ios.deployment_target = '8.0'
  s.ios.source_files = 'Mixpanel/*.swift'
  s.ios.resources = ['Mixpanel/**/*.{png,xib,storyboard}']
  s.ios.frameworks = 'UIKit', 'Foundation', 'CoreTelephony'
  s.ios.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '$(inherited) -D DECIDE'
  }
  s.tvos.deployment_target = '9.0'
  s.tvos.source_files = 'Mixpanel/*.swift'
  s.tvos.exclude_files = 'Mixpanel/MiniNotificationViewController.swift', 'Mixpanel/TakeoverNotificationViewController.swift'
  s.tvos.frameworks = 'UIKit', 'Foundation'
  s.tvos.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '$(inherited) -D TV_OS'
  }
  s.module_name = 'Mixpanel'

  s.subspec 'AppExtension' do |appex|
    appex.source_files  = ['Mixpanel/Network.swift', 'Mixpanel/FlushRequest.swift', 'Mixpanel/PrintLogging.swift', 'Mixpanel/FileLogging.swift',
      'Mixpanel/Logger.swift', 'Mixpanel/JSONHandler.swift', 'Mixpanel/Error.swift', 'Mixpanel/AutomaticProperties.swift',
      'Mixpanel/Constants.swift', 'Mixpanel/MixpanelType.swift', 'Mixpanel/Mixpanel.swift', 'Mixpanel/MixpanelInstance.swift',
      'Mixpanel/Persistence.swift', 'Mixpanel/Flush.swift','Mixpanel/Track.swift', 'Mixpanel/People.swift']
    appex.ios.pod_target_xcconfig = {
      'OTHER_SWIFT_FLAGS' => '$(inherited) -D APP_EXTENSION -D DOUCHEBAG'
    }
    appex.frameworks = 'UIKit', 'Foundation', 'CoreTelephony'
    appex.ios.deployment_target = '8.0'
  end

end
