import AppKit
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

    var body: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(.secondary.opacity(0.55))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .global)
                        .onChanged { _ in onDragChange?() }
                        .onEnded { _ in onDragEnd?() }
                )
                .help("Drag to move PulseBar")

            Picker("Section", selection: $state.selectedTab) {
                ForEach(AppState.Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch state.selectedTab {
                case .processes:
                    ProcessesView(service: state.processes)
                case .memory:
                    MemoryView(
                        metrics: state.metrics.snapshot,
                        processService: state.processes,
                        reliefService: state.memory
                    )
                case .clean:
                    CleanView(service: state.disk)
                }
            }
            .frame(width: 360, height: 360)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

private struct ProcessesView: View {
    @ObservedObject var service: ProcessService
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 8) {
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
                Text("PID \(item.pid)")
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
}

private struct MemoryView: View {
    let metrics: SystemMetrics
    @ObservedObject var processService: ProcessService
    @ObservedObject var reliefService: MemoryReliefService
    @State private var selectedPIDs: Set<pid_t> = []

    private var apps: [ProcessInfoItem] {
        processService.applications
            .filter { !$0.isProtected }
            .sorted { $0.memoryBytes > $1.memoryBytes }
    }

    private var listedAppBytes: UInt64 {
        apps.reduce(0) { $0 + $1.memoryBytes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Memory used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(ByteFormat.string(metrics.memoryUsedBytes)) of \(ByteFormat.string(metrics.memoryTotalBytes))")
                        .font(.headline)
                }
                Spacer()
                PressureBadge(pressure: metrics.pressure)
            }

            ProgressView(value: metrics.memoryUsedRatio)
                .tint(pressureColor)

            HStack {
                Label("Reclaimable", systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                Text(ByteFormat.string(metrics.reclaimableBytes))
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Label("Running apps", systemImage: "app.badge")
                Spacer()
                Text(ByteFormat.string(listedAppBytes))
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Text("Apps to close")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("Largest first")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(apps) { item in
                        Toggle(isOn: Binding(
                            get: { selectedPIDs.contains(item.pid) },
                            set: { selected in
                                if selected { selectedPIDs.insert(item.pid) }
                                else { selectedPIDs.remove(item.pid) }
                            }
                        )) {
                            HStack {
                                Text(item.name).lineLimit(1)
                                Spacer()
                                Text(ByteFormat.string(item.memoryBytes))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(.vertical, 3)
                    }
                }
            }

            Button {
                let selected = apps.filter { selectedPIDs.contains($0.pid) }
                Task {
                    await reliefService.relieve(metrics: metrics, quitApps: selected)
                    selectedPIDs.removeAll()
                }
            } label: {
                HStack {
                    if reliefService.isWorking { ProgressView().controlSize(.small) }
                    Text(reliefService.isWorking ? "Relieving Memory…" : "Relieve Memory")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(reliefService.isWorking)

            if let message = reliefService.lastMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var pressureColor: Color {
        switch metrics.pressure {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        }
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
