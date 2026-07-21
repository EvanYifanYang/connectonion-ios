//
//  AgentCapabilityLine.swift
//
//  Purpose: Implements AgentCapabilityLine for the Features/Agents module.
//  Collaborates with: AgentEditorView, AgentHeroView, AgentHomeView, AgentInfoPopover, AgentInfoStore, AgentLandingView.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct AgentCapabilityLine: View {
    var info: AgentInfo?

    var body: some View {
        VStack(spacing: 4) {
            if let acceptsLine {
                Text(acceptsLine)
            }
        }
        .appFont(.footnote)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }

    private var acceptsLine: String? {
        guard let inputs = info?.acceptedInputs else { return nil }
        var parts: [String] = []
        if inputs.text == true { parts.append("text") }
        if inputs.images == true { parts.append("images") }
        if let files = inputs.files { parts.append("files \(files.maxFileSizeMB)MB") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview("Capabilities Loaded") {
    AgentCapabilityLine(info: PreviewFixtures.sampleAgentInfo)
        .padding()
}

#Preview("Capabilities Empty") {
    AgentCapabilityLine(info: nil)
        .padding()
}
