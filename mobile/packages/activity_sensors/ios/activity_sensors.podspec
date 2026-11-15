Pod::Spec.new do |s|
  s.name             = 'activity_sensors'
  s.version          = '0.0.1'
  s.summary          = 'Đếm bước chân và quãng nghỉ bằng CoreMotion cho HealthTrack'
  s.description      = 'Đọc bước chân theo ngày, bước chân trực tiếp và hoạt động chuyển động từ CoreMotion.'
  s.homepage         = 'http://example.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'HealthTrack' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'activity_sensors/Sources/activity_sensors/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'CoreMotion'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
