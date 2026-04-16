# HADF: Hardware-Aware Dispatch Framework — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the v6.0 PM framework with hardware-aware dispatch — device detection, static chip profiles, cloud fingerprinting infrastructure, dynamic adaptation protocol, evolutionary learning, and v6.0 measurement integration.

**Architecture:** HADF is an extension layer that injects a `hardware_context` section into `dispatch-intelligence.json`. Five layers (device detection → static profiles → cloud fingerprinting → dynamic adaptation → evolutionary learning) feed a composite optimizer that produces a single dispatch hint. A confidence gate ensures zero regression — below threshold, HADF is ignored and the framework behaves identically to v6.0.

**Tech Stack:** JSON configs, SKILL.md protocol updates, shell scripts (token counting), pseudocode reference implementations (Swift/Kotlin detection code is documented but not compiled — theoretical research phase).

**Spec:** `docs/superpowers/specs/2026-04-16-hadf-hardware-aware-dispatch-design.md`

---

## File Structure

```
.claude/shared/
├── dispatch-intelligence.json       (MODIFY — add hardware_context section)
├── cache-metrics.json               (MODIFY — add hadf_affinity section)
├── token-budget.json                (MODIFY — add hadf layer entry)
├── chip-profiles.json               (CREATE — ~50 static chip profiles, Layer 1)
└── chip-affinity-map.json           (CREATE — empty Chip Affinity Map structure, Layer 4)

.claude/shared/hadf/
├── hardware-signature-table.json    (CREATE — cloud fingerprinting reference data, Layer 2)
├── hadf-metrics-template.json       (CREATE — per-feature telemetry template)
└── README.md                        (CREATE — HADF quick reference for agents)

docs/architecture/
└── hadf-reference-implementations.md (CREATE — pseudocode for device detection + fingerprinting)

scripts/
└── count-framework-tokens.sh        (MODIFY — add hadf layer to token counting)
```

---

### Task 1: Static Chip Profiles (Layer 1)

**Files:**
- Create: `.claude/shared/chip-profiles.json`

- [ ] **Step 1: Create chip-profiles.json with Apple A-series profiles**

```json
{
  "version": "1.0",
  "updated": "2026-04-16",
  "description": "Static chip capability profiles for HADF Layer 1. Dispatch-oriented — only data that affects routing decisions.",
  "profiles": {
    "apple_a18_pro": {
      "vendor": "apple",
      "family": "a_series",
      "generation": 18,
      "tier": "flagship",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 38,
        "max_model_size_mb": 4500,
        "preferred_precision": "float16",
        "concurrent_ml_tasks": 2
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization", "lightweight_inference"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 30,
        "throttle_risk": "moderate",
        "battery_sensitivity": "high"
      },
      "memory_constraints": {
        "available_for_ml_mb": 3500,
        "unified_memory": true,
        "swap_penalty": "none"
      },
      "composite_baseline": {
        "latency_score": 0.85,
        "cost_score": 0.92,
        "quality_score": 0.68,
        "overall": 0.82
      }
    },
    "apple_a17_pro": {
      "vendor": "apple",
      "family": "a_series",
      "generation": 17,
      "tier": "flagship",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 35,
        "max_model_size_mb": 4000,
        "preferred_precision": "float16",
        "concurrent_ml_tasks": 2
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization", "lightweight_inference"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 30,
        "throttle_risk": "moderate",
        "battery_sensitivity": "high"
      },
      "memory_constraints": {
        "available_for_ml_mb": 3000,
        "unified_memory": true,
        "swap_penalty": "none"
      },
      "composite_baseline": {
        "latency_score": 0.82,
        "cost_score": 0.90,
        "quality_score": 0.65,
        "overall": 0.79
      }
    },
    "apple_a16": {
      "vendor": "apple",
      "family": "a_series",
      "generation": 16,
      "tier": "mid",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 17,
        "max_model_size_mb": 2000,
        "preferred_precision": "float16",
        "concurrent_ml_tasks": 1
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation", "lightweight_inference"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 25,
        "throttle_risk": "moderate",
        "battery_sensitivity": "high"
      },
      "memory_constraints": {
        "available_for_ml_mb": 2000,
        "unified_memory": true,
        "swap_penalty": "none"
      },
      "composite_baseline": {
        "latency_score": 0.70,
        "cost_score": 0.75,
        "quality_score": 0.50,
        "overall": 0.65
      }
    },
    "apple_a15": {
      "vendor": "apple",
      "family": "a_series",
      "generation": 15,
      "tier": "low",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 15.8,
        "max_model_size_mb": 1500,
        "preferred_precision": "float16",
        "concurrent_ml_tasks": 1
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "tokenization"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation", "lightweight_inference", "embedding"],
        "hybrid_capable": false
      },
      "thermal_profile": {
        "sustained_workload_seconds": 20,
        "throttle_risk": "high",
        "battery_sensitivity": "high"
      },
      "memory_constraints": {
        "available_for_ml_mb": 1500,
        "unified_memory": true,
        "swap_penalty": "none"
      },
      "composite_baseline": {
        "latency_score": 0.55,
        "cost_score": 0.60,
        "quality_score": 0.40,
        "overall": 0.52
      }
    }
  }
}
```

- [ ] **Step 2: Add Apple M-series profiles**

Add these entries to the `profiles` object in `chip-profiles.json`:

