//
//  ChatFailure.swift
//
//  Purpose: Turns a thrown error into user-facing chat failure copy and the action that can fix it.
//  Collaborates with: ChatErrorBanner, ChatViewModel, AgentDirectoryError, ConnectOnionClientError.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

/// A chat failure the user can actually act on: a short title, a body that says what to DO, an
/// optional technical detail behind a disclosure, and the one action that genuinely helps. Replaces
/// substring-sniffing an arbitrary error string, which produced technical copy and offered a
/// "Reconnect" button even where reconnecting could not possibly help.
struct ChatFailure: Equatable {
    enum Action: Equatable {
        /// The prompt provably never left the device, so Retry re-sends it.
        case resend
        /// The host may already hold the turn; Retry can only re-attach.
        case reconnect
        /// Nothing to retry — the user has to change something first.
        case dismiss
    }

    var title: String
    var body: String
    var action: Action
    /// Raw technical text (server message, endpoint list, size numbers) shown behind "Show details".
    var detail: String?

    /// Single-line projection kept for the places that still consume a plain `errorMessage` string.
    var bannerMessage: String { "\(title). \(body)" }

    init(title: String, body: String, action: Action, detail: String? = nil) {
        self.title = title
        self.body = body
        self.action = action
        self.detail = detail
    }

    /// `canResend` must mirror `ChatViewModel.retryLastTurn`: there has to BE a captured turn, and its
    /// INPUT must provably not have been written. Otherwise the copy would promise a resend that the
    /// button does not perform.
    init(error: Error, canResend: Bool) {
        let retry = ChatFailure.recoveryHint(canResend: canResend)
        let action: Action = canResend ? .resend : .reconnect

        switch error {
        case let directoryError as AgentDirectoryError:
            switch directoryError {
            case .invalidAddress:
                self.init(
                    title: "That agent address isn't valid",
                    body: "An address looks like 0x followed by 64 characters. Edit the agent and paste it again.",
                    action: .dismiss
                )
            case .preferredEndpointUnavailable(let endpoint):
                let hostPort = [endpoint.host(), endpoint.port.map(String.init)]
                    .compactMap { $0 }
                    .joined(separator: ":")
                self.init(
                    title: "Couldn't reach \(hostPort.isEmpty ? "the configured address" : hostPort)",
                    body: "Check the agent is running and that this iPhone is on the same network. \(retry)",
                    action: action,
                    detail: endpoint.absoluteString
                )
            case .directoryUnavailable:
                self.init(
                    title: "Couldn't look up this agent",
                    body: "The agent directory didn't respond. Check your connection. \(retry)",
                    action: action
                )
            case .noReachableRoute(let endpoints):
                self.init(
                    title: "No route to this agent",
                    body: "It's online but none of its addresses are reachable from this network. Set a LAN address in the agent's settings. \(retry)",
                    action: action,
                    detail: endpoints.isEmpty ? nil : endpoints.map(\.absoluteString).joined(separator: "\n")
                )
            }

        case let clientError as ConnectOnionClientError:
            switch clientError {
            case .connectionRejected(let message):
                self.init(
                    title: "The agent refused the connection",
                    body: "It rejected this device. Check the agent's trust settings, then try again.",
                    action: .dismiss,
                    detail: message
                )
            case .inputFrameTooLarge:
                self.init(
                    title: "That message is too large to send",
                    body: "Remove an attachment or pick a smaller file, then send again.",
                    action: .dismiss,
                    detail: error.localizedDescription
                )
            case .handshakeTimedOut:
                self.init(
                    title: "The agent never finished starting up",
                    body: "It connected but stopped responding. It may be busy or stuck — restart it if this keeps happening. \(retry)",
                    action: action
                )
            case .connectionWentSilent:
                self.init(
                    title: "The agent stopped responding mid-reply",
                    body: "It went quiet while answering — it may have crashed. Check the agent's terminal for an error. \(retry)",
                    action: action
                )
            }

        case let urlError as URLError:
            switch urlError.code {
            case .notConnectedToInternet, .dataNotAllowed:
                self.init(
                    title: "This iPhone is offline",
                    body: "Check Wi-Fi or mobile data. \(retry)",
                    action: action
                )
            case .cannotConnectToHost, .cannotFindHost:
                // The literal "Could not connect" is asserted by Sprint1Tests — keep it in the title.
                self.init(
                    title: "Could not connect to this agent",
                    body: "Check that it's running and reachable from this iPhone. \(retry)",
                    action: action
                )
            case .networkConnectionLost:
                self.init(
                    title: "The connection dropped",
                    body: "The network went away mid-reply. \(retry)",
                    action: action
                )
            case .timedOut:
                self.init(
                    title: "The agent took too long to answer",
                    body: "It may be busy. \(retry)",
                    action: action
                )
            default:
                self.init(
                    title: "Couldn't reach this agent",
                    body: "Something went wrong on the way to the agent. \(retry)",
                    action: action,
                    detail: error.localizedDescription
                )
            }

        default:
            self.init(
                title: "The reply didn't complete",
                body: "Something went wrong while the agent was answering. \(retry)",
                action: action,
                detail: error.localizedDescription
            )
        }
    }

    /// A failure the HOST reported (an ERROR frame), where the text is authored by the agent.
    init(agentMessage: String, canResend: Bool) {
        self.init(
            title: "The agent stopped with an error",
            body: ChatFailure.recoveryHint(canResend: canResend),
            action: canResend ? .resend : .reconnect,
            detail: agentMessage
        )
    }

    private static func recoveryHint(canResend: Bool) -> String {
        canResend ? "Tap Retry to send it again." : "Tap Retry to reconnect."
    }
}
