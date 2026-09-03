#!/usr/bin/env swift

import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: video-to-gif.swift INPUT.mov OUTPUT.gif\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let asset = AVURLAsset(url: inputURL)
let duration = CMTimeGetSeconds(asset.duration)
guard duration.isFinite, duration > 0 else {
    fputs("Could not read the video duration.\n", stderr)
    exit(1)
}

let framesPerSecond = 15.0
let frameCount = max(1, Int(duration * framesPerSecond))
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = CGSize(width: 720, height: 220)
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.gif.identifier as CFString,
    frameCount,
    nil
) else {
    fputs("Could not create the GIF destination.\n", stderr)
    exit(1)
}

CGImageDestinationSetProperties(destination, [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
] as CFDictionary)

let frameProperties = [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / framesPerSecond]
] as CFDictionary

for index in 0..<frameCount {
    let seconds = min(duration, Double(index) / framesPerSecond)
    let time = CMTime(seconds: seconds, preferredTimescale: 600)
    do {
        let image = try generator.copyCGImage(at: time, actualTime: nil)
        CGImageDestinationAddImage(destination, image, frameProperties)
    } catch {
        fputs("Could not extract frame \(index): \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

guard CGImageDestinationFinalize(destination) else {
    fputs("Could not finalize the GIF.\n", stderr)
    exit(1)
}

print(outputURL.path)
