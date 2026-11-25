#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cunning_document_scanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'goapptiv_document_scanner'
  s.version          = '2.0.0'
  s.summary          = 'Goapptiv Document Scanner.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Goapptiv' => 'BiswajitP' }
  s.source           = { :path => '.' }
  # Shared with the Swift package in goapptiv_document_scanner/.
  s.source_files = 'goapptiv_document_scanner/Sources/goapptiv_document_scanner/**/*.swift'
  s.resource_bundles = {
    'goapptiv_document_scanner_privacy' => ['goapptiv_document_scanner/Sources/goapptiv_document_scanner/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.frameworks = 'AVFoundation', 'Vision', 'CoreImage'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.ios.deployment_target = '15.0'
end
