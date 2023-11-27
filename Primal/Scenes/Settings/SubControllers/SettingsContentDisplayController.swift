//
//  SettingsContentDisplayController.swift
//  Primal
//
//  Created by Pavle Stevanović on 14.11.23..
//

import UIKit

extension String {
    static let autoPlayVideosKey = "autoPlayVideosKey"
    static let animatedAvatarsKey = "animatedAvatarsKey"
    static let fullScreenFeedKey = "fullScreenFeedKey"
    static let autoDarkModeKey = "autoDarkModeKey"
}

struct ContentDisplaySettings {
    static var autoPlayVideos: Bool {
        get { UserDefaults.standard.bool(forKey: .autoPlayVideosKey) }
        set { UserDefaults.standard.set(newValue, forKey: .autoPlayVideosKey) }
    }
    
    static var animatedAvatars: Bool {
        get { UserDefaults.standard.bool(forKey: .animatedAvatarsKey) }
        set { UserDefaults.standard.set(newValue, forKey: .animatedAvatarsKey) }
    }
    
    
    static var fullScreenFeed: Bool {
        get { UserDefaults.standard.bool(forKey: .fullScreenFeedKey) }
        set { UserDefaults.standard.set(newValue, forKey: .fullScreenFeedKey) }
    }
    
    
    static var autoDarkMode: Bool {
        get { UserDefaults.standard.bool(forKey: .autoDarkModeKey) }
        set { UserDefaults.standard.set(newValue, forKey: .autoDarkModeKey) }
    }
}

final class SettingsContentDisplayController: UIViewController, Themeable {
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    func updateTheme() {
        view.backgroundColor = .background
        navigationItem.leftBarButtonItem = customBackButton
    }
}

private extension SettingsContentDisplayController {
    func setup() {
        title = "Content Display"
        
        let autoplay = SettingsSwitchView("Auto play videos")
        let animatedAvatars = SettingsSwitchView("Show animated avatars")
        let fullScreenFeed = SettingsSwitchView("Full screen feed display")
        
        let stack = UIStackView(axis: .vertical, [
            autoplay, SpacerView(height: 10),
            descLabel("Start playing videos automatically as you scroll the feed. Turn this off to use less network data."), SpacerView(height: 32),
            animatedAvatars, SpacerView(height: 10),
            descLabel("Switch off to disable animated avatars in feeds. Profile will continue to show the full version."), SpacerView(height: 32),
            fullScreenFeed, SpacerView(height: 10),
            descLabel("Maximize screen real estate by hiding app header & footer as you scroll down the feed."), SpacerView(height: 32),
        ])
        
        let scroll = UIScrollView()
        view.addSubview(scroll)
        scroll
            .pinToSuperview(edges: .horizontal)
            .pinToSuperview(edges: .bottom, padding: 56, safeArea: true)
            .pinToSuperview(edges: .top, padding: 7, safeArea: true)
        
        scroll.addSubview(stack)
        stack.pinToSuperview(edges: .horizontal, padding: 20).pinToSuperview(edges: .vertical, padding: 38)
        stack.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40).isActive = true
        
        updateTheme()
        
        autoplay.switchView.isOn = ContentDisplaySettings.autoPlayVideos
        animatedAvatars.switchView.isOn = ContentDisplaySettings.animatedAvatars
        fullScreenFeed.switchView.isOn = ContentDisplaySettings.fullScreenFeed
        
        autoplay.switchView.addAction(.init(handler: { [weak autoplay] _ in
            guard let value = autoplay?.switchView.isOn else { return }
            ContentDisplaySettings.autoPlayVideos = value
        }), for: .valueChanged)
        
        animatedAvatars.switchView.addAction(.init(handler: { [weak animatedAvatars] _ in
            guard let value = animatedAvatars?.switchView.isOn else { return }
            ContentDisplaySettings.animatedAvatars = value
            ThemingManager.instance.themeDidChange()
        }), for: .valueChanged)
        
        fullScreenFeed.switchView.addAction(.init(handler: { [weak fullScreenFeed] _ in
            guard let value = fullScreenFeed?.switchView.isOn else { return }
            ContentDisplaySettings.fullScreenFeed = value
        }), for: .valueChanged)
    }
    
    func descLabel(_ text: String) -> UILabel {
        let label = ThemeableLabel().setTheme { $0.textColor = .foreground3 }
        label.text = text
        label.font = .appFont(withSize: 14, weight: .regular)
        label.numberOfLines = 0
        return label
    }
}

final class SettingsSwitchView: UIView, Themeable {
    let switchView = UISwitch()
    let label = UILabel()
    
    init(_ text: String) {
        super.init(frame: .zero)
        
        updateTheme()
        
        label.font = .appFont(withSize: 16, weight: .regular)
        label.text = text
        
        let stack = UIStackView([label, UIView(), switchView])
        stack.alignment = .center
        
        addSubview(stack)
        stack.pinToSuperview(edges: .horizontal, padding: 16).centerToSuperview()
        
        layer.cornerRadius = 12
        constrainToSize(height: 48)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateTheme() {
        backgroundColor = .background3
        label.textColor = .foreground
    }
}
