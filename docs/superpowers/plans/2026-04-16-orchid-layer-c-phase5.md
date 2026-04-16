# Orchid Phase 5 — Layer C (Chipyard SoC Integration + FireSim) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the Orchid accelerator (U1-U6) into a Chipyard RISC-V SoC as a RoCC coprocessor alongside Gemmini (U7), validate with Verilator SoC simulation, optionally deploy to FireSim on AWS F1 for near-real-time emulation, and run the final composite score benchmark on real framework traces.

**Architecture:** The OrchidAccelerator from Phase 4 becomes a RoCC (Rocket Custom Coprocessor) that attaches to a Rocket core via the standard RoCC interface. A Gemmini systolic array attaches as a second RoCC accelerator. Both share the TileLink memory system. Software running on the Rocket core invokes Orchid via custom RISC-V instructions (custom0 opcode space). The entire SoC is simulated via Verilator (Phase 5a) and optionally compiled to an AWS F1 FPGA bitstream via FireSim (Phase 5b).

**Tech Stack:** Chisel 3, Chipyard 1.x, Rocket Chip, Gemmini, TileLink, Verilator, FireSim, RISC-V GCC toolchain, riscv-tests

**Prerequisite:** Phases 2-4 must be complete. Chipyard must be cloned and initialized. For FireSim (Phase 5b): AWS account with F1 access.

**Spec:** `docs/superpowers/specs/2026-04-16-orchid-ai-accelerator-design.md` (Sections 2, 3 Phase 5, 7 Level 3, 10)

**Hardware requirement:** M5 Max 128GB recommended (Chipyard elaboration spikes to 32-64GB). See `research_orchid_hardware_requirements.md`.

---

## File Map

| File | Responsibility |
|---|---|
| `orchid/layer-c/setup.sh` | Chipyard clone + init + Orchid generator registration |
| `orchid/layer-c/OrchidRoCC.scala` | RoCC wrapper: translates RoCC commands ↔ OrchidAccelerator IO |
| `orchid/layer-c/OrchidChipConfig.scala` | Chipyard config: Rocket + OrchidRoCC + Gemmini |
| `orchid/layer-c/OrchidChipConfigs.scala` | Config variants (small/medium/full) |
| `orchid/layer-c/tests/orchid_test.c` | Bare-metal C test: invoke Orchid via custom instructions |
| `orchid/layer-c/tests/trace_replay_test.c` | C program: replay .jsonl trace through Orchid hardware |
| `orchid/layer-c/firesim/config_runtime.yaml` | FireSim runtime config for Orchid SoC |
| `orchid/layer-c/firesim/config_build_recipes.yaml` | FireSim FPGA build recipe |
| `orchid/layer-c/README.md` | Layer C setup + usage instructions |

---

### Task 1: Chipyard Setup + Orchid Generator Registration

**Files:**
- Create: `orchid/layer-c/setup.sh`
- Create: `orchid/layer-c/README.md`

- [ ] **Step 1: Write setup script**

