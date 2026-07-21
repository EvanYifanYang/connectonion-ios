//
//  ConnectOnionWidgetBundle.swift
//
//  Purpose: Implements ConnectOnionWidgetBundle for the ConnectOnionWidget module.
//  Collaborates with: ConnectOnionLiveActivity, ConnectOnionWidget.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI
import WidgetKit

@main
struct ConnectOnionWidgetBundle: WidgetBundle {
    var body: some Widget {
        ConnectOnionWidget()
        ConnectOnionLiveActivity()
    }
}
