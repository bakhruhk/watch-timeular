//
//  WatchComplicationExtension.swift
//  WatchComplicationExtension
//
//  Created by Harshit Bakhru on 2024-09-23.
//

import WidgetKit
import SwiftUI

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let totalTrackedTime: String
}

struct Provider: TimelineProvider {
    
    func placeholder(in context: Context) -> ComplicationEntry {
       ComplicationEntry(date: Date(), totalTrackedTime: "0m")
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> ()) {
        let entry = ComplicationEntry(date: Date(), totalTrackedTime: "0m")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> ()) {
        let totalTrackedTime = TimeTrackedManagerExtension.shared.getTotalTrackedTime()
        let now = Date()
        let entry = ComplicationEntry(date: now, totalTrackedTime: totalTrackedTime)
        let timeline = Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60*15)))
        completion(timeline)
    }

}

struct ComplicationView : View {
    var entry: Provider.Entry

    private var dayProgress: Double {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let currentMinute = Calendar.current.component(.minute, from: Date())
        let totalMinutes = (currentHour * 60) + currentMinute
        let totalMinutesInDay = 1440 // 24 hours * 60 minutes
        return Double(totalMinutes) / Double(totalMinutesInDay)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 5) {
                // Display primary tracked time info
                Text(entry.totalTrackedTime)
                    .widgetCurvesContent()
                    .widgetLabel{
                        Gauge(value: dayProgress, in: 0...1) {}
                        .tint(Gradient(colors: [.blue, .green, .orange, .red]))
                    }
                    .widgetURL(URL(string: "watchtimeular://totaltimeview"))
            }
        }
    }
}

@main
struct WatchComplicationExtension: Widget {
    let kind: String = "WatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(watchOS 10.0, *) {
                ComplicationView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ComplicationView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .supportedFamilies([.accessoryCorner, .accessoryCircular, .accessoryRectangular])
        .configurationDisplayName("Timeular Tracking")
        .description("Shows total time tracked for today.")
    }
}