```bash
#!/usr/bin/env bash
# orchid/layer-c/setup.sh
# Sets up Chipyard with the Orchid accelerator generator.
# Run once. Takes ~30 minutes (toolchain download + build).
set -euo pipefail

ORCHID_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHIPYARD_DIR="${ORCHID_ROOT}/layer-c/chipyard"

echo "=== Orchid Layer C Setup ==="
echo "Orchid root: ${ORCHID_ROOT}"
echo "Chipyard dir: ${CHIPYARD_DIR}"

# 1. Clone Chipyard if not present
if [ ! -d "${CHIPYARD_DIR}" ]; then
    echo "Cloning Chipyard..."
    git clone https://github.com/ucb-bar/chipyard.git "${CHIPYARD_DIR}"
    cd "${CHIPYARD_DIR}"
    git checkout stable  # latest stable release
else
    echo "Chipyard already cloned."
    cd "${CHIPYARD_DIR}"
fi

# 2. Initialize Chipyard (downloads toolchain, builds Verilator, etc.)
if [ ! -f "${CHIPYARD_DIR}/.chipyard-setup-complete" ]; then
    echo "Initializing Chipyard (this takes ~20-30 min)..."
    ./build-setup.sh riscv-tools
    touch "${CHIPYARD_DIR}/.chipyard-setup-complete"
else
    echo "Chipyard already initialized."
fi

# 3. Symlink Orchid RTL into Chipyard generators
ORCHID_GEN="${CHIPYARD_DIR}/generators/orchid"
if [ ! -L "${ORCHID_GEN}" ]; then
    echo "Linking Orchid generator into Chipyard..."
    ln -sf "${ORCHID_ROOT}/layer-b" "${ORCHID_GEN}"
    echo "Linked: ${ORCHID_GEN} -> ${ORCHID_ROOT}/layer-b"
else
    echo "Orchid generator already linked."
fi

# 4. Register Orchid in Chipyard's build.sbt
CHIPYARD_BUILD="${CHIPYARD_DIR}/build.sbt"
if ! grep -q "orchid" "${CHIPYARD_BUILD}"; then
    echo "Registering Orchid in Chipyard build.sbt..."
    # Add orchid as a dependency of the chipyard project
    cat >> "${CHIPYARD_BUILD}" << 'SCALA'

// Orchid AI Orchestration Accelerator
lazy val orchid = (project in file("generators/orchid"))
  .dependsOn(rocketchip)
  .settings(commonSettings)
SCALA
    echo "Registered."
else
    echo "Orchid already registered in build.sbt."
fi

echo ""
echo "=== Setup complete ==="
echo "Next: cd ${CHIPYARD_DIR} && source env.sh"
echo "Then: make CONFIG=OrchidSmallConfig -C sims/verilator"
```

- [ ] **Step 2: Write README**

```markdown
# Orchid Layer C — Chipyard SoC Integration

## Prerequisites
- Phase 4 complete (all Chisel modules compiling)
- M5 Max 128GB recommended (Chipyard elaboration needs 32-64GB RAM)
- ~50GB disk space for Chipyard toolchain

## Setup
```bash
chmod +x setup.sh
./setup.sh    # ~30 min first time
cd chipyard && source env.sh
```

## Build + Simulate
```bash
# Small config (Rocket + Orchid only, no Gemmini)
make CONFIG=OrchidSmallConfig -C sims/verilator

# Full config (Rocket + Orchid + Gemmini)
make CONFIG=OrchidFullConfig -C sims/verilator

# Run bare-metal test
./sims/verilator/simulator-orchid-OrchidSmallConfig tests/orchid_test.riscv
```

## FireSim (optional, requires AWS F1)
```bash
cd chipyard/sims/firesim
firesim buildafi   # builds FPGA image (~6 hours)
firesim launchrunfarm && firesim infrasetup && firesim runworkload
```
```

- [ ] **Step 3: Commit**

```bash
git add orchid/layer-c/setup.sh orchid/layer-c/README.md
git commit -m "feat(orchid): Layer C setup script — Chipyard clone + Orchid generator registration"
```

---

### Task 2: RoCC Wrapper — Orchid as a Rocket Coprocessor

**Files:**
- Create: `orchid/layer-c/OrchidRoCC.scala`

- [ ] **Step 1: Implement the RoCC interface wrapper**

