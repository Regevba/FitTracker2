// Models/TrainingProgramData.swift
// Static training program — all 6 days, all exercises, all supplements

import Foundation

struct TrainingProgramData {

    // ─── Morning Supplements
    static let morningSupplements: [SupplementDefinition] = [
        .init(id:"vitc",     name:"Vitamin C",          dose:"500–1,000mg",    timing:.morning, benefit:"Cortisol metabolism · adrenal + antioxidant support", notes:"With breakfast. Max 2g/day."),
        .init(id:"vitd3",    name:"Vitamin D3",         dose:"2,000–4,000 IU", timing:.morning, benefit:"Dopamine pathway · mood regulation · immune function", notes:"With fat-containing food."),
        .init(id:"zinc",     name:"Zinc",               dose:"15–25mg",        timing:.morning, benefit:"Dopamine receptor recovery · testosterone support",    notes:"With food — not empty stomach."),
        .init(id:"nac",      name:"NAC",                dose:"600mg",          timing:.morning, benefit:"Glutathione precursor · glutamate modulation",         notes:"With food. 2h away from creatine."),
        .init(id:"taurine",  name:"Taurine",            dose:"1–2g",           timing:.morning, benefit:"Lowers resting HR/BP · GABA-modulating · neuroprotective", notes:"Morning or pre-workout."),
        .init(id:"ala",      name:"ALA",                dose:"300–600mg",      timing:.morning, benefit:"Mitochondrial antioxidant · synergistic with NAC",    notes:"Always with food."),
        .init(id:"creatine", name:"Creatine Monohydrate", dose:"5g",           timing:.withMeal, benefit:"Neuroprotective · ATP regeneration · lean mass support", notes:"Any time with food. 2h from NAC."),
    ]

    // ─── Evening Supplements
    static let eveningSupplements: [SupplementDefinition] = [
        .init(id:"glycine",    name:"Glycine",             dose:"3–5g",   timing:.preBed,  benefit:"Deep sleep N3 · core temp reduction · parasympathetic",  notes:"30 min before bed."),
        .init(id:"magnesium",  name:"Magnesium Glycinate", dose:"400mg",  timing:.preBed,  benefit:"HRV support · CNS calm · synergistic with glycine",       notes:"Before bed with glycine."),
        .init(id:"omega3",     name:"Omega-3 (EPA+DHA)",   dose:"2–4g",   timing:.evening, benefit:"Anti-inflammatory · dopamine receptor health · HRV",      notes:"With largest meal or evening."),
    ]

