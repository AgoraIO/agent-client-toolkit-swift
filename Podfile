platform :ios, '15.0'

target 'VoiceAgent' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Toolkit dependency for local development.
  pod 'agent-client-toolkit-swift', :path => './AgoraAgentClientToolkit'

  # Published pod verification: comment the local path pod above, then
  # uncomment this line after agent-client-toolkit-swift 2.11.0 is available
  # in the CocoaPods specs repo used by your Podfile.
  # pod 'agent-client-toolkit-swift', '2.11.0'

  pod 'AgoraRtcEngine_iOS', '4.5.1'
  # Use RTM lite version (RtmKit subspec) to avoid aosl.xcframework conflict with RTC SDK
  pod 'AgoraRtm', '2.2.3', :subspecs => ['RtmKit']
  pod 'SnapKit'
end

post_install do |installer|
  minimum_ios_version = Gem::Version.new('15.0')

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |configuration|
      deployment_target = configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
      if deployment_target && Gem::Version.new(deployment_target) < minimum_ios_version
        configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = minimum_ios_version.to_s
      end
    end
  end
end