```json
    "apple_m4_max": {
      "vendor": "apple",
      "family": "m_series",
      "generation": 4,
      "tier": "desktop",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 38,
        "max_model_size_mb": 50000,
        "preferred_precision": "float16",
        "concurrent_ml_tasks": 8
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization", "lightweight_inference", "code_generation", "complex_reasoning"],
        "prefer_cloud": ["long_context", "multi_step_planning"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 600,
        "throttle_risk": "low",
        "battery_sensitivity": "none"
      },
      "memory_constraints": {
        "available_for_ml_mb": 96000,
        "unified_memory": true,
        "swap_penalty": "none"
      },
      "composite_baseline": {
        "latency_score": 0.95,
        "cost_score": 0.98,
        "quality_score": 0.85,
        "overall": 0.93
      }
    },
    "apple_m3_pro": {
      "vendor": "apple",
      "family": "m_series",
      "generation": 3,
      "tier": "desktop",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 18,
        "max_model_size_mb": 20000,
        "preferred_precision": "float16",
        "concurrent_ml_tasks": 4
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization", "lightweight_inference"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 300,
        "throttle_risk": "low",
        "battery_sensitivity": "low"
      },
      "memory_constraints": {
        "available_for_ml_mb": 24000,
        "unified_memory": true,
        "swap_penalty": "none"
      },
      "composite_baseline": {
        "latency_score": 0.88,
        "cost_score": 0.92,
        "quality_score": 0.72,
        "overall": 0.84
      }
    },
    "apple_m1": {
      "vendor": "apple",
      "family": "m_series",
      "generation": 1,
      "tier": "desktop",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 11,
        "max_model_size_mb": 8000,
        "preferred_precision": "float16",
        "concurrent_ml_tasks": 2
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation", "lightweight_inference"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 300,
        "throttle_risk": "low",
        "battery_sensitivity": "low"
      },
      "memory_constraints": {
        "available_for_ml_mb": 10000,
        "unified_memory": true,
        "swap_penalty": "none"
      },
      "composite_baseline": {
        "latency_score": 0.72,
        "cost_score": 0.78,
        "quality_score": 0.55,
        "overall": 0.68
      }
    }
```

- [ ] **Step 3: Add Google Tensor profiles**

Add these entries to the `profiles` object:

```json
    "google_tensor_g4": {
      "vendor": "google",
      "family": "tensor",
      "generation": 4,
      "tier": "flagship",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 30,
        "max_model_size_mb": 3000,
        "preferred_precision": "int8",
        "concurrent_ml_tasks": 2
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization", "lightweight_inference"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 25,
        "throttle_risk": "high",
        "battery_sensitivity": "high"
      },
      "memory_constraints": {
        "available_for_ml_mb": 4000,
        "unified_memory": false,
        "swap_penalty": "moderate"
      },
      "composite_baseline": {
        "latency_score": 0.78,
        "cost_score": 0.85,
        "quality_score": 0.62,
        "overall": 0.75
      }
    },
    "google_tensor_g3": {
      "vendor": "google",
      "family": "tensor",
      "generation": 3,
      "tier": "mid",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 22,
        "max_model_size_mb": 2000,
        "preferred_precision": "int8",
        "concurrent_ml_tasks": 1
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation", "lightweight_inference"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 20,
        "throttle_risk": "high",
        "battery_sensitivity": "high"
      },
      "memory_constraints": {
        "available_for_ml_mb": 3000,
        "unified_memory": false,
        "swap_penalty": "moderate"
      },
      "composite_baseline": {
        "latency_score": 0.68,
        "cost_score": 0.72,
        "quality_score": 0.50,
        "overall": 0.63
      }
    }
```

- [ ] **Step 4: Add Qualcomm Snapdragon profiles**

Add these entries:

```json
    "qualcomm_snapdragon_8_gen3": {
      "vendor": "qualcomm",
      "family": "snapdragon",
      "generation": 8.3,
      "tier": "flagship",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 45,
        "max_model_size_mb": 4000,
        "preferred_precision": "int8",
        "concurrent_ml_tasks": 2
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization", "lightweight_inference"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 25,
        "throttle_risk": "moderate",
        "battery_sensitivity": "high"
      },
      "memory_constraints": {
        "available_for_ml_mb": 4000,
        "unified_memory": false,
        "swap_penalty": "moderate"
      },
      "composite_baseline": {
        "latency_score": 0.80,
        "cost_score": 0.88,
        "quality_score": 0.63,
        "overall": 0.77
      }
    },
    "qualcomm_snapdragon_7_gen3": {
      "vendor": "qualcomm",
      "family": "snapdragon",
      "generation": 7.3,
      "tier": "mid",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 20,
        "max_model_size_mb": 2000,
        "preferred_precision": "int8",
        "concurrent_ml_tasks": 1
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "tokenization"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation", "lightweight_inference", "embedding"],
        "hybrid_capable": false
      },
      "thermal_profile": {
        "sustained_workload_seconds": 20,
        "throttle_risk": "moderate",
        "battery_sensitivity": "high"
      },
      "memory_constraints": {
        "available_for_ml_mb": 2000,
        "unified_memory": false,
        "swap_penalty": "moderate"
      },
      "composite_baseline": {
        "latency_score": 0.60,
        "cost_score": 0.65,
        "quality_score": 0.42,
        "overall": 0.56
      }
    },
    "qualcomm_snapdragon_x_elite": {
      "vendor": "qualcomm",
      "family": "snapdragon",
      "generation": 1,
      "tier": "desktop",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 45,
        "max_model_size_mb": 25000,
        "preferred_precision": "int8",
        "concurrent_ml_tasks": 4
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization", "lightweight_inference"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 300,
        "throttle_risk": "low",
        "battery_sensitivity": "low"
      },
      "memory_constraints": {
        "available_for_ml_mb": 20000,
        "unified_memory": false,
        "swap_penalty": "low"
      },
      "composite_baseline": {
        "latency_score": 0.85,
        "cost_score": 0.90,
        "quality_score": 0.70,
        "overall": 0.82
      }
    }
```

