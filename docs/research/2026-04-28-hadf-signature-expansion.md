# HADF Signature Library Expansion — April 2026 Research Note

> **Status:** RESEARCH (2026-04-28). Baseline: 17 mobile/desktop profiles + 7 cloud signatures shipped in PR #82 (2026-04-16). This note proposes a delta against that baseline based on three research passes covering Apple/Android/Datacenter/RISC-V, Intel, and AMD.
>
> **Out of scope:** spec writing, schema changes, RTL changes. This note collects the candidate profiles, flags architectural primitives that don't fit the current schema, and proposes a prioritization. Implementation lands as a follow-up PR against `.claude/shared/chip-profiles.json` and `.claude/shared/hadf/hardware-signature-table.json`.
>
> **Companion note:** [ORCHID + framework v7.x mapping](2026-04-28-orchid-framework-v7-mapping.md).

---

## 1. What the current baseline covers

`chip-profiles.json` v1.0 (17 entries, Apr 16 2026):

- Apple A-series: A18 Pro, A17 Pro, A16, A15
- Apple M-series: M4 Max, M3 Pro, M1
- Google Tensor: G4, G3
- Qualcomm Snapdragon: 8 Gen 3, 7 Gen 3, X Elite
- Samsung Exynos: 2400
- MediaTek Dimensity: 9300
- Fallbacks: arm64-mobile-unknown, arm64-desktop-unknown, web-wasm-low

`hardware-signature-table.json` v1.0 (7 entries):

- Nvidia: H100-class, A100-class
- Google TPU: v5e-class, v4-class
- AWS Trainium2-class
- AMD MI300X-class
- CPU fallback

**Notable gaps even before this expansion:**
- No Intel mobile/desktop chip at all (Core Ultra Series 1/2/3 missing).
- No AMD client chip at all (Ryzen AI Strix Point/Halo/Krackan missing).
- No EPYC / Xeon CPU profile despite CPU-only inference being a real fallback path.
- No FP4 / FP6 / FP8 / MXFP encoding in the precision field — it's `int8` / `float16` only.
- No "platform TOPS" composite — peak NPU TOPS is the only compute axis.
- Cloud signature table has 7 entries with `calibration_status: "uncalibrated"` and a comment saying values "require empirical calibration via Phase 2 validation" — Phase 2 has not yet been run (per [project_hadf_research.md](../../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_hadf_research.md)).

---

## 2. Mobile / desktop chips to add

Each entry below is a **candidate** for `chip-profiles.json`. Specs sourced from the three research passes; numbers without a vendor-published TOPS figure are tagged `tops_source: "secondary"` so HADF can downweight them in dispatch.

### Apple

| Profile id | Tier | Released | Key delta vs baseline |
|---|---|---|---|
| `apple_a19` | flagship | Sep 2025 | Adds GPU-integrated Neural Accelerators per GPU core. **No Apple-published TOPS.** |
| `apple_a19_pro` | flagship | Sep 2025 | 12 GB LPDDR5X-9600, 76.8 GB/s. NPU and GPU AI both relevant. |
| `apple_m5` | desktop | Oct 2025 | 153.6 GB/s memory; Apple claims 4× peak GPU AI compute vs M4. |
| `apple_m5_pro` | desktop | Mar 2026 | Up to 64 GB / 307 GB/s. |
| `apple_m5_max` | desktop | Mar 2026 | Up to 128 GB / 460 GB/s (32-CU) or 614 GB/s (40-CU). 4× faster LLM prompt processing vs M4 Max. |

**Schema implication:** Apple's A19/M5 family is the first to put XMX-style matmul in the GPU rather than only the NPU. The current `npu_tops` single-axis model under-represents these chips. See §5 for the proposed `compute_axes` extension.

### Qualcomm

| Profile id | Tier | Released | Key delta |
|---|---|---|---|
| `qualcomm_snapdragon_8_elite` | flagship | Q4 2024 | Replaces "8 Gen 4" — Qualcomm renamed the generation. |
| `qualcomm_snapdragon_8_elite_gen5` | flagship | Sep 2025 | Hexagon supports **INT2** and **FP8** natively. Up to 220 tok/s on-device LLM. Galaxy S26 (Mar 2026). |

