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
    
    // machine returns e.g. "iPhone16,1" -> map to chip via lookup
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
    val socManufacturer = if (Build.VERSION.SDK_INT >= 31) {
        Build.SOC_MANUFACTURER
    } else {
        Build.HARDWARE
    }
    
    val socModel = if (Build.VERSION.SDK_INT >= 31) {
        Build.SOC_MODEL
    } else {
        parseCpuInfo()
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
import time
import uuid
from datetime import datetime
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
    if len(call_signatures) < 5:
        return {"estimated_class": None, "confidence": 0.0}
    
    ttft_per_1k = np.median([
        s.ttft_ms / (s.input_tokens / 1000)
        for s in call_signatures
    ])
    tps_median = np.median([s.tps for s in call_signatures])
    tps_cov = np.std([s.tps for s in call_signatures]) / tps_median
    
    observation = np.array([ttft_per_1k, tps_median, tps_cov])
    
    distances = {}
    for hw_class, signature in signature_table.items():
        center = np.array([
            (signature["ttft_per_1k_tokens_ms"]["min"] + signature["ttft_per_1k_tokens_ms"]["max"]) / 2,
            (signature["tps_median"]["min"] + signature["tps_median"]["max"]) / 2,
            signature["tps_cov"]["max"] / 2
        ])
        cov = np.diag([
            ((signature["ttft_per_1k_tokens_ms"]["max"] - signature["ttft_per_1k_tokens_ms"]["min"]) / 4) ** 2,
            ((signature["tps_median"]["max"] - signature["tps_median"]["min"]) / 4) ** 2,
            (signature["tps_cov"]["max"] / 4) ** 2
        ])
        cov_inv = np.linalg.inv(cov)
        dist = mahalanobis(observation, center, cov_inv)
        distances[hw_class] = dist
    
    sorted_classes = sorted(distances.items(), key=lambda x: x[1])
    best_class, best_dist = sorted_classes[0]
    runner_up, runner_dist = sorted_classes[1]
    
    call_factor = min(len(call_signatures) / 15, 1.0)
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

## Layer 3: Dynamic Adaptation

```python
def compute_dispatch_modifiers(
    thermal_state: str,
    battery_pct: int,
    is_charging: bool,
    session_tps_baseline: float,
    current_tps: float,
    session_ttft_floor: float,
    current_ttft: float
) -> dict:
    thermal_map = {"nominal": 1.0, "fair": 0.5, "serious": 0.2, "critical": 0.1}
    device_mod = thermal_map.get(thermal_state, 1.0)
    
    if is_charging:
        battery_mod = 1.0
    elif battery_pct > 50:
        battery_mod = 1.0
    elif battery_pct > 20:
        battery_mod = 0.7
    else:
        battery_mod = 0.4
    
    if session_tps_baseline > 0:
        tps_ratio = current_tps / session_tps_baseline
        cloud_mod = min(max(tps_ratio, 0.1), 1.5)
    else:
        cloud_mod = 1.0
    
    if session_ttft_floor > 0:
        ttft_ratio = session_ttft_floor / current_ttft
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

## Composite Score

```python
def compute_composite_score(
    baseline: dict,
    modifiers: dict,
    weight_preset: str,
    affinity_override: dict = None
) -> dict:
    presets = {
        "user_facing":        {"latency": 0.50, "cost": 0.15, "quality": 0.35},
        "background":         {"latency": 0.15, "cost": 0.50, "quality": 0.35},
        "critical_reasoning": {"latency": 0.10, "cost": 0.10, "quality": 0.80},
        "high_frequency":     {"latency": 0.35, "cost": 0.45, "quality": 0.20},
    }
    weights = presets[weight_preset]
    
    combined_modifier = (
        modifiers["device_modifier"]
        * modifiers["cloud_modifier"]
        * modifiers["network_modifier"]
        * modifiers["battery_modifier"]
    )
    
    if affinity_override and affinity_override.get("samples", 0) > 50:
        latency = affinity_override["performance_history"]["avg_latency_ms"]
        latency_score = max(0, 1.0 - (latency / 5000))
    else:
        latency_score = baseline["latency_score"] * combined_modifier
    
    cost_score = baseline["cost_score"] * modifiers["device_modifier"]
    quality_score = baseline["quality_score"]
    
    latency_score = min(max(latency_score, 0), 1)
    cost_score = min(max(cost_score, 0), 1)
    quality_score = min(max(quality_score, 0), 1)
    
    composite = (
        weights["latency"] * latency_score
        + weights["cost"] * cost_score
        + weights["quality"] * quality_score
    )
    
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
