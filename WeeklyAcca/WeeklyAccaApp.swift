//
//  WeeklyAccaApp.swift
//  WeeklyAcca
//
//  Created by Richard Doyle on 2/13/26.
//

import SwiftUI


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        UNUserNotificationCenter.current().delegate = self
        
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        // Convert to hex string
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        
        // Save locally so the app can sync it after login is confirmed
        UserDefaults.standard.set(token, forKey: "apnsToken")
        
        // Try to save to Supabase immediately (fire and forget)
        // If the user isn't logged in yet, this will fail silently, but `MainAppView`
        // or the login flow will catch it and sync it later.
        Task {
            do {
                if SupabaseService.shared.currentUser != nil {
                    try await SupabaseService.shared.updateAPNSToken(token: token)
                    print("✅ APNs token saved to Supabase on launch")
                }
            } catch {
                print("Failed to save APNs token on launch: \(error.localizedDescription)")
            }
        }
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for APNs: \(error.localizedDescription)")
    }
}

@main
struct WeeklyAccaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color("AccentColor"))
        }
    }
}