**Schema implication:** INT2 and FP8 are not in the current `preferred_precision` enum.

### MediaTek / Samsung / Google

| Profile id | Tier | Released | Key delta |
|---|---|---|---|
| `mediatek_dimensity_9500` | flagship | Sep 2025 | **NPU 990 — first mobile NPU with integrated compute-in-memory.** Native BitNet 1.58-bit. 2× compute vs 9400. |
| `samsung_exynos_2500` | flagship | Jun 2025 | **59 TOPS** (Samsung-published). 2× 12K MAC clusters. RDNA 3-derived Xclipse 950 GPU. |
| `google_tensor_g5` | flagship | Aug 2025 | TSMC 3nm (first time off Samsung Foundry). 4th-gen TPU. 2.6× Gemini Nano perf vs G4. No published TOPS. |

**Schema implication:** Compute-in-memory (Dimensity 9500) and BitNet 1.58-bit are dispatch-relevant but not in the current `preferred_precision` enum.

### Intel client (entirely new vendor in HADF)

| Profile id | Tier | Released | NPU TOPS | Key delta |
|---|---|---|---|---|
| `intel_meteor_lake_npu3` | mid | Dec 2023 | 10–11 INT8 | NPU 3, sub-Copilot+ baseline |
| `intel_arrow_lake_s_npu3` | desktop | Oct 2024 | 13 INT8 | First desktop with integrated NPU |
| `intel_arrow_lake_h_hx` | flagship | Jan 2025 | 13 INT8 | Gaming-laptop tier |
| `intel_lunar_lake_npu4` | flagship | Sep 2024 | 48 INT8 + FP16 | Copilot+ thin-and-light. Platform total ~115 TOPS (NPU 48 + GPU XMX 67). |
| `intel_panther_lake_npu5` | flagship | Jan 2026 | 50 INT8 + native FP8 | **First 18A client product.** Platform total ~180 TOPS (NPU 50 + Xe3 XMX 120 + CPU). |

**Schema implication:** Intel's **platform-TOPS-split** model (NPU + GPU XMX + CPU AMX) is materially different from Apple/Qualcomm's NPU-dominant model. A 50-TOPS Panther Lake NPU is not a "mid-tier" chip if dispatch can use Xe3 XMX + AMX simultaneously.

### AMD client (entirely new vendor in HADF)

| Profile id | Tier | Released | NPU TOPS | Key delta |
|---|---|---|---|---|
| `amd_strix_point_xdna2` | flagship | Jul 2024 | 50 (HX 370) / 55 (HX 375) | XDNA 2 NPU. Block FP16 (FP16 accuracy at INT8 cost). RDNA 3.5 iGPU. |
| `amd_krackan_point_xdna2` | mid | Jan 2025 | 50 INT8 | Same NPU at lower CPU/iGPU tier. |
| `amd_strix_halo_xdna2` | desktop | Jan 2025 | 50+ | **Workstation-class unified-memory client.** Up to 128 GB LPDDR5X-8000 shared CPU+iGPU+NPU. 40-CU RDNA 3.5 iGPU. Client-tier analogue of MI300A. |
| `amd_gorgon_point_xdna2` | flagship | 2026 | 55+ | XDNA 2 refresh. CES 2026. |

**Schema implication:** Strix Halo's **128 GB unified memory across CPU+iGPU+NPU** is a tier the baseline doesn't represent. `available_for_ml_mb` of "1500–4000" doesn't fit a 128 GB unified-memory client. Block FP16 also doesn't fit the precision enum.

### Fallback updates

Current `arm64_mobile_unknown` (15 TOPS NPU) is now below the median 2026 flagship. Recommend:
- Add `arm64_mobile_2026_unknown` at 30 TOPS, FP16 + INT8.
- Add `x86_64_npu_2026_unknown` (Intel-style or AMD-style client with dedicated NPU) at 40 TOPS.
- Keep the existing 15-TOPS entry as `arm64_mobile_legacy_unknown` for older devices.

---

## 3. Cloud / datacenter signatures to add

