//
//  KARAApp.swift
//  KARA
//
//  Created by sr-71 on 7/18/26.
//

import SwiftUI

@main
struct KARAApp: App {
    @State private var flow = AppFlow()
    @State private var theme = KaraTheme()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(flow)
                .environment(theme)
                .preferredColorScheme(.dark)
        }
    }
}
