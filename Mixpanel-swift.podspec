
Pod::Spec.new do |s|
  s.name = 'Mixpanel-swift'
  s.version = '2.1.3'
  s.module_name = 'Mixpanel' 
  s.license = 'Apache License, Version 2.0'
  s.summary = 'Mixpanel tracking library for iOS (Swift)'
  s.homepage = 'https://mixpanel.com'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-swift.git', :tag => "v#{s.version}" }
  s.default_subspec = 'Mixpanel'
  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '9.0'
  s.tvos.source_files = 'Mixpanel/*.swift'
  s.tvos.exclude_files = 'Mixpanel/MiniNotificationViewController.swift', 'Mixpanel/TakeoverNotificationViewController.swift'
  s.tvos.frameworks = 'UIKit', 'Foundation'
  s.tvos.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '$(inherited) -D TV_OS'
  }

  s.subspec 'Mixpanel' do |mp|
    mp.ios.source_files = 'Mixpanel/*.swift'
    mp.ios.frameworks = 'UIKit', 'Foundation', 'CoreTelephony'
    mp.ios.resources = ['Mixpanel/**/*.{png,xib,storyboard}']
    mp.ios.pod_target_xcconfig = {
      'OTHER_SWIFT_FLAGS' => '-D DECIDE'
    }
  end

  s.subspec 'AppExtension' do |appex|
    appex.source_files  = ['Mixpanel/Network.swift', 'Mixpanel/FlushRequest.swift', 'Mixpanel/PrintLogging.swift', 'Mixpanel/FileLogging.swift',
      'Mixpanel/Logger.swift', 'Mixpanel/JSONHandler.swift', 'Mixpanel/Error.swift', 'Mixpanel/AutomaticProperties.swift',
      'Mixpanel/Constants.swift', 'Mixpanel/MixpanelType.swift', 'Mixpanel/Mixpanel.swift', 'Mixpanel/MixpanelInstance.swift',
      'Mixpanel/Persistence.swift', 'Mixpanel/Flush.swift','Mixpanel/Track.swift', 'Mixpanel/People.swift']
    appex.pod_target_xcconfig = {
      'OTHER_SWIFT_FLAGS' => '-D APP_EXTENSION'
    }
    appex.frameworks = 'UIKit', 'Foundation', 'CoreTelephony'
  end

end
