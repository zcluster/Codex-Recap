// Hallmark · genre: modern-minimal · macrostructure: Workbench · mood: native Liquid Glass
// Hallmark · pre-emit critique: P5 H5 E4 S5 R5 V4
import AppKit
import SwiftUI

enum GlassTokens {
    static let cornerRadius: CGFloat = 14
    static let controlRadius: CGFloat = 10

    static func edge(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.14) : .white.opacity(0.72)
    }

    static func shadow(for colorScheme: ColorScheme) -> Color {
        .black.opacity(colorScheme == .dark ? 0.28 : 0.12)
    }
}

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
    @AppStorage("floatOnTop") private var floatOnTop = false
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool {
        themeMode == "dark" || (themeMode == "system" && colorScheme == .dark)
    }

    private var preferredColorScheme: ColorScheme? {
        themeMode == "system" ? nil : (themeMode == "dark" ? .dark : .light)
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            Color.black.opacity(isDark ? 0.22 : 0.025).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Codex Projects")
                            .font(.title2.bold())
                        Text("Click a project to continue in Codex")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Float on Top", isOn: $floatOnTop)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.thinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(GlassTokens.edge(for: colorScheme), lineWidth: 1))
                        .help("Keep Codex Recap above other windows")
                    Button {
                        themeMode = isDark ? "light" : "dark"
                    } label: {
                        Image(systemName: isDark ? "sun.max" : "moon")
                    }
                    .buttonStyle(GlassIconButtonStyle())
                    .help(isDark ? "Switch to light mode" : "Switch to dark mode")
                    Button(action: store.refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(GlassIconButtonStyle())
                    .help("Refresh")
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(GlassTokens.edge(for: colorScheme))
                        .frame(height: 1)
                }

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
                        LazyVStack(spacing: 12) {
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
        }
        .frame(minWidth: 640, minHeight: 480)
        .background(WindowAppearance(isDark: isDark, floatOnTop: floatOnTop))
        .preferredColorScheme(preferredColorScheme)
        .onAppear(perform: store.refresh)
    }
}

struct WindowAppearance: NSViewRepresentable {
    let isDark: Bool
    let floatOnTop: Bool

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .clear
            window.level = self.floatOnTop ? .floating : .normal
        }
    }
}

struct GlassBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct GlassIconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 30, height: 30)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: GlassTokens.controlRadius))
            .overlay(
                RoundedRectangle(cornerRadius: GlassTokens.controlRadius)
                    .stroke(GlassTokens.edge(for: colorScheme), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct ProjectSection: View {
    let title: String
    let detail: String
    let projects: [RecentProject]
    @Binding var isExpanded: Bool
    let openProject: (RecentProject) -> Void
    @Environment(\.colorScheme) private var colorScheme

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
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GlassTokens.controlRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: GlassTokens.controlRadius)
                        .stroke(GlassTokens.edge(for: colorScheme), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, title == "Dormant" ? 8 : 0)

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
    @State private var isHovered = false

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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: GlassTokens.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GlassTokens.cornerRadius)
                .stroke(GlassTokens.edge(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: GlassTokens.shadow(for: colorScheme), radius: isHovered ? 12 : 7, y: isHovered ? 5 : 3)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onHover { isHovered = $0 }
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: GlassTokens.cornerRadius))
        .padding(20)
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
