//
//  FloodfillViewController.swift
//  colorSelection
//
//  Created by Michael Wu on 5/10/22.
//

import Foundation
import UIKit
import AVFoundation
import CoreImage

class FloodfillViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate{
    
    @IBOutlet weak var rawUIView: UIView!
    @IBOutlet weak var resultImageView: UIImageView!
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    private let context = CIContext()
    var currentFilter = ThresholdFilter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoFeed()
    }
    
    private func setupVideoFeed() {
        self.captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {return}
        let videoInput : AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            print("Failed to get input")
            return
        }
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = self.rawUIView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.opacity = 1
        self.rawUIView.layer.addSublayer(previewLayer)
        captureSession.startRunning()
    }
    
    // MARK: Sample buffer to UIImage conversion
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer).oriented(.right)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    private func inference(uiImage: UIImage) -> UIImage {
//        let ciImage = CIImage(cgImage: uiImage.cgImage!)
        currentFilter.inputImage = CIImage(image: uiImage, options: [CIImageOption.colorSpace: NSNull()])
        if let cgimg = context.createCGImage(currentFilter.outputImage!, from: currentFilter.outputImage!.extent) {
            let processedImage = UIImage(cgImage: cgimg)
            return processedImage
        }
        return uiImage
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        
        let thresholdedUIImage = self.inference(uiImage: uiImage)
        
        DispatchQueue.main.async {
            self.resultImageView.image = thresholdedUIImage
        }
        
    }
}


class ThresholdFilter: CIFilter
{
    var inputImage : CIImage?
    var threshold: Float = 0.554688 // This is set to a good value via Otsu's method

    var thresholdKernel =  CIColorKernel(source:
        "kernel vec4 thresholdKernel(sampler image, float threshold) {" +
        "  vec4 pixel = sample(image, samplerCoord(image));" +
        "  const vec3 rgbToIntensity = vec3(0.114, 0.587, 0.299);" +
        "  float intensity = dot(pixel.rgb, rgbToIntensity);" +
        "  return intensity < threshold ? vec4(0, 0, 0, 1) : vec4(1, 1, 1, 1);" +
        "}")

    override var outputImage: CIImage! {
        guard let inputImage = inputImage,
            let thresholdKernel = thresholdKernel else {
                return nil
        }
        

        let extent = inputImage.extent
        let arguments : [Any] = [inputImage, threshold]
        return thresholdKernel.apply(extent: extent, arguments: arguments)
    }
}
