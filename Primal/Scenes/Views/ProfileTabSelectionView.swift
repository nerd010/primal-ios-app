//
//  ProfileTabSelectionView.swift
//  Primal
//
//  Created by Pavle Stevanović on 8.11.23..
//

import Combine
import UIKit

final class ProfileTabSelectionView: UIView {
    private(set) var buttons: [ProfileTabSelectionButton] = []
    private let selectionIndicator = ThemeableView().constrainToSize(height: 4).setTheme { $0.backgroundColor = .accent }
    
    @Published private(set) var selectedTab = 0
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(tabs: [String] = []) {
        super.init(frame: .zero)
        
        buttons = tabs.map { ProfileTabSelectionButton(text: $0) }
        for (index, button) in buttons.enumerated() {
            button.addAction(.init(handler: { [weak self] _ in
                self?.selectedTab = index
            }), for: .touchUpInside)
        }
            
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(_ tab: Int) {
        guard selectedTab != tab else { return }
        selectedTab = tab
    }
}

private extension ProfileTabSelectionView {
    func setup() {
        let stack = UIStackView(arrangedSubviews: buttons)
        addSubview(stack)
        stack.pinToSuperview(edges: [.horizontal, .top], padding: 8).pinToSuperview(edges: .bottom, padding: 16)
        stack.distribution = .fillEqually
        stack.spacing = 10
        
        selectionIndicator.layer.cornerRadius = 2
        
        $selectedTab.dropFirst().removeDuplicates().sink { [weak self] newTab in
            self?.setTab(newTab, animated: true)
        }
        .store(in: &cancellables)
        
        setTab(0)
    }
    
    func setTab(_ index: Int, animated: Bool = false) {
        guard let button = buttons[safe: index] else { return }
        selectionIndicator.removeFromSuperview()
        addSubview(selectionIndicator)
        selectionIndicator.pin(to: button, edges: .horizontal).pinToSuperview(edges: .bottom, padding: 4)
        
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.layoutSubviews()
            }
        }
    }
}

final class ProfileTabSelectionButton: MyButton, Themeable {
    
    private let titleLabel = UILabel()
    private let infoLabel = UILabel()
    
    var text: String {
        get { infoLabel.text ?? "" }
        set { infoLabel.text = newValue }
    }
    
    init(text: String) {
        super.init(frame: .zero)
        
        let stack = UIStackView(arrangedSubviews: [infoLabel, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        
        infoLabel.font  = .appFont(withSize: 24, weight: .regular)
        infoLabel.text = "0"
        
        titleLabel.font = .appFont(withSize: 14, weight: .regular)
        titleLabel.text = text
        
        addSubview(stack)
        stack.pinToSuperview()
        
        updateTheme()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateTheme() {
        infoLabel.textColor = .foreground
        titleLabel.textColor = .foreground5
    }
}
