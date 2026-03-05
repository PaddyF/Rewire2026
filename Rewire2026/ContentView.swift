import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LineupView()
                .tabItem {
                    Label("Lineup", systemImage: "music.note.list")
                }

            MyListView()
                .tabItem {
                    Label("My List", systemImage: "star.fill")
                }

            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "clock")
                }

            PlannerView()
                .tabItem {
                    Label("Planner", systemImage: "calendar")
                }
        }
        .tint(.rewireAccent)
        .preferredColorScheme(.dark)
    }
}
