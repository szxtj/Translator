import SwiftUI
import Combine

final class SettingsState: ObservableObject {
    @Published var loadedModels: [String] = []
    @Published var isLoadingModels = false
    @Published var errorMessage: String?
}

struct SettingsView: View {
    @AppStorage("apiEndpoint") private var apiEndpoint = "http://localhost:1234/v1"
    @AppStorage("selectedModel") private var selectedModel = "local-model"
    @AppStorage("temperature") private var temperature = 0.2

    @StateObject private var state = SettingsState()

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // API Endpoint Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Base URL")
                            .font(.headline)
                        TextField("e.g. http://localhost:1234/v1", text: $apiEndpoint)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: apiEndpoint) { _ in
                                // Trigger a refresh when the endpoint is updated
                                Task {
                                    await fetchModels()
                                }
                            }
                        Text("Point this to your running local model server (e.g. LM Studio, Ollama).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Model Selection
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model Selection")
                            .font(.headline)
                        
                        HStack {
                            Picker("", selection: $selectedModel) {
                                if state.loadedModels.isEmpty {
                                    Text("local-model").tag("local-model")
                                } else {
                                    ForEach(state.loadedModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                            }
                            .labelsHidden()
                            .disabled(state.isLoadingModels)

                            Button(action: {
                                Task {
                                    await fetchModels()
                                }
                            }) {
                                if state.isLoadingModels {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .imageScale(.medium)
                                }
                            }
                            .buttonStyle(.borderless)
                            .help("Refresh models from server")
                        }

                        if let errorMessage = state.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("Retrieve loaded models automatically from your local server.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Inference Options
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Inference Options")
                            .font(.headline)

                        HStack {
                            Text("Temperature: \(temperature, specifier: "%.1f")")
                                .frame(width: 110, alignment: .leading)
                            Slider(value: $temperature, in: 0.0...2.0, step: 0.1)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .frame(width: 450, height: 350)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            Task {
                await fetchModels()
            }
        }
    }

    private func fetchModels() async {
        state.isLoadingModels = true
        state.errorMessage = nil
        do {
            let service = TranslationService()
            let models = try await service.fetchLoadedModels(baseURL: apiEndpoint)
            state.loadedModels = models
            
            // If the currently selected model is no longer in the list, default to the first one
            if !models.contains(selectedModel) {
                if let first = models.first {
                    selectedModel = first
                } else {
                    selectedModel = "local-model"
                }
            }
        } catch {
            state.errorMessage = "Connection error: \(error.localizedDescription)"
        }
        state.isLoadingModels = false
    }
}
