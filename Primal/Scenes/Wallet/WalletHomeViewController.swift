//
//  WalletHomeViewController.swift
//  Primal
//
//  Created by Pavle Stevanović on 9.10.23..
//

import Combine
import UIKit

final class WalletHomeViewController: UIViewController, Themeable {
    enum Cell {
        case info
        case buySats
        case transaction((WalletTransaction, ParsedUser))
    }
    
    struct Section {
        var title: String?
        var cells: [Cell] = []
    }
    
    @Published var isBitcoinPrimary = true
    
    private let navBar = WalletNavView()
    private let table = UITableView()
    
    private var cancellables: Set<AnyCancellable> = []
    private var updateIsBitcoin: AnyCancellable?
    private var update: ContinousConnection?
    private var updateUpdate: AnyCancellable?
    
    private var tableData: [Section] = [] {
        didSet {
            table.reloadData()
        }
    }
    
    var isShowingNavBar = false {
        didSet {
            if isShowingNavBar == oldValue { return }
            
            if isShowingNavBar {
                navBar.balanceConversionView.isBitcoinPrimary = isBitcoinPrimary
            } else {
                (table.cellForRow(at: .init(row: 0, section: 0)) as? WalletInfoCell)?.balanceConversionView.isBitcoinPrimary = isBitcoinPrimary
            }
            
            if !isShowingNavBar {
                table.contentInset = isShowingNavBar ? UIEdgeInsets(top: 80, left: 0, bottom: 0, right: 0) : .zero
            }
            
            UIView.animate(withDuration: 0.2) {
                self.navBar.transform = self.isShowingNavBar ? .identity : .init(translationX: 0, y: -100)
            } completion: { _ in
                self.table.contentInset = self.isShowingNavBar ? UIEdgeInsets(top: 80, left: 0, bottom: 0, right: 0) : .zero
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        WalletManager.instance.refreshBalance()
        WalletManager.instance.loadNewTransactions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let event = NostrObject.wallet("{\"subwallet\":1}") else { return }

        updateUpdate = Connection.instance.$isConnected.removeDuplicates().filter { $0 }
            .sink { [weak self] _ in
                self?.update = Connection.instance.requestCacheContinous(name: "wallet_monitor", request: ["operation_event": event.toJSON()]) { result in
                    guard let content = result.arrayValue?.last?.objectValue?["content"]?.stringValue else { return }
                    guard let amountBTC = content.split(separator: "\"").compactMap({ Double($0) }).first else { return }
                    let sats = Int(amountBTC * .BTC_TO_SAT)
                    WalletManager.instance.balance = sats
                }
            }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        updateUpdate = nil
        update = nil
    }
    
    func updateTheme() {
//        let button = UIButton()
//        button.setImage(UIImage(named: "settingsIcon")?.withRenderingMode(.alwaysTemplate), for: .normal)
//        button.tintColor = .foreground3
//        button.addAction(.init(handler: { [weak self] _ in
//            self?.show(SettingsWalletViewController(), sender: nil)
//        }), for: .touchUpInside)
//        navigationItem.rightBarButtonItem = .init(customView: button)
        
        view.backgroundColor = .background
        table.backgroundColor = .background
        table.reloadData()
    }
}

extension WalletHomeViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { tableData.count }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { tableData[section].cells.count }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableData[indexPath.section].cells[indexPath.row] {
        case .buySats:
            let cell = tableView.dequeueReusableCell(withIdentifier: "buySats", for: indexPath)
            if let cell = cell as? BuySatsCell {
                cell.updateTheme()
                cell.delegate = self
            }
            return cell
        case .info:
            let cell = tableView.dequeueReusableCell(withIdentifier: "info", for: indexPath)
            if let cell = cell as? WalletInfoCell {
                updateIsBitcoin = nil
                cell.delegate = self
                cell.balanceConversionView.isBitcoinPrimary = isBitcoinPrimary
                updateIsBitcoin = cell.balanceConversionView.$isBitcoinPrimary.sink(receiveValue: { [weak self] isBitcoinPrimary in
                    self?.isBitcoinPrimary = isBitcoinPrimary
                })
            }
            return cell
        case .transaction(let transaction):
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            (cell as? TransactionCell)?.setup(with: transaction, showBTC: isBitcoinPrimary)
            
            if indexPath.section >= tableData.count - 1 {
                WalletManager.instance.loadMoreTransactions()
            }
            
            return cell
        }
    }
}

