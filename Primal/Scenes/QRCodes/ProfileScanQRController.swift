//
//  ProfileScanQRController.swift
//  Primal
//
//  Created by Pavle Stevanović on 23.11.23..
//

import AVKit
import Combine
import Kingfisher
import UIKit

final class CapturePreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

final class ProfileScanQRController: UIViewController, OnboardingViewController {
    var titleLabel: UILabel = .init()
    var backButton: UIButton = .init()
    
    var captureSession = AVCaptureSession()
    var qrCodeFrameView = UIView()
    
    let previewView = CapturePreviewView()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { previewView.previewLayer }
    
    var didOpenQRCode = false
    
    let action = QRCodeActionButton("View QR Code")
    
    private var cancellables: Set<AnyCancellable> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setup()
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera, .builtInDualCamera, .builtInDualWideCamera], mediaType: AVMediaType.video, position: .back)

        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Failed to get the camera device")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(input)
        } catch {
            print(error)
            return
        }
        
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(captureMetadataOutput)

        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    func search(_ text: String) {
        guard !didOpenQRCode else { return }
        
        let text: String = String(text.split(separator: ":").last ?? "") // Eliminate junk text ("nostr:", etc.)
        
        guard text.hasPrefix("npub"), let pubkey = HexKeypair.npubToHexPubkey(text) else { return }
        
        didOpenQRCode = true
        
        (onboardingParent as? ProfileQRController)?.isOpeningProfileScreen = true
        navigationController?.pushViewController(ProfileViewController(profile: .init(data: .init(pubkey: pubkey))), animated: true)
    }
}

extension ProfileScanQRController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            qrCodeFrameView.frame = CGRect.zero
            return
        }
        
        guard
            metadataObj.type == AVMetadataObject.ObjectType.qr
        else { return }
                
        if let barCodeObject = videoPreviewLayer.transformedMetadataObject(for: metadataObj) {
            qrCodeFrameView.frame = barCodeObject.bounds
        }

        if let text = metadataObj.stringValue {
            search(text)
        }
    }
}


private extension ProfileScanQRController {
    func setup() {
        addBackground(2)
        addNavigationBar("Scan QR Code")
        
        let descLabel = UILabel()
        descLabel.text = "Scan a user’s QR code to find them on Nostr"
        descLabel.textAlignment = .center
        descLabel.font = .appFont(withSize: 18, weight: .regular)
        descLabel.textColor = .white
        descLabel.numberOfLines = 0
        
        videoPreviewLayer.session = captureSession
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.masksToBounds = true
        videoPreviewLayer.borderColor = UIColor.white.cgColor
        videoPreviewLayer.borderWidth = 4
        videoPreviewLayer.cornerRadius = 16
        
        let mainStack = UIStackView(axis: .vertical, [previewView.constrainToSize(280), SpacerView(height: 16), descLabel])
        descLabel.pinToSuperview(edges: .horizontal, padding: 40)
        mainStack.alignment = .center
        view.addSubview(mainStack)
        mainStack.centerToSuperview().constrainToSize(width: 280)
        
        view.addSubview(action)
        action.pinToSuperview(edges: .horizontal, padding: 35).pinToSuperview(edges: .bottom, padding: 60, safeArea: true)
        
        qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
        qrCodeFrameView.layer.borderWidth = 2
        previewView.addSubview(qrCodeFrameView)
        
        action.addAction(.init(handler: { [weak self] _ in
            guard let self else { return }
            self.onboardingParent?.popViewController(animated: true)
        }), for: .touchUpInside)
    }
}
