#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint screenshot_kit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'screenshot_kit'
  s.version          = '1.0.0'
  s.summary          = 'Capture widgets and the whole screen, including web views, as images.'
  s.description      = <<-DESC
Capture widgets, long scroll views and the whole screen (including maps and web views) as images. A maintained, drop-in successor to the screenshot package.
                       DESC
  s.homepage         = 'https://github.com/vishnuprasad0/screenshot_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Vishnu Prasad KP' => 'vishnuprasad.mukundan@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'screenshot_kit/Sources/screenshot_kit/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {'screenshot_kit_privacy' => ['screenshot_kit/Sources/screenshot_kit/PrivacyInfo.xcprivacy']}
end