```scala
// orchid/layer-c/OrchidRoCC.scala
package orchid

import chisel3._
import chisel3.util._
import freechips.rocketchip.tile._
import freechips.rocketchip.config._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.rocket._

/** Orchid RoCC Accelerator.
  *
  * Wraps OrchidAccelerator as a Rocket Custom Coprocessor (RoCC).
  * Software invokes via custom RISC-V instructions:
  *
  *   custom0 rd, rs1, rs2, funct7
  *
  * Instruction encoding:
  *   funct7 = 0: SCORE  — rs1[1:0]=workType, rs1[5:2]=viewCount,
  *                         rs1[9:6]=newTypes, rs1[11:10]=scope,
  *                         rs1[12]=novelty, rs1[16:13]=phase
  *                         rd = {tier[1:0], score[6:0]}
  *   funct7 = 1: ROUTE  — rd = {budget[5:0], routeTier[1:0], skill0[3:0]}
  *   funct7 = 2: STATUS — rd = totalCycles
  *
  * The SCORE instruction packs the 13-bit task descriptor + 4-bit phase
  * into rs1 (17 bits total, fits in 64-bit register). The result packs
  * score + tier into rd. ROUTE returns the routing decision from the
  * most recent SCORE. STATUS returns the cycle counter.
  */
class OrchidRoCC(opcodes: OpcodeSet)(implicit p: Parameters)
    extends LazyRoCC(opcodes) {
  override lazy val module = new OrchidRoCCModuleImp(this)
}

class OrchidRoCCModuleImp(outer: OrchidRoCC)(implicit p: Parameters)
    extends LazyRoCCModuleImp(outer) {

  val cfg = OrchidConfig.default
  val accel = Module(new OrchidAccelerator(cfg))

  // Default: not busy, not interrupting
  io.busy := false.B
  io.interrupt := false.B

  // Response register
  val respValid = RegInit(false.B)
  val respData  = Reg(UInt(64.W))
  val respRd    = Reg(UInt(5.W))

  // Wire command to accelerator
  val cmd = io.cmd
  val doScore  = cmd.valid && cmd.bits.inst.funct === 0.U
  val doRoute  = cmd.valid && cmd.bits.inst.funct === 1.U
  val doStatus = cmd.valid && cmd.bits.inst.funct === 2.U

  cmd.ready := true.B  // always ready (combinational accelerator)

  // Decode rs1 for SCORE instruction
  val rs1 = cmd.bits.rs1
  accel.io.taskIn.valid             := doScore
  accel.io.taskIn.bits.workType     := rs1(1, 0)
  accel.io.taskIn.bits.viewCount    := rs1(5, 2)
  accel.io.taskIn.bits.newTypesCount := rs1(9, 6)
  accel.io.taskIn.bits.scopeTier    := rs1(11, 10)
  accel.io.taskIn.bits.noveltyFlag  := rs1(12).asBool
  accel.io.taskIn.bits.phase        := rs1(16, 13)

  // Encode response
  when(doScore) {
    respData  := Cat(0.U(55.W), accel.io.pipeOut.bits.tier, accel.io.pipeOut.bits.score)
    respValid := true.B
    respRd    := cmd.bits.inst.rd
  }.elsewhen(doRoute) {
    respData  := Cat(0.U(52.W),
      accel.io.pipeOut.bits.budget,
      accel.io.pipeOut.bits.routeTier,
      accel.io.pipeOut.bits.skill0)
    respValid := true.B
    respRd    := cmd.bits.inst.rd
  }.elsewhen(doStatus) {
    respData  := accel.io.bus.totalCycles
    respValid := true.B
    respRd    := cmd.bits.inst.rd
  }.otherwise {
    respValid := false.B
  }

  // RoCC response
  io.resp.valid     := respValid
  io.resp.bits.rd   := respRd
  io.resp.bits.data := respData

  // Memory interface: not used (Orchid is register-only, no memory ops)
  io.mem.req.valid := false.B
}
```

- [ ] **Step 2: Verify compilation within Chipyard**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-c/chipyard
source env.sh
sbt "project orchid" compile
```
Expected: `[success]`

- [ ] **Step 3: Commit**

```bash
git add orchid/layer-c/OrchidRoCC.scala
git commit -m "feat(orchid): RoCC wrapper — Orchid as Rocket coprocessor with custom instructions"
```

---

### Task 3: Chipyard SoC Configs

**Files:**
- Create: `orchid/layer-c/OrchidChipConfigs.scala`

- [ ] **Step 1: Write SoC configuration variants**

```scala
// orchid/layer-c/OrchidChipConfigs.scala
package orchid

import chisel3._
import freechips.rocketchip.config._
import freechips.rocketchip.subsystem._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.tile._
import freechips.rocketchip.rocket._

// === Orchid RoCC key for Config system ===

case object BuildOrchidRoCC extends Field[Boolean](false)

class WithOrchidAccelerator extends Config((site, here, up) => {
  case BuildRoCC => Seq(
    (p: Parameters) => {
      val orchid = LazyModule(new OrchidRoCC(OpcodeSet.custom0)(p))
      orchid
    }
  )
})

// === SoC Configurations ===

/** Small: Rocket + Orchid only. For quick iteration and unit testing. */
class OrchidSmallConfig extends Config(
  new WithOrchidAccelerator ++
  new freechips.rocketchip.system.DefaultConfig
)