- [ ] **Step 5: Add Samsung Exynos, MediaTek Dimensity, and fallback profiles**

Add these entries:

```json
    "samsung_exynos_2400": {
      "vendor": "samsung",
      "family": "exynos",
      "generation": 2400,
      "tier": "flagship",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 34,
        "max_model_size_mb": 3500,
        "preferred_precision": "int8",
        "concurrent_ml_tasks": 2
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization", "lightweight_inference"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 22,
        "throttle_risk": "high",
        "battery_sensitivity": "high"
      },
      "memory_constraints": {
        "available_for_ml_mb": 3500,
        "unified_memory": false,
        "swap_penalty": "moderate"
      },
      "composite_baseline": {
        "latency_score": 0.76,
        "cost_score": 0.82,
        "quality_score": 0.60,
        "overall": 0.73
      }
    },
    "mediatek_dimensity_9300": {
      "vendor": "mediatek",
      "family": "dimensity",
      "generation": 9300,
      "tier": "flagship",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 40,
        "max_model_size_mb": 3500,
        "preferred_precision": "int8",
        "concurrent_ml_tasks": 2
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization", "lightweight_inference"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 22,
        "throttle_risk": "moderate",
        "battery_sensitivity": "high"
      },
      "memory_constraints": {
        "available_for_ml_mb": 3500,
        "unified_memory": false,
        "swap_penalty": "moderate"
      },
      "composite_baseline": {
        "latency_score": 0.78,
        "cost_score": 0.85,
        "quality_score": 0.62,
        "overall": 0.75
      }
    },
    "arm64_mobile_unknown": {
      "vendor": "unknown",
      "family": "generic_arm64",
      "generation": 0,
      "tier": "mid",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 15,
        "max_model_size_mb": 1500,
        "preferred_precision": "int8",
        "concurrent_ml_tasks": 1
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "tokenization"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation", "lightweight_inference", "embedding"],
        "hybrid_capable": false
      },
      "thermal_profile": {
        "sustained_workload_seconds": 20,
        "throttle_risk": "high",
        "battery_sensitivity": "high"
      },
      "memory_constraints": {
        "available_for_ml_mb": 1500,
        "unified_memory": false,
        "swap_penalty": "high"
      },
      "composite_baseline": {
        "latency_score": 0.50,
        "cost_score": 0.55,
        "quality_score": 0.35,
        "overall": 0.47
      }
    },
    "arm64_desktop_unknown": {
      "vendor": "unknown",
      "family": "generic_arm64",
      "generation": 0,
      "tier": "desktop",
      "arch": "arm64",
      "compute_budget": {
        "on_device_ml_capable": true,
        "npu_tops": 11,
        "max_model_size_mb": 8000,
        "preferred_precision": "float16",
        "concurrent_ml_tasks": 2
      },
      "dispatch_hints": {
        "prefer_on_device": ["text_classification", "embedding", "tokenization"],
        "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning", "code_generation", "lightweight_inference"],
        "hybrid_capable": true
      },
      "thermal_profile": {
        "sustained_workload_seconds": 300,
        "throttle_risk": "low",
        "battery_sensitivity": "low"
      },
      "memory_constraints": {
        "available_for_ml_mb": 8000,
        "unified_memory": false,
        "swap_penalty": "low"
      },
      "composite_baseline": {
        "latency_score": 0.65,
        "cost_score": 0.70,
        "quality_score": 0.50,
        "overall": 0.62
      }
    },
    "web_wasm_low": {
      "vendor": "unknown",
      "family": "web",
      "generation": 0,
      "tier": "low",
      "arch": "wasm",
      "compute_budget": {
        "on_device_ml_capable": false,
        "npu_tops": 0,
        "max_model_size_mb": 0,
        "preferred_precision": "none",
        "concurrent_ml_tasks": 0
      },
      "dispatch_hints": {
        "prefer_on_device": [],
        "prefer_cloud": ["text_classification", "embedding", "tokenization", "lightweight_inference", "complex_reasoning", "long_context", "multi_step_planning", "code_generation"],
        "hybrid_capable": false
      },
      "thermal_profile": {
        "sustained_workload_seconds": 0,
        "throttle_risk": "none",
        "battery_sensitivity": "none"
      },
      "memory_constraints": {
        "available_for_ml_mb": 0,
        "unified_memory": false,
        "swap_penalty": "none"
      },
      "composite_baseline": {
        "latency_score": 0.10,
        "cost_score": 0.10,
        "quality_score": 0.10,
        "overall": 0.10
      }
    }
  }
```

- [ ] **Step 6: Validate JSON and commit**

Run: `python3 -c "import json; json.load(open('.claude/shared/chip-profiles.json')); print('VALID')"`
Expected: `VALID`

```bash
git add .claude/shared/chip-profiles.json
git commit -m "feat(hadf): add static chip profiles — 15 chips across 6 vendors + 3 fallbacks (Layer 1)"
```

---

### Task 2: Cloud Hardware Signature Table (Layer 2)

**Files:**
- Create: `.claude/shared/hadf/hardware-signature-table.json`

- [ ] **Step 1: Create the hadf directory**

Run: `mkdir -p .claude/shared/hadf`

- [ ] **Step 2: Create hardware-signature-table.json**

