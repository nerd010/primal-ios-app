//
//  LargeRoundedButton.swift
//  Primal
//
//  Created by Pavle Stevanović on 23.10.23..
//

import UIKit

final class LargeRoundedButton: MyButton, Themeable {
    private let label = UILabel()
    
    var title: String {
        didSet {
            label.text = title
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            updateTheme()
        }
    }
    
    override var isPressed: Bool {
        didSet {
            updateTheme()
        }
    }
    
    init(title: String) {
        self.title = title
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateTheme() {
        backgroundColor = isEnabled ? .accent : .background3
        label.textColor = isEnabled ? (isPressed ? .white.withAlphaComponent(0.6) : .white) : .foreground5
    }
}

private extension LargeRoundedButton {
    func setup() {
        updateTheme()
        
        addSubview(label)
        label.text = title
        label.font = .appFont(withSize: 18, weight: .medium)
        label.centerToSuperview()
        
        constrainToSize(height: 58)
        layer.cornerRadius = 29
    }
}
