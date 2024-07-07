//
//  ContentView.swift
//  LiDARViewer
//
//  Created by Shubham Patel on 07/07/2024.
//
import SwiftUI
import ARKit

struct ARViewContainer: UIViewRepresentable {
    
    @Binding var isSessionRunning: Bool
    @Binding var isSessionPaused: Bool
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARViewContainer
        var depthImageView: UIImageView
        
        init(_ parent: ARViewContainer, depthImageView: UIImageView) {
            self.parent = parent
            self.depthImageView = depthImageView
        }
        
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let arView = renderer as? ARSCNView else { return }
            guard let currentFrame = arView.session.currentFrame else { return }
            
            if let sceneDepth = currentFrame.sceneDepth {
                updateDepthImage(sceneDepth: sceneDepth)
            }
        }
        
        func updateDepthImage(sceneDepth: ARDepthData) {
            let depthMap = sceneDepth.depthMap
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
            
            let depthPointer = CVPixelBufferGetBaseAddress(depthMap)!.bindMemory(to: Float32.self, capacity: width * height)
            
            var pixelBuffer = [UInt8](repeating: 0, count: width * height)
            for y in 0..<height {
                for x in 0..<width {
                    var depth = depthPointer[y * width + x]
                    // Clamp depth to maximum 2 meters
                    depth = min(depth, 3.0)
                    let normalizedDepth = UInt8(min(max(depth * 255.0, 0), 255))
                    pixelBuffer[y * width + x] = normalizedDepth
                }
            }
            
            let colorSpace = CGColorSpaceCreateDeviceGray()
            let context = CGContext(data: &pixelBuffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue)
            if let cgImage = context?.makeImage() {
                let uiImage = UIImage(cgImage: cgImage)
                DispatchQueue.main.async {
                    self.depthImageView.image = uiImage
                    
                    // Apply the flip and rotate transformations here
                    let scaleTransform = CGAffineTransform(scaleX: 1, y: 1) // Horizontal flip
                    let rotateTransform = CGAffineTransform(rotationAngle: .pi / 2) // 90 degrees rotation
                    self.depthImageView.transform = scaleTransform.concatenating(rotateTransform)
                }
            }
        }
    }
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.delegate = context.coordinator
        arView.autoenablesDefaultLighting = true
        arView.scene = SCNScene()
        
        let depthImageView = UIImageView(frame: arView.bounds)
        depthImageView.contentMode = .scaleAspectFill
        depthImageView.transform = CGAffineTransform(scaleX: -1, y: 1) // Apply initial flip transformation
        arView.addSubview(depthImageView)
        context.coordinator.depthImageView = depthImageView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        if isSessionRunning {
            let config = ARWorldTrackingConfiguration()
            config.frameSemantics = .sceneDepth
            
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                config.frameSemantics = .sceneDepth
            }
            uiView.session.run(config)
        } else {
            uiView.session.pause()
        }
        
        if let depthImageView = uiView.subviews.first(where: { $0 is UIImageView }) as? UIImageView {
            depthImageView.frame = uiView.bounds
            depthImageView.transform = CGAffineTransform(scaleX: -1, y: 1) // Ensure the flip transformation is reapplied
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self, depthImageView: UIImageView())
    }
}

struct ContentView: View {
    @State private var isSessionRunning = false
    @State private var isSessionPaused = false
    
    var body: some View {
        VStack {
            ARViewContainer(isSessionRunning: $isSessionRunning, isSessionPaused: $isSessionPaused)
                .edgesIgnoringSafeArea(.all)
            
            HStack {
                Button(action: {
                    isSessionRunning = true
                    isSessionPaused = false
                }) {
                    Text("Start")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    isSessionRunning = false
                }) {
                    Text("Pause")
                        .padding()
                        .background(Color.yellow)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    isSessionRunning = false
                    isSessionPaused = true
                }) {
                    Text("Stop")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