```json
{
  "version": "1.0",
  "updated": "2026-04-16",
  "description": "Cloud inference hardware signatures for HADF Layer 2 classification. Values are illustrative ranges requiring empirical calibration via Phase 2 validation.",
  "calibration_status": "uncalibrated",
  "signatures": {
    "nvidia_h100_class": {
      "vendor": "nvidia",
      "chip": "H100 SXM",
      "generation": "hopper",
      "ttft_per_1k_tokens_ms": { "min": 45, "max": 65 },
      "tps_median": { "min": 80, "max": 120 },
      "tps_cov": { "max": 0.08 },
      "batch_scaling_factor": { "min": 0.92, "max": 0.98 },
      "notes": "Dominant cloud GPU. High throughput, low variance, excellent batch scaling."
    },
    "nvidia_a100_class": {
      "vendor": "nvidia",
      "chip": "A100",
      "generation": "ampere",
      "ttft_per_1k_tokens_ms": { "min": 70, "max": 100 },
      "tps_median": { "min": 55, "max": 80 },
      "tps_cov": { "max": 0.10 },
      "batch_scaling_factor": { "min": 0.88, "max": 0.95 },
      "notes": "Previous gen cloud GPU. Still common in cost-optimized deployments."
    },
    "google_tpu_v5e_class": {
      "vendor": "google",
      "chip": "TPU v5e",
      "generation": "v5e",
      "ttft_per_1k_tokens_ms": { "min": 50, "max": 75 },
      "tps_median": { "min": 70, "max": 100 },
      "tps_cov": { "max": 0.12 },
      "batch_scaling_factor": { "min": 0.95, "max": 0.99 },
      "notes": "Anthropic primary inference hardware. Excellent batch scaling due to systolic array architecture."
    },
    "google_tpu_v4_class": {
      "vendor": "google",
      "chip": "TPU v4",
      "generation": "v4",
      "ttft_per_1k_tokens_ms": { "min": 60, "max": 90 },
      "tps_median": { "min": 50, "max": 75 },
      "tps_cov": { "max": 0.15 },
      "batch_scaling_factor": { "min": 0.90, "max": 0.96 },
      "notes": "Previous gen TPU. Higher variance than v5e."
    },
    "aws_trainium2_class": {
      "vendor": "aws",
      "chip": "Trainium 2",
      "generation": "trn2",
      "ttft_per_1k_tokens_ms": { "min": 55, "max": 80 },
      "tps_median": { "min": 65, "max": 90 },
      "tps_cov": { "max": 0.10 },
      "batch_scaling_factor": { "min": 0.91, "max": 0.97 },
      "notes": "AWS custom silicon. Used by Anthropic on AWS deployments."
    },
    "amd_mi300x_class": {
      "vendor": "amd",
      "chip": "MI300X",
      "generation": "cdna3",
      "ttft_per_1k_tokens_ms": { "min": 50, "max": 70 },
      "tps_median": { "min": 75, "max": 105 },
      "tps_cov": { "max": 0.09 },
      "batch_scaling_factor": { "min": 0.93, "max": 0.98 },
      "notes": "High memory bandwidth. Competitive with H100 on large models."
    },
    "cpu_fallback_class": {
      "vendor": "generic",
      "chip": "CPU",
      "generation": "any",
      "ttft_per_1k_tokens_ms": { "min": 200, "max": 999 },
      "tps_median": { "min": 10, "max": 30 },
      "tps_cov": { "max": 999 },
      "batch_scaling_factor": { "min": 0.60, "max": 0.80 },
      "notes": "Catch-all for non-accelerated inference. Very slow. Should trigger quality concerns."
    }
  },
  "classification": {
    "method": "mahalanobis_nearest",
    "min_calls_to_classify": 5,
    "confident_at_calls": 15,
    "reclassify_trigger": {
      "tps_drop_pct": 0.20,
      "ttft_spike_multiplier": 2.0
    }
  }
}
```

- [ ] **Step 3: Validate JSON and commit**

Run: `python3 -c "import json; json.load(open('.claude/shared/hadf/hardware-signature-table.json')); print('VALID')"`
Expected: `VALID`

```bash
git add .claude/shared/hadf/hardware-signature-table.json
git commit -m "feat(hadf): add cloud hardware signature table — 7 hardware classes for Layer 2 fingerprinting"
```

---

### Task 3: Chip Affinity Map Structure (Layer 4)

**Files:**
- Create: `.claude/shared/chip-affinity-map.json`

- [ ] **Step 1: Create empty Chip Affinity Map with schema documentation**

```json
{
  "version": "1.0",
  "updated": "2026-04-16",
  "description": "Cross-session learned dispatch strategies per device+cloud hardware pair. Written by Layer 4 at session end. Never committed — local optimization cache only.",
  "schema_note": "Entries are created automatically. This file ships empty. Populated by HADF Layer 4 evolutionary learning.",
  "config": {
    "max_entries": 200,
    "expiry_days": 90,
    "anomaly_rejection_sigma": 3.0,
    "learning_rate": {
      "sessions_1_to_10": 0.3,
      "sessions_10_to_50": 0.1,
      "sessions_50_plus": 0.05
    }
  },
  "affinity_entries": []
}
```

- [ ] **Step 2: Validate JSON and commit**

Run: `python3 -c "import json; json.load(open('.claude/shared/chip-affinity-map.json')); print('VALID')"`
Expected: `VALID`

```bash
git add .claude/shared/chip-affinity-map.json
git commit -m "feat(hadf): add empty Chip Affinity Map with learning config (Layer 4)"
```

---

### Task 4: HADF Metrics Template and README

**Files:**
- Create: `.claude/shared/hadf/hadf-metrics-template.json`
- Create: `.claude/shared/hadf/README.md`

- [ ] **Step 1: Create the per-feature metrics template**

