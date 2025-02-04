//
//  Publisher+Extra.swift
//  Primal
//
//  Created by Pavle D Stevanović on 12.6.23..
//

import Combine
import Foundation

extension Publisher where Failure == Never {
    func assign<Root: AnyObject>(
            to keyPath: ReferenceWritableKeyPath<Root, Output>,
            onWeak object: Root
    ) -> AnyCancellable {
        sink { [weak object] value in
            object?[keyPath: keyPath] = value
        }
    }
}
extension Publisher where Self.Failure == Never {
    func sinkAsync(receiveValue: @escaping (Self.Output) async -> Void) -> AnyCancellable {
        sink { value in
            Task {
                await receiveValue(value)
            }
        }
    }
}

extension Publisher {
    func withPrevious() -> AnyPublisher<(Output, Output), Failure> {
        Publishers.Zip(self, self.dropFirst()).eraseToAnyPublisher()
    }
    
    func waitForConnection(_ connection: Connection) -> AnyPublisher<Output, Failure> {
        connection.$isConnected
            .filter { $0 }
            .first()
            .flatMap { _ in self }
            .eraseToAnyPublisher()
    }
}
