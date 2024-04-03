//
//  AudioSpatializer.swift
//  SpatialAudio
//
//  Created by 김호성 on 2024.04.03.
//

import PHASE
import AVFoundation
import CoreMotion
import UIKit

class AudioSpatializer: ObservableObject {
    
    private let phaseEngine = PHASEEngine(updateMode: .automatic)
    private let audioFileUrl =  Bundle.main.url(forResource: "ping", withExtension: "mp3")
    private let motionManager = CMHeadphoneMotionManager()
    private var referenceFrame = matrix_identity_float4x4
    private let mixerParameters = PHASEMixerParameters()
    private var soundEvent: PHASESoundEvent
    
    init() {
        let channelLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!
        let soundAsset = try! phaseEngine.assetRegistry.registerSoundAsset(url: audioFileUrl!, identifier: "ping", assetType: .resident, channelLayout: channelLayout, normalizationMode: .dynamic)
        
        let spatialPipeline = PHASESpatialPipeline(flags: [.directPathTransmission, .lateReverb])!
        spatialPipeline.entries[PHASESpatialCategory.lateReverb]!.sendLevel = 0.1;
        phaseEngine.defaultReverbPreset = .mediumRoom
        
        let spatialMixerDefinition = PHASESpatialMixerDefinition(spatialPipeline: spatialPipeline)

        let distanceModelParameters = PHASEGeometricSpreadingDistanceModelParameters()
        distanceModelParameters.fadeOutParameters = PHASEDistanceModelFadeOutParameters(cullDistance: 10.0)
        distanceModelParameters.rolloffFactor = 1.0
        spatialMixerDefinition.distanceModelParameters = distanceModelParameters
        
        let samplerNodeDefinition = PHASESamplerNodeDefinition(soundAssetIdentifier: "ping", mixerDefinition:spatialMixerDefinition)
        samplerNodeDefinition.playbackMode = .looping
//        samplerNodeDefinition.playbackMode = .oneShot
        samplerNodeDefinition.setCalibrationMode(calibrationMode: .relativeSpl, level: 12)
        samplerNodeDefinition.cullOption = .sleepWakeAtRealtimeOffset;
        
        let soundEventAsset = try! phaseEngine.assetRegistry.registerSoundEventAsset(rootNode:samplerNodeDefinition, identifier: "pingevent")
        
        let listener = PHASEListener(engine: phaseEngine)
        listener.transform = referenceFrame
        try! phaseEngine.rootObject.addChild(listener)
        
        let mesh = MDLMesh.newIcosahedron(withRadius: 0.0142, inwardNormals: false, allocator:nil)
        let shape = PHASEShape(engine: phaseEngine, mesh: mesh)
        let source = PHASESource(engine: phaseEngine, shapes: [shape])
        var sourceTransform: simd_float4x4 = simd_float4x4()
        sourceTransform.columns.0 = simd_make_float4(-1.0, 0.0, 0.0, 0.0)
        sourceTransform.columns.1 = simd_make_float4(0.0, 1.0, 0.0, 0.0)
        sourceTransform.columns.2 = simd_make_float4(0.0, 0.0, -1.0, 0.0)
        sourceTransform.columns.3 = simd_make_float4(0.0, 0.0, 2.0, 1.0)
        
        source.transform = sourceTransform;
        try! phaseEngine.rootObject.addChild(source)
        // ===================================================================
        /*
        // Create a streaming node from AudioKit and hook it into the downstream Channel Mixer.
        let pushNodeDefinition = PHASEPushStreamNodeDefinition(mixerDefinition: mixer, format: AVAudioFormat(standardFormatWithSampleRate: 44100, channelLayout: AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!), identifier: "audioStream")
        // Set the Push Node's Calibration Mode to Relative SPL and Level to 0 dB.
        pushNodeDefinition.setCalibrationMode(calibrationMode: .relativeSpl, level: 0)
        // Register a Sound Event Asset with the Engine named "audioStreamEvent".
        try! phaseEngine.assetRegistry.registerSoundEventAsset(rootNode: pushNodeDefinition, identifier: "audioStreamEvent")
        // Settings for audio player
        player?.isLooping = true
        player?.isBuffered = true
        // Initialize tap with some settings
        myTap = PhaseTap(akNode, bufferSize: 2048, callbackQueue: .main)
        // Associate the Source and Listener with the Spatial Mixer in the Sound Event.
        let mixerParameters = PHASEMixerParameters()
        mixerParameters.addSpatialMixerParameters(identifier: mixer.identifier, source: source, listener: listener)
        // Create a Sound Event from the built Sound Event Asset "audioStreamEvent".
        let streamSoundEvent = try! PHASESoundEvent(engine: phaseEngine, assetIdentifier: "audioStreamEvent", mixerParameters: mixerParameters)
        // Start the engines and AudioKit's audio player.
        // This will internally start the Audio IO Thread.
        myTap.pushNode = streamSoundEvent.pushStreamNodes["audioStream"]
        try! akEngine.start()
        try! phaseEngine.start()
        player!.play()
        // Start the Sound Event and streaming.
        streamSoundEvent.start()
        myTap.start()
        // Get data from the AirPods pro for panning the listener (if it's available)
         */
        mixerParameters.addSpatialMixerParameters(identifier: spatialMixerDefinition.identifier, source: source, listener: listener)
        soundEvent = try! PHASESoundEvent(engine: phaseEngine, assetIdentifier: "pingevent", mixerParameters: mixerParameters)
        
        // Start the Engine.
        // This will internally start the Audio IO Thread.
        try! phaseEngine.start()
        
        // Start the Sound Event.
        soundEvent.start()
        
        
        
        if motionManager.isDeviceMotionAvailable && !motionManager.isDeviceMotionActive {
            motionManager.startDeviceMotionUpdates(to: .main) { [self] deviceMotion, error in
                if let deviceMotion = deviceMotion {
                    let rotation = float4x4(rotationMatrix: deviceMotion.attitude.rotationMatrix)
                    let mirrorTransform = simd_float4x4([
                        simd_float4(-1.0, 0.0, 0.0, 0.0),
                        simd_float4( 0.0, 1.0, 0.0, 0.0),
                        simd_float4( 0.0, 0.0, 1.0, 0.0),
                        simd_float4( 0.0, 0.0, 0.0, 1.0)
                    ])
                    print("============================")
                    print(rotation.columns.0)
                    print(rotation.columns.1)
                    print(rotation.columns.2)
                    print(rotation.columns.3)
                    listener.transform = mirrorTransform * rotation * self.referenceFrame
                }
            }
        }
        
    }
    
    deinit {
        soundEvent.stopAndInvalidate()
        
        phaseEngine.stop()
        phaseEngine.assetRegistry.unregisterAsset(identifier: "pingevent")
        phaseEngine.assetRegistry.unregisterAsset(identifier: "ping")
    }
}
