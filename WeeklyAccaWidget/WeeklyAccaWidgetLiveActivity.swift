//
//  WeeklyAccaWidgetLiveActivity.swift
//  WeeklyAccaWidget
//

import ActivityKit
import WidgetKit
import SwiftUI



struct WeeklyAccaWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AccaActivityAttributes.self) { context in
            // Lock screen/banner UI
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text(context.attributes.accaName).font(.headline)
                        Text(context.attributes.groupName).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(context.state.statusText).font(.subheadline).foregroundStyle(Color.green)
                        Text("\(context.state.correctPicks)/\(context.state.totalPicks) Correct").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Active Pick").font(.caption2).foregroundStyle(.secondary)
                        Text(context.state.currentPickMatch).font(.subheadline).bold()
                        Text("Pick: \(context.state.currentPickSelection)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(context.state.currentPickScore).font(.title3).bold()
                        Text(context.state.currentPickTime).font(.caption).foregroundStyle(context.state.currentPickStatus == "winning" ? Color.green : (context.state.currentPickStatus == "losing" ? Color.red : Color.gray))
                    }
                }
                .padding(.top, 4)
            }
            .padding()
            .activityBackgroundTint(Color(uiColor: .systemBackground))
            .activitySystemActionForegroundColor(Color.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.accaName).font(.headline)
                        Text(context.attributes.groupName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("\(context.state.correctPicks)/\(context.state.totalPicks)").font(.headline)
                        Text(context.state.statusText).font(.caption).foregroundStyle(Color.green)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(context.state.currentPickMatch).font(.subheadline).bold()
                            Text(context.state.currentPickSelection).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(context.state.currentPickScore).font(.headline)
                            Text(context.state.currentPickTime).font(.caption).foregroundStyle(context.state.currentPickStatus == "winning" ? Color.green : (context.state.currentPickStatus == "losing" ? Color.red : Color.gray))
                        }
                    }
                }
            } compactLeading: {
                Text("\(context.state.correctPicks)/\(context.state.totalPicks)")
            } compactTrailing: {
                Text(context.state.currentPickScore).foregroundStyle(context.state.currentPickStatus == "winning" ? Color.green : (context.state.currentPickStatus == "losing" ? Color.red : Color.gray))
            } minimal: {
                Image(systemName: "soccerball").foregroundStyle(.green)
            }
            .widgetURL(URL(string: "weeklyacca://"))
            .keylineTint(Color.green)
        }
    }
}