/** Medium: Rocket + Orchid + larger L2 cache. For pipeline benchmarks. */
class OrchidMediumConfig extends Config(
  new WithOrchidAccelerator ++
  new WithNBanks(2) ++
  new WithNMemoryChannels(1) ++
  new freechips.rocketchip.system.DefaultConfig
)

/** Full: Rocket + Orchid + Gemmini. The complete Orchid SoC.
  * Requires Gemmini generator to be present in Chipyard.
  * Uncomment the Gemmini line when ready.
  */
class OrchidFullConfig extends Config(
  new WithOrchidAccelerator ++
  // new gemmini.DefaultGemminiConfig ++  // uncomment when Gemmini is configured
  new WithNBanks(4) ++
  new WithNMemoryChannels(2) ++
  new freechips.rocketchip.system.DefaultConfig
)
```

- [ ] **Step 2: Build the small config with Verilator**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-c/chipyard
source env.sh
make CONFIG=OrchidSmallConfig -C sims/verilator -j$(nproc)
```
Expected: Builds `simulator-orchid-OrchidSmallConfig` binary. Takes 30-90 min on first build.

- [ ] **Step 3: Commit**

```bash
git add orchid/layer-c/OrchidChipConfigs.scala
git commit -m "feat(orchid): Chipyard configs — Small/Medium/Full SoC variants"
```

---

### Task 4: Bare-Metal Test Program

**Files:**
- Create: `orchid/layer-c/tests/orchid_test.c`

- [ ] **Step 1: Write bare-metal C test**

```c
// orchid/layer-c/tests/orchid_test.c
// Bare-metal test: invoke Orchid accelerator via custom0 instructions.
// Compile with riscv64-unknown-elf-gcc from the Chipyard toolchain.

#include <stdio.h>
#include <stdint.h>

// Orchid custom instructions via inline assembly.
// custom0: opcode 0x0B (custom-0 in RISC-V spec)
//
// SCORE: funct7=0, rs1=packed task descriptor
//   rs1[1:0]   = work_type (0=CHORE,1=FIX,2=ENHANCEMENT,3=FEATURE)
//   rs1[5:2]   = view_count (0-15)
//   rs1[9:6]   = new_types_count (0-15)
//   rs1[11:10] = scope_tier (0-3)
//   rs1[12]    = novelty_flag
//   rs1[16:13] = phase (0-9)
//   Returns: rd = {tier[8:7], score[6:0]}
//
// ROUTE: funct7=1, returns last routing decision
// STATUS: funct7=2, returns cycle counter

static inline uint64_t orchid_score(uint64_t packed_task) {
    uint64_t result;
    asm volatile(
        ".insn r 0x0B, 0, 0, %0, %1, x0"
        : "=r"(result)
        : "r"(packed_task)
    );
    return result;
}

static inline uint64_t orchid_route(void) {
    uint64_t result;
    asm volatile(
        ".insn r 0x0B, 0, 1, %0, x0, x0"
        : "=r"(result)
    );
    return result;
}

static inline uint64_t orchid_status(void) {
    uint64_t result;
    asm volatile(
        ".insn r 0x0B, 0, 2, %0, x0, x0"
        : "=r"(result)
    );
    return result;
}

// Pack a task descriptor into rs1 format
static inline uint64_t pack_task(
    uint8_t work_type, uint8_t view_count, uint8_t new_types,
    uint8_t scope, uint8_t novelty, uint8_t phase
) {
    return (uint64_t)work_type
         | ((uint64_t)view_count << 2)
         | ((uint64_t)new_types << 6)
         | ((uint64_t)scope << 10)
         | ((uint64_t)novelty << 12)
         | ((uint64_t)phase << 13);
}

int main(void) {
    printf("=== Orchid Accelerator Test ===\n");

    // Test 1: CHORE task → should score low (HAIKU)
    uint64_t task1 = pack_task(0, 0, 0, 0, 0, 2);  // CHORE, tasks phase
    uint64_t result1 = orchid_score(task1);
    uint8_t score1 = result1 & 0x7F;
    uint8_t tier1 = (result1 >> 7) & 0x3;
    printf("Test 1 (CHORE): score=%d, tier=%d (expect: 10, HAIKU=0)\n", score1, tier1);
    if (score1 != 10 || tier1 != 0) { printf("FAIL\n"); return 1; }

    // Test 2: FEATURE with many views → should score high (OPUS)
    uint64_t task2 = pack_task(3, 6, 4, 2, 1, 4);  // FEATURE, impl phase
    uint64_t result2 = orchid_score(task2);
    uint8_t score2 = result2 & 0x7F;
    uint8_t tier2 = (result2 >> 7) & 0x3;
    printf("Test 2 (FEATURE): score=%d, tier=%d (expect: 81, OPUS=2)\n", score2, tier2);
    if (score2 != 81 || tier2 != 2) { printf("FAIL\n"); return 1; }

    // Test 3: Route for the last scored task
    uint64_t route = orchid_route();
    uint8_t skill0 = route & 0xF;
    uint8_t route_tier = (route >> 4) & 0x3;
    uint8_t budget = (route >> 6) & 0x3F;
    printf("Test 3 (ROUTE): skill0=%d, tier=%d, budget=%d (expect: dev=4, SONNET=1, 25)\n",
           skill0, route_tier, budget);
    if (skill0 != 4 || route_tier != 1 || budget != 25) { printf("FAIL\n"); return 1; }

    // Test 4: Status (cycle counter)
    uint64_t cycles = orchid_status();
    printf("Test 4 (STATUS): cycles=%lu (expect: >0)\n", cycles);
    if (cycles == 0) { printf("FAIL\n"); return 1; }

    printf("=== All tests PASSED ===\n");
    return 0;
}
```

