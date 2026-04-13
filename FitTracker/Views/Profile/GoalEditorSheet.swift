// FitTracker/Views/Profile/GoalEditorSheet.swift
// Sheet for editing fitness goal, experience level, training frequency, and personal targets.
// Fires analytics events for each changed field on save.

import SwiftUI

struct GoalEditorSheet: View {
    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var analytics: AnalyticsService
    @Environment(\.dismiss) var dismiss

    // MARK: - Local state (populated from dataStore in onAppear)

    @State private var fitnessGoal: FitnessGoal = .generalFitness
    @State private var experienceLevel: ExperienceLevel = .beginner
    @State private var trainingDaysPerWeek: Int = 4
    @State private var name: String = ""
    @State private var age: Int = 30
    @State private var heightCm: String = ""
    @State private var targetWeightMin: String = ""
    @State private var targetWeightMax: String = ""
    @State private var targetBFMin: String = ""
    @State private var targetBFMax: String = ""

    // Snapshot of original values for change-detection
    @State private var originalGoal: FitnessGoal = .generalFitness
    @State private var originalExperience: ExperienceLevel = .beginner
    @State private var originalDays: Int = 4
    @State private var originalName: String = ""
    @State private var originalAge: Int = 30
    @State private var originalHeightCm: String = ""
    @State private var originalTargetWeightMin: String = ""
    @State private var originalTargetWeightMax: String = ""
    @State private var originalTargetBFMin: String = ""
    @State private var originalTargetBFMax: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.screenBackground
                    .ignoresSafeArea()

