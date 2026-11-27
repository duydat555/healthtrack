Pod::Spec.new do |s|
  s.name             = 'route_tracker'
  s.version          = '0.0.1'
  s.summary          = 'Ghi vị trí GPS bằng CoreLocation cho HealthTrack'
  s.description      = 'Phát luồng vị trí thô (CLLocation), xin quyền và chạy nền khi ghi buổi tập.'
  s.homepage         = 'http://example.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'HealthTrack' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'route_tracker/Sources/route_tracker/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'CoreLocation'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
