//
//  ChatViewController.swift
//  Primal
//
//  Created by Pavle Stevanović on 8.9.23..
//

import Combine
import UIKit
import FLAnimatedImage

final class ChatViewController: UIViewController, Themeable {
    enum Cell {
        case message(ProcessedMessage)
        case timeLabel(Date)
        case loading
        
        var cellID: String {
            switch self {
            case .message:
                return "cell"
            case .timeLabel:
                return "time"
            case .loading:
                return "loading"
            }
        }
    }
    
    var table = UITableView()
    
    let chatManager: ChatManager
    
    private var textHeightConstraint: NSLayoutConstraint?
    let textInputView = SelfSizingTextView()
    private let placeholderLabel = UILabel()
    private let inputParent = UIView()
    private let inputBackground = UIView()
    private let bottomBarSpacer = UIView()
    private let loadingSpinner = LoadingSpinnerView().constrainToSize(70)
    
    private lazy var postButton = UIButton()
    private let buttonStack = UIStackView()
    
    private var inputContentMaxHeightConstraint: NSLayoutConstraint?
    
    var cancellables: Set<AnyCancellable> = []
    
    lazy var inputManager = ChatTextViewManager(textView: textInputView)
    
    var messages: [ProcessedMessage] = [] {
        didSet {
            updateCells()
        }
    }
    
    var cells: [Cell] = [] {
        didSet {
            table.reloadData()
        }
    }
    
    var didReachEndOfHistory = false
    var isLoadingPast = false
    var isLoadingFuture = false
    var shouldNotifyReadStatus = true
    
    let user: ParsedUser
    
    init(user: ParsedUser, chatManager: ChatManager) {
        self.user = user
        self.chatManager = chatManager
        super.init(nibName: nil, bundle: nil)
        setup()
        
        navigationItem.rightBarButtonItem = navigationBarButton(for: user)
        
        chatManager.getChatMessages(pubkey: user.data.pubkey) { [weak self] result in
            self?.messages = result
            self?.loadingSpinner.stop()
            self?.loadingSpinner.isHidden = true
        }
        
        addPublishers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: animated)
    
        mainTabBarController?.showTabBarBorder = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        mainTabBarController?.showTabBarBorder = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        mainTabBarController?.showTabBarBorder = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateTheme() {
        navigationItem.leftBarButtonItem = customBackButton
        navigationItem.titleView = navigationBarTitle(for: user)
        
        view.backgroundColor = .background
        
        postButton.backgroundColor = .accent
        
        inputParent.backgroundColor = .background
        inputBackground.backgroundColor = .background3
        
        table.reloadData()
    }
}

private extension ChatViewController {
    func setup() {
        updateTheme()
        
        let navigationBarExtender = ThemeableView().setTheme { $0.backgroundColor = .background } .constrainToSize(height: 14)
        let navigationBorder = ThemeableView().setTheme { $0.backgroundColor = .background3 } .constrainToSize(height: 1)
        
        let stack = UIStackView(axis: .vertical, [navigationBarExtender, navigationBorder, table, inputParent, bottomBarSpacer])
        view.addSubview(stack)
        stack.pinToSuperview(edges: [.horizontal, .top], safeArea: true).pinToSuperview(edges: .bottom, padding: 56, safeArea: true)
        
        view.addSubview(loadingSpinner)
        loadingSpinner.centerToSuperview()
        loadingSpinner.play()
        
        table.transform = .init(scaleX: -1, y: 1).rotated(by: .pi)
        table.keyboardDismissMode = .interactive
        table.dataSource = self
        table.separatorStyle = .none
        table.register(ChatMessageCell.self, forCellReuseIdentifier: "cell")
        table.register(ChatTimeCell.self, forCellReuseIdentifier: "time")
        table.register(ChatLoadingCell.self, forCellReuseIdentifier: "loading")
        
        inputBackground.layer.cornerRadius = 20
        
        postButton.setImage(UIImage(named: "sendMessage"), for: .normal)
        postButton.addTarget(self, action: #selector(postButtonPressed), for: .touchUpInside)
        postButton.isEnabled = false
        postButton.alpha = 0.5
        postButton.adjustsImageWhenDisabled = false
        postButton.layer.cornerRadius = 20
        postButton.constrainToSize(40)
        
        let inputStackFirstLine = UIStackView([inputBackground, postButton])
        inputStackFirstLine.alignment = .bottom
        inputStackFirstLine.spacing = 8
        
        let inputStack = UIStackView(axis: .vertical, [inputStackFirstLine, buttonStack])
        
        let inputBorder = ThemeableView().constrainToSize(height: 1).setTheme { $0.backgroundColor = .background3 }
        
        inputParent.addSubview(inputStack)
        inputParent.addSubview(inputBorder)
        inputBackground.addSubview(placeholderLabel)
        
        let textParent = UIView()
        let contentStack = UIStackView(axis: .vertical, [textParent])
        contentStack.spacing = 12
        
        inputBackground.addSubview(contentStack)
        textParent.addSubview(textInputView)
        
        contentStack
            .pinToSuperview(edges: [.top, .horizontal])
            .pinToSuperview(edges: .bottom, padding: 5)
        
        placeholderLabel
            .pinToSuperview(edges: .leading, padding: 21)
            .centerToSuperview(axis: .vertical)
        
        textInputView
            .pinToSuperview(edges: .horizontal, padding: 16)
            .pinToSuperview(edges: .top, padding: 2.5)
            .pinToSuperview(edges: .bottom, padding: -2.5)
        
        inputStack
            .pinToSuperview(edges: .horizontal, padding: 12)
            .pinToSuperview(edges: .top, padding: 16)
            .pinToSuperview(edges: .bottom)
        
        inputBorder.pinToSuperview(edges: [.top, .horizontal])
        
        let bottomC = bottomBarSpacer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -56)
        bottomC.priority = .defaultLow
        bottomC.isActive = true
        
        bottomBarSpacer.topAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor, constant: -16).isActive = true
        