- [ ] **Step 2: Compile with RISC-V toolchain**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-c/chipyard
source env.sh
riscv64-unknown-elf-gcc -O2 -static -o ../tests/orchid_test.riscv ../tests/orchid_test.c
```

- [ ] **Step 3: Run on Verilator simulator**

```bash
./sims/verilator/simulator-orchid-OrchidSmallConfig ../tests/orchid_test.riscv
```
Expected: `All tests PASSED`

- [ ] **Step 4: Commit**

```bash
git add orchid/layer-c/tests/
git commit -m "feat(orchid): bare-metal test — custom instruction SCORE/ROUTE/STATUS verified on SoC"
```

---

### Task 5: Trace Replay on SoC

**Files:**
- Create: `orchid/layer-c/tests/trace_replay_test.c`

- [ ] **Step 1: Write trace replay C program**

```c
// orchid/layer-c/tests/trace_replay_test.c
// Replays a hardcoded trace (from burst_haiku.jsonl) through Orchid hardware.
// Measures total cycles for the composite score benchmark.

#include <stdio.h>
#include <stdint.h>

// Same orchid_score/orchid_status functions as orchid_test.c
static inline uint64_t orchid_score(uint64_t packed_task) {
    uint64_t result;
    asm volatile(".insn r 0x0B, 0, 0, %0, %1, x0" : "=r"(result) : "r"(packed_task));
    return result;
}

static inline uint64_t orchid_status(void) {
    uint64_t result;
    asm volatile(".insn r 0x0B, 0, 2, %0, x0, x0" : "=r"(result));
    return result;
}

static inline uint64_t pack_task(
    uint8_t wt, uint8_t vc, uint8_t ntc, uint8_t scope, uint8_t nov, uint8_t phase
) {
    return (uint64_t)wt | ((uint64_t)vc<<2) | ((uint64_t)ntc<<6)
         | ((uint64_t)scope<<10) | ((uint64_t)nov<<12) | ((uint64_t)phase<<13);
}

// Hardcoded burst_haiku trace: 100 CHORE tasks on tasks phase
#define TRACE_LEN 100

int main(void) {
    printf("=== Orchid Trace Replay: burst_haiku (%d events) ===\n", TRACE_LEN);

    uint64_t start_cycles = orchid_status();

    for (int i = 0; i < TRACE_LEN; i++) {
        // CHORE, 0 views, 0 types, TEXT_ONLY, no novelty, tasks phase(2)
        uint64_t task = pack_task(0, 0, 0, 0, 0, 2);
        uint64_t result = orchid_score(task);

        // Verify score = 10 (CHORE base), tier = 0 (HAIKU)
        uint8_t score = result & 0x7F;
        uint8_t tier = (result >> 7) & 0x3;
        if (score != 10 || tier != 0) {
            printf("FAIL at event %d: score=%d, tier=%d\n", i, score, tier);
            return 1;
        }
    }

    uint64_t end_cycles = orchid_status();
    uint64_t total = end_cycles - start_cycles;

    printf("Events processed: %d\n", TRACE_LEN);
    printf("Hardware cycles:  %lu\n", total);
    printf("Cycles/event:     %lu\n", total / TRACE_LEN);
    printf("=== Trace replay PASSED ===\n");

    return 0;
}
```

- [ ] **Step 2: Compile and run**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-c/chipyard
source env.sh
riscv64-unknown-elf-gcc -O2 -static -o ../tests/trace_replay_test.riscv ../tests/trace_replay_test.c
./sims/verilator/simulator-orchid-OrchidSmallConfig ../tests/trace_replay_test.riscv
```
Expected: `Trace replay PASSED` with cycle count printed.

