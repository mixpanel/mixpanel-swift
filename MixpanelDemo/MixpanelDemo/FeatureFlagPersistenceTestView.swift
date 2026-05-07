//
//  FeatureFlagPersistenceTestView.swift
//  MixpanelDemo
//
//  Comprehensive test screen for Feature Flag Persistence (PR #723)
//
//  API Note: The actual API uses:
//  - `.persistenceUntilNetworkSuccess(ttl:)` not `.cacheFirst(ttl:)`
//  - `.persistence(persistedAt:)` not `.cache(cachedAt:)`
//  - `source` is always non-nil with `.fallback` case
//

import SwiftUI
import Mixpanel

// MARK: - Main View

struct FeatureFlagPersistenceTestView: View {
    @StateObject private var viewModel = FeatureFlagPersistenceViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Current flag policy: \(Mixpanel.mainInstance().getOptions().featureFlagOptions.variantLookupPolicy)")
                    // Policy Configuration
//                    PolicyConfigurationSection(viewModel: viewModel)

                    // Flag Inspection
                    FlagInspectionSection(viewModel: viewModel)

                    // Identity Controls
                    IdentityControlsSection(viewModel: viewModel)

                    // Cache Inspection
                    CacheInspectionSection(viewModel: viewModel)

                    // Event Log
                    EventLogSection(viewModel: viewModel)
                }
                .padding()
            }
//            .navigationTitle("Flag Persistence Test")
            .navigationBarTitleDisplayMode(.inline)
            .alert(item: $viewModel.activeAlert) { alertItem in
                alertItem.alert(copyAction: { viewModel.copyToClipboard(alertItem.message) })
            }
            .overlay(
                ToastView(message: viewModel.toastMessage, isShowing: $viewModel.showToast)
                    .animation(.spring(), value: viewModel.showToast),
                alignment: .top
            )
        }
    }
}

// MARK: - Policy Configuration Section

struct PolicyConfigurationSection: View {
    @ObservedObject var viewModel: FeatureFlagPersistenceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Policy Configuration")
                .font(.headline)