```json
{
  "feature": "{{FEATURE_NAME}}",
  "hadf_version": "1.0",
  "sessions": 0,
  "device": {
    "chip_id": null,
    "detection_method": null,
    "confidence": 0.0
  },
  "cloud": {
    "classified_as": null,
    "confidence_progression": [],
    "reclassifications": 0
  },
  "adaptation_events": [],
  "affinity": {
    "warm_starts": 0,
    "cold_starts": 0,
    "hit_rate": 0.0
  },
  "impact": {
    "avg_dispatch_overhead_ms": null,
    "latency_improvement_pct": null,
    "cost_savings_pct": null
  }
}
```

- [ ] **Step 2: Create HADF README for agents**

```markdown
# HADF — Hardware-Aware Dispatch Framework

Extension layer for the PM framework dispatch engine. Detects hardware on both
device (edge) and cloud (inference server) sides, then optimizes dispatch for
latency, cost, and quality.

## Files in this directory

| File | Purpose | Updated by |
|---|---|---|
| `hardware-signature-table.json` | Cloud hardware fingerprint reference data | Framework releases |
| `hadf-metrics-template.json` | Template for per-feature telemetry | Copied per feature |

## Files in parent (.claude/shared/)

| File | Purpose |
|---|---|
| `chip-profiles.json` | Static device chip profiles (Layer 1) |
| `chip-affinity-map.json` | Cross-session learned strategies (Layer 4) |
| `dispatch-intelligence.json` | Dispatch config — `hardware_context` section |

## Confidence Gate

HADF output is gated before it influences dispatch:

- Score > 0.7: trust HADF fully
- Score 0.4-0.7: blend with default routing
- Score < 0.4: ignore HADF entirely (zero regression)

## Spec

Full design: `docs/superpowers/specs/2026-04-16-hadf-hardware-aware-dispatch-design.md`
```

- [ ] **Step 3: Validate and commit**

Run: `python3 -c "import json; json.load(open('.claude/shared/hadf/hadf-metrics-template.json')); print('VALID')"`
Expected: `VALID`

```bash
git add .claude/shared/hadf/hadf-metrics-template.json .claude/shared/hadf/README.md
git commit -m "feat(hadf): add metrics template and agent README"
```

---

### Task 5: Dispatch Intelligence Integration

**Files:**
- Modify: `.claude/shared/dispatch-intelligence.json`

- [ ] **Step 1: Add hardware_context section to dispatch-intelligence.json**

Add the following after the `mirror_pattern` section (before the closing `}`):

```json
  ,
  "hardware_context": {
    "hadf_version": "1.0",
    "enabled": false,
    "confidence_gate": {
      "trust_threshold": 0.7,
      "blend_threshold": 0.4,
      "note": "Below blend_threshold, HADF is ignored entirely. Between blend and trust, HADF blends with default routing."
    },
    "device": {
      "chip_id": null,
      "tier": null,
      "realtime_modifier": 1.0,
      "thermal_state": "unknown"
    },
    "cloud": {
      "estimated_class": null,
      "confidence": 0.0,
      "realtime_tps": null,
      "drift_status": "unknown"
    },
    "composite": {
      "score": 0.0,
      "latency_component": 0.0,
      "cost_component": 0.0,
      "quality_component": 0.0,
      "weight_preset": "cloud_preferred",
      "strategy": "cloud_preferred",
      "on_device_tasks": [],
      "cloud_tasks": [],
      "affinity_source": "none",
      "affinity_samples": 0
    },
    "weight_presets": {
      "user_facing": { "latency": 0.50, "cost": 0.15, "quality": 0.35 },
      "background": { "latency": 0.15, "cost": 0.50, "quality": 0.35 },
      "critical_reasoning": { "latency": 0.10, "cost": 0.10, "quality": 0.80 },
      "high_frequency": { "latency": 0.35, "cost": 0.45, "quality": 0.20 }
    },
    "adaptation": {
      "thermal_escalation": {
        "nominal": 1.0,
        "fair": 0.5,
        "serious": 0.2,
        "critical": 0.0
      },
      "battery_thresholds": {
        "full_capability_pct": 50,
        "reduced_pct": 20
      },
      "cloud_drift_trigger_pct": 0.20,
      "anti_thrash_min_change_pct": 0.05
    },
    "meta": {
      "layers_active": [],
      "layer2_calls_observed": 0,
      "layer4_warm_start": false,
      "last_updated": null
    }
  }
```

- [ ] **Step 2: Update version and description**

Change the `description` field to:

```json
  "description": "Dispatch Intelligence — 3-stage pipeline for subagent routing with HADF hardware-aware extension: score complexity → probe capability → dispatch with budget + hardware context.",
```

- [ ] **Step 3: Validate JSON and commit**

Run: `python3 -c "import json; json.load(open('.claude/shared/dispatch-intelligence.json')); print('VALID')"`
Expected: `VALID`

```bash
git add .claude/shared/dispatch-intelligence.json
git commit -m "feat(hadf): integrate hardware_context into dispatch-intelligence.json — confidence gate, weight presets, adaptation config"
```

---

### Task 6: Extend cache-metrics.json and token-budget.json

**Files:**
- Modify: `.claude/shared/cache-metrics.json`
- Modify: `.claude/shared/token-budget.json`

- [ ] **Step 1: Add hadf_affinity section to cache-metrics.json**

Add the following after the `rolling_baselines` section (before the closing `}`):

```json
  ,
  "hadf_affinity": {
    "total_entries": 0,
    "warm_start_rate": 0.0,
    "avg_cloud_confidence": 0.0,
    "most_seen_cloud_class": null,
    "adaptation_events_per_session": 0.0,
    "note": "Populated by HADF Layer 4. Updated on feature completion alongside cache metrics."
  }
```

