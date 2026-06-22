platform :ios, '15.0'

target 'VoiceAgent' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for VoiceAgent
  pod 'agent-client-toolkit-swift', '1.0.0'
  pod 'AgoraRtcEngine_iOS', '>= 4.5.1'
  # Use RTM lite version (RtmKit subspec) to avoid aosl.xcframework conflict with RTC SDK
  pod 'AgoraRtm', '>= 2.2.3', :subspecs => ['RtmKit']
  pod 'SnapKit'
end
