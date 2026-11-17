Pod::Spec.new do |s|
  s.name             = 'native_bottomsheet'
  s.version          = '0.1.1'
  s.summary          = 'Native bottom sheets for DartNative.'
  s.homepage         = 'https://dartpub.dev'
  s.license          = { :type => 'MIT' }
  s.author           = { 'DartNative' => 'crazibeatdeveloper@gmail.com' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.swift'
  s.swift_version    = '5.9'

  # DartNative 1.8's dartnative_ios pod targets iOS 15, and every sheet API in
  # this plugin is iOS 15+. Match the SDK floor instead of advertising 14.
  s.platform         = :ios, '15.0'
  s.dependency 'FlexLayout'

  # FlexLayout is linked into the app statically by the DartNative podhelper
  # (DartNativeStaticFlexLayout), so a pod built from source as a dynamic
  # framework that depends on it stops `pod install` with "transitive
  # dependencies that include statically linked binaries". Build this pod as a
  # static framework too.
  s.static_framework = true

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
