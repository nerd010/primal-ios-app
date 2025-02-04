//
//  UIView+Extra.swift
//  Primal
//
//  Created by Pavle D Stevanović on 22.4.23..
//

import UIKit
import SwiftUI

extension UIView {
    @discardableResult
    func dropShadow(scale: Bool = true) -> Self {
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = .init(width: 0, height: 3)
        layer.shadowRadius = 1
        layer.shouldRasterize = true
        layer.rasterizationScale = scale ? UIScreen.main.scale : 1
        
        return self
    }

    func findAllSubviews<T>() -> [T] {
        var result = [T]()

        if let t = self as? T {
            result.append(t)
        }
        
        for subview in subviews {
            result += subview.findAllSubviews()
        }
        
        return result
    }
    
    // MARK: - Constraints
    
    @discardableResult
    func centerToSuperview(axis: Axis.Set = [.horizontal, .vertical]) -> Self {
        guard let superview else { return self }
        return centerToView(superview, axis: axis)
    }
    
    @discardableResult
    func pinToSuperview(edges: Edge.Set = .all, padding: CGFloat = 0, safeArea: Bool = false) -> Self {
        guard let superview else { return self }
        return pin(to: superview, edges: edges, padding: padding, safeArea: safeArea)
    }
    
    @discardableResult
    func constrainToSize(_ size: CGFloat) -> Self {
        constrainToSize(width: size, height: size)
    }
    
    @discardableResult
    func pin(to view: UIView, edges: Edge.Set = .all, padding: CGFloat = 0, safeArea: Bool = false) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        
        if edges.contains(.top) {
            topAnchor.constraint(
                equalTo: safeArea ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor,
                constant: padding
            ).isActive = true
        }
        if edges.contains(.bottom) {
            bottomAnchor.constraint(
                equalTo: safeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor,
                constant: -padding
            ).isActive = true
        }
        if edges.contains(.leading) {
            leadingAnchor.constraint(
                equalTo: safeArea ? view.safeAreaLayoutGuide.leadingAnchor : view.leadingAnchor,
                constant: padding
            ).isActive = true
        }
        if edges.contains(.trailing) {
            trailingAnchor.constraint(
                equalTo: safeArea ? view.safeAreaLayoutGuide.trailingAnchor : view.trailingAnchor,
                constant: -padding
            ).isActive = true
        }
        return self
    }
    
    @discardableResult
    func centerToView(_ view: UIView, axis: Axis.Set = [.horizontal, .vertical]) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        if axis.contains(.vertical) {
            centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        }
        if axis.contains(.horizontal) {
            centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        }
        return self
    }
    
    @discardableResult
    func constrainToSize(width: CGFloat? = nil, height: CGFloat? = nil) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        if let width {
            widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        if let height {
            heightAnchor.constraint(equalToConstant: height).isActive = true
        }
        return self
    }
}
