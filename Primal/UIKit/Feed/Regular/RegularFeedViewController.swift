//
//  RegularFeedViewController.swift
//  Primal
//
//  Created by Pavle D Stevanović on 20.6.23..
//

import UIKit

final class RegularFeedViewController: PostFeedViewController {
    
    let addFeedButton = UIButton()
    let loadingSpinner = LoadingSpinnerView()
    
    var feedHex: String { "search;\(feed.searchTerm ?? "")" }
    var didAddToFeed: Bool {
        let hex = feedHex
        return IdentityManager.instance.userSettings?.content.feeds?.contains(where: { $0.hex == hex }) ?? false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let search = feed.searchTerm {
            title = "Search: \(search)"
        } else {
            title = "Search"
        }
        
        addFeedButton.setImage(UIImage(named: "addFeed"), for: .normal)
        addFeedButton.addTarget(self, action: #selector(addFeedButtonPressed), for: .touchUpInside)
        addFeedButton.constrainToSize(44)
        navigationItem.rightBarButtonItem = .init(customView: addFeedButton)
        
        feed.$parsedPosts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] posts in
                self?.posts = posts
                if posts.isEmpty {
                    self?.loadingSpinner.isHidden = false
                    self?.loadingSpinner.play()
                } else {
                    self?.loadingSpinner.isHidden = true
                    self?.loadingSpinner.stop()
                }
            }
            .store(in: &cancellables)
        
        view.addSubview(loadingSpinner)
        loadingSpinner.centerToSuperview().constrainToSize(100)
        
        updateTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: animated)
        
        view.bringSubviewToFront(loadingSpinner)
        loadingSpinner.play()
    }
    
    override func updateTheme() {
        super.updateTheme()
        
        navigationItem.leftBarButtonItem = customBackButton
        
        addFeedButton.tintColor = .foreground3
    }
    
    @objc func addFeedButtonPressed() {
        guard let search = feed.searchTerm else { return }

        if didAddToFeed {
            view.showToast("Feed is already in your home feeds")
        } else {
            if search.hasPrefix("#") {
                IdentityManager.instance.addFeedToList(feed: .init(name: search, hex: feedHex))
            } else {
                IdentityManager.instance.addFeedToList(feed: .init(name: "Search: \(search)", hex: feedHex))
            }
            hapticGenerator.impactOccurred()
            
            view.showUndoToast("Added to your home feeds") { [weak self] in
                guard let self = self else { return }
                IdentityManager.instance.removeFeedFromList(hex: self.feedHex)
            }
        }
    }
}
