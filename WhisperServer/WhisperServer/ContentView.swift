import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var serverManager: ServerManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    Toggle(isOn: $serverManager.isServerRunning) {
                        Text("Server running")
                    }
                    .onChange(of: serverManager.isServerRunning) { isRunning in
                        Task {
                            if isRunning {
                                await serverManager.startServer()
                            } else {
                                serverManager.stopServer()
                            }
                        }
                    }

                    HStack {
                        Text("Local address")
                        Spacer()
                        Text("http://\(serverManager.localIPAddress):\(serverManager.serverPort)")
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Status")
                        Spacer()
                        Text(serverManager.statusMessage)
                            .foregroundColor(serverManager.isServerRunning ? .green : .secondary)
                    }
                }

                Section("Model") {
                    Picker("Select model", selection: $serverManager.modelOption) {
                        ForEach(ServerManager.ModelOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: serverManager.modelOption) { _ in
                        Task {
                            await serverManager.prepareModel()
                        }
                    }

                    if serverManager.isLoadingModel {
                        HStack {
                            ProgressView()
                            Text("Loading model...")
                        }
                    }
                }

                Section("Last transcription") {
                    TextEditor(text: $serverManager.lastTranscript)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("WhisperServer")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(ServerManager())
    }
}
