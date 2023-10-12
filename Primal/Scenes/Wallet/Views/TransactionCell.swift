//
//  TransactionCell.swift
//  Primal
//
//  Created by Pavle Stevanović on 9.10.23..
//

import UIKit
import FLAnimatedImage

extension UIColor {
    static var receiveMoney = UIColor(rgb: 0x2CA85E)
    static var sendMoney = UIColor(rgb: 0xCC331E)
}

final class TransactionCell: UITableViewCell, Themeable {
    
    private let profileImage = FLAnimatedImageView().constrainToSize(36)
    
    private let nameLabel = UILabel()
    private let separator = UIView().constrainToSize(width: 1, height: 16)
    private let timeLabel = UILabel()
    private let messageLabel = UILabel()
    
    private let amountLabel = UILabel()
    private let currencyLabel = UILabel()
    
    private let arrowIcon = UIImageView(image: UIImage(named: "income"))
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
 
    func setup(with transaction: (WalletTransaction, ParsedUser), showBTC: Bool) {
        profileImage.setUserImage(transaction.1)
        nameLabel.text = (transaction.1).data.firstIdentifier
        timeLabel.text = Date(timeIntervalSince1970: TimeInterval(transaction.0.created_at)).timeAgoDisplay()
        
        let isDeposit = transaction.0.type == "DEPOSIT"
        
        arrowIcon.transform = isDeposit ? .identity : .init(rotationAngle: .pi)
        arrowIcon.tintColor = isDeposit ? .receiveMoney : .sendMoney
        
        if transaction.0.note?.isEmpty == false {
            messageLabel.text = transaction.0.note
        } else {
            if transaction.0.is_zap {
                messageLabel.text = isDeposit ? "Zap received" : "Zap sent"
            } else {
                messageLabel.text = isDeposit ? "Payment received" : "Payment sent"
            }
        }
        
        let btcAmount = (Double(transaction.0.amount_btc) ?? 0)
        
        if showBTC {
            amountLabel.text = (btcAmount * .BTC_TO_SAT).localized()
            currencyLabel.text = "sats"
        } else {
            let usdAmount = Double(btcAmount * .BTC_TO_USD)
            let usdString = "$" + usdAmount.localized()
            
            amountLabel.text = usdString
            currencyLabel.text = "USD"
        }
        
        updateTheme()
    }
    
    func updateTheme() {
        separator.backgroundColor = .foreground5
        timeLabel.textColor = .foreground5
        messageLabel.textColor = .foreground3
        nameLabel.textColor = .foreground
        
        amountLabel.textColor = .foreground
        currencyLabel.textColor = .foreground5
        
        contentView.backgroundColor = .background
    }
}

private extension TransactionCell {
    func setup() {
        selectionStyle = .none
        
        profileImage.layer.cornerRadius = 18
        profileImage.layer.masksToBounds = true
        profileImage.contentMode = .scaleAspectFill
                
        let nameStack = UIStackView([nameLabel, separator, timeLabel, UIView()])
        nameStack.spacing = 8
        
        let firstVStack = UIStackView(axis: .vertical, [nameStack, messageLabel])
        let secondVStack = UIStackView(axis: .vertical, [amountLabel, currencyLabel])
        secondVStack.alignment = .trailing
        
        messageLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        timeLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let thirdStack = UIView()
        thirdStack.addSubview(arrowIcon)
        arrowIcon.pinToSuperview(edges: .horizontal).pinToSuperview(edges: .top, padding: 5)
        
        let mainStack = UIStackView([profileImage, SpacerView(width: 8), firstVStack, secondVStack, SpacerView(width: 5), thirdStack])
        mainStack.alignment = .center
        thirdStack.pin(to: secondVStack, edges: .vertical)
        
        contentView.addSubview(mainStack)
        mainStack.pinToSuperview(edges: .horizontal, padding: 20).pinToSuperview(edges: .vertical, padding: 12)
        
        nameLabel.font = .appFont(withSize: 16, weight: .bold)
        timeLabel.font = .appFont(withSize: 14, weight: .regular)
        messageLabel.font = .appFont(withSize: 14, weight: .regular)
        amountLabel.font = .appFont(withSize: 16, weight: .bold)
        currencyLabel.font = .appFont(withSize: 14, weight: .regular)
    }
}
