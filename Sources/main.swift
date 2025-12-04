import SwiftUI
import AppKit
import Network

// MARK: - Color Extension
extension Color {
    static let softPeach = Color(red: 1.0, green: 0.898, blue: 0.82) // #FFE5D1
}

// MARK: - App Entry Point
@main
struct ClaudeNotifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var httpServer: HTTPServer?

    static let availableSounds = ["Pop", "Purr", "Tink", "Glass", "Ping", "Submarine", "Funk", "Hero", "None"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()

        httpServer = HTTPServer(port: 19280)
        httpServer?.start()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = NSImage(systemSymbolName: "bell", accessibilityDescription: "Claude Notify")?
                .withSymbolConfiguration(config)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Claude Notify", action: nil, keyEquivalent: ""))
        menu.items.first?.isEnabled = false
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show History", action: #selector(showHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Test Notification", action: #selector(testNotification), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())

        // Sound submenu
        let soundMenu = NSMenu()
        for sound in Self.availableSounds {
            let item = NSMenuItem(title: sound, action: #selector(selectSound(_:)), keyEquivalent: "")
            item.target = self
            if sound == NotificationManager.shared.currentSound {
                item.state = .on
            }
            soundMenu.addItem(item)
        }
        let soundMenuItem = NSMenuItem(title: "Sound", action: nil, keyEquivalent: "")
        soundMenuItem.submenu = soundMenu
        menu.addItem(soundMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc func showHistory() {
        NotificationManager.shared.showFullHistory()
    }

    @objc func testNotification() {
        NotificationManager.shared.addNotification(
            project: "Test Project",
            path: "/Users/tony/test",
            message: "테스트 알림입니다"
        )
    }

    @objc func selectSound(_ sender: NSMenuItem) {
        NotificationManager.shared.currentSound = sender.title
        // Update menu checkmarks
        if let soundMenu = sender.menu {
            for item in soundMenu.items {
                item.state = item.title == sender.title ? .on : .off
            }
        }
        // Play preview
        if sender.title != "None" {
            NSSound(named: NSSound.Name(sender.title))?.play()
        }
    }

    @objc func antigravity() {
        if let url = URL(string: "https://xkcd.com/353/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - Notification Item
struct NotificationItem: Identifiable, Equatable, Codable {
    let id: UUID
    let project: String
    let path: String
    let message: String
    let timestamp: Date
    let startTime: Date?
    let endTime: Date?
    let model: String?
    var isRead: Bool

    init(id: UUID = UUID(), project: String, path: String, message: String, timestamp: Date, startTime: Date? = nil, endTime: Date? = nil, model: String? = nil, isRead: Bool = false) {
        self.id = id
        self.project = project
        self.path = path
        self.message = message
        self.timestamp = timestamp
        self.startTime = startTime
        self.endTime = endTime
        self.model = model
        self.isRead = isRead
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: timestamp)
    }

    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let start = startTime, let end = endTime else {
            return timeString
        }
        return "\(formatter.string(from: start))~\(formatter.string(from: end))"
    }

    var durationString: String {
        guard let start = startTime, let end = endTime else { return "" }
        let seconds = Int(end.timeIntervalSince(start))
        if seconds < 60 { return "\(seconds)초" }
        if seconds < 3600 { return "\(seconds / 60)분 \(seconds % 60)초" }
        return "\(seconds / 3600)시간 \((seconds % 3600) / 60)분"
    }

    var modelShort: String {
        guard let m = model, !m.isEmpty else { return "" }

        // Parse model name: claude-{type}-{major}-{minor}-{date}
        let parts = m.components(separatedBy: "-")

        var name = ""
        var version = ""

        if m.contains("opus") {
            name = "Opus"
        } else if m.contains("sonnet") {
            name = "Sonnet"
        } else if m.contains("haiku") {
            name = "Haiku"
        }

        // Extract version (major.minor)
        if parts.count >= 4 {
            let major = parts[2]
            let minor = parts[3]
            version = "\(major).\(minor)"
        }

        if !name.isEmpty && !version.isEmpty {
            return "\(name) \(version)"
        } else if !name.isEmpty {
            return name
        }

        return parts.first ?? m
    }

    var timeAgo: String {
        let seconds = Int(-timestamp.timeIntervalSinceNow)
        if seconds < 60 { return "방금" }
        if seconds < 3600 { return "\(seconds / 60)분 전" }
        if seconds < 86400 { return "\(seconds / 3600)시간 전" }
        return "\(seconds / 86400)일 전"
    }

    var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 MM월 dd일"
        return formatter.string(from: timestamp)
    }

    var dateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Notification Manager
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var notifications: [NotificationItem] = []
    @Published var isVisible = false
    private var panel: NSPanel?
    private var historyWindow: NSWindow?
    private var dismissTimer: Timer?

    var currentSound: String {
        get { UserDefaults.standard.string(forKey: "notificationSound") ?? "Pop" }
        set { UserDefaults.standard.set(newValue, forKey: "notificationSound") }
    }

    private var dataURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("ClaudeNotify")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("notifications.jsonl")
    }

    private init() {
        loadNotifications()
    }

    private func loadNotifications() {
        guard FileManager.default.fileExists(atPath: dataURL.path) else { return }
        guard let data = try? String(contentsOf: dataURL, encoding: .utf8) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var loaded: [NotificationItem] = []
        for line in data.components(separatedBy: "\n") where !line.isEmpty {
            if let lineData = line.data(using: .utf8),
               let item = try? decoder.decode(NotificationItem.self, from: lineData) {
                loaded.append(item)
            }
        }
        notifications = loaded.sorted { $0.timestamp > $1.timestamp }
    }

    private func saveNotification(_ item: NotificationItem) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(item),
              let line = String(data: data, encoding: .utf8) else { return }

        let lineWithNewline = line + "\n"
        if let handle = try? FileHandle(forWritingTo: dataURL) {
            handle.seekToEndOfFile()
            handle.write(lineWithNewline.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? lineWithNewline.write(to: dataURL, atomically: true, encoding: .utf8)
        }
    }

    func addNotification(project: String, path: String, message: String = "", startTime: Date? = nil, endTime: Date? = nil, model: String? = nil) {
        DispatchQueue.main.async {
            let item = NotificationItem(
                project: project,
                path: path,
                message: message.isEmpty ? "Task completed" : message,
                timestamp: Date(),
                startTime: startTime,
                endTime: endTime,
                model: model
            )
            self.notifications.insert(item, at: 0)
            self.saveNotification(item)

            self.showPanel(autoNotification: true)
            self.playSound()
        }
    }

    func showPanel(autoNotification: Bool = false) {
        if panel == nil {
            createPanel()
        }
        updateContent()

        // Position directly on screen (no animation for now to debug)
        guard let screen = NSScreen.main, let panel = panel else {
            print("ERROR: No screen or panel")
            return
        }

        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        let x = screenFrame.maxX - panelSize.width - 12
        let y = screenFrame.maxY - panelSize.height - 12

        print("Screen: \(screenFrame), Panel size: \(panelSize)")
        print("Position: x=\(x), y=\(y)")

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        isVisible = true

        // Only auto-dismiss if this is an automatic notification
        if autoNotification {
            scheduleAutoDismiss()
        } else {
            // Cancel any existing timer when manually showing history
            dismissTimer?.invalidate()
            dismissTimer = nil
        }
    }

    private func createPanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 200),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        panel?.isFloatingPanel = true
        panel?.level = .floating
        panel?.backgroundColor = .clear
        panel?.isOpaque = false
        panel?.hasShadow = true
        panel?.titlebarAppearsTransparent = true
        panel?.titleVisibility = .hidden
        panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    private func updateContent() {
        let contentView = NotificationPanel(manager: self)
        let hostingView = NSHostingView(rootView: contentView)
        panel?.contentView = hostingView

        let height = min(CGFloat(56 + notifications.count * 64 + (notifications.count > 1 ? 44 : 0)), 380)
        panel?.setContentSize(NSSize(width: 340, height: height))
    }

    private func positionPanelOffScreen() {
        guard let screen = NSScreen.main, let panel = panel else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        // Start off-screen to the right
        let x = screenFrame.maxX + 20
        let y = screenFrame.maxY - panelSize.height - 12

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.alphaValue = 0
    }

    private func animateIn() {
        guard let screen = NSScreen.main, let panel = panel else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        let targetX = screenFrame.maxX - panelSize.width - 12
        let y = screenFrame.maxY - panelSize.height - 12

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(NSPoint(x: targetX, y: y))
            panel.animator().alphaValue = 1
        }

        isVisible = true
    }

    func dismiss() {
        guard let screen = NSScreen.main, let panel = panel else { return }
        dismissTimer?.invalidate()

        let screenFrame = screen.visibleFrame
        let targetX = screenFrame.maxX + 20
        let y = panel.frame.origin.y

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(NSPoint(x: targetX, y: y))
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            self.isVisible = false
        })
    }

    func clearAll() {
        notifications.removeAll()
        dismiss()
    }

    func toggleRead(id: UUID) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead.toggle()
            updateContent()
        }
    }

    func removeNotification(id: UUID) {
        notifications.removeAll { $0.id == id }
        if notifications.isEmpty {
            dismiss()
        } else {
            updateContent()
            repositionPanel()
        }
    }

    private func repositionPanel() {
        guard let screen = NSScreen.main, let panel = panel else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        let x = screenFrame.maxX - panelSize.width - 12
        let y = screenFrame.maxY - panelSize.height - 12

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func openFolder(path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    private func playSound() {
        guard currentSound != "None" else { return }
        NSSound(named: NSSound.Name(currentSound))?.play()
    }

    private func scheduleAutoDismiss() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    func showFullHistory() {
        if historyWindow == nil {
            historyWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            historyWindow?.title = ""
            historyWindow?.center()
            historyWindow?.minSize = NSSize(width: 500, height: 400)
            historyWindow?.titlebarAppearsTransparent = true
            historyWindow?.titleVisibility = .hidden
            historyWindow?.appearance = NSAppearance(named: .darkAqua)
            historyWindow?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        }

        let contentView = HistoryWindowView(manager: self)
        let hostingView = NSHostingView(rootView: contentView)
        historyWindow?.contentView = hostingView
        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    var groupedNotificationsByDate: [(String, [NotificationItem])] {
        let grouped = Dictionary(grouping: notifications) { $0.dateKey }
        return grouped.sorted { $0.key > $1.key }.map { (key, items) in
            let sortedItems = items.sorted { $0.timestamp > $1.timestamp }
            return (key, sortedItems)
        }
    }

    var groupedNotificationsByProject: [(String, [NotificationItem])] {
        let grouped = Dictionary(grouping: notifications) { $0.project }
        return grouped.sorted { $0.key < $1.key }.map { (key, items) in
            let sortedItems = items.sorted { $0.timestamp > $1.timestamp }
            return (key, sortedItems)
        }
    }
}

// MARK: - Notification Panel View
struct NotificationPanel: View {
    @ObservedObject var manager: NotificationManager
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Button(action: { manager.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(isHovered ? 1 : 0.5))
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(isHovered ? 0.15 : 0))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Image(systemName: "bell.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.softPeach)

                Text("Claude Code")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(manager.notifications.count)개의 알림")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .background(Color.white.opacity(0.2))

            // Notification List
            if manager.notifications.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))

                    Text("알림 없음")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(manager.notifications) { item in
                            NotificationRow(item: item) {
                                manager.toggleRead(id: item.id)
                            } onRemove: {
                                manager.removeNotification(id: item.id)
                            }

                            if item.id != manager.notifications.last?.id {
                                Divider()
                                    .padding(.leading, 50)
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            // Footer
            if manager.notifications.count > 1 {
                Divider()
                    .background(Color.white.opacity(0.2))

                Button(action: { manager.clearAll() }) {
                    Text("모두 지우기")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 10)
            }
        }
        .background(
            ZStack {
                // Dark tinted background
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.75))

                // Glass effect on top
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    let item: NotificationItem
    let onTap: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.softPeach.opacity(item.isRead ? 0.1 : 0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.softPeach.opacity(item.isRead ? 0.4 : 1.0))
                }

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(item.project)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(item.isRead ? 0.4 : 1.0))
                            .lineLimit(1)

                        Spacer()

                        // Time range (시작~종료)
                        Text(item.timeRangeString)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(item.isRead ? 0.3 : 0.6))
                    }

                    Text(item.message)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(item.isRead ? 0.3 : 0.7))
                        .lineLimit(1)

                    // Duration and Model info
                    HStack(spacing: 6) {
                        if !item.durationString.isEmpty {
                            Text(item.durationString)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(item.isRead ? 0.25 : 0.5))
                        }
                        if !item.modelShort.isEmpty {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(item.isRead ? 0.15 : 0.3))
                            Text(item.modelShort)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.softPeach.opacity(item.isRead ? 0.3 : 1.0))
                        }
                    }
                }

                // Remove button on hover
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(isHovered ? 0.8 : 0))
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(isHovered ? 0.15 : 0))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isHovered ? Color.white.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - History Window View
struct HistoryWindowView: View {
    @ObservedObject var manager: NotificationManager
    @State private var groupBy: GroupType = .date

