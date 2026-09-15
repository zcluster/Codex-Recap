import AppKit
import SwiftUI

struct RecentProject: Codable, Identifiable {
    let id: String
    let cwd: String
    let title: String
    let recencyAt: Int
    let threadCount: Int

    var name: String {
        URL(fileURLWithPath: cwd).lastPathComponent
    }

    var activeTime: String {
        let date = Date(timeIntervalSince1970: TimeInterval(recencyAt))
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) {
            return "Today at \(time)"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday at \(time)"
        }
        return date.formatted(.dateTime.month().day().hour().minute())
    }

    var isRecent: Bool {
        recencyAt >= Int(Date().timeIntervalSince1970) - 86_400
    }

    enum CodingKeys: String, CodingKey {
        case id, cwd, title
        case recencyAt = "recency_at"
        case threadCount = "thread_count"
    }
}

@MainActor
final class ProjectStore: ObservableObject {
    @Published var projects: [RecentProject] = []
    @Published var errorMessage: String?

    var recentProjects: [RecentProject] {
        projects.filter(\.isRecent)
    }

    var dormantProjects: [RecentProject] {
        projects.filter { !$0.isRecent }
    }

    func refresh() {
        do {
            projects = try Self.loadProjects()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openInCodex(_ project: RecentProject) {
        guard let url = URL(string: "codex://threads/\(project.id)") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func loadProjects() throws -> [RecentProject] {
        let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]
            .map { NSString(string: $0).expandingTildeInPath }
            ?? NSString(string: "~/.codex").expandingTildeInPath
        let database = URL(fileURLWithPath: codexHome).appendingPathComponent("state_5.sqlite")

        let query = """
        WITH all_threads AS (
          SELECT id, cwd,
                 COALESCE(NULLIF(name, ''), NULLIF(title, ''),
                          NULLIF(first_user_message, ''), 'Untitled thread') AS title,
                 recency_at
          FROM threads
          WHERE COALESCE(thread_source, 'user') = 'user'
        ), ranked AS (
          SELECT *,
                 ROW_NUMBER() OVER (PARTITION BY cwd ORDER BY recency_at DESC, id DESC) AS rank,
                 COUNT(*) OVER (PARTITION BY cwd) AS thread_count
          FROM all_threads
        )
        SELECT id, cwd, title, recency_at, thread_count
        FROM ranked
        WHERE rank = 1
        ORDER BY recency_at DESC;
        """

        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", "-json", database.path, query]
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errors.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: data, as: UTF8.self)
            throw NSError(
                domain: "CodexRecent",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return try JSONDecoder().decode([RecentProject].self, from: data)
    }
}

struct ContentView: View {
    @StateObject private var store = ProjectStore()
    @State private var recentExpanded = true
    @State private var dormantExpanded = false
    @AppStorage("themeMode") private var themeMode = "system"
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool {
        themeMode == "dark" || (themeMode == "system" && colorScheme == .dark)
    }

    private var preferredColorScheme: ColorScheme? {
        themeMode == "system" ? nil : (themeMode == "dark" ? .dark : .light)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Codex Projects")
                        .font(.title2.bold())
                    Text("Click a project to continue in Codex")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    themeMode = isDark ? "light" : "dark"
                } label: {
                    Image(systemName: isDark ? "sun.max" : "moon")
                }
                .help(isDark ? "Switch to light mode" : "Switch to dark mode")
                Button(action: store.refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .padding(20)

            Divider()

            if let error = store.errorMessage {
                UnavailableView(
                    title: "Couldn’t Load Codex History",
                    icon: "exclamationmark.triangle",
                    detail: error
                )
            } else if store.projects.isEmpty {
                UnavailableView(
                    title: "No Projects",
                    icon: "clock",
                    detail: "No local Codex sessions were found."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ProjectSection(
                            title: "Recent",
                            detail: "Past 24 hours",
                            projects: store.recentProjects,
                            isExpanded: $recentExpanded,
                            openProject: store.openInCodex
                        )
                        ProjectSection(
                            title: "Dormant",
                            detail: "More than 24 hours ago · Newest to oldest",
                            projects: store.dormantProjects,
                            isExpanded: $dormantExpanded,
                            openProject: store.openInCodex
                        )
                    }
                    .padding(16)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .background((isDark ? Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255) : Color(nsColor: .windowBackgroundColor)).ignoresSafeArea())
        .background(WindowAppearance(isDark: isDark))
        .preferredColorScheme(preferredColorScheme)
        .onAppear(perform: store.refresh)
    }
}

struct WindowAppearance: NSViewRepresentable {
    let isDark: Bool

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = self.isDark
            window.backgroundColor = self.isDark
                ? NSColor(red: 34 / 255, green: 34 / 255, blue: 34 / 255, alpha: 1)
                : .windowBackgroundColor
        }
    }
}

struct ProjectSection: View {
    let title: String
    let detail: String
    let projects: [RecentProject]
    @Binding var isExpanded: Bool
    let openProject: (RecentProject) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.bold())
                        .frame(width: 12)
                    Text(title).font(.title3.bold())
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(projects.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, title == "Dormant" ? 14 : 0)

            if isExpanded && projects.isEmpty {
                Text("No projects")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else if isExpanded {
                ForEach(projects) { project in
                    Button {
                        openProject(project)
                    } label: {
                        ProjectRow(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ProjectRow: View {
    let project: RecentProject
    @Environment(\.colorScheme) private var colorScheme

    private var sessionCount: String {
        "\(project.threadCount) \(project.threadCount == 1 ? "session" : "sessions")"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(project.name).font(.headline)
                    Spacer()
                    Text(project.activeTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(project.title.replacingOccurrences(of: "\n", with: " "))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                Text("\(sessionCount)  ·  \(project.cwd)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Image(systemName: "arrow.up.forward.app")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .contentShape(Rectangle())
        .background(
            colorScheme == .dark
                ? Color(red: 43 / 255, green: 43 / 255, blue: 43 / 255)
                : Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

struct UnavailableView: View {
    let title: String
    let icon: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.largeTitle)
            Text(title).font(.headline)
            Text(detail).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

@main
struct CodexRecapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentMinSize)
    }
}