- [ ] **Step 2: Add hadf layer to token-budget.json**

Add the following entry to the `layers` object:

```json
    "hadf": {
      "files": 4,
      "tokens": 0,
      "pct_of_total": 0.0,
      "note": "chip-profiles.json + hardware-signature-table.json + chip-affinity-map.json + hadf-metrics-template.json. Measured on next token count run."
    }
```

- [ ] **Step 3: Validate both files and commit**

Run:
```bash
python3 -c "import json; json.load(open('.claude/shared/cache-metrics.json')); print('cache-metrics: VALID')"
python3 -c "import json; json.load(open('.claude/shared/token-budget.json')); print('token-budget: VALID')"
```
Expected: Both `VALID`

```bash
git add .claude/shared/cache-metrics.json .claude/shared/token-budget.json
git commit -m "feat(hadf): extend cache-metrics with hadf_affinity, add hadf layer to token-budget"
```

---

### Task 7: Reference Implementations (Pseudocode)

**Files:**
- Create: `docs/architecture/hadf-reference-implementations.md`

- [ ] **Step 1: Write Layer 0 reference implementations**

Create `docs/architecture/hadf-reference-implementations.md`:

````markdown
# HADF Reference Implementations

> **Status:** Pseudocode / theoretical. These become real implementations when
> HADF moves from research to production (post-validation Phase 1).
>
> **Spec:** `docs/superpowers/specs/2026-04-16-hadf-hardware-aware-dispatch-design.md`

## Layer 0: Device Detection

### iOS / iPadOS (Swift)

```swift
import Foundation

struct DeviceCapabilityManifest: Codable {
    let chipId: String
    let vendor: String
    let arch: String
    let family: String
    let generation: Int
    let detectionConfidence: Double
}

func detectDeviceChip() -> DeviceCapabilityManifest {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machine = withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(cString: $0)
        }
    }
    
    // machine returns e.g. "iPhone16,1" → map to chip via lookup
    let chipId = ChipProfileLookup.resolve(deviceModel: machine)
    
    return DeviceCapabilityManifest(
        chipId: chipId ?? "arm64_mobile_unknown",
        vendor: chipId != nil ? "apple" : "unknown",
        arch: "arm64",
        family: chipId?.contains("m_series") == true ? "m_series" : "a_series",
        generation: ChipProfileLookup.generation(for: chipId),
        detectionConfidence: chipId != nil ? 1.0 : 0.3
    )
}
```

### macOS (Swift)

```swift
func detectMacChip() -> DeviceCapabilityManifest {
    var size: size_t = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var brand = [CChar](repeating: 0, count: size)
    sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
    let chipName = String(cString: brand)  // e.g. "Apple M3 Max"
    
    let chipId = ChipProfileLookup.resolve(cpuBrand: chipName)
    
    return DeviceCapabilityManifest(
        chipId: chipId ?? "arm64_desktop_unknown",
        vendor: "apple",
        arch: "arm64",
        family: "m_series",
        generation: ChipProfileLookup.generation(for: chipId),
        detectionConfidence: chipId != nil ? 1.0 : 0.3
    )
}
```

### Android (Kotlin)

```kotlin
import android.os.Build

data class DeviceCapabilityManifest(
    val chipId: String,
    val vendor: String,
    val arch: String,
    val family: String,
    val generation: Int,
    val detectionConfidence: Double
)

fun detectDeviceChip(): DeviceCapabilityManifest {
    // API 31+ provides direct SoC identity
    val socManufacturer = if (Build.VERSION.SDK_INT >= 31) {
        Build.SOC_MANUFACTURER  // e.g. "Google"
    } else {
        Build.HARDWARE  // fallback: e.g. "taro"
    }
    
    val socModel = if (Build.VERSION.SDK_INT >= 31) {
        Build.SOC_MODEL  // e.g. "Tensor G4"
    } else {
        parseCpuInfo()  // parse /proc/cpuinfo
    }
    
    val chipId = ChipProfileLookup.resolve(socManufacturer, socModel)
    
    return DeviceCapabilityManifest(
        chipId = chipId ?: "arm64_mobile_unknown",
        vendor = socManufacturer.lowercase(),
        arch = "arm64",
        family = ChipProfileLookup.family(chipId),
        generation = ChipProfileLookup.generation(chipId),
        detectionConfidence = if (chipId != null) 1.0 else 0.3
    )
}

private fun parseCpuInfo(): String {
    return try {
        java.io.File("/proc/cpuinfo").readLines()
            .firstOrNull { it.startsWith("Hardware") }
            ?.substringAfter(":")?.trim()
            ?: "unknown"
    } catch (e: Exception) {
        "unknown"
    }
}
```

## Layer 2: Cloud Fingerprinting Algorithm

### Signal Collection (per API call)

```python
# Pseudocode — runs after every API call
import time
from dataclasses import dataclass

@dataclass
class CallSignature:
    call_id: str
    timestamp: str
    provider: str
    model: str
    input_tokens: int
    output_tokens: int
    ttft_ms: float
    tps: float
    total_latency_ms: float

def record_call_signature(
    request_sent_at: float,
    first_token_at: float,
    response_done_at: float,
    input_tokens: int,
    output_tokens: int,
    provider: str,
    model: str
) -> CallSignature:
    ttft_ms = (first_token_at - request_sent_at) * 1000
    decode_time = response_done_at - first_token_at
    tps = output_tokens / decode_time if decode_time > 0 else 0
    total_ms = (response_done_at - request_sent_at) * 1000

    return CallSignature(
        call_id=str(uuid.uuid4()),
        timestamp=datetime.utcnow().isoformat(),
        provider=provider,
        model=model,
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        ttft_ms=ttft_ms,
        tps=tps,
        total_latency_ms=total_ms
    )
```