    enum GroupType {
        case date, project
    }

    var groupedItems: [(String, [NotificationItem])] {
        switch groupBy {
        case .date:
            return manager.groupedNotificationsByDate
        case .project:
            return manager.groupedNotificationsByProject
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.softPeach)

                Text("알림 히스토리")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Picker("", selection: $groupBy) {
                    Text("날짜별").tag(GroupType.date)
                    Text("프로젝트별").tag(GroupType.project)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                Text("총 \(manager.notifications.count)개")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .background(Color.white.opacity(0.2))

            // Content
            if manager.notifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.3))
                    Text("저장된 알림이 없습니다")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedItems, id: \.0) { key, items in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(sectionTitle(for: key))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)

                                ForEach(items) { item in
                                    HistoryListRow(item: item, onTap: {
                                        manager.toggleRead(id: item.id)
                                    }, onRemove: {
                                        manager.removeNotification(id: item.id)
                                    })

                                    if item.id != items.last?.id {
                                        Divider()
                                            .padding(.leading, 64)
                                            .background(Color.white.opacity(0.1))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(Color.black.opacity(0.85))
    }

    func sectionTitle(for key: String) -> String {
        switch groupBy {
        case .date:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: key) else { return key }

            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy년 MM월 dd일"

            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "오늘"
            } else if calendar.isDateInYesterday(date) {
                return "어제"
            } else {
                return displayFormatter.string(from: date)
            }
        case .project:
            return key
        }
    }
}

