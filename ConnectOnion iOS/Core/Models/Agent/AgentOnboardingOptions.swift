//
//  AgentOnboardingOptions.swift
//
//  Purpose: Describes the proactive onboarding methods advertised by connectonion /info.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct AgentOnboardingOptions: Codable, Equatable, Sendable {
    var inviteCode: Bool
    var payment: Double?

    init(inviteCode: Bool = false, payment: Double? = nil) {
        self.inviteCode = inviteCode
        self.payment = payment
    }

    enum CodingKeys: String, CodingKey {
        case inviteCode = "invite_code"
        case payment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inviteCode = try container.decodeIfPresent(Bool.self, forKey: .inviteCode) ?? false
        payment = try container.decodeIfPresent(Double.self, forKey: .payment)
    }
}
