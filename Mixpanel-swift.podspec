
Pod::Spec.new do |s|
  s.name = 'Mixpanel-swift'
  s.version = '1.0.0'
  s.license = 'Apache License, Version 2.0'
  s.summary = 'iPhone tracking library for Mixpanel Analytics in Swift'
  s.homepage = 'https://mixpanel.com'
  s.author       = { 'Mixpanel, Inc' => 'support@mixpanel.com' }
  s.source       = { :git => 'git@github.com:mixpanel/mixpanel-swift.git', :tag => "v#{s.version}" }
  s.ios.deployment_target = '8.0'
  s.source_files = 'Mixpanel/*.swift'
  s.module_name = 'Mixpanel'
end
