//
//  OnboardingProfileImageView.swift
//  Primal
//
//  Created by Pavle Stevanović on 16.11.23..
//

import UIKit
import FLAnimatedImage

final class OnboardingProfileImageView: FLAnimatedImageView {
    init() {
        super.init(frame: .zero)
        image = UIImage(named: "onboardingDefaultAvatar")
        
        constrainToSize(108)
        layer.cornerRadius = 54
        layer.masksToBounds = true
        layer.borderWidth = 3
        layer.borderColor = UIColor.white.cgColor
        contentMode = .scaleAspectFill
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class OnboardingProfileInfoView: UIStackView {
    let image = OnboardingProfileImageView()
    let name = UILabel()
    let address = UILabel()
    
    init() {
        super.init(frame: .zero)
        [image, SpacerView(height: 12, priority: .defaultLow), name, SpacerView(height: 4, priority: .defaultLow), address].forEach { addArrangedSubview($0) }
        axis = .vertical
        alignment = .center
        
        name.font = .appFont(withSize: 24, weight: .bold)
        address.font = .appFont(withSize: 18, weight: .regular)
        name.textColor = .white
        address.textColor = .white
        
        [name, address].forEach { $0.setContentCompressionResistancePriority(.required, for: .vertical) }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
