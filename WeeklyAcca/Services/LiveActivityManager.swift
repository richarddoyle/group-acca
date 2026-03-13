import Foundation
import ActivityKit
import SwiftUI



@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var liveActivitiesEnabled: Bool {
        return UserDefaults.standard.object(forKey: "liveActivitiesEnabled") as? Bool ?? true
    }
    
    // Store the active activity so we can update/end it
    private var currentActivity: Activity<AccaActivityAttributes>?
    
    private init() {}
    
    func startActivity(accaName: String, groupName: String, state: AccaActivityAttributes.ContentState) {
        guard liveActivitiesEnabled else { return }
        
        // Don't start a new one if we already have one
        if currentActivity != nil { return }
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = AccaActivityAttributes(accaName: accaName, groupName: groupName)
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            self.currentActivity = activity
            print("Successfully started Live Activity: \(activity.id)")
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    func updateActivity(state: AccaActivityAttributes.ContentState) {
        guard let activity = currentActivity else { return }
        
        Task {
            let contentState = ActivityContent(state: state, staleDate: nil)
            await activity.update(contentState)
        }
    }
    
    func endActivity() {
        guard let activity = currentActivity else { return }
        
        Task {
            let finalState = activity.content.state
            let finalContent = ActivityContent(state: finalState, staleDate: nil)
            
            // End activity immediately and dismiss
            await activity.end(finalContent, dismissalPolicy: .immediate)
            self.currentActivity = nil
        }
    }
    
    // Clean up any stale activities
    func endAllStaleActivities() {
        Task {
            for activity in Activity<AccaActivityAttributes>.activities {
                let finalContent = ActivityContent(state: activity.content.state, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
            self.currentActivity = nil
        }
    }
}
