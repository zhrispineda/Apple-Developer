//
//  AccountList.swift
//  Developer
//

import SwiftUI

struct AccountList: View {
    var body: some View {
        List {
                Section {
                    Button("Sign In") {}
                } footer: {
                    Text("Sign in to your Apple Account to manage your program membership and more.")
                }

                Section {
                    Button("Profile") {}.disabled(true)
                } footer: {
                    Text("Sign in to your Apple Account to manage your profile.")
                }

                Section {
                    NavigationLink("Notifications") {
                        NotificationSettingsView()
                    }
                } footer: {
                    Text("Customize how you receive updates about your account, announcements, WWDC, and more.")
                }
            }
            .navigationTitle("Account")
    }
}

struct NotificationSettingsView: View {
    var body: some View {
        ContentUnavailableView(
            "Notifications",
            systemImage: "bell.badge",
            description: Text("Notification settings are coming soon.")
        )
        .navigationTitle("Notifications")
    }
}
