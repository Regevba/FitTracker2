// FitTracker/DesignSystem/AppIcon.swift
// SF Symbol name inventory — centralises all icon strings.
// Use AppIcon.* instead of string literals in Image(systemName:).
import SwiftUI

enum AppIcon {
    // MARK: - Navigation
    static let home       = "house.fill"
    static let training   = "dumbbell.fill"
    static let nutrition  = "fork.knife"
    static let stats      = "chart.bar.fill"
    static let settings   = "gearshape.fill"

    // MARK: - Actions
    static let thumbsUp   = "hand.thumbsup.fill"
    static let thumbsDown = "hand.thumbsdown.fill"
    static let add        = "plus"
    static let addCircle  = "plus.circle.fill"
    static let edit       = "pencil"
    static let delete     = "trash"
    static let close      = "xmark"
    static let closeCircle = "xmark.circle.fill"
    static let back       = "chevron.left"
    static let forward    = "chevron.right"
    static let chevronDown = "chevron.down"
    static let chevronUp  = "chevron.up"
    static let share      = "square.and.arrow.up"
    static let copy       = "doc.on.doc"

    // MARK: - Status
    static let checkmark       = "checkmark"
    static let checkmarkCircle = "checkmark.circle.fill"
    static let warning         = "exclamationmark.triangle.fill"
    static let info            = "info.circle.fill"
    static let error           = "xmark.circle.fill"
    static let lock            = "lock.fill"
    static let unlock          = "lock.open.fill"

    // MARK: - Training
    static let dumbbell  = "dumbbell.fill"
    static let timer     = "timer"
    static let stopwatch = "stopwatch.fill"
    static let rest      = "zzz"
    static let setDone   = "checkmark.circle.fill"
    static let liveTag   = "bolt.fill"
    static let pr        = "trophy.fill"
    static let fire      = "flame.fill"
    static let heart     = "heart.fill"
    static let heartRate = "heart.fill"

    // MARK: - Nutrition
    static let meal        = "fork.knife"
    static let barcode     = "barcode.viewfinder"
    static let supplement  = "pill.fill"
    static let water       = "drop.fill"
    static let calories    = "flame"

    // MARK: - Health / Stats
    static let steps       = "figure.walk"
    static let sleep       = "moon.fill"
    static let hrv         = "waveform.path.ecg"
    static let weight      = "scalemass.fill"
    static let bodyFat     = "percent"
    static let trend       = "chart.line.uptrend.xyaxis"
    static let chart       = "chart.bar"
    static let calendar    = "calendar"

    // MARK: - Biometrics / Auth
    static let faceID      = "faceid"
    static let touchID     = "touchid"
    static let passkey     = "key.fill"
    static let appleSign   = "apple.logo"

    // MARK: - Misc
    static let person      = "person.fill"
    static let personCircle = "person.circle.fill"
    static let notification = "bell.fill"
    static let search      = "magnifyingglass"
    static let filter      = "line.3.horizontal.decrease.circle"
    static let more        = "ellipsis"
    static let moreCircle  = "ellipsis.circle"
    static let star        = "star.fill"
    static let target      = "target"
    static let sparkles    = "sparkles"
    static let ai          = "sparkle"
    static let cloud       = "icloud.fill"
    static let sync        = "arrow.triangle.2.circlepath"
}
