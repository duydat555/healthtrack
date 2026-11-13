Pod::Spec.new do |s|
  s.name             = 'health_bridge'
  s.version          = '0.0.1'
  s.summary          = 'Đọc dữ liệu Apple Health (HealthKit) cho HealthTrack'
  s.description      = 'Đọc bước chân, giấc ngủ và cân nặng từ HealthKit.'
  s.homepage         = 'http://example.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'HealthTrack' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'health_bridge/Sources/health_bridge/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'HealthKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
