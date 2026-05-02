---
title: "Modular Chip Architecture Survey: Patterns for Orchid v1.5 → v2.0 Bridge"
date: 2026-05-01
status: research
audience: orchid-architects
tags: [orchid, hardware, risc-v, chiplets, tilelink, modularity, versioning]
---

# Modular Chip Architecture Survey: Patterns for Orchid v1.5 → v2.0 Bridge

## Executive Summary

Modular chip design has converged on three reusable patterns over 2020–2026: (1) **physical disaggregation** via chiplets and standardized die-to-die interconnects (UCIe, BoW, NVLink-C2C), which trades a 2–6% area/latency penalty for dramatic yield and IP-reuse wins; (2) **interface contracts** at the protocol layer (TileLink, AXI/ACE, CXL.cache, RoCC), which decouple unit implementation from system composition; and (3) **explicit hardware versioning** with semver-flavored conventions (OpenTitan, lowRISC's Comportability spec, RISC-V's frozen/ratified ISA tiers), which separate the *interface ABI* from the *micro-architecture*. For Orchid, the v1.5 → v2.0 bridge depends on locking three things now — the U1–U9 RoCC-style boundary, the TileLink tier-tag encoding, and the PMU/assertion-mode CSR map — while leaving four things explicitly extensible: TileLink user bits, CSR address space, opcode space for new units, and a discovery/capability register. Three concrete v1.5 changes (versioned CSR header, reserved opcode/CSR ranges, capability-discovery register) buy v2.0 freedom at <1% area cost.

---

## 1. Chiplets and Die-to-Die Interconnects

The chiplet era began industrially with AMD's Zen 2 (2019) splitting the CPU into compute dies (CCDs) plus an I/O die over Infinity Fabric, and accelerated through Intel's Sapphire Rapids (4 tiles via EMIB), Ponte Vecchio (47 tiles via EMIB + Foveros), and Apple's M1 Ultra (UltraFusion silicon interposer, 2.5TB/s die-to-die)[^1][^2][^3]. The Universal Chiplet Interconnect Express (UCIe) 1.0 published 2022 and 2.0 in 2024 standardized the physical, link, and protocol layers — letting a CXL-over-UCIe chiplet from vendor A talk to a PCIe-over-UCIe chiplet from vendor B[^4].

**Architectural tradeoffs observed:**

| Dimension | Monolithic | Chiplet |
|---|---|---|
| Yield (large die) | Drops exponentially with area | Dies binned independently |
| NRE cost | Single mask set | Mask set per chiplet, but reusable |
| Die-to-die latency | ~1–3 ns on-die | 5–10 ns via UCIe-A, 10–20 ns via UCIe-S |
| Bandwidth | TB/s on-die | 1–2 TB/mm of beachfront with UCIe-A |
| PPA penalty | Baseline | 2–6% area, 5–15% energy/bit overhead[^4] |
| Supply chain | Single foundry, single node | Mix nodes (5nm compute + 7nm I/O) |

The pattern that matters for Orchid: **chiplet boundaries align with verification boundaries**. AMD ships Zen CCDs that have not changed their die-to-die protocol since Zen 2 (2019) despite five micro-architecture generations. The interface is the contract; the implementation is fluid.

**Implication for Orchid:** even as a single-die design through v2.0, treat the U1–U9 unit boundaries *as if* they were chiplet boundaries. Document the protocol at each crossing (TileLink + tier bits + sideband). When v3.0 (hypothetical) wants to spin out the cache subsystem as a chiplet, the work is mostly already done.

---

## 2. System-in-Package (SiP) and Unified Memory

Apple M1/M2/M3/M4/M5 packages integrate CPU + GPU + Neural Engine + LPDDR5X all in one substrate with unified memory addressing[^5]. NVIDIA's Grace Hopper (GH200) couples a 72-core Arm Neoverse CPU with an H100 GPU over NVLink-C2C at 900 GB/s, presenting a coherent memory view to both[^6]. AMD's MI300A puts 24 Zen 4 cores + CDNA3 GPU + 128 GB HBM3 on a single package with Infinity Fabric coherence[^7].

