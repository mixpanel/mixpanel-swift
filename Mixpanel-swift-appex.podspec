Pod::Spec.new do |s|
  s.name = 'Mixpanel-swift-appex'
  s.version = '2.1.5'
  s.module_name = 'MixpanelAppex' 
  s.license = 'Apache License, Version 2.0'
  s.summary = 'Mixpanel tracking library for iOS (Swift) App Extensions'
  s.homepage = 'https://mixpanel.com'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'https://github.com/mixpanel/mixpanel-swift.git',
                     :tag => "v#{s.version}" }
  s.ios.deployment_target = '8.0'
  s.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '$(inherited) -D APP_EXTENSION'
  }
  s.source_files = ['Mixpanel/Network.swift', 'Mixpanel/FlushRequest.swift', 'Mixpanel/PrintLogging.swift', 'Mixpanel/FileLogging.swift',
      'Mixpanel/Logger.swift', 'Mixpanel/JSONHandler.swift', 'Mixpanel/Error.swift', 'Mixpanel/AutomaticProperties.swift',
      'Mixpanel/Constants.swift', 'Mixpanel/MixpanelType.swift', 'Mixpanel/Mixpanel.swift', 'Mixpanel/MixpanelInstance.swift',
      'Mixpanel/Persistence.swift', 'Mixpanel/Flush.swift','Mixpanel/Track.swift', 'Mixpanel/People.swift']
  s.frameworks = 'UIKit', 'Foundation', 'CoreTelephony'
end