Current `hardware-signature-table.json` has 7 entries. Below adds 11 distinct generations / vendors that have shipped or moved into broad GA since April 2026.

| Signature id | Vendor | Generation | Status April 2026 | Distinct primitive |
|---|---|---|---|---|
| `nvidia_b200_class` | nvidia | blackwell | Production at scale, sold out through mid-2026 | NVFP4 native, 192 GB HBM3e, 8 TB/s, FP4 dense 10 PFLOPS |
| `nvidia_b300_class` | nvidia | blackwell-ultra | Shipping since Jan 2026 | 288 GB HBM3e, **15 PFLOPS dense FP4**, 1400W, GB300 NVL72 |
| `google_tpu_v6e_trillium_class` | google | v6e | GA late 2024, used for Gemini 2.0 training | First post-v5e TPU, training/inference |
| `google_tpu_v7_ironwood_class` | google | v7 | GA Nov 2025; Anthropic committed >1M units in 2026 | **Inference-optimized** (distinct from Trillium) |
| `aws_trainium3_class` | aws | trn3 | GA Dec 2025, EC2 Trn3 UltraServers | **Native MXFP8 + MXFP4** + structured sparsity. 144 GB HBM3e. First non-Nvidia chip with both microscaled formats. |
| `amd_mi325x_class` | amd | cdna3-refresh | Q4 2024 / Q1 2025 GA | 256 GB HBM3E @ 6 TB/s |
| `amd_mi350x_class` | amd | cdna4 | H2 2025 GA | **FP4 + FP6 + FP8 (MX) + OCP FP8.** 288 GB HBM3E @ 8 TB/s |
| `amd_mi300a_apu_class` | amd | cdna3-apu | Volume since 2023 | **Unified CPU+GPU+HBM3 memory** (128 GB). No PCIe copy. Distinct dispatch primitive. |
| `intel_gaudi3_class` | intel | gaudi3 | GA Q3 2024; IBM Cloud GA | 1.8 PFLOPS FP8 / 1.8 PFLOPS BF16. **24× 200 GbE on-package** (distinct scale-out primitive). 128 GB HBM2e. |
| `sambanova_sn40l_class` | sambanova | rdu | Production via SambaNova Cloud | **Pure dataflow / RDU** (not GPU/TPU). 520 MiB SRAM + 64 GiB HBM + up to 1.5 TiB DDR. |
| `tenstorrent_blackhole_class` | tenstorrent | blackhole | **Galaxy GA today (Apr 28 2026)** | 774 TFLOPS FP8/chip, 16 RISC-V CPU cores per chip, 12× 400 GbE per chip. RISC-V + Tensix++ dataflow. |
| `microsoft_maia100_class` | microsoft | maia1 | Production in Azure since 2024 | First-party Azure inference silicon. (Maia 200 / Braga delayed to 2026.) |
| `cerebras_wse3_class` | cerebras | wse3 | Production; Meta + OpenAI named customers | Wafer-scale; >1000 tok/s on Llama 3.1-405B. |
| `groq_lpu_class` | groq | lpu (now nvidia) | Production; **Nvidia acquired Groq Dec 2025 for $20B** | Tag with vendor-status change; future independent target uncertain. |

### Vendor / market events that should be encoded in dispatch heuristics

- **Nvidia ↔ Groq merger (Dec 2025, $20B).** HADF dispatch should treat Groq endpoints as Nvidia-controlled going forward.
- **Esperanto Technologies folded mid-2025.** Drop ET-SoC-1 from any tracking — it never shipped at scale and the company is gone.
- **Falcon Shores cancelled (2025).** Don't add a Falcon Shores profile; Intel's discrete-card AI roadmap moved to Jaguar Shores (H2 2026).
- **Intel Diamond Rapids slipped to mid-2027.** AMX-FP8 is at least 14 months away on Intel CPU.
- **AMD ROCm 7 (Sept 2025) unified datacenter + consumer + Windows.** Treat MI350 and RX 9070 XT as dispatch siblings now, not separate stacks.

---

## 4. Server CPU (entirely new bucket — not in baseline)

