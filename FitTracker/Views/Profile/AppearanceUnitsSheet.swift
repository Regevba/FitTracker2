// FitTracker/Views/Profile/AppearanceUnitsSheet.swift
// Picker sheet for theme (System/Light/Dark) and units (Metric/Imperial).

import SwiftUI

struct AppearanceUnitsSheet: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Units") {
                    Picker("Unit System", selection: $settings.unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.rawValue).tag(system)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Appearance & Units")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
