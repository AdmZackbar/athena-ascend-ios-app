//
//  AudioManager.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/24/26.
//

import Foundation
import AVFoundation
import AudioToolbox

class AudioManager: Observable {
    static let shared = AudioManager()
    
    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure and activate AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    func playSystemSound(_ id: SystemSoundID) {
        // This targets the configured AVAudioSession instead of the native hardware layer
        AudioServicesPlaySystemSound(id)
    }
    
    func playSystemSoundWithCompletion(_ id: SystemSoundID, completion: @escaping () -> Void) {
        AudioServicesPlaySystemSoundWithCompletion(id) {
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
