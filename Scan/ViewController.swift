import UIKit
import AVFoundation
import CoreML
import Vision


class ViewController: UIViewController , AVCapturePhotoCaptureDelegate {
    
    @IBOutlet weak var cameraView: UIView! // Connect your UIView from the storyboard
    // Connect your UILabel
    
    let instruction : [String] = ["1. Snap The whole Plant" , "2. Snap the infected area" , "3. Now take the same with different angle"]
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var photoOutput: AVCapturePhotoOutput!
    @IBOutlet weak var instructionLabel: UILabel!
    
    @IBOutlet weak var snapImage1: UIImageView!
    
    @IBOutlet weak var snapImage2: UIImageView!
    
    @IBOutlet weak var snapImage3: UIImageView!
    
    @IBOutlet weak var resultLabel: UILabel!
    
    var model: VNCoreMLModel?
    var counter : Int = 0
    var capturedImages: [UIImage] = []
    var predictions: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        instructionLabel.text = instruction[0]
        if #available(iOS 17.0, *) {
            loadModel()
        } else {
            // Fallback on earlier versions
        }
    }
    @available(iOS 17.0, *)
    func loadModel() {
        do {
            let config = MLModelConfiguration()
            let modelInstance = try plantclassify(configuration: config) // ✅ Correct way to load the model
            model = try VNCoreMLModel(for: modelInstance.model) // ✅ Converts it for Vision framework
        } catch {
            print("Error loading ML model: \(error.localizedDescription)")
        }
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Error: No camera available.")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            photoOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            } else {
                fatalError("Unable to add photo output.")
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = cameraView.bounds
            cameraView.layer.insertSublayer(previewLayer, at: 0)
            
            captureSession.startRunning()
        } catch {
            print("Error setting up the camera: \(error.localizedDescription)")
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = cameraView.bounds
    }
    
    @IBAction func captureImage(_ sender: UIButton) {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let photoData = photo.fileDataRepresentation() else {
            print("Error capturing photo: \(String(describing: error))")
            return
        }
        
        if let capturedImage = UIImage(data: photoData) {
            if counter == 0 {
                snapImage1.image = capturedImage
                resultViewController.image = capturedImage
                instructionLabel.text = instruction[counter + 1]
            } else if counter == 1 {
                snapImage2.image = capturedImage
                instructionLabel.text = instruction[counter + 1]
            } else if counter == 2 {
                snapImage3.image = capturedImage
                instructionLabel.text = "3 images done"
            } else if counter > 2 {
                instructionLabel.text = "Done"
            }
            
            counter += 1
            capturedImages.append(capturedImage)
        }
        
        if counter == 3 {
            classifyAllImages()
        }
    }
    
    func classifyAllImages() {
        predictions = []
        let group = DispatchGroup()
        
        for image in capturedImages {
            group.enter()
            classifyImage(image) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let finalPrediction = self.mostCommonPrediction()
            resultViewController.result = "Result: \(finalPrediction)"
            self.resultLabel.text = "Result: \(finalPrediction)"
//            print("Final Prediction: \(finalPrediction)")
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
                   if let resultVC = storyboard.instantiateViewController(withIdentifier: "ResultViewController") as? resultViewController {
//                       resultVC.finalResult = finalPrediction // Pass data to new VC
                       self.navigationController?.pushViewController(resultVC, animated: true)
                   }
        }
    }
    
    func classifyImage(_ image: UIImage, completion: @escaping () -> Void) {
        guard let model = model, let ciImage = CIImage(image: image) else {
            completion()
            return
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNClassificationObservation],
                  let topResult = results.first else {
                completion()
                return
            }
            
            DispatchQueue.main.async {
                self.predictions.append(topResult.identifier)
                completion()
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try? handler.perform([request])
    }
    
    func mostCommonPrediction() -> String {
        let frequency = Dictionary(grouping: predictions, by: { $0 }).mapValues { $0.count }
        return frequency.max { $0.value < $1.value }?.key ?? "Unknown"
    }
}