                Form {
                    // MARK: Fitness Goal
                    Section {
                        Picker("Goal", selection: $fitnessGoal) {
                            ForEach(FitnessGoal.allCases, id: \.self) { goal in
                                Text(goal.rawValue).tag(goal)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.primary)
                    } header: {
                        Text("Fitness Goal")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }

                    // MARK: Experience
                    Section {
                        Picker("Level", selection: $experienceLevel) {
                            ForEach(ExperienceLevel.allCases, id: \.self) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Experience")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }

                    // MARK: Training
                    Section {
                        Stepper(
                            "\(trainingDaysPerWeek) days / week",
                            value: $trainingDaysPerWeek,
                            in: 2...7
                        )
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.primary)
                        .accessibilityLabel("Training frequency: \(trainingDaysPerWeek) days per week")
                        .accessibilityHint("Swipe up or down to adjust between 2 and 7 days")
                    } header: {
                        Text("Training")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }

                    // MARK: Personal
                    Section {
                        TextField("Name", text: $name)
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                            .accessibilityLabel("Display name")

                        Stepper("Age: \(age)", value: $age, in: 15...99)
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                            .accessibilityLabel("Age: \(age) years")
                            .accessibilityHint("Swipe up or down to adjust")

                        TextField("Height (cm)", text: $heightCm)
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Height in centimetres")
                    } header: {
                        Text("Personal")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }

                    // MARK: Targets
                    Section {
                        TextField("Min weight (kg)", text: $targetWeightMin)
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Minimum target weight in kilograms")

                        TextField("Max weight (kg)", text: $targetWeightMax)
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Maximum target weight in kilograms")

                        TextField("Min body fat (%)", text: $targetBFMin)
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Minimum target body fat percentage")

                        TextField("Max body fat (%)", text: $targetBFMax)
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Maximum target body fat percentage")
                    } header: {
                        Text("Targets")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    } footer: {
                        Text("Weight in kg. Body fat as a percentage.")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Accent.primary)
                    .accessibilityLabel("Save")
                    .accessibilityHint("Saves your profile changes and closes this sheet")
                }
            }
            .onAppear {
                loadFromStore()
            }
        }
    }

    // MARK: - Private helpers

    private func loadFromStore() {
        let profile = dataStore.userProfile

        fitnessGoal = profile.fitnessGoal ?? .generalFitness
        experienceLevel = profile.experienceLevel ?? .beginner
        trainingDaysPerWeek = profile.trainingDaysPerWeek ?? 4
        name = profile.name
        age = profile.age
        heightCm = profile.heightCm == 0 ? "" : String(format: "%.1f", profile.heightCm)
        targetWeightMin = String(format: "%.1f", profile.targetWeightMin)
        targetWeightMax = String(format: "%.1f", profile.targetWeightMax)
        targetBFMin = String(format: "%.1f", profile.targetBFMin)
        targetBFMax = String(format: "%.1f", profile.targetBFMax)

        // Snapshot for change-detection
        originalGoal = fitnessGoal
        originalExperience = experienceLevel
        originalDays = trainingDaysPerWeek
        originalName = name
        originalAge = age
        originalHeightCm = heightCm
        originalTargetWeightMin = targetWeightMin
        originalTargetWeightMax = targetWeightMax
        originalTargetBFMin = targetBFMin
        originalTargetBFMax = targetBFMax
    }

    private func saveChanges() {
        // Fire analytics for each changed field
        if fitnessGoal != originalGoal {
            analytics.logProfileGoalChanged(
                field: "fitnessGoal",
                oldValue: originalGoal.rawValue,
                newValue: fitnessGoal.rawValue
            )
        }
        if experienceLevel != originalExperience {
            analytics.logProfileGoalChanged(
                field: "experienceLevel",
                oldValue: originalExperience.rawValue,
                newValue: experienceLevel.rawValue
            )
        }
        if trainingDaysPerWeek != originalDays {
            analytics.logProfileGoalChanged(
                field: "trainingDaysPerWeek",
                oldValue: "\(originalDays)",
                newValue: "\(trainingDaysPerWeek)"
            )
        }
        if name != originalName {
            analytics.logProfileGoalChanged(
                field: "name",
                oldValue: originalName,
                newValue: name
            )
        }
        if age != originalAge {
            analytics.logProfileGoalChanged(
                field: "age",
                oldValue: "\(originalAge)",
                newValue: "\(age)"
            )
        }
        if heightCm != originalHeightCm {
            analytics.logProfileGoalChanged(
                field: "heightCm",
                oldValue: originalHeightCm,
                newValue: heightCm
            )
        }
        if targetWeightMin != originalTargetWeightMin {
            analytics.logProfileGoalChanged(
                field: "targetWeightMin",
                oldValue: originalTargetWeightMin,
                newValue: targetWeightMin
            )
        }
        if targetWeightMax != originalTargetWeightMax {
            analytics.logProfileGoalChanged(
                field: "targetWeightMax",
                oldValue: originalTargetWeightMax,
                newValue: targetWeightMax
            )
        }
        if targetBFMin != originalTargetBFMin {
            analytics.logProfileGoalChanged(
                field: "targetBFMin",
                oldValue: originalTargetBFMin,
                newValue: targetBFMin
            )
        }
        if targetBFMax != originalTargetBFMax {
            analytics.logProfileGoalChanged(
                field: "targetBFMax",
                oldValue: originalTargetBFMax,
                newValue: targetBFMax
            )
        }

        // Write back to the store
        dataStore.userProfile.fitnessGoal = fitnessGoal
        dataStore.userProfile.experienceLevel = experienceLevel
        dataStore.userProfile.trainingDaysPerWeek = trainingDaysPerWeek
        dataStore.userProfile.name = name
        dataStore.userProfile.age = age
        if let h = Double(heightCm) { dataStore.userProfile.heightCm = h }
        if let v = Double(targetWeightMin) { dataStore.userProfile.targetWeightMin = v }
        if let v = Double(targetWeightMax) { dataStore.userProfile.targetWeightMax = v }
        if let v = Double(targetBFMin) { dataStore.userProfile.targetBFMin = v }
        if let v = Double(targetBFMax) { dataStore.userProfile.targetBFMax = v }

        Task { await dataStore.persistToDisk() }
        dismiss()
    }
}

// Preview removed — EncryptedDataStore requires Secure Enclave context