- [ ] **Step 3: Compare to Layer A baseline**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-a
/Volumes/DevSSD/FitTracker2/orchid/.venv/bin/python -c "
import json
with open('../results/layer_a/burst_haiku_results.json') as f:
    layer_a = json.load(f)
print(f'Layer A: {layer_a[\"total_cycles\"]} cycles for {layer_a[\"events_processed\"]} events')
print(f'Layer A cycles/event: {layer_a[\"total_cycles\"] / layer_a[\"events_processed\"]:.1f}')
print('Layer C cycles/event: <from trace_replay_test output above>')
print('Speedup: Layer A / Layer C = <compute>')
"
```

- [ ] **Step 4: Commit**

```bash
git add orchid/layer-c/tests/trace_replay_test.c
git commit -m "feat(orchid): trace replay on SoC — burst_haiku benchmark, cycles/event measured"
```

---

### Task 6: FireSim Configuration (Optional — AWS F1)

**Files:**
- Create: `orchid/layer-c/firesim/config_runtime.yaml`
- Create: `orchid/layer-c/firesim/config_build_recipes.yaml`

- [ ] **Step 1: Write FireSim configs**

```yaml
# orchid/layer-c/firesim/config_runtime.yaml
# FireSim runtime configuration for Orchid SoC.
# Runs the trace replay workload on AWS F1 FPGA at ~150 MHz.

run_farm:
  base_recipe: run-farm-recipes/aws_ec2.yaml
  recipe_arg_overrides:
    run_farm_tag: orchid-firesim
    run_instance_market: ondemand
    run_instance_type: f1.2xlarge    # 1 FPGA

target_config:
  topology: no_net_config
  no_net_num_nodes: 1
  default_hw_config: firesim_orchid_small

workload:
  workload_name: orchid-trace-replay.json
  terminate_on_completion: yes
  suffix_tag: null
```

```yaml
# orchid/layer-c/firesim/config_build_recipes.yaml
# FPGA build recipe for Orchid SoC.
# Synthesizes OrchidSmallConfig to AWS F1 bitstream.

builds_to_run:
  - firesim_orchid_small

build_recipes:
  firesim_orchid_small:
    DESIGN: FireSim
    TARGET_CONFIG: WithDefaultFireSimBridges_WithDefaultMemModel_OrchidSmallConfig
    PLATFORM_CONFIG: WithAutoILA_F1Config
    deploy_quintuplet: null
    post_build_hook: null
    metasim_customruntimeconfig: null
    bit_builder_recipe: bit-builder-recipes/f1.yaml
```

- [ ] **Step 2: Write workload JSON**

```json
{
  "benchmark_name": "orchid-trace-replay",
  "common_simulation_outputs": ["uartlog"],
  "workloads": [
    {
      "name": "orchid-trace-replay",
      "bootbinary": "../tests/trace_replay_test.riscv",
      "outputs": ["/root/orchid-output.txt"]
    }
  ]
}
```
Save to `orchid/layer-c/firesim/orchid-trace-replay.json`.

- [ ] **Step 3: Build FPGA image (long — ~6 hours)**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-c/chipyard/sims/firesim
# Copy configs
cp ../../firesim/config_runtime.yaml config_runtime.yaml
cp ../../firesim/config_build_recipes.yaml config_build_recipes.yaml

firesim buildafi
```
Expected: AGFI ID printed on completion.

- [ ] **Step 4: Run on FPGA**

```bash
firesim launchrunfarm
firesim infrasetup
firesim runworkload
firesim terminaterunfarm
```
Expected: `Trace replay PASSED` in uartlog, with cycle count at ~150 MHz clock speed.