### Mahalanobis Classification

```python
import numpy as np
from scipy.spatial.distance import mahalanobis

def classify_cloud_hardware(
    call_signatures: list[CallSignature],
    signature_table: dict
) -> dict:
    """Classify cloud hardware class from observed API call patterns."""
    
    if len(call_signatures) < 5:
        return {"estimated_class": None, "confidence": 0.0}
    
    # Extract feature vector from observations
    ttft_per_1k = np.median([
        s.ttft_ms / (s.input_tokens / 1000)
        for s in call_signatures
    ])
    tps_median = np.median([s.tps for s in call_signatures])
    tps_cov = np.std([s.tps for s in call_signatures]) / tps_median
    
    observation = np.array([ttft_per_1k, tps_median, tps_cov])
    
    # Compare to each known hardware class
    distances = {}
    for hw_class, signature in signature_table.items():
        center = np.array([
            (signature["ttft_per_1k_tokens_ms"]["min"] + signature["ttft_per_1k_tokens_ms"]["max"]) / 2,
            (signature["tps_median"]["min"] + signature["tps_median"]["max"]) / 2,
            signature["tps_cov"]["max"] / 2
        ])
        # Simplified covariance (diagonal) from signature ranges
        cov = np.diag([
            ((signature["ttft_per_1k_tokens_ms"]["max"] - signature["ttft_per_1k_tokens_ms"]["min"]) / 4) ** 2,
            ((signature["tps_median"]["max"] - signature["tps_median"]["min"]) / 4) ** 2,
            (signature["tps_cov"]["max"] / 4) ** 2
        ])
        cov_inv = np.linalg.inv(cov)
        dist = mahalanobis(observation, center, cov_inv)
        distances[hw_class] = dist
    
    # Nearest class = best match
    sorted_classes = sorted(distances.items(), key=lambda x: x[1])
    best_class, best_dist = sorted_classes[0]
    runner_up, runner_dist = sorted_classes[1]
    
    # Confidence: inverse of distance, scaled by call count
    call_factor = min(len(call_signatures) / 15, 1.0)  # max at 15 calls
    raw_confidence = 1.0 / (1.0 + best_dist)
    confidence = raw_confidence * call_factor
    
    return {
        "estimated_class": best_class,
        "confidence": round(confidence, 2),
        "runner_up": runner_up,
        "runner_up_confidence": round(1.0 / (1.0 + runner_dist) * call_factor, 2),
        "signals_used": len(call_signatures),
        "classification_method": "mahalanobis_nearest"
    }
```

### Layer 3: Dynamic Adaptation

```python
def compute_dispatch_modifiers(
    thermal_state: str,        # "nominal", "fair", "serious", "critical"
    battery_pct: int,
    is_charging: bool,
    session_tps_baseline: float,
    current_tps: float,
    session_ttft_floor: float,
    current_ttft: float
) -> dict:
    """Compute real-time dispatch weight modifiers."""
    
    # Device modifier (thermal)
    thermal_map = {"nominal": 1.0, "fair": 0.5, "serious": 0.2, "critical": 0.1}
    device_mod = thermal_map.get(thermal_state, 1.0)
    
    # Battery modifier
    if is_charging:
        battery_mod = 1.0
    elif battery_pct > 50:
        battery_mod = 1.0
    elif battery_pct > 20:
        battery_mod = 0.7
    else:
        battery_mod = 0.4
    
    # Cloud modifier (TPS drift)
    if session_tps_baseline > 0:
        tps_ratio = current_tps / session_tps_baseline
        cloud_mod = min(max(tps_ratio, 0.1), 1.5)
    else:
        cloud_mod = 1.0
    
    # Network modifier (TTFT decomposition)
    if session_ttft_floor > 0:
        ttft_ratio = session_ttft_floor / current_ttft  # inverted — higher is worse
        network_mod = min(max(ttft_ratio, 0.1), 1.5)
    else:
        network_mod = 1.0
    
    return {
        "device_modifier": round(device_mod, 2),
        "battery_modifier": round(battery_mod, 2),
        "cloud_modifier": round(cloud_mod, 2),
        "network_modifier": round(network_mod, 2)
    }
```

### Composite Score

