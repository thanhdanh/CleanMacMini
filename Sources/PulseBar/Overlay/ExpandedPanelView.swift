import AppKit
import Charts
import SwiftUI

private enum ProcessTableLayout {
    static let spacing: CGFloat = 8
    static let horizontalPadding: CGFloat = 5
    static let iconWidth: CGFloat = 22
    static let cpuWidth: CGFloat = 54
    static let memoryWidth: CGFloat = 82
    static let actionWidth: CGFloat = 24
}

struct ExpandedPanelView: View {
    @ObservedObject var state: AppState
    var onDragChange: (() -> Void)?
    var onDragEnd: (() -> Void)?
    @State private var showsSettings = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Color.clear

                HStack {
                    Text(AppVersion.display)
                        .font(.caption2.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.leading, 4)

                Capsule()
                    .fill(.secondary.opacity(0.55))
                    .frame(width: 40, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { _ in onDragChange?() }
                    .onEnded { _ in onDragEnd?() }
            )
            .help("Drag to move PulseBar")

            HStack(spacing: 7) {
                if showsSettings {
                    Label("Settings", systemImage: "gearshape.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                } else {
                    Picker("Section", selection: $state.selectedTab) {
                        ForEach(AppState.Tab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showsSettings.toggle()
                    }
                } label: {
                    Image(systemName: showsSettings ? "xmark" : "gearshape")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .help(showsSettings ? "Close settings" : "Overlay settings")
            }

            Group {
                if showsSettings {
                    SettingsView(preferences: state.preferences)
                } else {
                    switch state.selectedTab {
                    case .processes:
                        ProcessesView(service: state.processes, metrics: state.metrics)
                    case .memory:
                        MemoryView(
                            metricsService: state.metrics,
                            processService: state.processes,
                            reliefService: state.memory
                        )
                    case .clean:
                        CleanView(service: state.disk)
                    }
                }
            }
            .frame(width: 360, height: 460)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

private struct MetricChartCard: View {
    let title: String
    let currentValue: Double
    let color: Color
    let points: [MetricHistoryPoint]
    let value: KeyPath<MetricHistoryPoint, Double>
    var chartHeight: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(String(format: "%.1f%%", currentValue))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(color)
            }

            Chart(points) { point in
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value(title, point[keyPath: value])
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value(title, point[keyPath: value])
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) {
                    AxisGridLine().foregroundStyle(.white.opacity(0.08))
                    AxisValueLabel()
                }
            }
            .frame(height: chartHeight)
            .overlay {
                if points.count < 2 {
                    Text("Collecting samples…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct SettingsView: View {
    @ObservedObject var preferences: PreferencesService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsGroup("Refresh intervals", symbol: "timer") {
                settingPicker("System metrics", selection: $preferences.metricsInterval)
                settingPicker("Processes", selection: $preferences.processInterval)

                Text("Low Power Mode uses an interval of at least 2 seconds.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            settingsGroup("Overlay appearance", symbol: "paintpalette") {
                HStack {
                    Text("Gradient")
                    Spacer()
                    Picker("Gradient", selection: $preferences.appearance) {
                        ForEach(OverlayAppearance.allCases) { appearance in
                            Text(appearance.rawValue).tag(appearance)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 130)
                }

                HStack {
                    Text("Tint strength")
                    Slider(value: $preferences.tintStrength, in: 0...0.45)
                    Text("\(Int(preferences.tintStrength / 0.45 * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
            }

            Spacer()

            HStack {
                Text("Preferences are saved automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset") { preferences.reset() }
            }
        }
        .padding(.top, 2)
    }

    private func settingsGroup<Content: View>(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 3)
        } label: {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
        }
    }

    private func settingPicker(
        _ label: String,
        selection: Binding<RefreshInterval>
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            Picker(label, selection: selection) {
                ForEach(RefreshInterval.allCases) { interval in
                    Text(interval.label).tag(interval)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 130)
        }
    }
}

private struct ProcessesView: View {
    @ObservedObject var service: ProcessService
    @ObservedObject var metrics: MetricsService
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 8) {
            MetricChartCard(
                title: "CPU history · 5 min",
                currentValue: metrics.snapshot.cpuPercent,
                color: .green,
                points: metrics.history,
                value: \.cpuPercent
            )

            HStack {
                TextField("Search process or PID", text: $service.query)
                    .textFieldStyle(.roundedBorder)

                Picker("Sort", selection: $service.sort) {
                    ForEach(ProcessSort.allCases) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 105)
            }

            HStack(spacing: ProcessTableLayout.spacing) {
                Color.clear
                    .frame(width: ProcessTableLayout.iconWidth, height: 1)
                Text("Process")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("CPU")
                    .frame(width: ProcessTableLayout.cpuWidth, alignment: .trailing)
                Text("Memory")
                    .frame(width: ProcessTableLayout.memoryWidth, alignment: .trailing)
                Color.clear
                    .frame(width: ProcessTableLayout.actionWidth, height: 1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, ProcessTableLayout.horizontalPadding)
            .padding(.vertical, 5)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))

            GeometryReader { viewport in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(service.items) { item in
                            ProcessRow(item: item) { force in
                                errorMessage = service.quit(item, force: force)
                            }
                        }
                    }
                    .frame(width: viewport.size.width, alignment: .top)
                }
                .defaultScrollAnchor(.top)
                .overlay {
                    if service.items.isEmpty {
                        ContentUnavailableView(
                            "No Processes",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Process activity will appear here shortly.")
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .alert("Could Not Stop Process", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }
}

private struct ProcessRow: View {
    let item: ProcessInfoItem
    let stop: (Bool) -> Void

    var body: some View {
        HStack(spacing: ProcessTableLayout.spacing) {
            Group {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                } else {
                    Image(systemName: item.isApp ? "app" : "gearshape")
                        .resizable()
                        .scaledToFit()
                        .padding(3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: ProcessTableLayout.iconWidth, height: ProcessTableLayout.iconWidth)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .lineLimit(1)
                    .help(item.name)
                Text(processSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(String(format: "%.1f%%", item.cpuPercent))
                .monospacedDigit()
                .frame(width: ProcessTableLayout.cpuWidth, alignment: .trailing)
            Text(ByteFormat.string(item.memoryBytes))
                .monospacedDigit()
                .frame(width: ProcessTableLayout.memoryWidth, alignment: .trailing)

            Menu {
                Button("Quit") { stop(false) }
                Button("Force Stop", role: .destructive) { stop(true) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: ProcessTableLayout.actionWidth, height: ProcessTableLayout.actionWidth)
            }
            .frame(width: ProcessTableLayout.actionWidth)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .disabled(item.isProtected)
            .help(item.isProtected ? "Protected system process" : "Process actions")
        }
        .font(.system(size: 11))
        .padding(.vertical, 4)
        .padding(.horizontal, ProcessTableLayout.horizontalPadding)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
    }

    private var processSubtitle: String {
        if item.processCount > 1 {
            return "\(item.processCount) processes · PID \(item.pid)"
        }
        return "PID \(item.pid)"
    }
}

private struct MemoryView: View {
    @ObservedObject var metricsService: MetricsService
    @ObservedObject var processService: ProcessService
    @ObservedObject var reliefService: MemoryReliefService
    @State private var selectedPIDs: Set<pid_t> = []
    @State private var showsAllConsumers = true

    private var metrics: SystemMetrics {
        metricsService.snapshot
    }

    private var apps: [ProcessInfoItem] {
        processService.applications
            .filter { !$0.isProtected }
            .sorted { $0.memoryBytes > $1.memoryBytes }
    }

    private var consumers: [ProcessInfoItem] {
        showsAllConsumers ? processService.memoryConsumers : apps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Memory")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(ByteFormat.string(metrics.memoryUsedBytes)) of \(ByteFormat.string(metrics.memoryTotalBytes))")
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    PressureBadge(pressure: metrics.pressure)
                    Text("\(ByteFormat.string(metrics.reclaimableBytes)) reclaimable")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            MemoryCompositionBar(metrics: metrics)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3),
                spacing: 5
            ) {
                MemoryKindCell(title: "App Memory", value: metrics.appMemoryBytes, color: .purple)
                MemoryKindCell(title: "Wired", value: metrics.wiredBytes, color: .orange)
                MemoryKindCell(title: "Compressed", value: metrics.compressorBytes, color: .pink)
                MemoryKindCell(title: "Cached Files", value: metrics.cachedFilesBytes, color: .blue)
                MemoryKindCell(title: "Swap Used", value: metrics.swapUsedBytes, color: .indigo)
                MemoryKindCell(title: "Free", value: metrics.freeBytes, color: .green)
            }

            MetricChartCard(
                title: "RAM history · 5 min",
                currentValue: metrics.memoryUsedRatio * 100,
                color: .purple,
                points: metricsService.history,
                value: \.memoryPercent,
                chartHeight: 48
            )

            HStack {
                Text("Top consumers")
                    .font(.caption.weight(.semibold))
                Spacer()
                Picker("Consumers", selection: $showsAllConsumers) {
                    Text("All").tag(true)
                    Text("Apps").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 104)
                .controlSize(.mini)
            }

            GeometryReader { viewport in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(consumers) { item in
                            MemoryConsumerRow(
                                item: item,
                                totalBytes: metrics.memoryTotalBytes,
                                isSelected: selectedPIDs.contains(item.pid)
                            ) { selected in
                                if selected { selectedPIDs.insert(item.pid) }
                                else { selectedPIDs.remove(item.pid) }
                            }
                        }
                    }
                    .frame(width: viewport.size.width, alignment: .top)
                }
                .defaultScrollAnchor(.top)
                .overlay {
                    if consumers.isEmpty {
                        Text("Collecting process activity…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                let selected = apps.filter { selectedPIDs.contains($0.pid) }
                Task {
                    await reliefService.freeUp(metrics: metrics, quitApps: selected)
                    selectedPIDs.removeAll()
                }
            } label: {
                HStack {
                    if reliefService.isWorking { ProgressView().controlSize(.small) }
                    Text(freeUpButtonTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(reliefService.isWorking)
            .help("Purge inactive memory and close any selected apps")

            if let message = reliefService.lastMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var freeUpButtonTitle: String {
        if reliefService.isWorking { return "Freeing Up Memory…" }
        if selectedPIDs.isEmpty {
            return metrics.reclaimableBytes > 0
                ? "Free Up \(ByteFormat.string(metrics.reclaimableBytes))"
                : "Free Up Memory"
        }
        return "Free Up Memory · Close \(selectedPIDs.count)"
    }
}

private struct MemoryCompositionBar: View {
    let metrics: SystemMetrics

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                segment(metrics.appMemoryBytes, color: .purple, width: geometry.size.width)
                segment(metrics.wiredBytes, color: .orange, width: geometry.size.width)
                segment(metrics.compressorBytes, color: .pink, width: geometry.size.width)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 8)
        .background(.secondary.opacity(0.16), in: Capsule())
        .clipShape(Capsule())
        .accessibilityLabel("Memory composition")
        .accessibilityValue("App memory \(ByteFormat.string(metrics.appMemoryBytes)), wired \(ByteFormat.string(metrics.wiredBytes)), compressed \(ByteFormat.string(metrics.compressorBytes))")
    }

    private func segment(_ bytes: UInt64, color: Color, width: CGFloat) -> some View {
        color.frame(width: max(0, width * ratio(bytes)))
    }

    private func ratio(_ bytes: UInt64) -> CGFloat {
        guard metrics.memoryTotalBytes > 0 else { return 0 }
        return CGFloat(Double(bytes) / Double(metrics.memoryTotalBytes))
    }
}

private struct MemoryKindCell: View {
    let title: String
    let value: UInt64
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(ByteFormat.string(value))
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct MemoryConsumerRow: View {
    let item: ProcessInfoItem
    let totalBytes: UInt64
    let isSelected: Bool
    let select: (Bool) -> Void

    var body: some View {
        HStack(spacing: 7) {
            if canClose {
                Toggle("", isOn: Binding(get: { isSelected }, set: select))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            } else {
                Color.clear.frame(width: 14, height: 14)
            }

            Group {
                if let icon = item.icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: item.isApp ? "app" : "gearshape")
                        .resizable()
                        .scaledToFit()
                        .padding(2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name)
                        .lineLimit(1)
                    Spacer()
                    Text(ByteFormat.string(item.memoryBytes))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: memoryRatio)
                    .progressViewStyle(.linear)
                    .tint(item.isApp ? .purple : .blue)
            }
        }
        .font(.system(size: 10))
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
        .help(canClose ? "Select to close this app when freeing memory" : "Background or protected process")
    }

    private var canClose: Bool { item.isApp && !item.isProtected }

    private var memoryRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(item.memoryBytes) / Double(totalBytes))
    }
}

private struct PressureBadge: View {
    let pressure: MemoryPressure

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
    }

    private var label: String {
        switch pressure {
        case .normal: "Normal"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }

    private var color: Color {
        switch pressure {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        }
    }
}

private struct CleanView: View {
    @ObservedObject var service: DiskCleanerService

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Available storage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ByteFormat.string(service.diskFreeBytes))
                        .font(.headline)
                }
                Spacer()
                Button {
                    service.scan()
                } label: {
                    Label(service.isScanning ? "Scanning…" : "Scan", systemImage: "magnifyingglass")
                }
                .disabled(service.isScanning || service.isCleaning)
            }

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(service.categories) { category in
                        Toggle(isOn: Binding(
                            get: { category.isSelected },
                            set: { _ in service.toggleCategory(category.id) }
                        )) {
                            HStack(spacing: 8) {
                                Image(systemName: category.symbol)
                                    .frame(width: 20)
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(category.title)
                                    Text(category.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(ByteFormat.string(category.bytes))
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(.vertical, 4)
                    }
                }
            }
            .overlay {
                if service.categories.isEmpty && !service.isScanning {
                    ContentUnavailableView(
                        "Ready to Scan",
                        systemImage: "internaldrive",
                        description: Text("Review files before removing anything.")
                    )
                }
            }

            if service.isScanning {
                ProgressView()
            }

            Button(role: .destructive) {
                Task { await service.cleanSelected() }
            } label: {
                HStack {
                    if service.isCleaning { ProgressView().controlSize(.small) }
                    Text(service.isCleaning ? "Cleaning…" : "Remove \(ByteFormat.string(service.selectedBytes))")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(service.selectedBytes == 0 || service.isScanning || service.isCleaning)

            if let message = service.lastMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            service.refreshVolumeStats()
        }
    }
}