extension WalletHomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = tableData[section].title else { return UIView() }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header")
        (header as? TransactionHeader)?.set(title)
        return header
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        isShowingNavBar = scrollView.contentOffset.y > 190
    }
}

extension WalletHomeViewController: WalletInfoCellDelegate, BuySatsCellDelegate {
    func buySatsPressed() {
        show(WalletInAppPurchaseController(), sender: nil)
    }
    
    func receiveButtonPressed() {
        show(WalletReceiveViewController(), sender: nil)
    }
    
    func sendButtonPressed() {
        show(WalletPickUserController(), sender: nil)
    }
    
    func scanButtonPressed() {
        present(WalletQRCodeViewController(), animated: true)
    }
}

private extension WalletHomeViewController {
    func setup() {
        title = "Wallet"
        
        view.addSubview(table)
        table.pinToSuperview(edges: .horizontal).pinToSuperview(edges: .top, safeArea: true).pinToSuperview(edges: .bottom, padding: 56, safeArea: true)
        
        view.addSubview(navBar)
        navBar.pinToSuperview(edges: [.horizontal, .top], safeArea: true)
        navBar.transform = .init(translationX: 0, y: -100)
        
        table.separatorStyle = .none
        table.dataSource = self
        table.delegate = self
        table.showsVerticalScrollIndicator = false
        table.register(TransactionCell.self, forCellReuseIdentifier: "cell")
        table.register(WalletInfoCell.self, forCellReuseIdentifier: "info")
        table.register(TransactionHeader.self, forHeaderFooterViewReuseIdentifier: "header")
        table.register(BuySatsCell.self, forCellReuseIdentifier: "buySats")
        
        let refresh = UIRefreshControl()
        refresh.addAction(.init(handler: { _ in
            WalletManager.instance.refreshTransactions()
            WalletManager.instance.refreshBalance()
        }), for: .valueChanged)
        table.refreshControl = refresh
        
        updateTheme()
        
        WalletManager.instance.$parsedTransactions.receive(on: DispatchQueue.main).sink { [weak self] transactions in
            let grouping = Dictionary(grouping: transactions) {
                Calendar.current.dateComponents([.day, .year, .month], from: Date(timeIntervalSince1970: TimeInterval($0.0.created_at)))
            }
            
            self?.table.refreshControl?.endRefreshing()
            var firstSection = Section(cells: [.info])
            if WalletManager.instance.balance < 500000 {
                firstSection.cells += [.buySats]
            }
            
            self?.tableData = [firstSection] + grouping.sorted(by: { $0.1.first?.0.created_at ?? 0 > $1.1.first?.0.created_at ?? 0 }).map {
                let date = Date(timeIntervalSince1970: TimeInterval($0.value.first?.0.created_at ?? 0))
                return .init(title: date.daysAgoDisplay(), cells: $0.value.map { .transaction($0) })
            }
        }
        .store(in: &cancellables)
        
        navBar.receive.addAction(.init(handler: { [weak self] _ in
            self?.receiveButtonPressed()
        }), for: .touchUpInside)
        navBar.send.addAction(.init(handler: { [weak self] _ in
            self?.sendButtonPressed()
        }), for: .touchUpInside)
        navBar.scan.addAction(.init(handler: { [weak self] _ in
            self?.scanButtonPressed()
        }), for: .touchUpInside)
        navBar.balanceConversionView.$isBitcoinPrimary.dropFirst().sink { [weak self] isBitcoinPrimary in
            self?.isBitcoinPrimary = isBitcoinPrimary
        }
        .store(in: &cancellables)
        
        $isBitcoinPrimary.dropFirst().removeDuplicates().throttle(for: 0.3, scheduler: DispatchQueue.main, latest: true).sink { [weak self] _ in
            guard let self else { return }
            if self.tableData.count > 1 {
                self.table.reloadData()
//                if let rows = self.table.indexPathsForVisibleRows?.filter({ $0.section != 0 }) {
//                    self.table.reloadRows(at: rows, with: .none)
//                }
            }
        }
        .store(in: &cancellables)
    }
}