**Architectural implications for dispatch:**

- **Memory hierarchy collapses.** When CPU and accelerator share LPDDR5X (Apple) or HBM (MI300A), the dispatch layer no longer plans around `cudaMemcpy` boundaries. Orchid's U3 (cache) and U4 (memory bus) need a story for "what happens when the host CPU and Orchid see the same DRAM."
- **Cache coherence becomes mandatory, not optional.** Grace Hopper uses NVLink-C2C with a coherence domain; MI300A uses Infinity Fabric coherence. Apple's solution is custom but observable as system-level coherence to user code.
- **Dispatch decisions become NUMA-aware even on a single package.** Apple's NE has access to all unified memory but with different latency than the CPU's L2-adjacent regions.

**Implication for Orchid:** v1.5 should not assume Orchid lives on its own dedicated SRAM/DRAM. The TileLink master/slave roles at U4 should accept a *coherent* upstream (a CCX-style cache that snoops Orchid's traffic) without an RTL change. This is the difference between TileLink-UL (uncached, one-shot) and TileLink-C (full coherence). Locking U4 at TileLink-UH (uncached + bursts + atomics) in v1.5 is a defensible middle position — it's what Rocket Chip uses by default, and TL-C can be added at the master side without changing slave behavior[^8].

---

## 3. RISC-V Composability and the RoCC Pattern

SiFive's Rocket Custom Coprocessor (RoCC) interface, baked into the Rocket core in 2014 and inherited by BOOM, is the canonical "plug an accelerator into a RISC-V core" interface[^9]. RoCC defines:

- 4 custom opcodes (`custom-0` through `custom-3`) reserved by the RISC-V ISA
- A 32-bit instruction encoding with `funct7`, two source register specifiers, a destination register specifier, and `xd`/`xs1`/`xs2` bits for valid-data signaling
- A request/response handshake between core and accelerator
- An optional memory port to L1 D-cache (TileLink-aware)
- An interrupt line and a busy signal

**Why RoCC is the right abstraction for Orchid's U1–U9 boundary:**

1. **Forward compatibility.** Custom opcodes 0–3 are *guaranteed* by the RISC-V ISA spec to never be reused. Orchid can occupy `custom-0` for "Orchid v1.5 ops" and reserve `custom-1` for v2.0 expansion.
2. **Implementation hiding.** The core doesn't care whether the accelerator is a 100-gate FSM or a 100K-gate matrix engine. It only sees the handshake.
3. **Multiple accelerators.** Rocket allows up to 4 RoCC accelerators per core via the 4 custom opcodes.

**Chipyard's modular composition** takes this further. Chipyard is a Berkeley-led SoC framework that uses Chisel + Diplomacy to compose configurations[^10]. A single config like `RocketWithGemminiConfig` chains: a Rocket tile + a Gemmini matrix accelerator + a TileLink crossbar + an L2 + memory controllers. Swapping in BOOM is a one-line config change. This is what "modular RTL" looks like in practice.

**OpenSoCFabric** (Stanford, ~2014) and **Constellation** (Berkeley, 2022) extend Chipyard's approach to NoCs[^11]. Constellation in particular is what Orchid's U4/U9 should look at: a parameterizable NoC generator with configurable topology, virtual channels, and tier propagation.

**BOOM core configurability:** BOOM (Berkeley Out-of-Order Machine) ships in Small/Medium/Large/Mega configs differing in issue width (1/2/3/4), ROB size, and FU mix — all from the same RTL via Chisel parameters[^12]. The lesson: parameterize aggressively, freeze the *interface* not the *parameters*.

**Implication for Orchid:** define the U1↔core boundary as RoCC-compatible (or RoCC-extended). Each Orchid unit U2–U9 should be reachable either via custom-opcode dispatch (for instruction-style units) or via memory-mapped CSRs (for state-style units). v2.0 units (U10+) plug into the same RoCC slot or take a reserved CSR range.

---

## 4. TileLink, AXI, NVLink-C2C, CXL — Future-Proof Bus Design

TileLink (UCB, used by Chipyard) is an open, cache-coherent protocol with three flavors: TL-UL (uncached lite), TL-UH (uncached + bursts + atomics), TL-C (cached + MESI/MOESI variants)[^8]. AXI (Arm AMBA family) is the industry incumbent; AXI4 + ACE adds coherence; AXI5 + ACE5 (2021) added 64-byte atomic ops and persistent memory hints[^13]. CXL (Compute Express Link) layered on PCIe physical adds three protocols: CXL.io (PCIe-equiv), CXL.cache (device caching host memory), CXL.mem (host caching device memory). CXL 3.0 (2022) adds switching and peer-to-peer[^14]. NVLink-C2C is NVIDIA's proprietary die-to-die at 900 GB/s with cache-line granular coherence[^6]. AMD's Infinity Fabric is similar in role[^15].

**What makes a bus protocol future-proof:**

| Property | TileLink | AXI4 | AXI5/ACE5 | CXL 3.0 |
|---|---|---|---|---|
| Open spec | Yes (UCB) | Yes (Arm, free) | Yes (Arm, free) | Yes (consortium) |
| Coherence variants | UL/UH/C tiers | Base + ACE | Base + ACE5 | .cache + .mem |
| User/sideband bits | `user` field, opaque | `AxUSER` configurable | `AxUSER` configurable | TLP prefix |
| Versioning | TL 1.7, 1.8, 2.0 | AXI3/4/5 | AXI5 | CXL 1.1/2.0/3.0 |
| Atomics | TL-UH+ | AXI5 atomics | AXI5 atomics | CXL.mem |

**The user-bits pattern is the single most important future-proofing mechanism.** TileLink's `user` field, AXI's `AxUSER`/`xUSER` signals, and CXL's TLP prefix all let designers carry sideband metadata (security tags, ECC, *tier bits*) without changing the base protocol. AMD has used AXI USER bits for cache-partition tags since Zen 1[^15]. Arm's MTE (Memory Tagging Extension) propagates 4-bit tags through AXI USER bits[^16].

**Implication for Orchid:** the 2-bit tier propagation across TileLink should occupy *defined positions in the TileLink user field*, with the encoding documented in the v1.5 spec. v2.0 may extend to 3-bit or 4-bit tiers; reserving bits `user[1:0]` for v1.5 and `user[3:2]` as "must-be-zero in v1.5, reserved for v2.0" is the textbook move. Do not encode tier bits as a separate sideband bus — that's an interface change for v2.0.

---

## 5. Standardized Accelerator Unit Interfaces

Beyond RoCC, the industry has converged on a small set of accelerator-interface patterns:

- **AMBA AXI** for memory-mapped accelerators (most Arm SoCs, Xilinx FPGAs)
- **AXI-Stream** for dataflow accelerators (DMA-style, no addressing)
- **ACE-Lite** for I/O-coherent accelerators that can snoop CPU caches but not be snooped (typical GPU pattern)
- **OpenCAPI** (IBM POWER, 2017–2022, deprecated in favor of CXL)
- **CXL.cache** (the OpenCAPI successor, modern accelerators)
- **CCIX** (interim, deprecated 2022)
- **RoCC** (RISC-V research/Chipyard ecosystem)

**Multi-generation survivability:** Arm's AXI moved AXI3→AXI4 (2010)→AXI5 (2021). Each transition was *strict superset*: AXI3 masters can talk to AXI4 slaves with adapter shims; new features (atomics, persistent memory hints) live in newly-defined opcodes/bits[^13]. Compare to OpenCAPI, which made breaking changes between versions and was abandoned. The lesson: **superset evolution survives; incompatible revisions don't.**

**Implication for Orchid:** the U1–U9 internal interfaces should commit to superset evolution. v2.0 may add new TileLink message types or new CSR fields, but it must not redefine v1.5 ones. Pick one accelerator-interface pattern (RoCC for instruction-style, MMIO/CSR for state-style) and document the rule for v1.5: *new functionality lives in new opcodes or new CSR addresses, never in redefined ones*.

---

## 6. Open-Source Hardware Design Ecosystems

The major open ecosystems and their patterns:

- **Chipyard** (Berkeley) — Chisel-based SoC generator, the de facto reference for RISC-V research SoCs. Includes Rocket, BOOM, Gemmini, Hwacha, NVDLA wrappers. Configuration is declarative; everything composes via Diplomacy[^10].
- **OpenROAD** + **OpenLane** — Open-source RTL-to-GDS flows. OpenLane wraps OpenROAD for SkyWater 130nm and now GlobalFoundries 180nm. Useful for taping out v1.5 if Orchid wants a real silicon path[^17].
- **SiFive Freedom** — open SoC platforms (E300/E500/U500), now somewhat dated but historically the reference RISC-V Linux-class SoC[^18].
- **lowRISC** — Cambridge-based foundation hosting Ibex (small RV32 core), OpenTitan (RoT), and the Comportability framework for IP integration[^19].
- **OpenTitan** — Google + lowRISC, open silicon root of trust. Notable for **Comportability**: a strict spec for what every IP block must export (registers, interrupts, alerts, clocks, resets) so that integration is mechanical[^20].

**The Comportability pattern is gold for Orchid.** Every OpenTitan IP block ships with a `.hjson` register description, a generated reference manual, an interrupt list, a fatal/recoverable alert list, and clock/reset declarations. The top-level integration is *generated* from those manifests. Adding a new IP block doesn't require touching the top — you write your `.hjson` and the integration scaffolding generates itself.

**Implication for Orchid:** before Phase 2 RTL, define an `orchid_unit.hjson` schema. Each U1–U9 ships its own manifest. The top-level integration script generates the TileLink crossbar wiring, CSR address decoder, interrupt aggregation, and assertion-mode decoder. v2.0 adding U10 means writing one more `.hjson`, not modifying integration RTL. This is the difference between "we have 9 units" and "we have a 9-unit *product line*."

---

## 7. Hardware Versioning Patterns

How open-source RTL projects version their interfaces:

| Project | Versioning scheme | What "compat" means |
|---|---|---|
| RISC-V ISA | Frozen / Ratified / Draft tiers; extensions versioned (Zicsr 2.0, Zba 1.0, Zbb 1.0)[^21] | Ratified extensions immutable; new functionality = new extension |
| OpenTitan | Semver-style on IP blocks; design verification "lifecycle" stages: D0/D1/D2/D2S/D3 + V0/V1/V2/V2S/V3 + S0/S1/S2/S3[^20] | D2 and above: register interface frozen; D3: tape-out clean |
| lowRISC Ibex | Git tags + Comportability spec version | New revisions add features in reserved CSR space |
| BOOM | Major version bumps (v1/v2/v3); micro-arch revs don't change ISA | ISA preserved; performance and gate count change |
| Rocket Chip | Continuous; Chisel API has soft compat across releases | Breakage is documented in release notes |
| TileLink | TL 1.7 → 1.8 → 2.0 (in progress); strict superset evolution | New messages added; old messages preserved |
| CXL | 1.0/1.1/2.0/3.0/3.1; backward compat required by spec[^14] | Newer host/device must support older link training |

**The semver-for-hardware consensus that has emerged:**

- **MAJOR** = breaking interface change (rare; equivalent to "you need a new compiler")
- **MINOR** = additive interface change (new opcode, new CSR, new TileLink message)
- **PATCH** = micro-arch / implementation change with no interface effect

OpenTitan separates this further into **D-stage** (design completeness) and **V-stage** (verification completeness), which is useful for managing pre-tape-out RTL where the interface is stable but the implementation isn't done yet.

**Implication for Orchid:** adopt a 3-tuple version: `<interface_major>.<interface_minor>.<impl_rev>`. v1.5 means "interface major=1, interface minor=5"; an `impl_rev` bumps when you fix a bug without changing the spec. The CSR space exposes this as a read-only register so software can detect what it's running on.

---

## 8. Hardware/Software Co-Design Across Generations

How accelerator stacks evolve when hardware changes:

- **Apple Neural Engine** — Core ML provides a stable software API across A11 (1st-gen NE) through M5 (latest). The hardware has changed dramatically (8-core → 16-core → 32-core, FP16 → INT8 → mixed precision), but Core ML programs from 2017 still run. The trick: **Apple owns the compiler.** Core ML programs are compiled to a bytecode at install time, and Apple's runtime targets whichever NE generation is on the device[^22].
- **NVIDIA CUDA** — PTX (Parallel Thread eXecution) is the stable IR; SASS (per-architecture machine code) is regenerated by the JIT for each new SM (Streaming Multiprocessor) generation. CUDA programs from Fermi (2010) still run on Hopper (2022) because PTX is forward-compatible[^23]. Per-generation features (TensorCores, Hopper's TMA, FP8) are exposed as *opt-in PTX intrinsics* that older code simply doesn't use.
- **AMD ROCm** — HSA (Heterogeneous System Architecture) IR plays the PTX role. ROCm has had rougher generation transitions than CUDA — early versions broke when GFX9→GFX10 changed the wave size from 64 to 32. Lesson: do not let micro-architecture leak into the IR[^24].
- **Arm SVE** (Scalable Vector Extension) — vector-length agnostic ISA. Code written for SVE runs on any vector width (128 to 2048 bits) without recompilation. The hardware can grow vector width across generations without breaking software[^25].

**The pattern:** ship a stable IR (PTX, Core ML bytecode, SVE) above the micro-architecture. Per-generation features are *additive* — opt-in intrinsics or extension flags. Discovery happens via runtime queries (e.g. `cudaGetDeviceProperties`).

**Implication for Orchid:** the Orchid dispatch ABI (custom-opcode encoding + CSR layout + PMU register layout) is the equivalent of PTX or Core ML bytecode. Code compiled against Orchid v1.5 should run on Orchid v2.0 unchanged. v2.0 features are accessed via *new opcodes that v1.5 software doesn't emit*. A capability-discovery CSR (read-only, returns a feature bitmap) lets compilers and runtimes query what's available — exactly like `cpuid` or `mcountinhibit`.

---

## Synthesis: Orchid v1.5 → v2.0 Bridge

### 9.1 Interface stability principles — what to lock in v1.5

The following must be **immutable** from v1.5 onward (any change is a v2.0 *major* bump):

1. **U1–U9 RoCC-style boundary.** Each unit's `custom-N` opcode allocation, CSR address range, and TileLink endpoint role are fixed. v2.0 may add U10, U11, etc. in *new* opcode/CSR ranges; it may not relocate existing units.
2. **TileLink tier-tag bit positions.** If v1.5 puts the 2-bit tier in `user[1:0]`, v2.0 keeps `user[1:0]` for backward-compatible tier bits and uses `user[3:2]` (or higher) for any extension. Never repack.
3. **PMU CSR layout.** The address and bit-field encoding of every v1.5 PMU counter — including `cache_hits` — is locked. v2.0 PMU counters live at new addresses; v2.0 must not reinterpret v1.5 bits.
4. **`assertion_mode` register encoding.** The bit positions for "off / log / fatal / sticky" (or whatever v1.5 picks) are immutable. New assertion modes use reserved bits.
5. **Validation bus protocol (U9).** Message framing, ack/nack semantics, and error codes are locked. New error codes are added in reserved code points.
6. **Capability/version CSR (proposed below).** Once defined, the CSR address and the meaning of bits 0..N-1 are immutable. Future bits N..M extend the bitmap without redefinition.

**Tradeoff stake:** locking these costs ~1–2 person-weeks of careful spec writing in v1.5 and a CSR/opcode allocation review session. It saves an unknown but probably much larger cost in v2.0 — if v2.0 has to break v1.5 software, the entire dispatch layer (Orchid's reason for existing) needs a parallel-stack story for some transition window. Worth it.

### 9.2 Extension hooks — where v2.0 must be free to grow

Reserve the following in v1.5, *unused but declared*:

1. **Custom opcode `custom-2` and `custom-3`** — leave for v2.0 unit families. v1.5 occupies `custom-0` (and possibly `custom-1` for tier-aware variants).
2. **CSR address range** — partition the Orchid CSR space into v1.5 (used) and v2.0+ (reserved, must read as zero). Document the boundary.
3. **TileLink `user` upper bits** — bits beyond what v1.5 uses are "must-be-zero on transmit, ignore on receive" until v2.0 defines them. This is exactly the AXI USER pattern.
4. **PMU counter address range** — v1.5 defines, say, 16 counters. Reserve at least 48 more addresses for v2.0 counters. PMU address space is cheap; running out is expensive.
5. **Assertion-mode reserved bits** — if v1.5 needs 2 bits per unit for mode, allocate 4 bits per unit in the CSR layout and document the upper 2 as reserved.
6. **Validation bus reserved error codes** — if v1.5 defines 8 error codes, allocate a 5-bit field (32 codes). Reserved codes are "v2.0+ only, v1.5 must report 'unknown'".
7. **Discovery/capability register (new in v1.5).** A read-only CSR exposing a feature bitmap. v1.5 sets bits for features present; v2.0 sets additional bits. Software queries this register to feature-detect.

**Tradeoff stake:** reserved address space and bit fields cost essentially nothing in area or power. They cost a small amount of spec discipline. Failing to reserve them costs a future ABI break.

### 9.3 Versioning strategy for Orchid

Adopt a **three-tier version** modeled on OpenTitan + RISC-V:

```
Orchid <interface_major>.<interface_minor>.<impl_rev>
        e.g. 1.5.0, 1.5.1 (bug fix), 1.6.0 (additive interface), 2.0.0 (breaking)
```

- **Interface major** bumps only on breaking change. v1.x → v2.x is a deliberate event with a migration plan.
- **Interface minor** bumps on additive change (new opcode, new CSR, new PMU counter, new validation error code). v1.5 → v1.6 is "v1.5 software still runs; v1.6 software requires v1.6+ hardware".
- **Impl rev** bumps on bug fixes or micro-arch changes that don't touch the spec. Software can ignore.

Expose this as a **`mvendorid`-adjacent CSR triple**:

| CSR | Width | Meaning |
|---|---|---|
| `orchid_iface_major` | 8 | Breaking-version |
| `orchid_iface_minor` | 8 | Additive-version |
| `orchid_impl_rev` | 16 | Implementation rev |
| `orchid_capabilities` | 64 | Feature bitmap (see §9.2) |

This matches the RISC-V style (`misa`, `mvendorid`, `marchid`, `mimpid`) and is what RISC-V software already expects to query[^21].

**Tradeoff stake:** four read-only CSRs. ~64 flip-flops total. Negligible area. The benefit is that compilers, runtimes, and dispatchers can feature-detect Orchid generations the same way they detect RISC-V extensions today — using a familiar pattern, not an Orchid-specific hack.

### 9.4 Three concrete v1.5 design changes for v2.0 bridgeability

**Change 1: Add a versioned CSR header to every Orchid unit's CSR block.**

The first 4 CSRs in each unit's CSR range expose `unit_id`, `iface_major`, `iface_minor`, `capabilities`. This is borrowed directly from OpenTitan Comportability[^20]. Software walks the units, queries each header, and builds a feature map. Adding U10 in v2.0 means software *automatically* discovers it without firmware changes.

**Cost:** 4 CSRs × 9 units = 36 read-only CSRs. ~1000 flip-flops total. Estimated <0.5% area overhead.

**Win:** v2.0 unit discovery is free. No firmware update needed for software to see new units.

---

**Change 2: Reserve opcode and CSR address ranges in the v1.5 spec, even though v1.5 doesn't use them.**

Specifically:
- `custom-0` opcodes: v1.5 uses bits `funct7[6:4]` = `000`–`011`. Reserve `100`–`111` for v2.0.
- `custom-1`, `custom-2`, `custom-3` opcodes: entirely reserved.
- Orchid CSR address space: v1.5 uses `0xBC0`–`0xBCF` (just an example). Reserve `0xBD0`–`0xBFF` for v2.0.
- TileLink `user` field: v1.5 uses `user[1:0]` for tier. Reserve `user[7:2]` (or whatever upstream bus width allows) as "must-be-zero".

**Cost:** zero gates. Pure spec discipline. ~1 day of allocation review.

**Win:** v2.0 has 4× the opcode space, 4× the CSR space, and 6× the user-bit space available without renegotiating with v1.5 software.

---

**Change 3: Add the `orchid_capabilities` discovery register to U1.**

A single 64-bit read-only CSR in U1 (the dispatch unit) exposing a bitmap of features. v1.5 defines bits 0–15 (e.g. bit 0 = U8 present, bit 1 = U9 present, bit 2 = tier propagation enabled, bit 3 = PMU `cache_hits` exposed, etc.). Bits 16–63 are reserved-zero in v1.5 and become v2.0 features.

The compiler, runtime, dispatcher, and even host CPU code can query this register to feature-detect. This is the Orchid equivalent of CUDA's `cudaGetDeviceProperties` or RISC-V's `misa`[^21][^23].

**Cost:** 1 CSR (64 read-only bits). ~64 flip-flops. <0.1% area.

**Win:** v1.5 software written against the discovery register will run on v2.0 without recompilation, taking advantage of v1.5 features and gracefully ignoring v2.0 ones. v2.0 software queries the register and lights up new code paths only when bits are set. This is the single cheapest mechanism for forward-compatible software.

---

### 9.5 What v1.5 should *not* try to solve

Out of scope for the v1.5 → v2.0 bridge, deferred to v2.0 design:

- **Cache coherence with an external host CPU.** Locking U4 at TL-UH is the right v1.5 call; TL-C is a v2.0 conversation tied to whether Orchid ever ships in an SiP.
- **Multi-Orchid scaling.** A NoC-of-Orchids is a v2.0+ topic. v1.5 single-instance is the verification target.
- **Chiplet-ization.** Treat unit boundaries as if they could be chiplet boundaries (per §1) but don't actually disaggregate.
- **A stable software ABI above the dispatch layer.** That's a runtime/compiler conversation, not an RTL one. v1.5 locks the hardware ABI; the software ABI evolves separately.

---

## References

[^1]: AMD Zen 2 architecture deep dive, AMD presentation at Hot Chips 31, 2019. Also Naffziger et al., "AMD Chiplet Architecture for High-Performance Server and Desktop Products," ISSCC 2020.
[^2]: Intel Sapphire Rapids architecture, Hot Chips 34 (2022); "Intel Architecture Day 2021" disclosures on EMIB and Foveros.
[^3]: Apple M1 Ultra UltraFusion, WWDC 2022 Mac Studio announcement; AnandTech analysis March 2022.
[^4]: UCIe 1.0 Specification (March 2022) and UCIe 2.0 Specification (August 2024), https://www.uciexpress.org/. Sharma et al., "Universal Chiplet Interconnect Express (UCIe): An Open Industry Standard for Innovations With Chiplets at Package Level," IEEE Micro 2022.
[^5]: Apple Silicon technical overview, Apple Platforms Security Guide and WWDC sessions on Apple Silicon GPU + Neural Engine architecture (2020–2025).
[^6]: NVIDIA Grace Hopper Superchip Architecture White Paper, NVIDIA 2023; "NVLink-C2C: A Coherent Chip-to-Chip Interconnect," Hot Chips 34 (2022).
[^7]: AMD Instinct MI300A architecture, AMD Advancing AI 2023 presentation; ISSCC 2024 paper on MI300 family.
[^8]: TileLink Specification v1.8.1, SiFive (2022). https://www.sifive.com/documentation/tilelink/. Also "TileLink: A Reusable Cache-Coherence Protocol," UCB Tech Report.
[^9]: Asanović et al., "The Rocket Chip Generator," EECS Department, UC Berkeley, Tech. Rep. UCB/EECS-2016-17, 2016. RoCC interface documented in Rocket Chip source: https://github.com/chipsalliance/rocket-chip.
[^10]: Amid et al., "Chipyard: Integrated Design, Simulation, and Implementation Framework for Custom SoCs," IEEE Micro 2020. https://chipyard.readthedocs.io.
[^11]: Jerger et al., "Constellation: An Open-Source SoC-Capable NoC Generator," IEEE Computer Architecture Letters 2022. OpenSoCFabric: Stanford, https://github.com/Stanford-CleanSlate/OpenSoCFabric.
[^12]: Zhao et al., "BOOM v3: An open-source out-of-order RISC-V superscalar core," Berkeley CARRV 2020.
[^13]: Arm AMBA AXI and ACE Protocol Specification, IHI 0022 issues E (AXI4) and H (AXI5/ACE5), Arm Ltd., 2021.
[^14]: Compute Express Link Specification, revisions 1.1 (2019), 2.0 (2020), 3.0 (2022), 3.1 (2023). https://www.computeexpresslink.org.
[^15]: AMD Infinity Architecture, AMD presentations at Hot Chips and ISSCC 2018–2024.
[^16]: Arm Memory Tagging Extension (MTE) whitepaper, Arm 2019. ARM-software documentation.
[^17]: OpenROAD Project, https://theopenroadproject.org. OpenLane: https://github.com/The-OpenROAD-Project/OpenLane. Ajayi et al., "OpenROAD: Toward a Self-Driving, Open-Source Digital Layout Implementation Tool Chain," GOMACTech 2019.
[^18]: SiFive Freedom Platform documentation, https://github.com/sifive/freedom (now in maintenance).
[^19]: lowRISC, https://lowrisc.org. Ibex core: https://github.com/lowRISC/ibex. Comportability framework: https://docs.opentitan.org/doc/contributing/hw/comportability/.
[^20]: OpenTitan documentation, https://opentitan.org/book/. "Hardware Development Stages" doc defines D0–D3 / V0–V3 / S0–S3 lifecycle.
[^21]: RISC-V Instruction Set Manual, Volume I: Unprivileged ISA, and Volume II: Privileged Architecture, RISC-V International, 2024 ratified. https://riscv.org/specifications/ratified/.
[^22]: Apple Core ML documentation, https://developer.apple.com/documentation/coreml. WWDC sessions 2017–2025 on Core ML evolution.
[^23]: NVIDIA CUDA Programming Guide, latest revision; "Parallel Thread Execution ISA" specification, NVIDIA. https://docs.nvidia.com/cuda/parallel-thread-execution/.
[^24]: AMD ROCm documentation, https://rocm.docs.amd.com. HSA Foundation HSAIL specification (historical).
[^25]: Arm Scalable Vector Extension (SVE) architecture reference, Arm 2017 (SVE) and 2021 (SVE2). Stephens et al., "The ARM Scalable Vector Extension," IEEE Micro 2017.