    // ─── All exercises, all days
    static let allExercises: [ExerciseDefinition] = [

        // ══ UPPER PUSH — Monday ══
        ex("chest_press_m",   "Chest Press Machine",          .machine,      .machine,     [.chest],               3, "8–12",      90,  "Full stretch at bottom. Slow 3-sec descent. Full lockout.", .upperPush, 1),
        ex("pec_deck",        "Pec Deck / Cable Fly",         .machine,      .cable,       [.chest],               3, "12–15",     60,  "Squeeze hard at top. No momentum. Flush set.", .upperPush, 2),
        ex("shoulder_press_m","Shoulder Press Machine",        .machine,      .machine,     [.shoulders],           3, "8–12",      90,  "Core braced. Don't shrug. Control descent.", .upperPush, 3),
        ex("tricep_pushdown", "Tricep Cable Pushdown",         .machine,      .cable,       [.triceps],             3, "12–15",     60,  "Elbows locked at sides. Full extension. Pause 1s.", .upperPush, 4),
        ex("db_incline",      "DB Incline Press",              .freeWeight,   .dumbbell,    [.chest],               3, "8–10",      90,  "30° incline. Lower to nipple line. Neutral grip.", .upperPush, 5),
        ex("lateral_raise",   "Dumbbell Lateral Raise",        .freeWeight,   .dumbbell,    [.shoulders],           3, "12–15",     60,  "Pinky slightly higher. No swinging. Stop at shoulder height.", .upperPush, 6),
        ex("db_tri_ext",      "DB Tricep Extension",           .freeWeight,   .dumbbell,    [.triceps],             3, "10–12",     60,  "Elbows close. Lower behind head for full stretch.", .upperPush, 7),
        ex("pushups",         "Push-ups",                      .calisthenics, .bodyweight,  [.chest,.triceps],      3, "Max–2",     75,  "Straight line. Touch chest to floor. Full lockout.", .upperPush, 8),
        ex("bench_dips",      "Bench Dips / Parallel Dips",   .calisthenics, .bodyweight,  [.triceps,.chest],      3, "8–12",      75,  "Lean forward for chest. Elbows track back.", .upperPush, 9),
        ex("pike_pushup",     "Pike Push-up",                  .calisthenics, .bodyweight,  [.shoulders],           2, "8–10",      60,  "Hips high. Head through arms at bottom.", .upperPush, 10),
        ex("elliptical_d1",   "Elliptical — Zone 2",           .cardio,       .elliptical,  [.cardiovascular],      1, "25–30 min", 0,   "HR 106–124 bpm. Steady state post-lift.", .upperPush, 11),

        // ══ LOWER BODY — Tuesday ══
        ex("leg_press",       "Leg Press Machine",             .machine,      .machine,     [.quads],               4, "8–12",      120, "Full depth — thighs past 90°. Don't lock out.", .lowerBody, 1),
        ex("leg_curl",        "Leg Curl Machine",              .machine,      .machine,     [.hamstrings],          3, "10–12",     75,  "Full stretch at top. Slow 3-sec negative.", .lowerBody, 2),
        ex("leg_extension",   "Leg Extension Machine",         .machine,      .machine,     [.quads],               3, "12–15",     60,  "Hold 1s at top. Don't slam down.", .lowerBody, 3),
        ex("hip_abduction",   "Hip Abduction Machine",         .machine,      .machine,     [.glutes],              3, "15–20",     60,  "Slow and controlled. Full range.", .lowerBody, 4),
        ex("goblet_squat",    "Goblet Squat",                  .freeWeight,   .dumbbell,    [.quads,.glutes],       4, "8–10",      90,  "Sit between heels. Knees track toes. Depth to parallel.", .lowerBody, 5),
        ex("rdl",             "Romanian Deadlift (RDL)",       .freeWeight,   .barbell,     [.hamstrings,.glutes],  4, "10–12",     90,  "Hip hinge. Bar close to legs. Back flat throughout.", .lowerBody, 6),
        ex("calf_raise",      "Standing Calf Raise",           .freeWeight,   .barbell,     [.calves],              3, "15–20",     60,  "Full extension. Hold 1s at top. 3-sec descent.", .lowerBody, 7),
        ex("walking_lunge",   "Walking Lunge",                 .calisthenics, .bodyweight,  [.quads,.glutes],       3, "12 each",   75,  "Long stride. Back knee near floor. Push through front heel.", .lowerBody, 8),
        ex("glute_bridge",    "Glute Bridge",                  .calisthenics, .bodyweight,  [.glutes],              3, "15–20",     60,  "Drive through heels. Full extension. Hold 2s.", .lowerBody, 9),
        ex("wall_sit",        "Wall Sit",                      .calisthenics, .bodyweight,  [.quads],               3, "45s",       60,  "90° at knee. Back flat. Breathe through the burn.", .lowerBody, 10),
        ex("sl_calf",         "Single-Leg Calf Raise",         .calisthenics, .bodyweight,  [.calves],              3, "15 each",   45,  "Step edge for ROM. 3-sec descent.", .lowerBody, 11),
        ex("rowing_d2",       "Rowing Machine — Zone 2",       .cardio,       .rowingMachine,[.cardiovascular],     1, "15 min",    0,   "HR 106–118 bpm. Legs pre-fatigued. Damper 4–5.", .lowerBody, 12),

        // ══ UPPER PULL — Thursday ══
        ex("lat_pulldown",    "Lat Pulldown Machine",          .machine,      .machine,     [.back],                4, "8–12",      90,  "Initiate with lats not biceps. Full stretch at top.", .upperPull, 1),
        ex("cable_row",       "Seated Cable Row",              .machine,      .cable,       [.back],                3, "10–12",     90,  "Chest to pad. Pull to navel. Full scapular retraction.", .upperPull, 2),
        ex("assisted_pullup", "Assisted Pull-up",              .machine,      .machine,     [.back,.biceps],        3, "6–10",      90,  "Dead hang start. Chin over bar. 3-sec negative.", .upperPull, 3),
        ex("face_pull",       "Face Pull (Cable)",             .machine,      .cable,       [.rearDelt],            3, "15–20",     60,  "Pull to face. Elbows above wrists. Big external rotation.", .upperPull, 4),
        ex("db_row",          "Single-Arm DB Row",             .freeWeight,   .dumbbell,    [.back],                3, "10 each",   60,  "Brace on bench. Row to hip. Full stretch at bottom.", .upperPull, 5),
        ex("hammer_curl",     "Hammer Curl",                   .freeWeight,   .dumbbell,    [.biceps],              3, "10–12",     60,  "Neutral grip. No swinging. Full extension.", .upperPull, 6),
        ex("sup_curl",        "Supinating DB Curl",            .freeWeight,   .dumbbell,    [.biceps],              3, "10–12",     60,  "Rotate palm up as you curl. Squeeze at top.", .upperPull, 7),
        ex("inv_row",         "Inverted Row (TRX/bar)",        .calisthenics, .bodyweight,  [.back],                3, "Max–2",     75,  "Feet forward = harder. Squeeze shoulder blades at top.", .upperPull, 8),
        ex("chinup",          "Chin-up Progression",           .calisthenics, .bodyweight,  [.back,.biceps],        3, "Max / 6–8 assisted", 90, "Full dead hang. Chin over bar. 3-sec negative.", .upperPull, 9),
        ex("band_pull",       "Band Pull-Apart",               .calisthenics, .resistanceBand,[.rearDelt],          3, "20",        45,  "Arms straight. Slow and controlled. Full ROM.", .upperPull, 10),
        ex("elliptical_d4",   "Elliptical — Zone 2",           .cardio,       .elliptical,  [.cardiovascular],      1, "25–30 min", 0,   "HR 106–124 bpm. Post-lift steady state.", .upperPull, 11),

        // ══ FULL BODY — Friday ══
        ex("deadlift",        "Barbell Deadlift",              .freeWeight,   .barbell,     [.fullBody,.posterior], 4, "5–6",       180, "Back flat. Bar close. Pull slack out before each rep. Drive floor away.", .fullBody, 1, "Warm-up: Bar×10, 50%×5, 75%×3. Film form every 4 weeks."),
        ex("bb_bench",        "Barbell Bench Press",           .freeWeight,   .barbell,     [.chest],               4, "6–8",       120, "Lower to chest with control. Heavier than Day 1.", .fullBody, 2),
        ex("bb_row",          "Barbell Row",                   .freeWeight,   .barbell,     [.back],                4, "6–8",       120, "Sit tall. Pull to navel. Heavier than Day 4.", .fullBody, 3),
        ex("ohp",             "Overhead Press",                .freeWeight,   .barbell,     [.shoulders],           3, "6–8",       90,  "Strict — no leg drive. Core braced. Full lockout.", .fullBody, 4),
        ex("goblet_fb",       "Goblet Squat (moderate)",       .freeWeight,   .dumbbell,    [.quads],               2, "15",        75,  "Lighter than Day 2. Perfect form focus.", .fullBody, 5),
        ex("leg_press_fb",    "Leg Press (heavy)",             .machine,      .machine,     [.quads],               3, "6–8",       120, "Heavier than Day 2. Lower foot position.", .fullBody, 6),
        ex("pec_deck_fb",     "Pec Deck Flush",                .machine,      .machine,     [.chest],               2, "15",        60,  "Light. Feel the muscle. End of pressing.", .fullBody, 7),
        ex("plank",           "Forearm Plank",                 .core,         .bodyweight,  [.core],                3, "45s",       0,   "Neutral spine. Squeeze glutes. No hips dropping.", .fullBody, 8),
        ex("dead_bug",        "Dead Bug",                      .core,         .bodyweight,  [.core],                3, "10 each",   0,   "Low back flat to floor. Exhale on each extension.", .fullBody, 9),
        ex("hollow_body",     "Hollow Body Hold",              .core,         .bodyweight,  [.core],                3, "20–30s",    0,   "Start knees bent if needed. Control breathing.", .fullBody, 10),
        ex("mountain_climb",  "Mountain Climber",              .core,         .bodyweight,  [.core],                3, "20 each",   0,   "Don't let hips rise. Drive knees to chest.", .fullBody, 11),
        ex("side_plank",      "Side Plank",                    .core,         .bodyweight,  [.core],                3, "30s each",  0,   "Stack feet. Straight body. Hips up.", .fullBody, 12),
        ex("elliptical_d5",   "Elliptical — Zone 2 Extended",  .cardio,       .elliptical,  [.cardiovascular],      1, "45–60 min", 0,   "HR 110–125 bpm. Fat oxidation. Reward the work.", .fullBody, 13),

        // ══ CARDIO ONLY — Saturday ══
        ex("elliptical_d6",   "Elliptical — Zone 2 Main",      .cardio,       .elliptical,  [.cardiovascular],      1, "45–50 min", 0,   "HR 106–124 bpm. Consistent pace.", .cardioOnly, 1),
        ex("rowing_d6",       "Rowing Machine — Zone 2",        .cardio,       .rowingMachine,[.cardiovascular],     1, "20–25 min", 0,   "24–26 spm. Damper 4–5. Pace 2:20–2:40/500m.", .cardioOnly, 2),
    ]

