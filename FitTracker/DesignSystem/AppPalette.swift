// FitTracker/DesignSystem/AppPalette.swift
// Primitive token tier — raw colour values only.
// Never used directly in views. AppTheme.swift is the only consumer.
import SwiftUI

enum AppPalette {
    // MARK: - Orange tonal ramp
    static let orange50  = Color(red: 1.00, green: 0.89, blue: 0.73)  // #FFE3BA
    static let orange100 = Color(red: 1.00, green: 0.78, blue: 0.54)  // #FFC78A
    static let orange500 = Color(red: 0.98, green: 0.56, blue: 0.25)  // #FA8F40

    // MARK: - Blue tonal ramp
    static let blue50  = Color(red: 0.87, green: 0.95, blue: 1.00)    // #DFF3FF
    static let blue100 = Color(red: 0.94, green: 0.98, blue: 1.00)    // #F0FAFF
    static let blue200 = Color(red: 0.73, green: 0.89, blue: 1.00)    // #BAE3FF
    static let blue500 = Color(red: 0.54, green: 0.78, blue: 1.00)    // #8AC7FF

    // MARK: - Auth dark surface
    static let darkForest0 = Color(red: 0.04, green: 0.08, blue: 0.06)  // #0A140F
    static let darkForest1 = Color(red: 0.06, green: 0.14, blue: 0.10)  // #102419
    static let darkForest2 = Color(red: 0.02, green: 0.06, blue: 0.04)  // #05100A

    // MARK: - Accent colours
    static let cyan   = Color(red: 0.353, green: 0.784, blue: 0.980)  // #5AC8FA
    static let purple = Color(red: 0.749, green: 0.353, blue: 0.949)  // #BF5AF2
    static let gold   = Color(red: 1.000, green: 0.839, blue: 0.039)  // #FFD60A

    // MARK: - Semantic status
    static let green = Color(red: 0.204, green: 0.780, blue: 0.349)   // #34C759
    static let amber = Color(red: 1.000, green: 0.584, blue: 0.000)   // #FF9500
    static let red   = Color(red: 1.000, green: 0.231, blue: 0.188)   // #FF3B30

    // MARK: - Neutrals
    static let white = Color.white
    static let black = Color.black

    // MARK: - Chart
    static let brown = Color(red: 0.60, green: 0.35, blue: 0.15)      // Chart.nutritionFat
}
