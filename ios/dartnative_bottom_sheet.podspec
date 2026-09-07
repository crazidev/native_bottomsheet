Pod::Spec.new do |s|
  s.name             = 'dartnative_bottom_sheet'
  s.version          = '0.1.0'
  s.summary          = 'Native bottom sheets for DartNative.'
  s.homepage         = 'https://dartpub.dev'
  s.license          = { :type => 'MIT' }
  s.author           = { 'DartNative' => 'hello@dartpub.dev' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.swift'
  s.swift_version    = '5.9'

  s.platform         = :ios, '14.0'
  s.dependency 'FlexLayout'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
