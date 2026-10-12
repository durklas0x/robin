import SwiftUI
import ServiceManagement

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(nsImage: AppArtwork.icon)
                    .resizable().frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.bold())
                    Text(subtitle).foregroundStyle(.secondary)
                }
            }

            ScrollView {
                Group {
                    switch model.progress.step {
                    case .welcome: welcome
                    case .finderExtension: finderExtension
                    case .automation: automation
                    case .tour: tour
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            Spacer(minLength: 0)
            Divider()
            HStack {
                Text("\(model.progress.step.rawValue + 1) of \(OnboardingProgress.Step.allCases.count)")
                    .font(.callout).foregroundStyle(.secondary)
                    .accessibilityLabel("Step \(model.progress.step.rawValue + 1) of 4")
                Spacer()
                if model.progress.step != .welcome {
                    Button("Back") { model.back() }.disabled(model.checking)
                }
                Button(model.progress.step == .tour ? "Start Robin" : "Continue") {
                    Task { if await model.advance() { onFinish() } }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canContinue)
            }
        }
        .padding(24)
        .frame(width: 480, height: 440)
    }

    private var title: String {
        switch model.progress.step {
        case .welcome: "Finder’s little sidekick."
        case .finderExtension: "Add your Finder actions"
        case .automation: "Connect Robin to Finder"
        case .tour: "You’re ready to go"
        }
    }

    private var subtitle: String {
        switch model.progress.step {
        case .welcome: "A few quick steps, then back to your folders."
        case .finderExtension: "New File, paths, and tools in your right-click menu."
        case .automation: "Keep the path bar beside your current window."
        case .tour: "Your folder actions, right beside Finder."
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            PathBarIllustration()
            Text("Robin adds an editable path bar below Finder and handy actions to its right-click menu.")
            Text("First, enable the Finder extension and allow Finder access. Then take a quick tour.")
                .foregroundStyle(.secondary)
        }
    }

    private var finderExtension: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(model.extensionEnabled ? "Finder extension is enabled" : "Enable Robin in the extension sheet",
                  systemImage: model.extensionEnabled ? "checkmark.circle.fill" : "puzzlepiece.extension")
                .font(.headline)
            Text("Open Extension Settings, turn on Robin, then click Done. macOS may call this sheet File Providers.")
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open Extension Settings…") { FinderExtensionSettings.open() }
                Button("Check Again") { Task { await model.refresh() } }
                    .disabled(model.checking)
            }
            Text(model.extensionEnabled ? "You can continue." : "Return here after enabling Robin. This step is required.")
                .foregroundStyle(.secondary)
        }
    }

    private var automation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(automationTitle, systemImage: model.automation == .allowed ? "checkmark.circle.fill" : "folder")
                .font(.headline)
            Text("Robin needs Finder Automation access to read the current folder and navigate when you edit the path.")
                .fixedSize(horizontal: false, vertical: true)
            switch model.automation {
            case .checking:
                ProgressView("Checking Finder access…").controlSize(.small)
            case .allowed:
                Text("Finder access is allowed. You can continue.").foregroundStyle(.secondary)
            case .notRequested:
                Button("Allow Finder Access…") { Task { await model.refresh(requestAutomation: true) } }
                    .disabled(model.checking)
                Text("Choose Allow in the macOS prompt.").foregroundStyle(.secondary)
            case .denied:
                Text("In System Settings → Privacy & Security → Automation, turn on Finder under Robin. Then return here.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Open Automation Settings…") { model.openAutomationSettings() }
            case .finderNotRunning:
                Text("Open Finder, then check again.").foregroundStyle(.secondary)
                Button("Open Finder") { model.openFinder() }
            case .unavailable(let code):
                Text("Could not check Finder access (\(code)). Open Finder and try again.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Button("Check Again") { Task { await model.refresh() } }.disabled(model.checking)
            if !model.extensionEnabled {
                Button("Enable the Finder extension first") { model.reviewPermissions() }
            }
        }
    }

    private var automationTitle: String {
        model.automation == .allowed ? "Finder access is allowed" : "Allow Robin to work with Finder"
    }

    private var tour: some View {
        VStack(alignment: .leading, spacing: 12) {
            PathBarIllustration()
            Text("Click the path to edit it. Press Return to open the folder, or Escape to cancel.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Use the buttons to copy the path, create a file, or open Terminal or an editor. These actions are also in Finder’s right-click menu.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Terminal asks for access on first use. You choose an editor when opening a folder.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Launch Robin at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLoginEnabled($0) }))
                .toggleStyle(.checkbox)
            if model.loginNeedsApproval {
                Button("Approve in Login Items…") { SMAppService.openSystemSettingsLoginItems() }
            }
            if !model.loginError.isEmpty {
                Text(model.loginError).font(.callout).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !model.extensionEnabled || model.automation != .allowed {
                Button("Review required permissions") { model.reviewPermissions() }
            }
        }
    }
}

private struct PathBarIllustration: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
            Text("~/Documents").lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "doc.on.doc")
            Image(systemName: "doc.badge.plus")
            Image(systemName: "terminal")
            Image(systemName: "curlybraces")
        }
        .font(.system(size: 15))
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Path bar example with a folder path and buttons for Copy Path, New File, Terminal, and Editor")
    }
}