            // Current status
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Current Policy:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.currentPolicyDisplay)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                HStack {
                    Text("Current TTL:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.currentTTLDisplay)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            // Policy picker
            Picker("Policy", selection: $viewModel.selectedPolicy) {
                Text("Network Only").tag(PolicyOption.networkOnly)
                Text("Persistence Until Network Success").tag(PolicyOption.persistenceUntilNetworkSuccess)
                Text("Network First").tag(PolicyOption.networkFirst)
            }
            .pickerStyle(SegmentedPickerStyle())

            // TTL input
            if viewModel.selectedPolicy != .networkOnly {
                HStack {
                    Text("TTL (seconds):")
                        .font(.subheadline)
                    TextField("3600", text: $viewModel.ttlString)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                    Spacer()
                    Text("(\(viewModel.ttlInHours) hours)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Flag Inspection Section

struct FlagInspectionSection: View {
    @ObservedObject var viewModel: FeatureFlagPersistenceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flag Inspection")
                .font(.headline)

            // Flag name input
            TextField("Flag name", text: $viewModel.flagName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            // Query buttons
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Button("getVariant (async)") { viewModel.getVariantAsync() }
                    .buttonStyle(SecondaryButtonStyle())

                Button("getVariantSync") { viewModel.getVariantSync() }
                    .buttonStyle(SecondaryButtonStyle())

                Button("isEnabled (async)") { viewModel.isEnabledAsync() }
                    .buttonStyle(SecondaryButtonStyle())

                Button("isEnabledSync") { viewModel.isEnabledSync() }
                    .buttonStyle(SecondaryButtonStyle())

                Button("areFlagsReady()") { viewModel.checkAreFlagsReady() }
                    .buttonStyle(SecondaryButtonStyle())

                Button("loadFlags()") { viewModel.loadFlags() }
                    .buttonStyle(SecondaryButtonStyle())
            }

            // Last result card
            if let result = viewModel.lastFlagResult {
                ResultCard(result: result)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Identity Controls Section

struct IdentityControlsSection: View {
    @ObservedObject var viewModel: FeatureFlagPersistenceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Identity Controls")
                .font(.headline)

            // Current identity display
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Current distinctId:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.currentDistinctId)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            // Identify
            HStack {
                TextField("New distinctId", text: $viewModel.newDistinctId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("identify()") { viewModel.identify() }
                    .buttonStyle(SecondaryButtonStyle())
            }

            // Other identity buttons
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Button("reset()") { viewModel.reset() }
                    .buttonStyle(DestructiveButtonStyle())

                Button("optOutTracking()") { viewModel.optOut() }
                    .buttonStyle(DestructiveButtonStyle())

                Button("optInTracking()") { viewModel.optIn() }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Cache Inspection Section

struct CacheInspectionSection: View {
    @ObservedObject var viewModel: FeatureFlagPersistenceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cache Inspection")
                .font(.headline)

            HStack {
                Button("Inspect Cache") { viewModel.inspectCache() }
                    .buttonStyle(SecondaryButtonStyle())

                Button("Wipe Cache") { viewModel.wipeCache() }
                    .buttonStyle(DestructiveButtonStyle())
            }

            // Cache details card
            if let cacheInfo = viewModel.cacheInfo {
                CacheInfoCard(info: cacheInfo)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Event Log Section

struct EventLogSection: View {
    @ObservedObject var viewModel: FeatureFlagPersistenceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Event Log")
                    .font(.headline)
                Spacer()
                Button("Clear") { viewModel.clearLog() }
                    .font(.caption)
                    .foregroundColor(.red)
                Button("Copy") { viewModel.copyLog() }
                    .font(.caption)
            }

            if viewModel.eventLog.isEmpty {
                Text("No events yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.eventLog.reversed()) { event in
                            LogRow(event: event)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Supporting Views

struct ResultCard: View {
    let result: FlagResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last Result")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(result.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                DetailRow(label: "Flag", value: result.flagName)
                DetailRow(label: "Key", value: result.variantKey)
                DetailRow(label: "Value", value: "\(result.variantValue)")
                DetailRow(label: "Source", value: result.sourceDescription)
                    .foregroundColor(result.sourceColor)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CacheInfoCard: View {
    let info: CacheInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cache Details")
                .font(.subheadline)
                .fontWeight(.semibold)

            Divider()

            DetailRow(label: "Distinct ID", value: info.distinctId)
            DetailRow(label: "Persisted At", value: info.persistedAtDisplay)
            DetailRow(label: "Age", value: info.ageDisplay)
            DetailRow(label: "Within TTL?", value: info.withinTTL ? "✅ Yes" : "❌ No")
                .foregroundColor(info.withinTTL ? .green : .red)

            Text("Response Preview:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            Text(info.responsePreview)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct LogRow: View {
    let event: LogEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("•")
                    .foregroundColor(.secondary)
                Text(event.type)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            Text(event.message)
                .font(.caption)
            if let details = event.details {
                Text(details)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(4)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            Text(message)
                .padding()
                .background(Color.green.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.top, 50)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isShowing = false
                        }
                    }
                }
        }
    }
}

// MARK: - Button Styles

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(configuration.isPressed ? 0.5 : 0.7))
            .foregroundColor(.white)
            .cornerRadius(6)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(configuration.isPressed ? 0.5 : 0.7))
            .foregroundColor(.white)
            .cornerRadius(6)
    }
}

// MARK: - View Model

class FeatureFlagPersistenceViewModel: ObservableObject {
    // Policy configuration
    @Published var selectedPolicy: PolicyOption = .networkOnly
    @Published var ttlString: String = "3600"
    @Published var currentPolicyDisplay: String = "Network Only"
    @Published var currentTTLDisplay: String = "N/A"

    // Flag inspection
    @Published var flagName: String = "agent_automation"
    @Published var lastFlagResult: FlagResult?

    // Identity
    @Published var newDistinctId: String = ""
    @Published var currentDistinctId: String = ""

    // Cache
    @Published var cacheInfo: CacheInfo?

    // Event log
    @Published var eventLog: [LogEvent] = []

    // Alerts & Toasts
    @Published var activeAlert: AlertItem?
    @Published var toastMessage: String = ""
    @Published var showToast: Bool = false

    private var mixpanelInstance: MixpanelInstance?
    private let instanceName = "9c4e9a6caf9f429a7e3821141fc769b7"

    var ttlInHours: String {
        guard let ttl = TimeInterval(ttlString) else { return "0" }
        return String(format: "%.1f", ttl / 3600)
    }

    init() {
        updateCurrentStatus()
        mixpanelInstance = Mixpanel.mainInstance()
        currentDistinctId = mixpanelInstance?.distinctId ?? "Not set"
    }

    // MARK: - Policy Configuration

    private func updateCurrentStatus() {
        if let instance = mixpanelInstance ?? Mixpanel.getInstance(name: instanceName) {

            let options = instance.getOptions()
            let policy = options.featureFlagOptions.variantLookupPolicy

            switch policy {
            case .networkOnly:
                currentPolicyDisplay = "Network Only"
                currentTTLDisplay = "N/A"
            case .persistenceUntilNetworkSuccess(let ttl):
                currentPolicyDisplay = "Persistence Until Network Success"
                currentTTLDisplay = "\(Int(ttl))s (\(String(format: "%.1f", ttl/3600))h)"
            case .networkFirst(let ttl):
                currentPolicyDisplay = "Network First"
                currentTTLDisplay = "\(Int(ttl))s (\(String(format: "%.1f", ttl/3600))h)"
            }
        } else {
            currentPolicyDisplay = "Not initialized"
            currentTTLDisplay = "N/A"
            currentDistinctId = "N/A"
        }
    }

    // MARK: - Flag Inspection

    func getVariantAsync() {
        guard let instance = getInstance() else { return }
        let startTime = Date()

        instance.flags.getVariant(flagName, fallback: MixpanelFlagVariant(value: "fallback")) { [weak self] variant in
            let duration = Date().timeIntervalSince(startTime)
            self?.handleVariantResult(variant, operation: "getVariant (async)", duration: duration)
        }
    }

    func getVariantSync() {
        guard let instance = getInstance() else { return }
        let startTime = Date()

        let variant = instance.flags.getVariantSync(flagName, fallback: MixpanelFlagVariant(value: "fallback"))
        let duration = Date().timeIntervalSince(startTime)

        handleVariantResult(variant, operation: "getVariantSync", duration: duration)
    }

    func isEnabledAsync() {
        guard let instance = getInstance() else { return }
        let startTime = Date()

        instance.flags.isEnabled(flagName, fallbackValue: false) { [weak self] enabled in
            let duration = Date().timeIntervalSince(startTime)
            let variant = MixpanelFlagVariant(
                key: enabled ? "true" : "false",
                value: enabled
            )
            self?.handleVariantResult(variant, operation: "isEnabled (async)", duration: duration)
        }
    }

    func isEnabledSync() {
        guard let instance = getInstance() else { return }
        let startTime = Date()

        let enabled = instance.flags.isEnabledSync(flagName, fallbackValue: false)
        let duration = Date().timeIntervalSince(startTime)

        let variant = MixpanelFlagVariant(
            key: enabled ? "true" : "false",
            value: enabled
        )
        handleVariantResult(variant, operation: "isEnabledSync", duration: duration)
    }

    func checkAreFlagsReady() {
        guard let instance = getInstance() else { return }

        let ready = instance.flags.areFlagsReady()
        let explanation: String

        switch currentPolicyDisplay {
        case "Network Only":
            explanation = ready ? "Flags loaded from network" : "No flags loaded yet"
        case "Persistence Until Network Success":
            explanation = ready ? "Flags available (from cache or network)" : "No cached or network flags"
        case "Network First":
            explanation = ready ? "Flags available (may be cached, awaiting network)" : "No cached or network flags"
        default:
            explanation = "Unknown policy"
        }

        showAlert(
            title: ready ? "✅ Flags Ready" : "❌ Flags Not Ready",
            message: "\(ready)\n\n\(explanation)",
            type: "FLAGS_READY"
        )
    }

    func loadFlags() {
        guard let instance = getInstance() else { return }
        let startTime = Date()

        instance.flags.loadFlags { [weak self] success in
            let duration = Date().timeIntervalSince(startTime)
            let message = success
                ? "✅ Success\nDuration: \(String(format: "%.2f", duration))s"
                : "❌ Failed\nDuration: \(String(format: "%.2f", duration))s"

            self?.showAlert(
                title: "loadFlags() Complete",
                message: message,
                type: "LOAD_FLAGS"
            )
        }
    }

    private func handleVariantResult(_ variant: MixpanelFlagVariant, operation: String, duration: TimeInterval) {
        let sourceDesc = describeSource(variant.source)
        let result = FlagResult(
            flagName: flagName,
            variantKey: variant.key,
            variantValue: variant.value ?? "nil",
            source: variant.source,
            timestamp: Date()
        )

        DispatchQueue.main.async {
            self.lastFlagResult = result

            let message = """
            Flag: \(self.flagName)
            Value: \(variant.value ?? "nil")
            Source: \(operation.range(of: "isEnabled") != nil ? "N/A" :sourceDesc)
            Duration: \(String(format: "%.3f", duration))s
            """

//            self.showAlert(
//                title: "🏁 \(operation)",
//                message: message,
//                type: "FLAG_QUERY"
//            )
        }
    }

    // MARK: - Identity Controls

    func identify() {
        guard !newDistinctId.isEmpty, let instance = getInstance() else { return }

        let oldId = instance.distinctId
        instance.identify(distinctId: newDistinctId)

        updateCurrentStatus()

        showAlert(
            title: "✅ Identified",
            message: "Old: \(oldId)\nNew: \(newDistinctId)\n\n⚠️ Cache invalidated for old identity",
            type: "IDENTIFY"
        )

        newDistinctId = ""
    }

    func reset() {
        guard let instance = getInstance() else { return }

        let oldId = instance.distinctId
        instance.reset()

        updateCurrentStatus()

        showAlert(
            title: "🔄 Reset Complete",
            message: "Old ID: \(oldId)\nNew ID: \(instance.distinctId)\n\n⚠️ Cache cleared",
            type: "RESET"
        )
    }

    func optOut() {
        guard let instance = getInstance() else { return }

        instance.optOutTracking()

        updateCurrentStatus()

        showAlert(
            title: "🚫 Opted Out",
            message: "Tracking disabled\nNew anonymous ID: \(instance.distinctId)\n\n⚠️ Cache cleared",
            type: "OPT_OUT"
        )
    }

    func optIn() {
        guard let instance = getInstance() else { return }

        instance.optInTracking(distinctId: Mixpanel.mainInstance().distinctId)

        showAlert(
            title: "✅ Opted In",
            message: "Tracking enabled",
            type: "OPT_IN"
        )
    }

    // MARK: - Cache Inspection

    func inspectCache() {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            showAlert(title: "⚠️ Error", message: "Could not access UserDefaults", type: "ERROR")
            return
        }

        let key = "mixpanel-\(instanceName)-MPFlagsPersistence"
        guard let data = defaults.data(forKey: key) else {
            showAlert(
                title: "ℹ️ No Cache",
                message: "No cached flags found",
                type: "CACHE_INSPECT"
            )
            return
        }

        do {
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let persistedAtMillis = dict["persistedAt"] as? Int64,
                  let distinctId = dict["distinctId"] as? String,
                  let response = dict["response"] as? String else {
                showAlert(title: "⚠️ Error", message: "Cache blob has unexpected format", type: "ERROR")
                return
            }

            let persistedAt = Date(timeIntervalSince1970: TimeInterval(persistedAtMillis) / 1000.0)
            let age = Date().timeIntervalSince(persistedAt)
            let currentTTL = TimeInterval(ttlString) ?? 3600
            let withinTTL = selectedPolicy != .networkOnly && age <= currentTTL

            let preview = String(response.prefix(100)) + (response.count > 100 ? "..." : "")

            cacheInfo = CacheInfo(
                distinctId: distinctId,
                persistedAt: persistedAt,
                age: age,
                withinTTL: withinTTL,
                responsePreview: preview
            )

            logEvent(type: "CACHE_INSPECT", message: "Cache inspected: age \(Int(age))s, within TTL: \(withinTTL)")
        } catch {
            showAlert(title: "⚠️ Error", message: "Failed to parse cache: \(error)", type: "ERROR")
        }
    }

    func wipeCache() {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            showAlert(title: "⚠️ Error", message: "Could not access UserDefaults", type: "ERROR")
            return
        }

        let key = "mixpanel-\(instanceName)-MPFlagsPersistence"
        let hadCache = defaults.data(forKey: key) != nil

        defaults.removeObject(forKey: key)
        cacheInfo = nil

        showAlert(
            title: hadCache ? "🗑️ Cache Wiped" : "ℹ️ No Cache",
            message: hadCache ? "Cache blob deleted" : "No cache blob existed",
            type: "CACHE_WIPE"
        )
    }

    // MARK: - Event Log

    func clearLog() {
        eventLog.removeAll()
    }

    func copyLog() {
        let logText = eventLog.reversed().map { event in
            var text = "[\(event.timestamp)] \(event.type): \(event.message)"
            if let details = event.details {
                text += "\n  \(details)"
            }
            return text
        }.joined(separator: "\n\n")

        UIPasteboard.general.string = logText
        showToast(message: "📋 Log copied to clipboard")
    }

    private func logEvent(type: String, message: String, details: String? = nil) {
        let event = LogEvent(type: type, message: message, details: details)
        DispatchQueue.main.async {
            self.eventLog.append(event)
        }
    }

    // MARK: - Helpers

    private func getInstance() -> MixpanelInstance? {
        if let instance = mixpanelInstance ?? Mixpanel.getInstance(name: instanceName) {
            return instance
        }
        showAlert(title: "⚠️ Error", message: "Mixpanel not initialized. Tap 'Re-initialize Mixpanel' first.", type: "ERROR")
        return nil
    }

    private func showAlert(title: String, message: String, type: String) {
        DispatchQueue.main.async {
            self.activeAlert = AlertItem(title: title, message: message)
            self.logEvent(type: type, message: message)
        }
    }

    private func showToast(message: String) {
        DispatchQueue.main.async {
            self.toastMessage = message
            withAnimation {
                self.showToast = true
            }
        }
    }

    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        showToast(message: "📋 Copied to clipboard")
    }

    private func describeSource(_ source: MixpanelFlagVariant.Source) -> String {
        switch source {
        case .network:
            return "Served from network"
        case .persistence(let persistedAt):
            let age = Date().timeIntervalSince(persistedAt)
            return "Served from cache (persisted \(Int(age))s ago)"
        case .fallback:
            return "Served fallback — flag not found"
        }
    }
}

// MARK: - Models

enum PolicyOption {
    case networkOnly
    case persistenceUntilNetworkSuccess
    case networkFirst

    var displayName: String {
        switch self {
        case .networkOnly: return "Network Only"
        case .persistenceUntilNetworkSuccess: return "Persistence Until Network Success"
        case .networkFirst: return "Network First"
        }
    }
}

struct FlagResult {
    let flagName: String
    let variantKey: String
    let variantValue: Any
    let source: MixpanelFlagVariant.Source
    let timestamp: Date

    var sourceDescription: String {
        switch source {
        case .network:
            return "🌐 Network (fresh)"
        case .persistence(let persistedAt):
            let age = Date().timeIntervalSince(persistedAt)
            return "💾 Persistence (\(Int(age))s ago)"
        case .fallback:
            return "🔄 Fallback (not found)"
        }
    }

    var sourceColor: Color {
        switch source {
        case .network: return .green
        case .persistence: return .orange
        case .fallback: return .gray
        }
    }
}

struct CacheInfo {
    let distinctId: String
    let persistedAt: Date
    let age: TimeInterval
    let withinTTL: Bool
    let responsePreview: String

    var persistedAtDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: persistedAt)
    }

    var ageDisplay: String {
        if age < 60 {
            return "\(Int(age)) seconds"
        } else if age < 3600 {
            return "\(Int(age / 60)) minutes"
        } else {
            return String(format: "%.1f hours", age / 3600)
        }
    }
}

struct LogEvent: Identifiable {
    let id = UUID()
    let timestamp: Date = Date()
    let type: String
    let message: String
    let details: String?
}

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    func alert(copyAction: @escaping () -> Void) -> Alert {
        Alert(
            title: Text(title),
            message: Text(message),
            primaryButton: .default(Text("OK")),
            secondaryButton: .default(Text("Copy")) {
                copyAction()
            }
        )
    }
}

// MARK: - Preview

struct FeatureFlagPersistenceTestView_Previews: PreviewProvider {
    static var previews: some View {
        FeatureFlagPersistenceTestView()
    }
}