    static func exercises(for day: DayType) -> [ExerciseDefinition] {
        #if DEBUG
        assert(
            Set(allExercises.map(\.id)).count == allExercises.count,
            "Duplicate exercise IDs detected in TrainingProgramData.allExercises"
        )
        #endif
        return allExercises.filter { $0.dayType == day }.sorted { $0.order < $1.order }
    }

    static let stage1Criteria = [
        "Resting HR < 75 bpm sustained 5+ days",
        "HRV ≥ 35 ms sustained 5+ days",
        "Weight stable or declining",
        "Body fat trending downward",
        "Sleep ≥ 7.5 hrs consistently",
        "No acute cardiovascular symptoms",
        "Recovery day count ≥ 55 (approx. March 25, 2026)",
    ]

    // Builder helper
    private static func ex(
        _ id: String, _ name: String, _ cat: ExerciseCategory, _ equip: Equipment,
        _ muscles: [MuscleGroup], _ sets: Int, _ reps: String, _ rest: Int,
        _ cue: String, _ day: DayType, _ order: Int, _ prog: String = ""
    ) -> ExerciseDefinition {
        ExerciseDefinition(id: id, name: name, category: cat, equipment: equip,
                           muscleGroups: muscles, targetSets: sets, targetReps: reps,
                           restSeconds: rest, coachingCue: cue, dayType: day,
                           order: order, progressionNote: prog)
    }
}
