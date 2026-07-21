//
//  WebSocketTransporting.swift
//
//  Purpose: Implements WebSocketTransporting for the Core/Network/Transport module.
//  Collaborates with: MockWebSocketTransport, WebSocketTransport.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

@MainActor
protocol WebSocketTransporting: AnyObject {
    var isConnected: Bool { get }
    func connect(to url: URL) async throws
    func send(json: [String: JSONValue]) async throws
    func send(text: String) async throws
    func messages() -> AsyncThrowingStream<String, Error>
    func close()
}
