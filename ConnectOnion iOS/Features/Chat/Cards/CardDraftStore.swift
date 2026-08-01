//
//  CardDraftStore.swift
//
//  Purpose: Holds in-progress answers for pending chat cards so they survive row recycling.
//  Collaborates with: AskUserCard, ApprovalNeededCard, OnboardRequiredCard, PlanReviewCard.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

/// Interactive cards live in the transcript's `LazyVStack`, which destroys a row once it scrolls far
/// enough off-screen and rebuilds it with fresh `@State`. A half-written ask-user answer, plan-revision
/// note or invite code would silently vanish just because the user scrolled up to re-read context, so
/// the drafts are held here — outside the view — keyed by chat item id.
@MainActor
@Observable
final class CardDraftStore {
    private var texts: [String: String] = [:]
    private var optionSelections: [String: Set<String>] = [:]
    private var fieldValues: [String: [String: String]] = [:]

    /// Nonisolated so the environment default can be built outside the main actor; every stored
    /// property has an inline default, and all access afterwards is main-actor isolated.
    nonisolated init() {}

    func text(for id: String) -> String { texts[id] ?? "" }
    func setText(_ value: String, for id: String) { texts[id] = value }

    func options(for id: String) -> Set<String> { optionSelections[id] ?? [] }
    func setOptions(_ value: Set<String>, for id: String) { optionSelections[id] = value }

    func field(_ name: String, for id: String) -> String { fieldValues[id]?[name] ?? "" }
    func setField(_ name: String, value: String, for id: String) {
        fieldValues[id, default: [:]][name] = value
    }

    /// Called once a card is answered — the draft has served its purpose and must not linger.
    func clear(id: String) {
        texts[id] = nil
        optionSelections[id] = nil
        fieldValues[id] = nil
    }

    // MARK: - Bindings

    func textBinding(for id: String) -> Binding<String> {
        Binding(get: { self.text(for: id) }, set: { self.setText($0, for: id) })
    }

    func fieldBinding(_ name: String, for id: String) -> Binding<String> {
        Binding(get: { self.field(name, for: id) }, set: { self.setField(name, value: $0, for: id) })
    }
}

private struct CardDraftStoreKey: EnvironmentKey {
    // Safe in practice: the instance is only ever read or mutated from the main actor.
    nonisolated(unsafe) static let defaultValue = CardDraftStore()
}

extension EnvironmentValues {
    /// Defaults to a shared app-lifetime store, so previews and tests need no wiring.
    var cardDrafts: CardDraftStore {
        get { self[CardDraftStoreKey.self] }
        set { self[CardDraftStoreKey.self] = newValue }
    }
}
