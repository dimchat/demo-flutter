#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint dim_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
    s.name                  = 'dim_flutter'
    s.version               = '0.0.1'
    s.summary               = 'DIM Client'
    s.description           = <<-DESC
            Flutter Channels for DIM Client
                                DESC
    s.homepage              = 'https://github.com/dimchat/demo-flutter'
    s.license               = { :file => '../LICENSE' }
    s.author                = { 'Albert Moky' => 'albert.moky@gmail.com' }
    s.social_media_url      = "https://twitter.com/AlbertMoky"
    s.source                = { :git => 'https://github.com/dimchat/demo-flutter.git', :tag => s.version.to_s }
    # s.platform            = :ios, "11.0"
    s.ios.deployment_target = '12.0'

    s.source_files          = 'Classes', 'Classes/**/*.{h,m}'
    s.public_header_files   = 'Classes/**/*.h'

    s.dependency 'Flutter'
    s.dependency 'ObjectKey', '~> 0.1.3'
    s.dependency 'DIMSDK', '~> 0.7.2'
    s.dependency 'DIMPlugins', '~> 0.7.2'

    # Flutter.framework does not contain a i386 slice.
    s.pod_target_xcconfig   = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