// MARK: - History List Row (Dark Style)
struct HistoryListRow: View {
    let item: NotificationItem
    let onTap: () -> Void
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.softPeach.opacity(item.isRead ? 0.1 : 0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.softPeach.opacity(item.isRead ? 0.4 : 1.0))
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.project)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(item.isRead ? 0.4 : 1.0))
                            .lineLimit(1)

                        Spacer()

                        Text(item.timeRangeString)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(item.isRead ? 0.3 : 0.6))
                    }

                    if !item.message.isEmpty {
                        Text(item.message)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(item.isRead ? 0.3 : 0.7))
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        if !item.durationString.isEmpty {
                            Text(item.durationString)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(item.isRead ? 0.25 : 0.5))
                        }
                        if !item.modelShort.isEmpty {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(item.isRead ? 0.15 : 0.3))
                            Text(item.modelShort)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.softPeach.opacity(item.isRead ? 0.3 : 1.0))
                        }
                    }
                }

                // Remove button on hover
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(isHovered ? 0.8 : 0))
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(isHovered ? 0.15 : 0))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isHovered ? Color.white.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - HTTP Server
class HTTPServer {
    let port: UInt16
    var listener: NWListener?

    init(port: UInt16) {
        self.port = port
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port))

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: .global())
            print("Claude Notify listening on port \(port)")
        } catch {
            print("Failed to start server: \(error)")
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            if let data = data, let request = String(data: data, encoding: .utf8) {
                let response = self?.handleRequest(request) ?? "HTTP/1.1 500 Error\r\n\r\n"
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    private func handleRequest(_ request: String) -> String {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return httpResponse(400, "Bad Request") }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return httpResponse(400, "Bad Request") }

        let method = parts[0]
        let path = parts[1]

        if path == "/health" {
            return httpResponse(200, "ok")
        }

        if path == "/notify" && method == "POST" {
            if let bodyStart = request.range(of: "\r\n\r\n") {
                let body = String(request[bodyStart.upperBound...])
                if let data = body.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let projectPath = json["project"] as? String {

                    let projectName = (projectPath as NSString).lastPathComponent
                    let message = json["message"] as? String ?? ""
                    let model = json["model"] as? String

                    // Parse ISO8601 timestamps
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                    var startTime: Date? = nil
                    var endTime: Date? = nil

                    if let startStr = json["startTime"] as? String, !startStr.isEmpty {
                        startTime = isoFormatter.date(from: startStr)
                    }
                    if let endStr = json["endTime"] as? String, !endStr.isEmpty {
                        endTime = isoFormatter.date(from: endStr)
                    }

                    NotificationManager.shared.addNotification(
                        project: projectName,
                        path: projectPath,
                        message: message,
                        startTime: startTime,
                        endTime: endTime,
                        model: model
                    )
                    return httpResponse(200, "ok")
                }
            }
            return httpResponse(400, "Invalid JSON")
        }

        return httpResponse(404, "Not Found")
    }

    private func httpResponse(_ status: Int, _ body: String) -> String {
        let statusText = status == 200 ? "OK" : status == 400 ? "Bad Request" : "Not Found"
        return "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
    }
}
