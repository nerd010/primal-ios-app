//
//  SettingsMainViewController.swift
//  Primal
//
//  Created by Pavle D Stevanović on 25.5.23..
//

import UIKit

class SettingsMainViewController: UIViewController, Themeable {
    let versionLabel = UILabel()
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        updateTheme()
    }
    
    func updateTheme() {
        view.backgroundColor = .background
        
        versionLabel.textColor = .foreground
        
        navigationItem.leftBarButtonItem = customBackButton
    }
}

private extension SettingsMainViewController {
    func setupView() {
        title = "Settings"
        
        let keys = SettingsOptionButton(title: "Keys")
        let network = SettingsOptionButton(title: "Network")
        let appearance = SettingsOptionButton(title: "Appearance")
        let contentDisplay = SettingsOptionButton(title: "Content Display")
        let muted = SettingsOptionButton(title: "Muted Accounts")
        let notifications = SettingsOptionButton(title: "Notifications")
        let feeds = SettingsOptionButton(title: "Feeds")
        let wallet = SettingsOptionButton(title: "Wallet")
        let zaps = SettingsOptionButton(title: "Zaps")
        
        let versionTitleLabel = SettingsTitleView(title: "VERSION")
        
        let bottomStack = UIStackView(arrangedSubviews: [versionTitleLabel, versionLabel, UIView()])
        let stack = UIStackView(arrangedSubviews: [keys, network, appearance, contentDisplay, muted, notifications, feeds, zaps, SpacerView(height: 40), bottomStack])
        
        let scroll = UIScrollView()
        
        view.addSubview(scroll)
        scroll.pinToSuperview(edges: .horizontal).pinToSuperview(edges: .top, safeArea: true).pinToSuperview(edges: .bottom, padding: 56, safeArea: true)
        
        scroll.addSubview(stack)
        stack.pinToSuperview(edges: .horizontal, padding: 24).pinToSuperview(edges: .vertical, padding: 12)
        stack.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48).isActive = true
        stack.axis = .vertical
        stack.setCustomSpacing(12, after: versionTitleLabel)
        
        bottomStack.axis = .vertical
        bottomStack.spacing = 12
        bottomStack.isLayoutMarginsRelativeArrangement = true
        bottomStack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        versionLabel.font = .appFont(withSize: 20, weight: .bold)
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            versionLabel.text = appVersion
        } else {
            versionLabel.text = "Unknown"
        }
        
        guard LoginManager.instance.method() == .nsec else {
            [keys, feeds, appearance, contentDisplay, muted, notifications, zaps, network].forEach {
                $0.addAction(.init(handler: { [weak self] _ in
                    self?.showErrorMessage(title: "Logged in with npub", "Primal is in read only mode because you are signed in via your public key. To enable all options, please sign in with your private key, starting with 'nsec...")
                }), for: .touchUpInside)
            }
            return
        }
        
        keys.addTarget(self, action: #selector(keysPressed), for: .touchUpInside)
        feeds.addTarget(self, action: #selector(feedsPressed), for: .touchUpInside)
        
        appearance.addAction(.init(handler: { [weak self] _ in
            self?.navigationController?.pushViewController(SettingsAppearanceViewController(), animated: true)
        }), for: .touchUpInside)
        
        contentDisplay.addAction(.init(handler: { [weak self] _ in
            self?.navigationController?.pushViewController(SettingsContentDisplayController(), animated: true)
        }), for: .touchUpInside)
        
        muted.addAction(.init(handler: { [weak self] _ in
            self?.navigationController?.pushViewController(SettingsMutedViewController(), animated: true)
        }), for: .touchUpInside)
        
        notifications.addAction(.init(handler: { [weak self] _ in
            self?.navigationController?.pushViewController(SettingsNotificationsViewController(), animated: true)
        }), for: .touchUpInside)
        
        zaps.addAction(.init(handler: { [weak self] _ in
            self?.navigationController?.pushViewController(SettingsZapsViewController(), animated: true)
        }), for: .touchUpInside)
        
        network.addAction(.init(handler: { [weak self] _ in
            self?.navigationController?.pushViewController(SettingsNetworkViewController(), animated: true)
        }), for: .touchUpInside)
    }
    
    @objc func feedsPressed() {
        navigationController?.pushViewController(SettingsFeedViewController(), animated: true)
    }
    
    @objc func keysPressed() {
        navigationController?.pushViewController(SettingsNsecViewController(), animated: true)
    }
}