```python
def compute_composite_score(
    baseline: dict,          # from chip-profiles.json composite_baseline
    modifiers: dict,         # from Layer 3
    weight_preset: str,      # "user_facing", "background", etc.
    affinity_override: dict  # from Layer 4, or None
) -> dict:
    """Compute final HADF composite score."""
    
    presets = {
        "user_facing":       {"latency": 0.50, "cost": 0.15, "quality": 0.35},
        "background":        {"latency": 0.15, "cost": 0.50, "quality": 0.35},
        "critical_reasoning": {"latency": 0.10, "cost": 0.10, "quality": 0.80},
        "high_frequency":    {"latency": 0.35, "cost": 0.45, "quality": 0.20},
    }
    weights = presets[weight_preset]
    
    # Apply modifiers to baseline
    combined_modifier = (
        modifiers["device_modifier"]
        * modifiers["cloud_modifier"]
        * modifiers["network_modifier"]
        * modifiers["battery_modifier"]
    )
    
    # Use affinity override if available and confident
    if affinity_override and affinity_override.get("samples", 0) > 50:
        latency = affinity_override["performance_history"]["avg_latency_ms"]
        # Normalize to 0-1 scale (lower latency = higher score)
        latency_score = max(0, 1.0 - (latency / 5000))
    else:
        latency_score = baseline["latency_score"] * combined_modifier
    
    cost_score = baseline["cost_score"] * modifiers["device_modifier"]
    quality_score = baseline["quality_score"]
    
    # Clamp all to [0, 1]
    latency_score = min(max(latency_score, 0), 1)
    cost_score = min(max(cost_score, 0), 1)
    quality_score = min(max(quality_score, 0), 1)
    
    composite = (
        weights["latency"] * latency_score
        + weights["cost"] * cost_score
        + weights["quality"] * quality_score
    )
    
    # Determine strategy
    if composite < 0.3:
        strategy = "cloud_preferred"
    elif modifiers["device_modifier"] < 0.3:
        strategy = "cloud_preferred"
    elif baseline.get("overall", 0) > 0.8 and modifiers["device_modifier"] > 0.8:
        strategy = "device_preferred"
    else:
        strategy = "hybrid"
    
    return {
        "score": round(composite, 2),
        "latency_component": round(latency_score, 2),
        "cost_component": round(cost_score, 2),
        "quality_component": round(quality_score, 2),
        "weight_preset": weight_preset,
        "strategy": strategy
    }
```
````

- [ ] **Step 2: Commit**

```bash
git add docs/architecture/hadf-reference-implementations.md
git commit -m "docs(hadf): add reference implementations — Layer 0 (Swift/Kotlin), Layer 2 (Python classifier), Layer 3 + Composite"
```

---

### Task 8: Token Budget Update

**Files:**
- Modify: `scripts/count-framework-tokens.sh`

- [ ] **Step 1: Check current token counting script**

Run: `head -50 scripts/count-framework-tokens.sh`

Review the script to understand how layers are counted.

- [ ] **Step 2: Add HADF layer to the counting script**

Add a new layer section for HADF files. The exact edit depends on the script structure, but the HADF layer should count:
- `.claude/shared/chip-profiles.json`
- `.claude/shared/chip-affinity-map.json`
- `.claude/shared/hadf/hardware-signature-table.json`
- `.claude/shared/hadf/hadf-metrics-template.json`

- [ ] **Step 3: Run the updated token counter**

Run: `bash scripts/count-framework-tokens.sh`
Expected: Output includes a new `hadf` layer with token count.

- [ ] **Step 4: Commit**

```bash
git add scripts/count-framework-tokens.sh .claude/shared/token-budget.json
git commit -m "feat(hadf): add hadf layer to token budget counter"
```

---

### Task 9: Final Validation and Summary Commit

**Files:**
- All HADF files

- [ ] **Step 1: Validate all JSON files**

Run:
```bash
python3 -c "
import json, glob
files = [
    '.claude/shared/chip-profiles.json',
    '.claude/shared/chip-affinity-map.json',
    '.claude/shared/hadf/hardware-signature-table.json',
    '.claude/shared/hadf/hadf-metrics-template.json',
    '.claude/shared/dispatch-intelligence.json',
    '.claude/shared/cache-metrics.json',
    '.claude/shared/token-budget.json'
]
for f in files:
    try:
        json.load(open(f))
        print(f'  VALID: {f}')
    except Exception as e:
        print(f'  FAIL:  {f} — {e}')
"
```
Expected: All 7 files `VALID`

- [ ] **Step 2: Verify chip-profiles.json has all expected profiles**

Run:
```bash
python3 -c "
import json
data = json.load(open('.claude/shared/chip-profiles.json'))
profiles = data['profiles']
print(f'Total profiles: {len(profiles)}')
vendors = {}
for pid, p in profiles.items():
    v = p['vendor']
    vendors[v] = vendors.get(v, 0) + 1
for v, c in sorted(vendors.items()):
    print(f'  {v}: {c}')
"
```
Expected: 15 profiles across 6 vendors (apple, google, qualcomm, samsung, mediatek, unknown) + web_wasm

- [ ] **Step 3: Verify dispatch-intelligence.json has hardware_context**

Run:
```bash
python3 -c "
import json
data = json.load(open('.claude/shared/dispatch-intelligence.json'))
hc = data.get('hardware_context')
assert hc is not None, 'hardware_context missing'
assert hc['confidence_gate']['trust_threshold'] == 0.7
assert hc['confidence_gate']['blend_threshold'] == 0.4
assert hc['enabled'] == False
print('dispatch-intelligence.json: hardware_context verified')
print(f'  Confidence gate: trust={hc[\"confidence_gate\"][\"trust_threshold\"]}, blend={hc[\"confidence_gate\"][\"blend_threshold\"]}')
print(f'  Enabled: {hc[\"enabled\"]}')
print(f'  Weight presets: {list(hc[\"weight_presets\"].keys())}')
"
```
Expected: All assertions pass, enabled=False, 4 weight presets listed.

- [ ] **Step 4: Verify file sizes are within budget**

Run:
```bash
echo "HADF file sizes:"
wc -c .claude/shared/chip-profiles.json .claude/shared/chip-affinity-map.json .claude/shared/hadf/hardware-signature-table.json .claude/shared/hadf/hadf-metrics-template.json
```
Expected: chip-profiles.json ~15-25KB, others <5KB each. Total HADF footprint <35KB.

- [ ] **Step 5: Summary commit if any uncommitted HADF changes remain**

```bash
git status
# If anything is uncommitted:
git add .claude/shared/ docs/architecture/hadf-reference-implementations.md
git commit -m "feat(hadf): HADF v1.0 framework infrastructure — 15 chip profiles, 7 cloud signatures, dispatch integration, reference implementations"
```
