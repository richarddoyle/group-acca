//
//  WeeklyAccaWidgetBundle.swift
//  WeeklyAccaWidget
//
//  Created by Richard Doyle on 3/8/26.
//

import WidgetKit
import SwiftUI

@main
struct WeeklyAccaWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeeklyAccaWidget()
        WeeklyAccaWidgetControl()
        WeeklyAccaWidgetLiveActivity()
    }
}