        inputStack.spacing = 4
        
        textInputView.backgroundColor = .clear
        textInputView.font = .appFont(withSize: 16, weight: .regular)
        textInputView.textColor = .foreground
        textInputView.delegate = inputManager
        textInputView.returnKeyType = .send
        
        let imageButton = UIButton()
        imageButton.setImage(UIImage(named: "ImageIcon"), for: .normal)
        imageButton.constrainToSize(48)
        imageButton.addAction(.init(handler: { [unowned self] _ in
            ImagePickerManager(self, mode: .gallery) { [weak self] image, isPNG in
//                self?.inputManager.processSelectedImage(image, isPNG: isPNG)
            }
        }), for: .touchUpInside)
        
        let cameraButton = UIButton()
        cameraButton.setImage(UIImage(named: "CameraIcon"), for: .normal)
        cameraButton.constrainToSize(48)
        cameraButton.addAction(.init(handler: { [unowned self] _ in
            ImagePickerManager(self, mode: .camera) { [weak self] image, isPNG in
//                self?.inputManager.processSelectedImage(image, isPNG: isPNG)
            }
        }), for: .touchUpInside)
        
        let atButton = UIButton()
        atButton.setImage(UIImage(named: "AtIcon"), for: .normal)
//        atButton.addTarget(inputManager, action: #selector(PostingTextViewManager.atButtonPressed), for: .touchUpInside)
        
//        [/*imageButton, cameraButton, atButton,*/ UIView()].forEach {
//            buttonStack.addArrangedSubview($0)
//        }
//        atButton.widthAnchor.constraint(equalTo: imageButton.widthAnchor).isActive = true
        
//        buttonStack.alignment = .center
        
        placeholderLabel.font = .appFont(withSize: 16, weight: .regular)
        placeholderLabel.textColor = .foreground4
        placeholderLabel.text = "Message \(user.data.firstIdentifier)"
        
