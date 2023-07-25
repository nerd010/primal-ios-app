//
//  HomeFeedViewController.swift
//  Primal
//
//  Created by Pavle D Stevanović on 3.5.23..
//

import Combine
import UIKit

final class HomeFeedViewController: PostFeedViewController {
    
    let loadingSpinner = LoadingSpinnerView()
    let feedButton = UIButton()
    
    var onLoad: (() -> ())? {
        didSet {
            if !posts.isEmpty, let onLoad {
                DispatchQueue.main.async {
                    onLoad()
                    self.onLoad = nil
                }
            }
        }
    }
    
    let refresh = UIRefreshControl()
    let newPostsView = NewPostsButton()
    
    var newAddedPosts = 0 {
        didSet {
            updatePosts(oldValue + newPostObjects.count)
        }
    }
    
    var newPostObjects: [ParsedContent] = [] {
        didSet {
            updatePosts(newAddedPosts + oldValue.count)
        }
    }
    
    var newPosts: Int { newAddedPosts + newPostObjects.count }
    
    func updatePosts(_ oldValue: Int) {
        if newPosts != 0 {
            newPostsView.setCount(newPosts, avatarURLs: (newPostObjects + posts).prefix(3).compactMap { $0.user.profileImage.url(for: .small) })
        }
        
        if newPosts == 0 {
            UIView.animate(withDuration: 0.3) {
                self.newPostsView.transform = .init(translationX: 0, y: -100)
                self.newPostsView.alpha = 0.3
            }
        } else if oldValue == 0 {
            UIView.animate(withDuration: 0.9, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0) {
                self.newPostsView.transform = .identity
                self.newPostsView.alpha = 1
            }
        }
    }
    
    private var foregroundObserver: NSObjectProtocol?
    
    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Latest with Replies"
        
        feedButton.constrainToSize(44)
        feedButton.addTarget(self, action: #selector(openFeedSelection), for: .touchUpInside)
        feedButton.setImage(UIImage(named: "feedPicker"), for: .normal)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: feedButton)
        
        view.addSubview(loadingSpinner)
        loadingSpinner.centerToSuperview().constrainToSize(100)
        
        let postButton = UIButton()
        postButton.setImage(UIImage(named: "AddPost"), for: .normal)
        postButton.addTarget(self, action: #selector(postPressed), for: .touchUpInside)
        
        view.addSubview(postButton)
        postButton.constrainToSize(56).pinToSuperview(edges: [.trailing, .bottom], padding: 8, safeArea: true)
        
        view.addSubview(newPostsView)
        newPostsView.pinToSuperview(edges: .top, padding: 47, safeArea: true).centerToSuperview(axis: .horizontal)
        newPostsView.transform = .init(translationX: 0, y: -100)
        
        newPostsView.addAction(.init(handler: { [weak self] _ in
            guard let self, !self.posts.isEmpty else { return }
            
            if !newPostObjects.isEmpty {
                self.feed.parsedPosts.insert(contentsOf: newPostObjects, at: 0)
                newPostObjects = []
            }
            self.newAddedPosts = 0
            
            self.table.scrollToRow(at: IndexPath(row: 0, section: self.postSection), at: .top, animated: true)
        }), for: .touchDown)
        
        updateTheme()
        
        refresh.addAction(.init(handler: { [weak self] _ in
            self?.feed.refresh()
        }), for: .valueChanged)
        refresh.tintColor = .accent
        table.addSubview(refresh)
     
        setupPublishers()
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
    
    @objc func openFeedSelection() {
        present(FeedsSelectionController(feed: feed), animated: true)
    }
    
    @objc func postPressed() {
        present(NewPostViewController(), animated: true)
    }
    
    override func updateTheme() {
        super.updateTheme()
        
        feedButton.backgroundColor = .background
        feedButton.tintColor = .foreground3
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.section == postSection, indexPath.row < newAddedPosts else { return }
            
        newAddedPosts = indexPath.row
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y < 50 {
            newAddedPosts = 0
        }
    }
}

private extension HomeFeedViewController {
    func setupPublishers() {
        Timer.publish(every: 30, on: .main, in: .default).autoconnect().flatMap { [weak self] _ -> AnyPublisher<[ParsedContent], Never> in
            self?.feed.futurePostsPublisher() ?? Just([]).eraseToAnyPublisher()
        }
        .sink { [weak self] sorted in
            self?.processFuturePosts(sorted)
        }
        .store(in: &cancellables)
        
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] notification in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                guard let self else { return }
                self.feed.futurePostsPublisher().sink { [weak self] sorted in
                    self?.processFuturePosts(sorted)
                }
                .store(in: &self.cancellables)
            }
        }
        
        feed.$parsedPosts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] posts in
                if self?.refresh.isRefreshing == false {
                    self?.posts = posts
                } else if !posts.isEmpty {
                    self?.posts = []
                    self?.posts = posts
                }
                
                if posts.isEmpty {
                    if self?.refresh.isRefreshing == false {
                        self?.loadingSpinner.isHidden = false
                        self?.loadingSpinner.play()
                    }
                } else {
                    self?.loadingSpinner.isHidden = true
                    self?.loadingSpinner.stop()
                    self?.refresh.endRefreshing()
                }
                
                DispatchQueue.main.async {
                    self?.onLoad?()
                    self?.onLoad = nil
                }
            }
            .store(in: &cancellables)
        
        feed.$currentFeed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                self?.title = name
            }
            .store(in: &cancellables)
    }
    
    func processFuturePosts(_ sorted: [ParsedContent]) {
        let sorted = sorted.filter { post in
            !posts.contains(where: { $0.post.id == post.post.id && $0.reposted?.user.data.id == post.reposted?.user.data.id}) &&
            !newPostObjects.contains(where: { $0.post.id == post.post.id && $0.reposted?.user.data.id == post.reposted?.user.data.id})
        }
        
        if sorted.isEmpty { return }
        
        if table.contentOffset.y < 50 {
            newPostObjects = sorted + newPostObjects
            newPostsView.setCount(newPosts, avatarURLs: sorted.prefix(3).compactMap { $0.user.profileImage.url(for: .small) })
        } else {
            newAddedPosts += sorted.count
            feed.parsedPosts.insert(contentsOf: sorted, at: 0)
            newPostsView.setCount(newPosts, avatarURLs: sorted.prefix(3).compactMap { $0.user.profileImage.url(for: .small) })
        }
    }
}
