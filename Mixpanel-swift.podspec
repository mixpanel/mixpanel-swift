
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
  s.tvos.deployment_target = '9.0'
  s.tvos.source_files = 'Mixpanel/*.swift'
  s.tvos.exclude_files = 'Mixpanel/MiniNotificationViewController.swift', 'Mixpanel/TakeoverNotificationViewController.swift'
  s.tvos.frameworks = 'UIKit', 'Foundation'
  s.module_name = 'Mixpanel'


end