The current baseline has **no server-CPU profile at all**. CPU inference is real (Xeon Max, EPYC + AVX-512 VNNI, AMX on Granite Rapids) and a non-zero share of cloud-inference traffic still routes there for cost or sovereignty reasons. Proposed new bucket `server_cpu_profiles`:

| Profile id | Vendor | Cores | AI primitive | Memory |
|---|---|---|---|---|
| `intel_xeon_6900p_granite_rapids` | intel | up to 128 P | AMX (INT8/BF16/**FP16**), AVX10.1, AVX-512 | 12-ch DDR5-6400, MRDIMM-8800, 6 TB |
| `intel_xeon_6900e_sierra_forest` | intel | up to 288 E | AVX2 only (**no AMX, no AVX-512**) | 12-ch DDR5 |
| `intel_xeon_6_clearwater_forest` | intel | 288 Darkmont E | First 18A server (H1 2026) | 12-ch DDR5-8000 |
| `amd_epyc_turin_9005` | amd | up to 128 c (Zen 5) | Full 512-bit AVX-512 + VNNI + BF16 | 12-ch DDR5-6400, CXL 2.0 |
| `amd_epyc_turin_dense_9005` | amd | up to 192 c (Zen 5c) | Same ISA as Zen 5 (scale-out) | 12-ch DDR5 |
| `amd_epyc_4005_grado` | amd | up to 16 c | AVX-512 + VNNI + BF16, AM5 socket | DDR5-5600 ECC |

**Why this bucket matters for dispatch:** AMX-FP16 on a 128-core Granite Rapids node is a legitimate small-LLM inference target without a GPU. AVX-512 VNNI on EPYC Turin is too. Treating them as `cpu_fallback_class` (the current 200–999 ms TTFT entry) under-fits real cost-optimized inference paths — a "CPU with matrix unit" tier is genuinely faster than a CPU without.

---

## 5. Schema gaps the current `chip-profiles.json` doesn't cover

Five primitives surfaced across the three research passes that don't fit the current v1.0 schema:

### 5.1 Precision enum is too narrow
**Current:** `"int8" | "float16" | "none"`.
**Needed (April 2026 reality):**

| Format | First seen in production | Where |
|---|---|---|
| `fp8` | Late 2023 / Hopper | H100 Transformer Engine |
| `nvfp4` | 2025 | Blackwell B200/B300 |
| `mxfp8` | Dec 2025 | AWS Trainium3 |
| `mxfp4` | Dec 2025 / 2025 | Trainium3, AMD MI350 |
| `fp6` | 2025 | AMD MI350 |
| `int2` | 2025 | Snapdragon 8 Elite Gen 5 |
| `bitnet_1_58` | 2025 | MediaTek Dimensity 9500 NPU 990 |
| `block_fp16` | 2024 | AMD XDNA 2 (Strix Point family) |

Recommendation: replace `preferred_precision` (string) with `supported_precisions` (array) and add `peak_precision` separately.

### 5.2 No "platform TOPS split" for hybrid SoCs
Current schema has one `npu_tops` field. This under-fits:
- Intel Lunar Lake (NPU 48 + GPU XMX 67 = ~115 platform)
- Intel Panther Lake (NPU 50 + Xe3 XMX 120 + CPU AMX = ~180 platform)
- AMD Strix Halo (NPU 50 + 40-CU RDNA 3.5 iGPU)
- Apple M5 family (NE + per-GPU-core Neural Accelerators)

Recommendation: composite `compute_axes`:
```json
{
  "npu_tops": 50,
  "gpu_matmul_tops": 120,
  "cpu_matmul_tops": 10,
  "platform_tops": 180,
  "memory_bandwidth_gbps": 76.8
}
```

### 5.3 No unified-memory tier
MI300A (128 GB HBM3 unified CPU+GPU) and Strix Halo (128 GB LPDDR5X unified CPU+iGPU+NPU) eliminate the host↔device copy step. The current `unified_memory: bool` field doesn't distinguish "Apple-style on-die unified" from "MI300A in-package unified" from "no unified."

Recommendation: `memory_topology` enum: `"discrete" | "soc_unified" | "in_package_unified" | "rack_scale_pooled"` (last entry for Helios + Vulcano + future CXL pools).

### 5.4 No on-package networking primitive
Gaudi 3's 24×200 GbE on-package and Jaguar Shores' silicon-photonics interconnect are dispatch-relevant for scale-out workloads. Current schema has no networking field.

Recommendation: optional `built_in_networking` field with `{ports, lanes_per_port_gbps, total_gbps}`.

### 5.5 Vendor / market-event tagging
HADF currently treats vendor as a fixed string. Three 2025–2026 events broke that:
- Nvidia acquired Groq.
- Esperanto folded.
- Microsoft Maia 200 / Intel Falcon Shores both delayed/cancelled.

Recommendation: `vendor_status` field: `"independent" | "acquired_by:<vendor>" | "defunct" | "rebranded"`. Lets dispatch decay weight on at-risk vendors without removing the profile.

---

## 6. Cloud-fingerprinting heuristic gaps

The current `signatures` table (7 entries) classifies by `(ttft_per_1k_tokens_ms, tps_median, tps_cov, batch_scaling_factor)`. Phase 2 (50×5×3 = 750 data points) was never run per [project_hadf_research.md](../../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_hadf_research.md), and this baseline has known weaknesses:

1. **No precision-class signal.** Trainium3 (MXFP4) and B300 (NVFP4) produce different per-token latencies than B200 (FP8), but the 4-tuple above doesn't capture that.
2. **No NUMA / topology probe.** A B200 in a single-node deployment vs an NVL72 GB200 cluster has different batch_scaling_factor — it's already in the schema, but Phase 2 hasn't tuned it.
3. **No instruction-mix benchmark.** A Mahalanobis distance on (TTFT, TPS) confuses an under-utilized H100 with an A100. Adding an embedding-throughput probe (small batch + large batch deltas) could disambiguate.
4. **Container vs bare-metal detection.** A B200 in a serverless inference endpoint runs at lower percentile-99 than a dedicated B200 node. Variance signal helps but doesn't disambiguate the cause.
5. **No memory-bandwidth probe.** For long-context workloads, HBM bandwidth dominates; for short-context, compute does. A two-workload probe (small-context vs long-context same prompt) would discriminate.

Recommendation: Phase 2 calibration should add at least `(precision_class, bandwidth_probe_ratio, container_vs_bare_metal_variance)` to the signature schema before any new generation is added.

---

## 7. Architectural primitives that warrant new dispatch categories

These are primitives genuinely new since the April 2026 baseline that don't have a clean dispatch hint today:

| Primitive | Vendor / first chip | Why dispatch cares |
|---|---|---|
| **Compute-in-memory NPU** | MediaTek Dimensity 9500 NPU 990 | Bandwidth wall doesn't apply; very-low-bit (BitNet 1.58) inference becomes attractive. |
| **GPU-integrated Neural Accelerators per core** | Apple A19 / M5 family | NPU vs GPU dispatch is no longer cleanly separable on Apple. |
| **Block FP16** | AMD XDNA 2 (Strix Point/Halo/Krackan) | Lets the dispatcher treat the NPU as INT8-cost / FP16-accuracy — distinct from generic FP16. |
| **Microscaled FP (MXFP4/MXFP8)** | AWS Trainium3 | Distinct from generic FP4/FP8; routing decisions for low-precision inference should prefer it where available. |
| **In-package CPU+GPU unified memory** | AMD MI300A | Eliminates host↔device copy; latency profile of large-model dispatch changes. |
| **On-package datacenter networking** | Intel Gaudi 3 (24×200GbE), Jaguar Shores (silicon photonics) | Scale-out dispatch decisions weight idle-time differently. |
| **Dataflow / RDU architecture** | SambaNova SN40L/SN50, Tenstorrent Blackhole | Different cost curve than GPU/TPU; some agentic workloads (long-context, sparse) favor dataflow. |
| **Wafer-scale** | Cerebras WSE-3 | All-in-SRAM, very low TPS variance; dispatch should weight cost-per-token over latency at scale. |
| **Native FP4 / FP6 on consumer GPU** | AMD RX 9070 XT | First time a consumer GPU is a legitimate FP8 inference target — opens at-edge cloud workloads. |
| **No-AMX-on-EPYC negative primitive** | AMD EPYC Turin | Important to encode: a 128-core Turin without AMX is not interchangeable with a 128-core Granite Rapids with AMX. |
| **ROCm 7 unified stack** | AMD MI350 + RX 9070 XT + Strix Halo | Consumer + datacenter dispatch can share kernels; closes the long-standing CUDA-fragmentation gap on AMD. |

---

## 8. Recommended prioritization

Three tiers based on dispatch impact × evidence strength:

### Tier 1 — Add now (high impact, ships in production today)
1. `nvidia_b300_class` — Blackwell Ultra, 4× the dispatch volume of B200 by mid-2026.
2. `aws_trainium3_class` — first non-Nvidia chip with MXFP8/MXFP4; Anthropic on AWS uses it.
3. `google_tpu_v7_ironwood_class` — Anthropic committed >1M chips; will dominate cloud inference.
4. `amd_mi350x_class` — first AMD chip with FP4/FP6.
5. `intel_panther_lake_npu5` — first Intel client chip with native FP8 NPU.
6. `amd_strix_halo_xdna2` — establishes the unified-memory-client tier.
7. `qualcomm_snapdragon_8_elite_gen5` — INT2 + FP8 on mobile.
8. `mediatek_dimensity_9500` — compute-in-memory primitive.
9. `apple_a19_pro` + `apple_m5` + `apple_m5_max` — current Apple flagship reality.
10. **Schema additions:** precision enum expansion, `compute_axes` composite, `memory_topology` enum.

### Tier 2 — Add next quarter (moderate impact or mid-tier)
11. `intel_lunar_lake_npu4` + `intel_arrow_lake_*` — fills the entirely-missing Intel client bucket.
12. `amd_strix_point_xdna2` + `amd_krackan_point_xdna2` + `amd_gorgon_point_xdna2` — fills Ryzen client bucket.
13. `samsung_exynos_2500` + `google_tensor_g5` — fills mobile flagship gaps.
14. Server-CPU bucket: `intel_xeon_6900p_granite_rapids` + `amd_epyc_turin_9005` + `amd_epyc_turin_dense_9005` — opens CPU-only inference dispatch.
15. `amd_mi300a_apu_class` — codifies unified-memory datacenter tier.
16. `intel_gaudi3_class` — codifies on-package networking primitive.
17. `sambanova_sn40l_class` + `tenstorrent_blackhole_class` — codifies dataflow / RDU class.

### Tier 3 — Track but don't add yet (announced, not shipping at scale)
- `nvidia_rubin_r100_class` (sampling Q4 2026)
- `amd_mi400_class` (mid-2026 production target)
- `aws_trainium4_class` (in development)
- `microsoft_maia200_class` (delayed to 2026)
- `intel_jaguar_shores_class` (H2 2026 target)
- `intel_diamond_rapids_class` (slipped to mid-2027)
- `amd_zen6_medusa_xdna3` (2027)
- `apple_a20` / `apple_m6` family (unannounced)

### Tier 4 — Drop or rebrand
- `qualcomm_snapdragon_8_gen3` → keep but mark as non-current.
- ET-SoC-1 / Esperanto — never had a profile; do not add.
- `groq_lpu_class` — add with `vendor_status: "acquired_by:nvidia"`.

---

## 9. Open questions

1. **Phase 2 cloud-fingerprinting validation has not run.** All 7 cloud signatures are currently `calibration_status: "uncalibrated"`. Adding 11 more uncalibrated signatures may worsen classification accuracy if Phase 2 isn't run first. Two options:
   - **Option A:** Run Phase 2 with the existing 7 first (per the original plan), then add the new 11 calibrated.
   - **Option B:** Add all 18 uncalibrated, run Phase 2 once across the full set.
   Option B saves an iteration but trades classification accuracy for breadth. Recommendation: A.
2. **Should HADF carry "announced but not shipping" profiles?** Adding Tier-3 chips lets HADF prepare without code changes when they ship, but creates the risk of stale entries (Falcon Shores cancellation pattern). Recommendation: do not add Tier 3 to the active table; keep them in this research note as a watchlist.
3. **Server-CPU profiles — same table or separate?** Schema today is mobile/desktop only. Two options:
   - Add a new `server_cpu_profiles` block.
   - Extend `chip-profiles.json` with a `tier: "server_cpu"` value.
   Recommendation: separate block, because the field set is materially different (`amx_precisions`, `avx10_level`, `numa_nodes` don't apply to mobile).

---

## 10. Next steps

1. **Decide on schema changes** (§5) — these need to land before Tier-1 profiles can be encoded faithfully. ~1 PR, schema-only.
2. **Run Phase 2 cloud fingerprinting** with the existing 7 signatures (50×5×3 = 750 calls, ~$5).
3. **Land Tier 1 profiles** (10 entries + schema updates) in a single PR. Includes vendor_status tagging for Groq.
4. **Land Tier 2 profiles** (~9 entries + server-CPU bucket) in a second PR.
5. **Update the dispatch confidence-gate rollout plan** in [`dispatch-intelligence.json`](../../.claude/shared/dispatch-intelligence.json) to account for the larger profile library — current 0.4/0.7 gates were calibrated against 17 entries.
6. **Cross-link** this note from [project_hadf_research.md](../../../.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_hadf_research.md) and the backlog item under "High Priority (Architecture & Framework)" in [`docs/product/backlog.md`](../product/backlog.md).

---

## Appendix A — Source material

Primary research passes captured in this note:
1. **General chip landscape (Apple/Android/Datacenter/RISC-V):** Apple A19 family (Wikipedia, Tom's Hardware), Apple M5 family (Apple newsroom, MacRumors), Snapdragon 8 Elite Gen 5 (Qualcomm press release), Dimensity 9500 (MediaTek product page), Exynos 2500 (SamMobile, Samsung), Tensor G5 (Google blog, Android Authority), Blackwell B200/B300 (NVIDIA newsroom, Spheron), Trainium3 (HPCwire, AWS), TPU v7 Ironwood (SemiAnalysis, GCP docs), Cerebras WSE-3 (IntuitionLabs), Tenstorrent Blackhole (The Register Apr 28 2026, Tenstorrent docs), SambaNova SN40L/SN50 (SambaNova product pages), Lightmatter Passage (Lightmatter press), Mythic memBrain (Globe Newswire).
2. **Intel:** Panther Lake / Arrow Lake / Lunar Lake / Meteor Lake (Wikipedia, AnandTech, Intel EDC, Intel Newsroom CES 2026, PBXScience), Granite Rapids / Sierra Forest / Clearwater Forest / Diamond Rapids (Phoronix, Tom's Hardware, Wikipedia, VideoCardz, WCCFTech), Gaudi 3 (Intel white paper, IBM Newsroom), Falcon Shores cancellation + Jaguar Shores (Tom's Hardware, TrendForce), Arc Battlemage / Pro B60 (Intel Newsroom, TechPowerUp, StorageReview).
3. **AMD:** Ryzen AI 300 series + Strix Halo + Krackan + Gorgon Point (AMD product pages, Tom's Hardware, Notebookcheck, ServeTheHome), EPYC Turin 9005 + EPYC 4005 (AMD datasheets, Phoronix), Instinct MI300A/MI300X/MI325X/MI350X/MI400 (AMD blogs, Tweaktown, Tom's Hardware, AMD IR), RX 9070 XT (AMD product page, Oreate AI), Versal AI Edge Gen 2 + Alveo V80/V70 (AMD blog), ROCm 7 (AMD blog, AMD docs, Tom's Hardware).

Caveats:
- Apple does not publish TOPS for A19/M5 family. All TOPS figures for those chips are secondary-source.
- "Snapdragon 8 Elite Gen 5 = ~100 TOPS" is secondary; Qualcomm's press release says "37% faster NPU" without a number.
- Cloud-signature Phase 2 calibration has not been run; all signatures (existing 7 + proposed 11) are inference-grade until that completes.