        buttonStack.isHidden = true
        buttonStack.alpha = 0
        
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(inputSwippedDown))
        swipe.direction = .down
        inputParent.addGestureRecognizer(swipe)
        
        textInputView.heightAnchor.constraint(greaterThanOrEqualToConstant: 35).isActive = true
        textHeightConstraint = textInputView.heightAnchor.constraint(equalToConstant: 35)
        inputContentMaxHeightConstraint = contentStack.heightAnchor.constraint(equalToConstant: 600)
        
        inputContentMaxHeightConstraint?.priority = .defaultHigh
    }
    
    func navigationBarTitle(for user: ParsedUser) -> UIView {
        let first = UILabel()
        let second = UILabel()
        
        first.text = user.data.firstIdentifier
        second.text = user.data.secondIdentifier
        
        first.font = .appFont(withSize: 18, weight: .bold)
        first.textColor = .foreground
        
        second.font = .appFont(withSize: 14, weight: .regular)
        second.textColor = .foreground4
        second.isHidden = second.text?.isEmpty != false
        
        let stack = UIStackView(axis: .vertical, [first, second])
        stack.alignment = .center
        stack.spacing = 4
        return stack
    }
    
    func navigationBarButton(for user: ParsedUser) -> UIBarButtonItem {
        let button = UIButton()
        button.addAction(.init(handler: { [weak self] _ in
            self?.show(ProfileViewController(profile: user), sender: nil)
        }), for: .touchUpInside)
        let imageView = FLAnimatedImageView(frame: .init(origin: .zero, size: .init(width: 36, height: 36))).constrainToSize(36)
        imageView.layer.cornerRadius = 18
        imageView.layer.masksToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.setUserImage(user)
        let parent = UIView()
        parent.addSubview(imageView)
        imageView.centerToSuperview()
        parent.addSubview(button)
        button.pinToSuperview()
        return .init(customView: parent)
    }
    
    @objc func inputSwippedDown() {
        textInputView.resignFirstResponder()
    }
    
    @objc func postButtonPressed() {
        if inputManager.didUploadFail {
            inputManager.restartFailedUploads()
            return
        }
        
        if inputManager.isUploadingImages {
            return
        }
        
        let text = inputManager.postingText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else {
            showErrorMessage(title: "Please Enter Text", "Text cannot be empty")
            return
        }
        
        textInputView.text = ""
        postButton.isEnabled = false
        postButton.alpha = 0.5
        
        let date = Date()
        messages.append(.init(id: "", user: .init(data: .init(pubkey: IdentityManager.instance.userHexPubkey)), date: date, message: text, status: .sending))
        
        PostManager.instance.sendMessageEvent(message: text, userPubkey: user.data.pubkey) { [weak self] success in
            guard let self, let index = messages.firstIndex(where: { $0.date == date }) else { return }
            
            if success {
                self.messages[index].status = .sent
            } else {
                self.messages[index].status = .failed
            }
        }
    }
    
    func addPublishers() {
        inputManager.$isEditing.sink { [weak self] isEditing in
            guard let self = self else { return }
            let images = self.inputManager.images
            
            self.postButton.isHidden = !isEditing
            self.textHeightConstraint?.isActive = !isEditing
            self.placeholderLabel.isHidden = isEditing || !self.textInputView.text.isEmpty
            
            let isImageHidden = !isEditing || images.isEmpty
            
            UIView.animate(withDuration: 0.2) {
//                self.inputBackground.backgroundColor = isEditing ? .background3 : .background3
                
//                self.buttonStack.isHidden = !isEditing
//                self.buttonStack.alpha = isEditing ? 1 : 0
//
//                self.imagesCollectionView.isHidden = isImageHidden
//                self.imagesCollectionView.alpha = isImageHidden ? 0 : 1
//
                self.textInputView.layoutIfNeeded()
            }
        }
        .store(in: &cancellables)
        
        inputManager.$images.receive(on: DispatchQueue.main).sink { [weak self] images in
//            self?.imagesCollectionView.imageResources = images
            self?.inputContentMaxHeightConstraint?.isActive = !images.isEmpty
            
            let isHidden = images.isEmpty
//            UIView.animate(withDuration: 0.3, animations: {
//                self.imagesCollectionView.isHidden = isHidden
//                self.imagesCollectionView.alpha = isHidden ? 0 : 1
//            })
        }
        .store(in: &cancellables)
        
        Publishers.CombineLatest(inputManager.$images, inputManager.$isEmpty).receive(on: DispatchQueue.main).sink { [weak self] _, isEmpty in
            guard let self else { return }
            self.postButton.isEnabled = !isEmpty && !self.inputManager.isUploadingImages
            self.postButton.alpha = self.postButton.isEnabled ? 1 : 0.5
        }
        .store(in: &cancellables)
        
        chatManager.$newMessagesCount.withPrevious().receive(on: DispatchQueue.main).sink { [weak self] old, new in
            guard new != old, let self, self.isLoadingFuture == false else { return }
            
            self.isLoadingFuture = true
            self.chatManager.getChatMessages(pubkey: self.user.data.pubkey, since: self.messages.dropLast(5).last?.date.timeIntervalSince1970 ?? 0) { [weak self] newMessages in
                guard let self else { return }
                
                let newMessages = newMessages.filter { nm in !self.messages.contains(where: { $0.id == nm.id })}
                
                if !newMessages.isEmpty {
                    self.messages = self.messages + newMessages
                    self.shouldNotifyReadStatus = true
                }
                
                self.isLoadingFuture = false
            }
        }
        .store(in: &cancellables)
    }
    
    func updateCells() {
        var cells: [Cell] = []
        defer {
            self.cells = cells.reversed() // Reverse cells because the table is upside down
        }
        
        guard var lastMessage = messages.first else { return }
        
        for message in messages {
            if lastMessage.user.data.npub == message.user.data.npub {
                // 900 seconds is 15 minutes
                if message.date.timeIntervalSince(lastMessage.date) > 900 {
                    cells.append(.timeLabel(lastMessage.date))
                }
            } else {
                cells.append(.timeLabel(lastMessage.date))
            }
            
            cells.append(.message(message))
            lastMessage = message
        }
        
        cells.append(.timeLabel(lastMessage.date))
    }
    
    func loadPastIfNeeded() {
        guard !isLoadingPast, !didReachEndOfHistory else { return }
        
        isLoadingPast = true
        
        chatManager.getChatMessagesHistory(pubkey: user.data.pubkey, until: (messages.first?.date.timeIntervalSince1970 ?? 0)) { [weak self] messages in
            guard let self else { return }
            
            let messages = messages.filter { nm in !self.messages.contains(where: { $0.id == nm.id }) }
            
            if messages.isEmpty {
                self.didReachEndOfHistory = true
            } else {
                self.messages = messages + self.messages
            }
            
            self.isLoadingPast = false
        }
    }
    
    func notifyReadStatus() {
        guard shouldNotifyReadStatus else { return }
        shouldNotifyReadStatus = false
        
        chatManager.notifyReadStatus(pubkey: user.data.pubkey)
    }
}

extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        cells.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cells[indexPath.row].cellID, for: indexPath)
        cell.transform = tableView.transform
        
        if indexPath.row <= 1 {
            notifyReadStatus()
        }
        
        if indexPath.row > cells.count - 10 {
            loadPastIfNeeded()
        }
        
        switch cells[indexPath.row] {
        case .message(let message):
            if let messageCell = cell as? ChatMessageCell {
                let isLastInSeries = indexPath.row + 1 < cells.count && {
                    switch cells[indexPath.row + 1] {
                    case .loading, .timeLabel:
                        return true
                    case .message(let m):
                        return m.user.data.npub != message.user.data.npub
                    }
                }()
                
                messageCell.setupWith(message: message, roundSide: isLastInSeries)
                messageCell.delegate = self
            }
        case .timeLabel(let time):
            let isMine = indexPath.row == cells.count - 1 || {
                switch cells[indexPath.row + 1] {
                case .loading, .timeLabel:
                    return true
                case .message(let prevMessage):
                    return prevMessage.user.data.npub == IdentityManager.instance.user?.npub
                }
            }()
            
            (cell as? ChatTimeCell)?.setupWith(date: time, isMine: isMine)
        case .loading:
            break
        }
        
        return cell
    }
}

extension ChatViewController: ChatMessageCellDelegate {
    func contextMenuForMessageCell(_ cell: ChatMessageCell) -> UIMenu? {
        guard
            let index = table.indexPath(for: cell)?.row,
            case let .message(message) = cells[index]
        else { return nil }
        
        var items: [UIAction] = [
            UIAction(title: NSLocalizedString("Copy text", comment: ""), image: UIImage(systemName: "square.and.arrow.up")) { action in
                UIPasteboard.general.string = message.message
            }
        ]
        
        if !message.id.isEmpty {
            items.append(UIAction(title: NSLocalizedString("Copy note ID", comment: ""), image: UIImage(systemName: "square.and.arrow.up")) { action in
                UIPasteboard.general.string = message.id
            })
        }
        
        if message.user.data.pubkey != IdentityManager.instance.userHexPubkey {
            items.append(contentsOf: [
                UIAction(title: NSLocalizedString("Copy user pubkey", comment: ""), image: UIImage(systemName: "square.and.arrow.up")) { action in
                    UIPasteboard.general.string = message.user.data.pubkey
                },
                UIAction(title: "Mute user", image: UIImage(named: "blockIcon"), handler: { [weak self] _ in
                    let pubkey = message.user.data.pubkey
                    MuteManager.instance.toggleMute(pubkey) {
                        self?.navigationController?.popViewController(animated: true)
                    }
                })
            ])
        }
        
        return UIMenu(title: "", children: items)
    }
}
