//
//  ViewController.swift
//  colorSelection
//
//  Created by Michael Wu on 4/1/22.
//

import UIKit
import AVFoundation
class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate{
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var colorLabel: UILabel!
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    private let context = CIContext()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoFeed()
        print("Setup done")
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
        previewLayer.frame = self.cameraView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.opacity = 1
        cameraView.layer.addSublayer(previewLayer)
        captureSession.startRunning()
    }
    // MARK: Sample buffer to UIImage conversion
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        let size = uiImage.size
        let color = uiImage.getAveragePixelValuesAroundPosition(position: CGPoint(x: size.width/2, y: size.height/2), n: 2)
        let redUint = color.redUInt; let greenUint = color.greenUInt; let blueUint = color.blueUInt
        
        DispatchQueue.main.async {
            self.colorLabel.text = "\(redUint),\(greenUint),\(blueUint)"
            // set text color so that our text will not "fade" into the background
            self.colorLabel.textColor = UIColor(red: 1-color.redValue,
                                                green: 1-color.greenValue,
                                                blue: 1-color.blueValue,
                                                alpha: 1)
            self.colorLabel.backgroundColor = color
        }
        
    }
    
    
    

}

//On the top of your swift
extension UIImage {
    // returns average pixel values of a bbox nxn around center point position
    func getAveragePixelValuesAroundPosition(position: CGPoint, n: Int)->UIColor{
        let s = abs(n) // only positive values
        
        let minx = Int(max(0, Int(position.x) - s))
        let miny = Int(max(0, Int(position.y) - s))
        let maxx = Int(min(self.size.width, position.x + CGFloat(s)))
        let maxy = Int(min(self.size.height, position.y + CGFloat(s)))
        
        var r_cum:CGFloat = 0;
        var g_cum:CGFloat = 0;
        var b_cum:CGFloat = 0;
        var count:CGFloat = 0
        for x in minx...maxx{
            for y in miny...maxy{
                let color = getPixelColor(pos: CGPoint(x: x, y: y))
                r_cum += color.redValue; g_cum += color.greenValue; b_cum += color.blueValue
                count += 1
            }
        }
        
        let redVal = r_cum / count
        let greenVal = g_cum / count
        let blueVal = b_cum / count
        
        return UIColor(red: redVal, green: greenVal, blue: blueVal, alpha: 1)
    }
    func getPixelColor(pos: CGPoint) -> UIColor {

        let pixelData = self.cgImage!.dataProvider!.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)

        let pixelInfo: Int = ((Int(self.size.width) * Int(pos.y)) + Int(pos.x)) * 4

        let r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
        let g = CGFloat(data[pixelInfo+1]) / CGFloat(255.0)
        let b = CGFloat(data[pixelInfo+2]) / CGFloat(255.0)
        let a = CGFloat(data[pixelInfo+3]) / CGFloat(255.0)

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
extension UIColor {
    var redValue: CGFloat{ return CIColor(color: self).red }
    var greenValue: CGFloat{ return CIColor(color: self).green }
    var blueValue: CGFloat{ return CIColor(color: self).blue }
    var alphaValue: CGFloat{ return CIColor(color: self).alpha }
    
    var redUInt: UInt8{ return UInt8(redValue * 255) }
    var greenUInt: UInt8{ return UInt8(greenValue * 255) }
    var blueUInt: UInt8{ return UInt8(blueValue * 255) }
}
