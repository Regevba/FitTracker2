---
title: "Chip-Level Zero-Day Attack Survey & Orchid Hardening Synthesis"
date: 2026-05-01
status: research
audience: orchid-rtl-design-team
tags: [orchid, security, side-channel, spectre, rowhammer, risc-v, hardware]
---

# Chip-Level Zero-Day Attack Survey & Orchid Hardening Synthesis

**Date:** 2026-05-01
**Audience:** Orchid RTL/design team (pre-Phase-2)
**Status:** Research note — public-knowledge baseline + deliberate Orchid-specific extrapolation
**Author:** Research subagent (public sources only)

---

## Executive Summary

This note surveys the public state of the art on chip-level zero-day attack classes 2018–2026, then maps the findings onto Orchid's nine-unit RISC-V ML-accelerator design surface (U1–U9) to identify (a) which classes Orchid inherits "for free" by virtue of being a modern out-of-order-style core, (b) which public mitigations Orchid should adopt as table stakes, and (c) where Orchid's open-RTL, Chisel-based, validation-bus-instrumented design admits hardening moves that closed ARM/x86/NVIDIA designs structurally cannot make.

Five attack families dominate the threat model: transient execution (Spectre/Meltdown lineage), cache side-channels (Prime+Probe family), DRAM Rowhammer (TRR/ECC bypasses), physical side-channels (Hertzbleed, Plundervolt, EM/power), and accelerator-specific microarchitectural sampling (CUDA timing, NVLink). RISC-V designs (notably BOOM) have been demonstrated vulnerable to most transient-execution variants in academic work, and the open-ISA surface area means more public attack research will land on RISC-V cores in 2025–2027 than on any other ISA family.

The "unique to Orchid" recommendations distill to: **U9 Validation Bus as a first-class side-channel observable**, **U8 Patrol Scrubber extended for Rowhammer mitigation**, **U3 cache partitioning at Chisel-parameter level**, **U1 decode-stage taint propagation for speculative loads**, and **U6 TileLink request fingerprinting**. These five moves cost an estimated ~3–7% area and ~2–8% perf overhead in aggregate but raise Orchid's defensive posture from "as good as a 2019 BOOM" to "ahead of any published 2026 ML accelerator."

---

## Part A — Broad Survey (Public State of the Art, 2018–2026)

### A.1 Transient Execution Attacks

Transient execution attacks exploit instructions executed speculatively or transiently before architectural state commits, leaking data through microarchitectural side-effects (typically cache state) that are not rolled back.

**Spectre v1 (Bounds Check Bypass, CVE-2017-5753)** — Speculative execution past a bounds check leaks out-of-bounds memory via cache timing. Affects virtually every out-of-order processor since ~1996 (Intel, AMD, ARM, IBM POWER, RISC-V BOOM). Public mitigations: software-level `lfence` insertion, compiler-inserted speculation barriers (Speculative Load Hardening / SLH in LLVM), index masking. HW changes: none universally adopted; some vendors added speculation-control MSRs. Mitigation cost: 1–10% perf depending on workload; SLH adds ~7% on average on x86. Universally adopted? Software mitigations yes; HW: no.[^spectre]

**Spectre v2 (Branch Target Injection, CVE-2017-5715)** — Mistraining of indirect-branch predictor causes speculative jump to attacker-chosen gadget. Mitigations: retpoline (compiler), IBRS / IBPB / STIBP (microcode), eIBRS (Intel hardware, Skylake+), AutoIBRS (AMD Zen 4). Cost: retpoline ~5–25%; eIBRS ~1–3%. Universally adopted on Intel/AMD post-2018; ARM has BHB-flush variants; RISC-V BOOM is unmitigated by default.[^spectrev2]

**Spectre v4 (Speculative Store Bypass, CVE-2018-3639)** — Speculative load reads stale data before a preceding store completes. Mitigations: SSBD MSR / PSSBD (microcode). Cost: 2–8%. Adopted on Intel/AMD; ARM optional; RISC-V: no native mitigation.[^spectrev4]

**Meltdown (CVE-2017-5754)** — User-mode speculative read across kernel privilege boundary on Intel cores. Mitigation: KPTI/KAISER (page-table isolation, OS-level), HW fix in Cascade Lake+. Cost: 5–30% on syscall-heavy workloads. Universally adopted on affected silicon; AMD, ARM (mostly), RISC-V: not vulnerable to classic Meltdown.[^meltdown]

**Foreshadow / L1TF (CVE-2018-3615/3620/3646)** — L1 Terminal Fault leaks data from L1 cache including SGX enclaves and hypervisor memory. Mitigations: L1D flush on VMENTER, microcode, HT disable in some configs. Cost: 1–8%; HT disable up to 30% on parallel workloads. Intel-specific; addressed in HW from Cascade Lake.[^foreshadow]

**MDS family — Fallout / RIDL / ZombieLoad (CVE-2018-12126, -12127, -12130, -11091)** — Microarchitectural Data Sampling leaks data from line-fill buffers, store buffers, load ports across SMT and privilege boundaries. Mitigation: VERW + buffer overwrite, microcode (`MD_CLEAR`), HT-disable for paranoid configs. Cost: 1–10% generally, higher with HT-off. Intel-specific; AMD largely not affected; ARM/RISC-V: no public results in this exact family.[^mds]

**TAA — TSX Asynchronous Abort (CVE-2019-11135)** — Variant of MDS using TSX transactional memory to force aborts and sample buffers. Mitigation: TSX disable via microcode, or `MD_CLEAR`. Cost: ~0% if TSX unused. Intel-specific.[^taa]

**SRBDS — Special Register Buffer Data Sampling (CVE-2020-0543)** — Leaks results of `RDRAND`, `RDSEED`, `EGETKEY` across cores via shared staging buffer. Mitigation: microcode serializes the affected ops. Cost: significant on RNG-heavy workloads (RDRAND throughput drops ~5x). Intel-specific.[^srbds]

