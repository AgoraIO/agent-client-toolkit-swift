platform :ios, '15.0'

target 'VoiceAgent' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Toolkit dependency for local development.
  pod 'agent-client-toolkit-swift', :path => './AgoraAgentClientToolkit'

  # Published pod verification: comment the local path pod above, then
  # uncomment this line after agent-client-toolkit-swift 2.9.0 is available
  # in the CocoaPods specs repo used by your Podfile.
  # pod 'agent-client-toolkit-swift', '2.9.0'

  pod 'AgoraRtcEngine_iOS', '4.5.1'
  # Use RTM lite version (RtmKit subspec) to avoid aosl.xcframework conflict with RTC SDK
  pod 'AgoraRtm', '2.2.3', :subspecs => ['RtmKit']
  pod 'SnapKit'
end