- [ ] **Step 5: Commit**

```bash
git add orchid/layer-c/firesim/
git commit -m "feat(orchid): FireSim configs — AWS F1 FPGA deployment for Orchid SoC"
```

---

### Task 7: Final Composite Score + Phase 5 Verification

**Files:** None (verification only)

- [ ] **Step 1: Collect benchmark data from all three layers**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid
echo "=== Orchid Composite Score — All Layers ==="

# Layer A (Python behavioral)
.venv/bin/python -c "
import json
with open('results/layer_a/burst_haiku_results.json') as f:
    a = json.load(f)
print(f'Layer A: {a[\"events_processed\"]} events, {a[\"total_cycles\"]} cycles, composite={a[\"composite_score\"]:.2f}')
"

# Layer C (SoC): extract from trace_replay_test output
echo "Layer C: <paste cycles/event from Task 5 output>"
echo "Speedup: <Layer A cycles / Layer C cycles>"
```

- [ ] **Step 2: Run full regression across all layers**

```bash
# Layer A
cd /Volumes/DevSSD/FitTracker2/orchid/layer-a
/Volumes/DevSSD/FitTracker2/orchid/.venv/bin/python -m pytest tests/ -v

# Layer B
cd /Volumes/DevSSD/FitTracker2/orchid/layer-b
sbt test

# Layer C
cd /Volumes/DevSSD/FitTracker2/orchid/layer-c/chipyard
source env.sh
./sims/verilator/simulator-orchid-OrchidSmallConfig ../tests/orchid_test.riscv
./sims/verilator/simulator-orchid-OrchidSmallConfig ../tests/trace_replay_test.riscv
```
Expected: All pass.

- [ ] **Step 3: Write final benchmark results**

```bash
# Save to results
cat > /Volumes/DevSSD/FitTracker2/orchid/results/final_benchmark.json << 'EOF'
{
  "benchmark": "burst_haiku",
  "events": 100,
  "layer_a": {
    "total_cycles": "<from results/layer_a/burst_haiku_results.json>",
    "composite_score": "<from results>"
  },
  "layer_c": {
    "total_cycles": "<from trace_replay_test output>",
    "cycles_per_event": "<computed>",
    "clock_freq_mhz": 1000,
    "latency_ns_per_event": "<cycles / freq>"
  },
  "speedup": "<layer_a / layer_c>",
  "validation": "external-automated"
}
EOF
```

- [ ] **Step 4: Tag and commit**

```bash
git add orchid/results/final_benchmark.json
git commit -m "feat(orchid): Phase 5 complete — full SoC benchmark, composite score computed"
git tag orchid-phase5-complete
git tag orchid-v1.0
```

---

## Summary

| Task | Component | Tests | Type |
|---|---|---|---|
| 1 | Chipyard setup + registration | — | Infrastructure |
| 2 | RoCC wrapper (OrchidRoCC) | — | Integration |
| 3 | SoC configs (Small/Medium/Full) | — | Configuration |
| 4 | Bare-metal C test (custom instructions) | 4 asserts | Validation |
| 5 | Trace replay on SoC | 100 events | Benchmark |
| 6 | FireSim configs (optional) | — | Deployment |
| 7 | Final composite score + regression | All layers | Verification |
| **Total** | **7 tasks** | **~5 tests + benchmark** | **~6 commits** |

## Spec Coverage

| Spec Requirement | Task |
|---|---|
| Phase 5 Step 5.1: Rocket + U1-U2 as RoCC | Tasks 2-3 |
| Phase 5 Step 5.2: Add U3-U6 to SoC | Task 2 (OrchidAccelerator wraps all) |
| Phase 5 Step 5.3: Add Gemmini (U7) | Task 3 (OrchidFullConfig, commented until ready) |
| Phase 5 Step 5.4: FireSim deployment | Task 6 |
| Phase 5 Step 5.5: Trace replay on full SoC | Task 5 |
| Section 7 Level 3: Real trace replay, composite > 1.0x | Task 7 |
| Section 7 Level 3: Synthetic burst (100 haiku in 10us) | Task 5 |
| Section 10.10: v6.0+ traces as primary data | Task 5 (trace replay) |