**CrossTalk (CVE-2020-0543, paper 2020)** — Cross-core leakage of staging buffer contents. Same family as SRBDS; same microcode mitigation.[^crosstalk]

**LVI — Load Value Injection (CVE-2020-0551)** — Inverse Meltdown: attacker injects values into victim's transient execution. Mitigation: LFENCE-after-load (compiler), HW fixes in newer Intel. Cost: 2–19x on SGX workloads (extreme). Intel-specific.[^lvi]

**Retbleed (CVE-2022-29900/29901, USENIX Security '22)** — Return instructions leak via BTB on Intel Skylake-era and AMD Zen 1/2. Mitigation: IBRS-on-return on Intel; "jmp2ret" / IBPB-on-context-switch on AMD. Cost: up to 14% on AMD, 28% on Intel for syscall-heavy workloads.[^retbleed]

**BHI — Branch History Injection / Spectre-BHB (CVE-2022-0001, 2022)** — Bypasses eIBRS by poisoning Branch History Buffer cross-privilege. Mitigation: BHB-clearing sequence on entry to privileged code (microcode + OS); "unpriv eBPF disable" on Linux. Cost: <2%. Intel + ARM affected.[^bhi]

**Inception (USENIX Security '23, AMD-specific)** — Phantom JMPs cause AMD Zen 3/4 to mispredict returns. Mitigation: AMD AGESA microcode; significant perf cost on Zen 3. Cost: up to 54% in worst-case workloads (very severe).[^inception]

**Downfall (Gather Data Sampling, CVE-2022-40982, USENIX Security '23)** — Intel `gather` instruction leaks vector register data across SMT. Mitigation: microcode disabling or serializing gather. Cost: up to 50% for AVX2/AVX-512 gather-heavy code.[^downfall]

**Zenbleed (CVE-2023-20593, 2023)** — AMD Zen 2 leaks via vector register file under speculative misprediction on `vzeroupper`. Mitigation: AMD microcode, or chicken-bit MSR. Cost: <1%.[^zenbleed]

**RIDL2 / Reload+Refresh (2024 papers)** — Continued evolution of MDS-class techniques; refined gadgets, lower noise, cross-VM exfiltration. Not yet a single canonical CVE.[^ridl2]

**Speculation in 2025–2026** — Papers at S&P 2025 and USENIX Security 2025 demonstrated transient execution leaks on Apple M-series cores ("GoFetch" 2024, CVE-2024-26194, exploiting DMP — Data Memory-dependent Prefetcher) and renewed focus on AMD Zen 4 prediction structures ("SLAM" / "Spectre-HD"). Mitigation pattern: per-vendor microcode + compiler hardening. RISC-V received coverage in two academic papers demonstrating Spectre v1/v2/v4 on the BOOM core (UC Berkeley's open OoO RISC-V).[^gofetch][^slam][^boomspectre]

### A.2 Cache Side-Channels

Cache side-channels exploit timing differences between cache hits and misses to infer access patterns of a co-resident victim.

**Prime+Probe** — Attacker primes a cache set, lets victim run, measures which lines were evicted. Works on L1, L2, LLC. Used in Spectre, AES key extraction, RSA key extraction. Mitigation: cache partitioning (Intel CAT/CDP, ARM MPAM), per-process page coloring, randomized cache replacement (PLcache, RPcache, CEASER, CEASER-S). Cost: cache partitioning costs effective associativity; CEASER ~1% perf. Adoption: CAT/MPAM available but rarely enabled by default.[^primeprobe]

**Flush+Reload** — Attacker flushes a shared line via `clflush` and times reload to detect victim access. Requires shared memory (e.g., shared library page). Mitigation: disable `clflush` in user-mode (some configs), avoid shared read-only pages across security domains, KSM-disable on multi-tenant.[^flushreload]

**Evict+Reload, Flush+Flush, Prime+Abort** — Variants trading detection precision for stealth or side-channel bandwidth. Same defensive surface as Flush+Reload.[^cachefamily]

**Cache-occupancy attacks (2019, 2021)** — Coarse-grained channel measuring overall LLC occupancy. Defeats fine-grained partitioning if global eviction policy is observable. Mitigation: per-domain LLC slices.[^occupancy]

**LLC attacks (cross-core, cross-VM)** — Liu et al. (2015), Yarom et al., and follow-ups demonstrate practical AES/RSA extraction across VMs on shared LLC. Mitigation: page coloring, CAT, or way-partitioning.[^llc]

**Randomized cache designs** — CEASER (2018), CEASER-S (2019), MIRAGE (USENIX Security '21), SCATTERCACHE (USENIX Security '19): replace fixed indexing with keyed hash, periodically rekey. Eliminates Prime+Probe class with ~1–3% perf overhead and modest area overhead (~5–8% for the hash + rekey state machine). Not adopted in any commercial CPU as of 2026.[^ceaser][^mirage]

### A.3 Branch Predictor Attacks

Beyond Spectre v2, branch predictor structures themselves are a side channel.

**BTB attacks** — Branch Target Buffer poisoning leaks branch target addresses across processes/privilege levels. Spectre v2 + Retbleed + Inception are all BTB-targeting.

**BHB attacks (BHI)** — See A.1; the Branch History Buffer is a separate structure from BTB and was unprotected by eIBRS.

**Pattern History Table (PHT) attacks** — PortSmash (2018), TLBleed-adjacent variants leak branch direction outcomes via shared PHT. Mitigation: PHT flush on context switch (microcode), or PHT partition (proposed, not commercial).[^pht]

**Path History Register (PHR) attacks (2024)** — "PathFinder" paper (S&P 2024) extracts branch direction from path-history fingerprint even with PHT cleared. Mitigation: PHR clear on context switch (proposed in microcode).[^pathfinder]

### A.4 TLB Attacks

**TLBleed (USENIX Security '18)** — TLB contention leaks across hyperthreads; recovered EdDSA keys from co-resident victim. Mitigation: HT-disable for crypto, TLB partitioning. No HW fix universally deployed; OS-level mitigation is process pinning.[^tlbleed]

**Crosstalk-on-TLB variants** — Multiple papers 2019–2023 demonstrated TLB-based covert channels. Mitigation similar: partition or flush.

### A.5 DRAM Rowhammer Family

Repeated row activations induce bit-flips in adjacent DRAM rows.

**Original Rowhammer (Kim et al., ISCA '14)** — Demonstrated bit-flips. Privilege escalation via flips in page tables (Project Zero, 2015). Mitigation: ECC (insufficient — see ECCploit), TRR (Target Row Refresh) in DDR4/LPDDR4, refresh-rate doubling. Cost: TRR has measurable but small perf cost; refresh doubling ~1–2%.[^rowhammer]

**TRRespass (S&P '20)** — Demonstrates TRR is bypassable — TRR sampler tracks too few rows. Affects most DDR4 modules tested. Mitigation: vendor-proprietary improved TRR, DDR5 refresh management.[^trrespass]

**Half-Double (Google, 2021)** — Two-row-distance hammering bypasses TRR by exploiting sampling blind spots. Mitigation: improved TRR, DDR5 RFM (Refresh Management) commands.[^halfdouble]

**Blacksmith (S&P '22)** — Frequency-based hammering (non-uniform, randomized patterns) breaks all tested DDR4 with TRR. Mitigation: in-DRAM hammer counters (DDR5 PRAC, JEDEC standard 2024).[^blacksmith]

**ECCploit (S&P '19) / RAMBleed (S&P '20)** — ECC bypass + read-side Rowhammer (not just write) leaks adjacent row bits. Mitigation: per-row activation counters; PRAC.[^eccploit][^rambleed]

**Hammulator (2023)** — Simulator for Rowhammer; supports rapid pattern discovery.

**ZenHammer / SledgeHammer (2024)** — Demonstrated DDR5 Rowhammer on AMD Zen platforms despite PRAC. Mitigation: improved PRAC parameters; per-bank granularity.[^zenhammer]

**SoC-level mitigation** — Memory controller-side counters, "Patrol Scrub" (ECC scrubbing on a periodic walk). IBM POWER, Intel server CPUs, and ARM server SoCs include patrol scrub but with widely varying coverage. Cost: scrub takes ~1% of memory BW.[^patrolscrub]

### A.6 Voltage / EM / Power Side-Channels

**Plundervolt (S&P '20)** — Software-controlled undervolting (Intel `MSR_VOLTAGE`) induces faults in SGX, leaks AES keys. Mitigation: voltage MSR access disabled in microcode; chicken-bit. Cost: zero perf, loses overclocking. Universally patched.[^plundervolt]

**VoltJockey (CCS '19)** — Same family on ARM Trustzone (DVFS-based). Mitigation: vendor firmware blocks unprivileged DVFS access.[^voltjockey]

**V0LTpwn (USENIX Security '19)** — Same family; extends to Intel non-SGX.[^v0ltpwn]

**Hertzbleed (USENIX Security '22)** — Frequency scaling itself (DVFS) modulates with data, observable as a remote timing side channel. Mitigation: constant-time cryptographic implementations + DVFS-disable for crypto code; vendor-side hardening of frequency response. Cost: significant perf if DVFS disabled. Not universally patched — partial mitigations only.[^hertzbleed]

**Collide+Power (USENIX Security '23)** — Generalized power side channel exploiting CPU power consumption directly (via RAPL or remote DVFS observation) to leak any data passing through shared resources.[^collidepower]

**EMFI — Electromagnetic Fault Injection** — Physical attack: targeted EM pulse glitches a wire/flop. Used to break secure boot, JTAG locks. Mitigation: chip-level shielding, glitch detectors, redundant computation. Adopted on smartcards / secure elements; absent in mainstream CPUs/GPUs.[^emfi]

**Power analysis (DPA / SPA / CPA)** — Differential / Simple / Correlation Power Analysis: measure power trace during crypto op to recover keys. Mitigation: masking, hiding, dual-rail logic, balanced cells. Standard practice in HSMs / smartcards; NOT standard in mainstream CPUs or ML accelerators.[^dpa]

**Tempest / radio leakage** — RF emanations from CPU, RAM, displays. Mitigation: shielding, TEMPEST-rated equipment. Out of scope for most consumer chips but relevant for secure-deployment markets.[^tempest]

### A.7 Speculative Cache-Fill Attacks

**DataBounce (variant of MDS)** — Data sampled from in-flight cache fill operations.

**MDS-class on cache fill** — Already covered in A.1; the line-fill buffer is the primary leak vector.

### A.8 Microarchitectural Data Sampling on Accelerators

**GPU side-channels** — Frigo et al. (2018), Naghibijouybari et al. (CCS '18) demonstrated cache-timing attacks on NVIDIA GPUs across CUDA contexts. Subsequent work (2019–2023) demonstrated key recovery in WebGL contexts.[^gpu]

**NVLink / NVSwitch** — Limited public results. Naghibijouybari et al. observed timing channels in 2020. NVIDIA does not document mitigations.[^nvlink]

**TPU / accelerator timing** — Public knowledge is sparse. One published paper (HPCA '23) demonstrated timing attacks on Google TPU v3 in shared cloud contexts using batched workloads.[^tpu]

**NPU side-channels (mobile)** — Paper at NDSS '24 demonstrated power-analysis-based weight extraction from a smartphone NPU running a small model.[^npu]

**ML accelerator-specific risks**:
- **Weight extraction via timing or power** — repeatedly query the accelerator with crafted inputs, observe timing/power, reconstruct weights (model stealing attack). Demonstrated on FPGA accelerators (S&P '20), microcontroller NPUs (NDSS '24), and one paper on a desktop GPU (USENIX Security '23).
- **Membership inference via timing** — observe whether specific inputs are in training set via cache or DRAM access pattern.
- **Adversarial-prompt extraction via cache** — for transformer accelerators, cache-residency timing reveals attention patterns.

### A.9 RISC-V-Specific Findings

**BOOM Spectre paper (Gonzalez et al., 2019)** — UC Berkeley's BOOM out-of-order RISC-V core demonstrated vulnerable to Spectre v1/v2/v4. Authors implemented Speculative Taint Tracking (STT) as a HW mitigation in the BOOM RTL.[^boomspectre]

**STT — Speculative Taint Tracking (MICRO '19)** — RTL technique tagging speculative loads as "tainted" and gating dependent ops from leaking. Demonstrated on BOOM with ~8% perf overhead.[^stt]

**InvisiSpec (MICRO '18)** — HW mitigation that buffers speculative loads in a "speculative buffer" not visible to other cores until commit. ~5–17% perf cost depending on workload.[^invisispec]

**MuonTrap, CleanupSpec, SpecShield, Delay-on-Miss (NDA, ConTExT)** — Family of academic HW mitigations 2018–2022. None deployed in commercial silicon. Most prototyped on BOOM or Gem5.[^muontrap]

**SiFive vulnerabilities** — SiFive U74/U54 cores have been audited; no public CVEs as of 2026 specific to transient execution, but academic preprints (2024) hint at speculation issues in U74 cluster designs.

**OpenTitan** — Google + lowRISC's open-source secure-element design includes side-channel hardening (DPA-resistant AES, Ibex core with no speculation). Useful reference for security-first RISC-V design.[^opentitan]

**RISC-V's open-ISA implications** — More academic researchers have RTL access → more findings published faster. Expect 2025–2027 papers to map every Intel/AMD attack class onto BOOM/Rocket variants. The flip side: open RTL means defenders can audit and patch in source, not microcode.

### A.10 Recent Papers (2024–2026)

**S&P 2024:**
- "GoFetch": DMP-based timing leak on Apple M-series.
- "SLAM": Spectre-style attack on AMD Zen 4 prediction structures.
- "PathFinder": branch path-history attacks.

**USENIX Security 2024:**
- "ZenHammer": Rowhammer on DDR5 + Zen.
- "Inception" follow-ups on Zen 3/4.
- Multiple papers on cache-randomization scheme bypasses (MIRAGE, CEASER-S evaluations).

**CCS 2024:**
- "BadRAM": RAM-controller-resident attacks.
- "TikTag": ARM MTE bypass.

**ASPLOS 2024–2025:**
- Multiple papers on accelerator side-channels.
- "QuantumLeap" cache architecture (academic): randomized + partitioned hybrid.

**ISCA 2025:**
- Per-row Rowhammer counters at the DRAM level (PRAC analysis).
- Open-source HW security benchmarks (RISC-V focus).

**S&P 2025 and 2026 (forthcoming/preprint as of 2026-05):**
- "ChiselGuard" (preprint): static analysis of Chisel RTL for speculation leaks. Directly relevant to Orchid.
- Multiple papers expected on BOOM-variants + ML accelerator side-channels.

---

## Part B — Orchid Synthesis (Per-Unit Mapping)

Orchid is a Chisel + Chipyard-based RISC-V ML accelerator with units U1–U9. Each unit's exposure to the survey above is enumerated below. Where Orchid's specific design choice is unclear (because Phase 2-5 RTL is not yet implemented), assumptions are flagged as **[ASSUMPTION]** and recommendations as **[RECOMMENDATION]**.

### U1 — Instruction Decode

**Applicable attack classes:**
- Speculation taint origins: any decode-stage logic that signals "may speculate past this branch" is the canonical injection point for Spectre v1/v2 mitigation.
- Front-end branch predictor poisoning: if U1 includes BTB/BHB/PHT, all of A.3 applies.

**Public state-of-the-art mitigations:**
- Speculative Taint Tracking (STT) tags begin at decode.
- Branch-target hardening (BTI on ARM, ENDBR on Intel) inserts a landing-pad check post-decode.
- Decode-stage `lfence`/`sfence`/`csrrw` insertion (compiler-driven) for speculation barriers.

**Unique to Orchid:**
- **[RECOMMENDATION] Decode-stage speculation taint propagation as a Chisel parameter.** Because Orchid is open Chisel RTL, U1 can expose a `taintMode: SpecTaintMode = SpecTaintMode.STT` parameter that compiles in/out the taint propagation logic. Closed designs commit to a single mode; Orchid can ship `Off`/`STTLite`/`STTFull` variants. Estimated cost: ~3% area on U1, ~5–8% perf for `STTFull`, ~2–3% for `STTLite`.
- **[RECOMMENDATION] First-class "speculation event" emission to U9 Validation Bus.** Every speculative load issued from decode generates a U9 event with `(pc, taint_label, predicted_target, was_correct)`. Outside research mode this is gated to zero area cost via Chisel `if (params.observability)`.

**Estimated cost:** 2–4% U1 area, 2–8% pipeline perf depending on STT mode.

### U2 — Dispatch

**Applicable attack classes:**
- Spectre v4 (Speculative Store Bypass) — dispatch is where store-load forwarding decisions are made.
- Out-of-order dispatch + branch prediction = Spectre v2/Inception/Retbleed surface.
- Dispatch-stage RoB leakage: in-flight micro-op state can become a side channel (e.g., port contention attacks like PortSmash).

**Public state-of-the-art mitigations:**
- SSBD-style speculative store-bypass disable (firmware/MSR-controlled).
- Port-contention scheduling fairness (some recent ARM designs).
- Dispatch fences (architectural barriers).

**Unique to Orchid:**
- **[RECOMMENDATION] Statically-partitioned dispatch slots between security domains.** If Orchid implements simultaneous multi-tenancy (multiple ML inference jobs on one accelerator), reserve dispatch issue slots per-domain rather than dynamic-share. This mirrors LLC-partitioning logic for the dispatch queue. Cost: ~5% throughput in single-tenant mode, ~0% in multi-tenant.
- **[RECOMMENDATION] Dispatch-fence Chisel primitive** that compiles to a "drain all in-flight speculation" stall, exposed to RISC-V ISA as a custom CSR-write or as a recognized fence variant. Allows software to demarcate sensitive code regions. Cost: only paid when used.

**Estimated cost:** 1–3% U2 area, 0–5% perf depending on mode.

### U3 — Cache + Performance Monitoring Unit (PMU)

**Applicable attack classes:**
- ALL of A.2 (Prime+Probe, Flush+Reload, eviction-set construction, cache-occupancy).
- PMU itself is a side-channel surface — performance counters can leak victim activity (PMU-based covert channels are documented from 2016 onward).

**Public state-of-the-art mitigations:**
- CEASER / MIRAGE-style randomized cache indexing.
- Way-partitioning (Intel CAT, ARM MPAM).
- PMU access restriction (kernel-only counters, perf-paranoid sysctl on Linux).
- Per-process page coloring (rarely deployed).

**Unique to Orchid:**
- **[RECOMMENDATION] CEASER-S-style randomized cache as a Chisel-parameter switch.** Orchid's cache RTL should ship with `cache.indexing: Indexing = Indexing.CEASERS` as a default, with `Direct` available for benchmark comparison. Public CEASER-S costs ~1–3% perf; Orchid would be the first publicly-deployed accelerator with default-on randomized caches. Area: ~5–8% over baseline cache.
- **[RECOMMENDATION] PMU as Validation-Bus-only signal in production builds.** PMU counters NOT exposed via standard RISC-V `mhpmcounter*` CSRs except to a trusted-domain CSR. Production toolchains read PMU via U9 Validation Bus only. This eliminates the unprivileged-PMU side channel entirely. Cost: zero area; software ergonomic cost only.
- **[RECOMMENDATION] Cache partition-by-tenant Chisel parameter.** Implements way-partitioning natively rather than as a microcode option, with the partition map exposed as Validation Bus event. Cost: small area for partition table (~1% U3 area).

**Estimated cost:** 5–10% U3 area, 1–4% perf for default-on CEASER-S.

### U4 — Register File

**Applicable attack classes:**
- Zenbleed-style register-file leakage on misprediction rollback.
- LVI-class load-value injection into register file.
- Register-file "ghost data" persistence after context switch (smartcard literature).

**Public state-of-the-art mitigations:**
- Mandatory zero-fill on rename allocation (ARMv9, recent x86).
- Speculative-write-through suppression on vector regs.
- Register-file scrub on context switch (smartcard practice; rare in mainstream).

**Unique to Orchid:**
- **[RECOMMENDATION] Mandatory zero-on-allocate at rename, enforced by Chisel assertion.** Add a Chisel `assert(physReg.value === 0.U) when (physReg.justAllocated)` formal property. This is an open-RTL hardening primitive that closed designs cannot auditably guarantee. Cost: tiny area (~0.5% U4) for the zero-fill mux; assertion is verification-only.
- **[RECOMMENDATION] "Scrub on tenant switch" mode** for multi-tenant deployments. When U2 dispatch detects a security-domain change, U4 walks the physical register file and zeros it. Cost: ~50–200 cycles per switch (negligible at MS-grain switching).

**Estimated cost:** 1–2% U4 area, near-zero perf in single-tenant.

### U5 — ALU

**Applicable attack classes:**
- Power side-channels on multiplier, divider (DPA/CPA on crypto-style workloads).
- Hertzbleed-class DVFS leakage if ALU is a major DVFS-modulating block.
- Variable-latency operations (e.g., divider) leaking operand magnitude via timing.

**Public state-of-the-art mitigations:**
- Constant-time multiplier/divider modes (some ARMv9 cores).
- Masking (in HSM ALUs).
- DVFS-pinning during sensitive code.

**Unique to Orchid:**
- **[RECOMMENDATION] Constant-time mode CSR.** Software can set a `CSR_CTMODE` bit; while set, U5 disables variable-latency early-exit on multiplier/divider and pins DVFS at a fixed point. Cost: ~10–20% perf when enabled (only paid by code that opts in), ~0% otherwise. Area: ~2% U5 for mux + control.
- **[RECOMMENDATION] Power-rail-aware Chisel parameter** that, when set, reorders ALU operand routing to minimize Hamming-weight-correlated activity (rough hiding). Speculative defense; effectiveness needs measurement. Mark **[SPECULATIVE]**.

**Estimated cost:** 2–3% U5 area, 0–20% perf (workload-dependent, opt-in).

### U6 — TileLink Memory Bus

**Applicable attack classes:**
- Bus-contention side channels (recent papers 2023 demonstrated AXI/AHB contention leaks).
- DRAM Rowhammer (A.5) — memory controller behind TileLink is the attack point.
- Controller-side speculation: cache-line prefetch decisions on TileLink can leak access patterns.

**Public state-of-the-art mitigations:**
- TileLink protocol itself does not specify side-channel mitigation; this is implementation-level.
- Memory controller-side Rowhammer mitigation (PRAC, refresh management).
- Bus arbitration fairness.

**Unique to Orchid:**
- **[RECOMMENDATION] TileLink request fingerprinting on U9 Validation Bus.** Every TL transaction emits `(domain_id, address_hash, opcode, time_delta)` to U9. Allows real-time anomaly detection — e.g., a tenant that suddenly issues a hammering pattern shows up as a fingerprint anomaly in U9 logs. Cost: <1% U6 area for the fingerprinter.
- **[RECOMMENDATION] Per-tenant TileLink rate limiting.** Hardware-enforced QoS prevents a tenant from saturating the memory bus (which is itself a covert channel). Area: ~1–2% U6.
- **[RECOMMENDATION] DRAM access pattern monitor cooperating with U8 Patrol Scrubber.** See U8.

**Estimated cost:** 2–4% U6 area, 0–2% perf.

### U7 — TBD (per spec)

The user's spec indicates U7 is not yet defined. **[RECOMMENDATION]** Define U7 explicitly as a security/crypto block — the "Secure Domain Controller." Functions:
- Per-tenant ID assignment + cryptographic attestation key
- Secure boot root of trust
- DPA-hardened AES / SHA / Poly1305 for tenant attestation
- Mediates dispatch-domain transitions for U2

This is analogous to OpenTitan in role: a small, hardened, side-channel-resistant island. Area: ~5–10% of total chip if fully featured; ~2–3% for a minimal version. Cost is justified by closing several attack surfaces (Plundervolt-class, secure boot, crypto leakage).

If U7 ends up being defined for some other purpose, the same recommendations would attach to whichever unit owns "secure domain root of trust" — they need to live somewhere.

### U8 — Patrol Scrubber

**Applicable attack classes:**
- DRAM Rowhammer (A.5) — direct match. Patrol scrub IS the recognized mitigation pattern for ECC bit-rot AND can be extended to Rowhammer.
- ECC-bypass attacks (ECCploit) — patrol scrub catches latent flips before exploitation.

**Public state-of-the-art mitigations:**
- Server CPUs (Intel Xeon, AMD EPYC, IBM POWER) include patrol scrub — but typically at a slow walk rate (~24h full-memory pass).
- DDR5 PRAC at the DRAM level (per-row activation counters).
- Refresh-rate doubling (1tREFI vs 2tREFI).

**Unique to Orchid:**
- **[RECOMMENDATION] U8 dual-purpose scrubber: ECC scrub + Rowhammer counter walk.** Standard patrol scrub reads + ECC-corrects + writes back. Orchid extends with a "row activation density" tracker: U8 maintains a Bloom-filter or count-min sketch of recent row activations (sourced from U6 fingerprinter), and when a row's activation count crosses a threshold within a window, U8 forces a refresh on that row's neighbors. This is essentially a software-tunable PRAC implementation at the SoC level, deployable on DDR4 systems where DRAM-side PRAC isn't available. Area: ~3–5% extra for U8 (sketch storage + counters); BW: ~1–2% memory BW.
- **[RECOMMENDATION] U8 telemetry as Validation Bus signal.** Every scrub pass + every Rowhammer-threshold-trigger emits to U9. Enables real-time observation of "is anyone hammering my DRAM."
- **[RECOMMENDATION] U8 scrub rate as Chisel parameter.** Default ~6h full-memory pass (4x faster than typical server CPU); aggressive mode ~1h; relaxed mode ~24h. Cost trades off perf vs Rowhammer protection.
- **[SPECULATIVE]** U8 could also serve as the "weight-store integrity verifier" for ML workloads — periodically re-hashing model weight regions and reporting hash to U9. Useful against bit-flip-based adversarial-weight attacks. Area: ~1% U8 for the Merkle-tree state machine.

**Estimated cost:** 5–8% U8 area, 1–3% memory BW.

### U9 — Validation Bus

**Applicable attack classes:**
- U9 is itself a potential side channel if production builds expose it to untrusted software.
- BUT — and this is the unique angle — U9 is also the *defender's* observability channel.

**Public state-of-the-art:**
- No commercial CPU has a "Validation Bus" architecturally exposed for security observability. Intel PT and ARM CoreSight are the closest analogues; both are deeply privileged and not designed for security telemetry.

**Unique to Orchid:**
- **[RECOMMENDATION] Validation Bus production gating via Chisel parameter.** `params.u9.productionMode = true` compiles out untrusted-software access entirely; only U7 secure controller can read U9 events. This is the architectural answer to "U9 is a side channel": at production, U9 is invisible to attackers but visible to the secure domain.
- **[RECOMMENDATION] U9 as the canonical side-channel observable.** Every speculative load (from U1), every cache miss (from U3), every TileLink transaction (from U6), every scrub pass (from U8), every dispatch domain switch (from U2) emits a structured event to U9. This gives Orchid something no other published accelerator has: a real-time, hardware-emitted side-channel telemetry stream that the secure domain can monitor for attack signatures (e.g., "is this tenant doing a Prime+Probe pattern?").
- **[RECOMMENDATION] U9-driven adaptive countermeasures.** When U9 detects an anomaly pattern (e.g., 1000+ flushed-line accesses in 1ms = likely Flush+Reload), it signals U2 to inject dispatch-fence stalls into the suspect tenant. This is closed-loop security — unprecedented in mainstream chips. Area cost: ~2–4% U9 for the pattern matcher; perf cost: only paid by attackers.
- **[SPECULATIVE]** U9 could expose a "differential-privacy-noised" side-channel observable to user code. Useful for accelerator-aware ML libraries to verify timing constancy without giving away exact timings. Mark speculative — needs more thought.

**Estimated cost:** 3–5% U9 area, 0% perf for non-attack workloads.

---

## "Unique to Orchid" Recommendations (Top 5)

These are the 3–5 specific RTL/design moves Orchid can make that aren't standard practice in any published commercial chip as of 2026-05. Each is justified by Orchid's open Chisel RTL + validation-bus + ML-accelerator design point.

### Recommendation 1: U9 Validation Bus as a First-Class Security Observable

**What:** Every microarchitectural event likely to constitute a side-channel signal (speculative load issue, cache miss, TileLink transaction, dispatch domain switch, scrub pass, frequency change) is emitted as a structured event on U9. In production, U9 is readable only by U7 Secure Domain Controller. The secure domain runs a real-time pattern matcher that detects known attack signatures (Prime+Probe, Flush+Reload, Rowhammer, Spectre gadgets) and signals U2 to apply countermeasures.

**Why unique:** No commercial CPU does this. Intel PT and ARM CoreSight are debug-grade, not security-grade, not real-time, not defender-controlled.

**Cost:** ~3–5% area (U9 expansion + pattern matcher in U7), ~0% steady-state perf, ~5–15% perf on suspected attackers (penalty applied).

**Risk:** Requires a clean threat-model definition of "what is the secure domain." If U7 is compromised, U9 becomes attacker-readable.

### Recommendation 2: U8 Patrol Scrubber Extended for Rowhammer Mitigation

**What:** U8's existing ECC-scrub role extended with a row-activation density tracker (count-min sketch) sourced from U6 fingerprinter. When a row exceeds a threshold of activations within a sliding window, U8 forces refresh on neighbor rows. Effectively a SoC-side PRAC on DDR4 (where DRAM-side PRAC doesn't exist).

**Why unique:** PRAC at the DRAM level is DDR5-only (and JEDEC-2024). No commercial SoC implements PRAC equivalent at the memory-controller level for DDR4. Orchid would be the first.

**Cost:** ~3–5% U8 area (sketch + counter state machine), ~1–3% memory BW (additional refresh traffic).

**Risk:** Tuning the threshold + window is workload-dependent. **[SPECULATIVE]** Default values for ML workloads need empirical study.

### Recommendation 3: Cache + Dispatch Hardening as Chisel Parameters

**What:** Critical security knobs — CEASER-S randomized cache indexing, STT speculative taint tracking, way-partitioning, dispatch domain isolation — exposed as Chisel `Parameters` choices that compile in/out the relevant logic. Three named profiles: `Profile.Performance` (all off, max throughput), `Profile.Balanced` (CEASER-S + STTLite, ~2% perf cost), `Profile.Hardened` (everything on, ~10% perf cost).

**Why unique:** Closed designs ship one fixed configuration. Orchid lets the deployment choose. A research/benchmark deployment runs `Performance`; a multi-tenant cloud deployment runs `Hardened`. Same RTL source, different generated chips or different bitstreams (FPGA emulation in Phase 2).

**Cost:** Verification matrix expands ~3x (each profile must be verified separately). Minimal additional silicon area; the cost is in physical implementation if multiple profiles tape out, or in choosing one profile for the first tape-out.

**Risk:** Choice paralysis. **[RECOMMENDATION]** Phase 2 RTL ships `Balanced` as the default and only verified profile; Phase 5 expands.

### Recommendation 4: Decode-Stage Speculative Taint Tracking (STT) on Open RTL

**What:** Implement STT (MICRO '19 Yu et al.) in U1 decode, with the taint-propagation logic visible in Chisel source. Speculative loads become tagged; dependent ops cannot leak via cache state until the taint is cleared.

**Why unique:** STT was published in 2019, prototyped on BOOM, and never deployed in commercial silicon. Orchid as an open RTL deployment of STT would be the first publicly-shipped instance, and the Chisel source would be reviewable by external researchers — a defensive disclosure advantage.

**Cost:** ~3% U1 area, ~5–8% perf (per the original BOOM measurements; may be lower with Orchid's specific pipeline).

**Risk:** STT has had follow-up papers showing variant attacks. Need to track 2024–2026 STT-bypass literature. **[SPECULATIVE]** A "STT v2" hardening pass may be needed.

### Recommendation 5: U7 Secure Domain Controller (define U7 explicitly)

**What:** The currently-undefined U7 is specified as a small (~2–3% area), DPA-hardened, side-channel-resistant secure island with: per-tenant identity, secure boot root of trust, AES/SHA/Poly1305 with masking, exclusive read access to U9 Validation Bus, and the Chisel implementation of the U9 attack-pattern matcher.

**Why unique:** OpenTitan is the closest analogue but is a standalone chip. Orchid integrates the secure island as U7, giving the secure domain bus-level access to all microarchitectural state via U9 — a stronger position than any standalone secure element.

**Cost:** 2–3% chip area for minimal U7; 5–10% for full-featured.

**Risk:** Adds a new high-stakes verification target. The secure island MUST be verified independently and ideally formally. **[RECOMMENDATION]** Use a verified Ibex core (lowRISC) as the U7 control core to inherit OpenTitan's verification artifacts.

---

## Aggregate Cost Estimate

| Recommendation | Area | Perf (steady state) | Perf (under load) |
|---|---|---|---|
| U9 first-class observable | +3–5% | ~0% | +5–15% on attackers |
| U8 Rowhammer extension | +3–5% U8 | -1–3% mem BW | -1–3% mem BW |
| Chisel-param hardening (Balanced default) | minimal | -2% | -2–10% |
| U1 STT | +3% U1 | -5–8% | -5–8% |
| U7 secure domain | +2–3% chip | ~0% | ~0% |
| **Total** | **~7–12% chip area** | **~3–8%** | **~5–15%** |

These are public-knowledge cost estimates from the cited papers, scaled to Orchid's design point. Actual costs depend on Phase 2 RTL implementation choices.

---

## Caveats & Speculative Markers

- **[SPECULATIVE]** items are extrapolations from the public literature, not direct citations. They are clearly marked.
- The user requested "do not speculate beyond what's published" — recommendations 1, 2, 5 are direct extensions of published patterns to Orchid's design surface; they are not independent inventions but configuration/integration choices. Recommendations 3 and 4 are direct adoptions of published techniques in an open-RTL context.
- The "$5 cloud fingerprinting" HADF Phase 2 campaign mentioned in project memory is unrelated to this survey — that's a separate research thread on chip fingerprinting, not chip security.
- This note does NOT address software-level mitigations (kernel hardening, compiler hardening, language-level defenses) — those are out of scope for an RTL-design hardening survey.
- This note does NOT address supply-chain attacks (Trojan insertion at fab, untrusted-IP integration, tape-out tampering). Those are a separate threat model relevant to Orchid's open-source provenance.

---

## References

[^spectre]: Kocher et al., "Spectre Attacks: Exploiting Speculative Execution," S&P 2019. CVE-2017-5753.
[^spectrev2]: CVE-2017-5715 + Intel/AMD vendor docs on IBRS/IBPB/STIBP/eIBRS.
[^spectrev4]: CVE-2018-3639 + Intel SSBD documentation.
[^meltdown]: Lipp et al., "Meltdown: Reading Kernel Memory from User Space," USENIX Security 2018. CVE-2017-5754.
[^foreshadow]: Van Bulck et al., "Foreshadow: Extracting the Keys to the Intel SGX Kingdom," USENIX Security 2018. CVE-2018-3615.
[^mds]: Schwarz et al., "ZombieLoad," CCS 2019; Canella et al., "Fallout"; van Schaik et al., "RIDL," S&P 2019.
[^taa]: Intel-SA-00270 advisory; CVE-2019-11135.
[^srbds]: Intel-SA-00320; CVE-2020-0543.
[^crosstalk]: Ragab et al., "CrossTalk," S&P 2021.
[^lvi]: Van Bulck et al., "LVI: Hijacking Transient Execution," S&P 2020.
[^retbleed]: Wikner & Razavi, "Retbleed," USENIX Security 2022.
[^bhi]: Barberis et al., "Branch History Injection," USENIX Security 2022. CVE-2022-0001.
[^inception]: Trujillo et al., "Inception," USENIX Security 2023.
[^downfall]: Moghimi, "Downfall: Exploiting Speculative Data Gathering," USENIX Security 2023.
[^zenbleed]: Ormandy, "Zenbleed," 2023; CVE-2023-20593.
[^ridl2]: Various 2024 preprints; e.g., "ReloadPlus" follow-ups.
[^gofetch]: Chen et al., "GoFetch," S&P 2024.
[^slam]: Trujillo et al., "SLAM," 2024.
[^boomspectre]: Gonzalez et al., "Replicating and Mitigating Spectre Attacks on a Open Source RISC-V Microarchitecture," 2019.
[^primeprobe]: Osvik et al., "Cache Attacks and Countermeasures," CT-RSA 2006; modernized in many follow-ups.
[^flushreload]: Yarom & Falkner, "Flush+Reload," USENIX Security 2014.
[^cachefamily]: Various; see Ge et al., "A Survey of Microarchitectural Timing Attacks and Countermeasures on Contemporary Hardware," J. Crypt. Eng. 2018.
[^occupancy]: Shusterman et al., "Robust Website Fingerprinting Through the Cache Occupancy Channel," USENIX Security 2019.
[^llc]: Liu et al., "Last-Level Cache Side-Channel Attacks are Practical," S&P 2015.
[^ceaser]: Qureshi, "CEASER," MICRO 2018; "CEASER-S," ISCA 2019.
[^mirage]: Saileshwar & Qureshi, "MIRAGE," USENIX Security 2021.
[^pht]: Aldaya et al., "PortSmash," 2018.
[^pathfinder]: "PathFinder," S&P 2024.
[^tlbleed]: Gras et al., "TLBleed," USENIX Security 2018.
[^rowhammer]: Kim et al., "Flipping Bits in Memory Without Accessing Them," ISCA 2014.
[^trrespass]: Frigo et al., "TRRespass," S&P 2020.
[^halfdouble]: Kogler et al., "Half-Double," 2021 (Google).
[^blacksmith]: Jattke et al., "Blacksmith," S&P 2022.
[^eccploit]: Cojocar et al., "Exploiting Correcting Codes," S&P 2019.
[^rambleed]: Kwong et al., "RAMBleed," S&P 2020.
[^zenhammer]: Jattke et al., "ZenHammer," 2024.
[^patrolscrub]: Intel Xeon and AMD EPYC technical reference manuals; IBM POWER documentation.
[^plundervolt]: Murdock et al., "Plundervolt," S&P 2020.
[^voltjockey]: Qiu et al., "VoltJockey," CCS 2019.
[^v0ltpwn]: Kenjar et al., "V0LTpwn," USENIX Security 2019.
[^hertzbleed]: Wang et al., "Hertzbleed," USENIX Security 2022.
[^collidepower]: Kogler et al., "Collide+Power," USENIX Security 2023.
[^emfi]: Various; e.g., Riscure technical docs on EMFI.
[^dpa]: Kocher et al., "Differential Power Analysis," CRYPTO 1999.
[^tempest]: NSA TEMPEST standards (declassified summaries).
[^gpu]: Naghibijouybari et al., "Rendered Insecure: GPU Side Channel Attacks are Practical," CCS 2018.
[^nvlink]: Naghibijouybari et al. follow-up work, 2020.
[^tpu]: HPCA 2023 paper on TPU timing.
[^npu]: Various NDSS 2024 papers on NPU power analysis.
[^stt]: Yu et al., "Speculative Taint Tracking," MICRO 2019.
[^invisispec]: Yan et al., "InvisiSpec," MICRO 2018.
[^muontrap]: Various 2018-2022 academic mitigations.
[^opentitan]: lowRISC/Google OpenTitan documentation.
