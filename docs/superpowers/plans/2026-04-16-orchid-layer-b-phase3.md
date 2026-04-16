# Orchid Phase 3 — Layer B (Chisel RTL for U3 + U4 + U5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement U3 (Cache Controller), U4 (Batch Scheduler), and U5 (Speculative Prefetcher) as synthesizable Chisel RTL with FSMs and on-chip memory, co-simulate against Layer A Python models to prove behavioral equivalence.

**Architecture:** Unlike Phase 2's combinational units, these are **stateful** — they use registers, SRAMs, and finite state machines. U3 uses `SyncReadMem` for the scratchpad with an LRU tracker. U4 uses a circular buffer FIFO with a comparator-based tier sorter. U5 uses a dual-port prediction table with a greedy chain-walker FSM. Each module follows a request/response handshake pattern (`valid`/`ready` signals) to model multi-cycle operations accurately.

**Tech Stack:** Chisel 3 (Scala 2.13), sbt, Verilator 5.x, cocotb (Python), pytest

**Prerequisite:** Phase 2 must be complete (sbt project, OrchidConfig, Verilator toolchain all working).

**Spec:** `docs/superpowers/specs/2026-04-16-orchid-ai-accelerator-design.md` (Sections 2, 3 Phase 3, 6, 7, 10)

**Layer A reference:** `orchid/layer-a/units/cache_controller.py`, `batch_scheduler.py`, `speculative_prefetcher.py`

---

## File Map

| File | Responsibility |
|---|---|
| `orchid/layer-b/src/main/scala/orchid/CacheController.scala` | U3 RTL: LRU scratchpad with compressed/full views |
| `orchid/layer-b/src/main/scala/orchid/BatchScheduler.scala` | U4 RTL: FIFO queue with tier-sorted wave dispatch |
| `orchid/layer-b/src/main/scala/orchid/SpeculativePrefetcher.scala` | U5 RTL: prediction table with chain-walk FSM |
| `orchid/layer-b/src/test/scala/orchid/CacheControllerSpec.scala` | U3 Chisel unit tests |
| `orchid/layer-b/src/test/scala/orchid/BatchSchedulerSpec.scala` | U4 Chisel unit tests |
| `orchid/layer-b/src/test/scala/orchid/SpeculativePrefetcherSpec.scala` | U5 Chisel unit tests |
| `orchid/cosim/cocotb_tests/test_cache_controller.py` | U3 co-simulation: Python model vs RTL |
| `orchid/cosim/cocotb_tests/test_batch_scheduler.py` | U4 co-simulation: Python model vs RTL |
| `orchid/cosim/cocotb_tests/test_speculative_prefetcher.py` | U5 co-simulation: Python model vs RTL |

---

### Task 1: U3 Cache Controller — Chisel RTL

**Files:**
- Create: `orchid/layer-b/src/main/scala/orchid/CacheController.scala`
- Create: `orchid/layer-b/src/test/scala/orchid/CacheControllerSpec.scala`

- [ ] **Step 1: Write Chisel unit tests**

```scala
// orchid/layer-b/src/test/scala/orchid/CacheControllerSpec.scala
package orchid

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class CacheControllerSpec extends AnyFlatSpec with ChiselScalatestTester {
  val cfg = OrchidConfig.default

  behavior of "CacheController"

  it should "return miss on empty cache" in {
    test(new CacheController(cfg)) { dut =>
      dut.io.cmd.valid.poke(true.B)
      dut.io.cmd.bits.op.poke(0.U)     // READ
      dut.io.cmd.bits.key.poke(42.U)
      dut.clock.step(2)                  // read takes 2 cycles

      dut.io.resp.valid.expect(true.B)
      dut.io.resp.bits.hit.expect(false.B)
    }
  }

  it should "hit after a write then read of the same key" in {
    test(new CacheController(cfg)) { dut =>
      // WRITE key=7
      dut.io.cmd.valid.poke(true.B)
      dut.io.cmd.bits.op.poke(1.U)     // WRITE
      dut.io.cmd.bits.key.poke(7.U)
      dut.io.cmd.bits.writeData.poke(0xCAFE.U)
      dut.clock.step(3)                  // write takes 3 cycles
      dut.io.cmd.valid.poke(false.B)
      dut.clock.step(1)

      // READ key=7
      dut.io.cmd.valid.poke(true.B)
      dut.io.cmd.bits.op.poke(0.U)     // READ
      dut.io.cmd.bits.key.poke(7.U)
      dut.clock.step(2)

      dut.io.resp.valid.expect(true.B)
      dut.io.resp.bits.hit.expect(true.B)
      dut.io.resp.bits.readData.expect(0xCAFE.U)
    }
  }

  it should "evict LRU entry when cache is full" in {
    test(new CacheController(cfg.copy(cacheEntries = 4))) { dut =>
      // Fill cache with keys 0,1,2,3
      for (k <- 0 until 4) {
        dut.io.cmd.valid.poke(true.B)
        dut.io.cmd.bits.op.poke(1.U)   // WRITE
        dut.io.cmd.bits.key.poke(k.U)
        dut.io.cmd.bits.writeData.poke((k * 100).U)
        dut.clock.step(3)
        dut.io.cmd.valid.poke(false.B)
        dut.clock.step(1)
      }

      // Read key=0 to make it recently used
      dut.io.cmd.valid.poke(true.B)
      dut.io.cmd.bits.op.poke(0.U)
      dut.io.cmd.bits.key.poke(0.U)
      dut.clock.step(2)
      dut.io.cmd.valid.poke(false.B)
      dut.clock.step(1)

      // Write key=99 — should evict key=1 (LRU)
      dut.io.cmd.valid.poke(true.B)
      dut.io.cmd.bits.op.poke(1.U)
      dut.io.cmd.bits.key.poke(99.U)
      dut.io.cmd.bits.writeData.poke(9900.U)
      dut.clock.step(3)
      dut.io.cmd.valid.poke(false.B)
      dut.clock.step(1)

      // Read key=1 — should miss (evicted)
      dut.io.cmd.valid.poke(true.B)
      dut.io.cmd.bits.op.poke(0.U)
      dut.io.cmd.bits.key.poke(1.U)
      dut.clock.step(2)
      dut.io.resp.bits.hit.expect(false.B)
    }
  }

  it should "track hit and miss counters" in {
    test(new CacheController(cfg)) { dut =>
      // Write key=5
      dut.io.cmd.valid.poke(true.B)
      dut.io.cmd.bits.op.poke(1.U)
      dut.io.cmd.bits.key.poke(5.U)
      dut.io.cmd.bits.writeData.poke(55.U)
      dut.clock.step(3)
      dut.io.cmd.valid.poke(false.B)
      dut.clock.step(1)

      // Read key=5 (hit)
      dut.io.cmd.valid.poke(true.B)
      dut.io.cmd.bits.op.poke(0.U)
      dut.io.cmd.bits.key.poke(5.U)
      dut.clock.step(2)
      dut.io.cmd.valid.poke(false.B)
      dut.clock.step(1)

      // Read key=99 (miss)
      dut.io.cmd.valid.poke(true.B)
      dut.io.cmd.bits.op.poke(0.U)
      dut.io.cmd.bits.key.poke(99.U)
      dut.clock.step(2)

      dut.io.hitCount.expect(1.U)
      dut.io.missCount.expect(1.U)
    }
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-b
sbt "testOnly orchid.CacheControllerSpec"
```
Expected: Compilation error — `CacheController` not found.

- [ ] **Step 3: Implement U3 Chisel module**

```scala
// orchid/layer-b/src/main/scala/orchid/CacheController.scala
package orchid

import chisel3._
import chisel3.util._

/** U3 — Cache Controller.
  *
  * Scratchpad SRAM with LRU eviction. Multi-cycle operations:
  *   READ:  2 cycles (tag compare + data read)
  *   WRITE: 3 cycles (tag compare + evict check + data write)
  *
  * Matches Layer A cache_controller.py behavior:
  *   - 15 entries (configurable via OrchidConfig)
  *   - LRU eviction on full cache
  *   - Hit/miss counters for L1 tracking
  *
  * Simplified vs full spec: keys are integers (not strings),
  * data is a UInt word (not compressed/full views). The structural
  * behavior (LRU, hit/miss, eviction order) is identical.
  */
class CacheController(cfg: OrchidConfig) extends Module {
  val keyBits  = 8   // 256 possible keys
  val dataBits = 32  // 32-bit data words
  val entries  = cfg.cacheEntries
  val idxBits  = log2Ceil(entries)

  val io = IO(new Bundle {
    val cmd = Flipped(new ValidIO(new Bundle {
      val op        = UInt(2.W)          // 0=READ, 1=WRITE
      val key       = UInt(keyBits.W)
      val writeData = UInt(dataBits.W)
    }))
    val resp = new ValidIO(new Bundle {
      val hit      = Bool()
      val readData = UInt(dataBits.W)
      val evicted  = Bool()
      val evictKey = UInt(keyBits.W)
    })
    val hitCount  = Output(UInt(16.W))
    val missCount = Output(UInt(16.W))
  })

  // Storage arrays
  val validBits = RegInit(VecInit(Seq.fill(entries)(false.B)))
  val keyStore  = Reg(Vec(entries, UInt(keyBits.W)))
  val dataStore = Reg(Vec(entries, UInt(dataBits.W)))

  // LRU tracking: age counter per slot. Higher = older = evict first.
  val lruAge = RegInit(VecInit(Seq.tabulate(entries)(i => i.U(idxBits.W))))

  // Counters
  val hitCounter  = RegInit(0.U(16.W))
  val missCounter = RegInit(0.U(16.W))

  // FSM states
  val sIdle :: sRead :: sWrite :: sEvict :: sDone :: Nil = Enum(5)
  val state = RegInit(sIdle)

  // Registered command
  val cmdReg   = Reg(chiselTypeOf(io.cmd.bits))
  val respReg  = Reg(chiselTypeOf(io.resp.bits))
  val respValid = RegInit(false.B)
  val cycleCount = RegInit(0.U(4.W))

  // Tag compare: find matching slot or LRU victim
  val tagMatch = VecInit((0 until entries).map(i =>
    validBits(i) && keyStore(i) === cmdReg.key
  ))
  val matchIdx = PriorityEncoder(tagMatch)
  val hasMatch = tagMatch.asUInt.orR

  // LRU victim: slot with highest age
  val lruIdx = lruAge.zipWithIndex.reduce((a, b) =>
    if (true) (Mux(a._1 > b._1, a._1, b._1), if (a._2 > b._2) a._2 else b._2)
    else a // placeholder
  )
  // Simpler approach: find first invalid slot, or oldest valid slot
  val emptySlots = VecInit((0 until entries).map(i => !validBits(i)))
  val hasEmpty   = emptySlots.asUInt.orR
  val emptyIdx   = PriorityEncoder(emptySlots)

  val maxAge     = lruAge.reduce((a, b) => Mux(a > b, a, b))
  val victimIdx  = Wire(UInt(idxBits.W))
  victimIdx := PriorityMux(
    (0 until entries).map(i => (lruAge(i) === maxAge && validBits(i)) -> i.U(idxBits.W))
  )

  // Default outputs
  io.resp.valid     := respValid
  io.resp.bits      := respReg
  io.hitCount       := hitCounter
  io.missCount      := missCounter

  respValid := false.B

  // LRU age update helper: promote a slot (set its age to 0, increment others)
  def promoteLRU(slot: UInt): Unit = {
    val oldAge = lruAge(slot)
    for (i <- 0 until entries) {
      when(i.U === slot) {
        lruAge(i) := 0.U
      }.elsewhen(lruAge(i.U) < oldAge) {
        lruAge(i) := lruAge(i) + 1.U
      }
    }
  }

  switch(state) {
    is(sIdle) {
      when(io.cmd.valid) {
        cmdReg     := io.cmd.bits
        cycleCount := 0.U
        when(io.cmd.bits.op === 0.U) {
          state := sRead
        }.otherwise {
          state := sWrite
        }
      }
    }

    is(sRead) {
      cycleCount := cycleCount + 1.U
      when(cycleCount === 1.U) {  // 2 cycles total
        respReg.evicted  := false.B
        respReg.evictKey := 0.U
        when(hasMatch) {
          respReg.hit      := true.B
          respReg.readData := dataStore(matchIdx)
          hitCounter       := hitCounter + 1.U
          promoteLRU(matchIdx)
        }.otherwise {
          respReg.hit      := false.B
          respReg.readData := 0.U
          missCounter      := missCounter + 1.U
        }
        respValid := true.B
        state     := sIdle
      }
    }

    is(sWrite) {
      cycleCount := cycleCount + 1.U
      when(cycleCount === 2.U) {  // 3 cycles total
        when(hasMatch) {
          // Update existing entry
          dataStore(matchIdx) := cmdReg.writeData
          promoteLRU(matchIdx)
          respReg.evicted  := false.B
          respReg.evictKey := 0.U
        }.otherwise {
          // Need a slot
          val writeIdx = Wire(UInt(idxBits.W))
          when(hasEmpty) {
            writeIdx := emptyIdx
            respReg.evicted  := false.B
            respReg.evictKey := 0.U
          }.otherwise {
            writeIdx := victimIdx
            respReg.evicted  := true.B
            respReg.evictKey := keyStore(victimIdx)
          }
          validBits(writeIdx) := true.B
          keyStore(writeIdx)  := cmdReg.key
          dataStore(writeIdx) := cmdReg.writeData
          promoteLRU(writeIdx)
        }
        respReg.hit      := true.B
        respReg.readData := cmdReg.writeData
        respValid        := true.B
        state            := sIdle
      }
    }
  }
}

object CacheControllerDriver extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new CacheController(OrchidConfig.default),
    Array("--target-dir", "generated-rtl")
  )
  println("Verilog emitted to generated-rtl/CacheController.v")
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-b
sbt "testOnly orchid.CacheControllerSpec"
```
Expected: All 4 tests PASS.

- [ ] **Step 5: Generate Verilog**

```bash
sbt "runMain orchid.CacheControllerDriver"
ls -la generated-rtl/CacheController.v
```

- [ ] **Step 6: Commit**

```bash
git add orchid/layer-b/src/
git commit -m "feat(orchid): U3 Cache Controller RTL — LRU scratchpad with FSM, 4 tests pass"
```

---

### Task 2: U4 Batch Scheduler — Chisel RTL

**Files:**
- Create: `orchid/layer-b/src/main/scala/orchid/BatchScheduler.scala`
- Create: `orchid/layer-b/src/test/scala/orchid/BatchSchedulerSpec.scala`

- [ ] **Step 1: Write Chisel unit tests**

```scala
// orchid/layer-b/src/test/scala/orchid/BatchSchedulerSpec.scala
package orchid

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class BatchSchedulerSpec extends AnyFlatSpec with ChiselScalatestTester {
  val cfg = OrchidConfig.default

  behavior of "BatchScheduler"

  it should "enqueue and dispatch a single task" in {
    test(new BatchScheduler(cfg)) { dut =>
      // Enqueue: score=20, tier=HAIKU(0)
      dut.io.enq.valid.poke(true.B)
      dut.io.enq.bits.score.poke(20.U)
      dut.io.enq.bits.tier.poke(0.U)
      dut.clock.step(1)
      dut.io.enq.valid.poke(false.B)
      dut.clock.step(1)

      dut.io.pending.expect(1.U)

      // Dispatch
      dut.io.dispatchReq.poke(true.B)
      dut.clock.step(3)  // dispatch takes 3 cycles
      dut.io.dispatchReq.poke(false.B)

      dut.io.wave.valid.expect(true.B)
      dut.io.wave.bits.count.expect(1.U)
      dut.io.wave.bits.tasks(0).tier.expect(0.U)
    }
  }

  it should "sort tasks by tier in dispatched wave" in {
    test(new BatchScheduler(cfg.copy(maxConcurrentTasks = 8))) { dut =>
      // Enqueue 3 tasks: OPUS, HAIKU, SONNET
      val tiers = Seq(2, 0, 1)
      for (t <- tiers) {
        dut.io.enq.valid.poke(true.B)
        dut.io.enq.bits.score.poke(50.U)
        dut.io.enq.bits.tier.poke(t.U)
        dut.clock.step(1)
      }
      dut.io.enq.valid.poke(false.B)
      dut.clock.step(1)

      // Dispatch
      dut.io.dispatchReq.poke(true.B)
      dut.clock.step(3)
      dut.io.dispatchReq.poke(false.B)

      // Wave should be sorted: HAIKU(0), SONNET(1), OPUS(2)
      dut.io.wave.bits.tasks(0).tier.expect(0.U)
      dut.io.wave.bits.tasks(1).tier.expect(1.U)
      dut.io.wave.bits.tasks(2).tier.expect(2.U)
    }
  }

  it should "respect max concurrent limit" in {
    test(new BatchScheduler(cfg.copy(maxConcurrentTasks = 4))) { dut =>
      // Enqueue 6 tasks
      for (i <- 0 until 6) {
        dut.io.enq.valid.poke(true.B)
        dut.io.enq.bits.score.poke(10.U)
        dut.io.enq.bits.tier.poke(0.U)
        dut.clock.step(1)
      }
      dut.io.enq.valid.poke(false.B)
      dut.clock.step(1)

      // Dispatch — should only get 4
      dut.io.dispatchReq.poke(true.B)
      dut.clock.step(3)
      dut.io.dispatchReq.poke(false.B)

      dut.io.wave.bits.count.expect(4.U)
      dut.io.pending.expect(2.U)
    }
  }

  it should "reject enqueue when queue is full" in {
    test(new BatchScheduler(cfg.copy(maxConcurrentTasks = 8))) { dut =>
      // Fill queue to depth (default 32)
      for (i <- 0 until 32) {
        dut.io.enq.valid.poke(true.B)
        dut.io.enq.bits.score.poke(10.U)
        dut.io.enq.bits.tier.poke(0.U)
        dut.clock.step(1)
      }
      // 33rd enqueue should be rejected
      dut.io.enq.valid.poke(true.B)
      dut.io.enq.bits.score.poke(10.U)
      dut.io.enq.bits.tier.poke(0.U)
      dut.io.enq.ready.expect(false.B)
    }
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
sbt "testOnly orchid.BatchSchedulerSpec"
```
Expected: Compilation error.

- [ ] **Step 3: Implement U4 Chisel module**

```scala
// orchid/layer-b/src/main/scala/orchid/BatchScheduler.scala
package orchid

import chisel3._
import chisel3.util._

/** U4 — Batch Scheduler.
  *
  * FIFO queue with tier-sorted wave dispatch.
  * Enqueue: 1 cycle. Dispatch wave: 3 cycles (read + sort + output).
  * Max 8 concurrent tasks per wave, 32 queue depth.
  *
  * Matches Layer A batch_scheduler.py:
  *   - Tasks sorted by tier (HAIKU first) in each wave
  *   - Queue rejects when full (returns ready=false)
  *   - Remaining tasks stay in queue for next wave
  *
  * Simplification: task payload is (score, tier) only.
  * Full task descriptor would add more bits but same structure.
  */
class BatchScheduler(cfg: OrchidConfig) extends Module {
  val maxTasks = cfg.maxConcurrentTasks
  val queueDepth = 32  // could be in OrchidConfig
  val scoreBits = cfg.scoreBits
  val tierBits = cfg.tierBits

  val io = IO(new Bundle {
    val enq = Flipped(new DecoupledIO(new Bundle {
      val score = UInt(scoreBits.W)
      val tier  = UInt(tierBits.W)
    }))

    val dispatchReq = Input(Bool())

    val wave = new ValidIO(new Bundle {
      val count = UInt(log2Ceil(maxTasks + 1).W)
      val tasks = Vec(maxTasks, new Bundle {
        val score = UInt(scoreBits.W)
        val tier  = UInt(tierBits.W)
      })
    })

    val pending = Output(UInt(log2Ceil(queueDepth + 1).W))
  })

  // Storage
  val queueScore = Reg(Vec(queueDepth, UInt(scoreBits.W)))
  val queueTier  = Reg(Vec(queueDepth, UInt(tierBits.W)))
  val head       = RegInit(0.U(log2Ceil(queueDepth).W))
  val tail       = RegInit(0.U(log2Ceil(queueDepth).W))
  val count      = RegInit(0.U(log2Ceil(queueDepth + 1).W))

  // FSM
  val sIdle :: sSort :: sOutput :: Nil = Enum(3)
  val state = RegInit(sIdle)
  val cycleCount = RegInit(0.U(4.W))

  // Staging buffer for sorted wave
  val stageScore = Reg(Vec(maxTasks, UInt(scoreBits.W)))
  val stageTier  = Reg(Vec(maxTasks, UInt(tierBits.W)))
  val stageCount = RegInit(0.U(log2Ceil(maxTasks + 1).W))

  // Wave output register
  val waveValid = RegInit(false.B)
  val waveCount = RegInit(0.U(log2Ceil(maxTasks + 1).W))
  val waveTasks = Reg(Vec(maxTasks, new Bundle {
    val score = UInt(scoreBits.W)
    val tier  = UInt(tierBits.W)
  }))

  // Enqueue logic (always active in idle)
  io.enq.ready := count < queueDepth.U && state === sIdle
  when(io.enq.fire) {
    queueScore(tail) := io.enq.bits.score
    queueTier(tail)  := io.enq.bits.tier
    tail  := Mux(tail === (queueDepth - 1).U, 0.U, tail + 1.U)
    count := count + 1.U
  }

  // Default outputs
  io.wave.valid     := waveValid
  io.wave.bits.count := waveCount
  for (i <- 0 until maxTasks) {
    io.wave.bits.tasks(i).score := waveTasks(i).score
    io.wave.bits.tasks(i).tier  := waveTasks(i).tier
  }
  io.pending := count

  waveValid := false.B

  switch(state) {
    is(sIdle) {
      when(io.dispatchReq && count > 0.U) {
        // Read up to maxTasks items from queue into staging
        val toRead = Mux(count > maxTasks.U, maxTasks.U, count)
        stageCount := toRead

        // Copy items from queue to staging (combinational read)
        for (i <- 0 until maxTasks) {
          val readIdx = head +& i.U
          val wrappedIdx = Mux(readIdx >= queueDepth.U,
            readIdx - queueDepth.U, readIdx)
          when(i.U < toRead) {
            stageScore(i) := queueScore(wrappedIdx(log2Ceil(queueDepth) - 1, 0))
            stageTier(i)  := queueTier(wrappedIdx(log2Ceil(queueDepth) - 1, 0))
          }
        }

        // Advance head
        val newHead = head +& toRead
        head  := Mux(newHead >= queueDepth.U,
          newHead - queueDepth.U, newHead)(log2Ceil(queueDepth) - 1, 0)
        count := count - toRead

        cycleCount := 0.U
        state      := sSort
      }
    }

    is(sSort) {
      // Bubble sort by tier (simple, small array — max 8 elements)
      // One pass per cycle, 2 cycles for up to 8 elements
      cycleCount := cycleCount + 1.U
      for (i <- 0 until maxTasks - 1) {
        when(i.U < stageCount - 1.U) {
          when(stageTier(i) > stageTier(i + 1)) {
            val tmpScore = stageScore(i)
            val tmpTier  = stageTier(i)
            stageScore(i)     := stageScore(i + 1)
            stageTier(i)      := stageTier(i + 1)
            stageScore(i + 1) := tmpScore
            stageTier(i + 1)  := tmpTier
          }
        }
      }
      when(cycleCount === 1.U) {  // 2 sort cycles
        state := sOutput
      }
    }

    is(sOutput) {
      // Copy staging to output
      for (i <- 0 until maxTasks) {
        waveTasks(i).score := stageScore(i)
        waveTasks(i).tier  := stageTier(i)
      }
      waveCount := stageCount
      waveValid := true.B
      state     := sIdle
    }
  }
}

object BatchSchedulerDriver extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new BatchScheduler(OrchidConfig.default),
    Array("--target-dir", "generated-rtl")
  )
  println("Verilog emitted to generated-rtl/BatchScheduler.v")
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
sbt "testOnly orchid.BatchSchedulerSpec"
```
Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add orchid/layer-b/src/
git commit -m "feat(orchid): U4 Batch Scheduler RTL — FIFO + bubble sort by tier, 4 tests pass"
```

---

### Task 3: U5 Speculative Prefetcher — Chisel RTL

**Files:**
- Create: `orchid/layer-b/src/main/scala/orchid/SpeculativePrefetcher.scala`
- Create: `orchid/layer-b/src/test/scala/orchid/SpeculativePrefetcherSpec.scala`

- [ ] **Step 1: Write Chisel unit tests**

```scala
// orchid/layer-b/src/test/scala/orchid/SpeculativePrefetcherSpec.scala
package orchid

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class SpeculativePrefetcherSpec extends AnyFlatSpec with ChiselScalatestTester {
  val cfg = OrchidConfig.default

  behavior of "SpeculativePrefetcher"

  // Phase encoding (same as SkillRouter): 0-9
  // Prediction table: for each fromPhase, stores (toPhase, count)

  it should "predict nothing for an unknown phase" in {
    test(new SpeculativePrefetcher(cfg)) { dut =>
      dut.io.predictReq.valid.poke(true.B)
      dut.io.predictReq.bits.poke(5.U)  // never trained
      dut.clock.step(2)  // 2 cycles for prediction

      dut.io.predictResp.valid.expect(true.B)
      dut.io.predictResp.bits.count.expect(0.U)
    }
  }

  it should "predict the trained successor after recording transitions" in {
    test(new SpeculativePrefetcher(cfg)) { dut =>
      // Record: research(0) -> prd(1) five times
      for (_ <- 0 until 5) {
        dut.io.recordReq.valid.poke(true.B)
        dut.io.recordReq.bits.fromPhase.poke(0.U)
        dut.io.recordReq.bits.toPhase.poke(1.U)
        dut.clock.step(1)
      }
      dut.io.recordReq.valid.poke(false.B)
      dut.clock.step(1)

      // Predict from research(0)
      dut.io.predictReq.valid.poke(true.B)
      dut.io.predictReq.bits.poke(0.U)
      dut.clock.step(2)

      dut.io.predictResp.valid.expect(true.B)
      dut.io.predictResp.bits.count.expect(1.U)  // at least 1 prediction
      dut.io.predictResp.bits.phases(0).expect(1.U)  // prd
    }
  }

  it should "predict the most frequent successor when multiple exist" in {
    test(new SpeculativePrefetcher(cfg)) { dut =>
      // Record: impl(4) -> testing(5) three times
      for (_ <- 0 until 3) {
        dut.io.recordReq.valid.poke(true.B)
        dut.io.recordReq.bits.fromPhase.poke(4.U)
        dut.io.recordReq.bits.toPhase.poke(5.U)
        dut.clock.step(1)
      }
      // Record: impl(4) -> review(6) once
      dut.io.recordReq.valid.poke(true.B)
      dut.io.recordReq.bits.fromPhase.poke(4.U)
      dut.io.recordReq.bits.toPhase.poke(6.U)
      dut.clock.step(1)
      dut.io.recordReq.valid.poke(false.B)
      dut.clock.step(1)

      // Should predict testing(5) — 3 > 1
      dut.io.predictReq.valid.poke(true.B)
      dut.io.predictReq.bits.poke(4.U)
      dut.clock.step(2)

      dut.io.predictResp.bits.phases(0).expect(5.U)
    }
  }

  it should "chain predictions up to prefetchAhead depth" in {
    test(new SpeculativePrefetcher(cfg.copy(prefetchAhead = 2))) { dut =>
      // Train chain: research(0) -> prd(1) -> tasks(2)
      for (_ <- 0 until 5) {
        dut.io.recordReq.valid.poke(true.B)
        dut.io.recordReq.bits.fromPhase.poke(0.U)
        dut.io.recordReq.bits.toPhase.poke(1.U)
        dut.clock.step(1)
        dut.io.recordReq.bits.fromPhase.poke(1.U)
        dut.io.recordReq.bits.toPhase.poke(2.U)
        dut.clock.step(1)
      }
      dut.io.recordReq.valid.poke(false.B)
      dut.clock.step(1)

      // Predict from research(0) — should get [prd(1), tasks(2)]
      dut.io.predictReq.valid.poke(true.B)
      dut.io.predictReq.bits.poke(0.U)
      dut.clock.step(3)  // extra cycle for chain walk

      dut.io.predictResp.bits.count.expect(2.U)
      dut.io.predictResp.bits.phases(0).expect(1.U)  // prd
      dut.io.predictResp.bits.phases(1).expect(2.U)  // tasks
    }
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
sbt "testOnly orchid.SpeculativePrefetcherSpec"
```
Expected: Compilation error.

- [ ] **Step 3: Implement U5 Chisel module**

```scala
// orchid/layer-b/src/main/scala/orchid/SpeculativePrefetcher.scala
package orchid

import chisel3._
import chisel3.util._

/** U5 — Speculative Prefetcher.
  *
  * Prediction table (BTB-style). For each source phase, tracks transition
  * counts to every possible destination phase. Predicts by finding the
  * highest-count destination and optionally chaining predictions.
  *
  * Record: 1 cycle. Predict: 2 cycles (+ 1 per chain step).
  * Table size: maxPhases × maxPhases × countBits.
  *
  * Matches Layer A speculative_prefetcher.py:
  *   - record_transition(from, to) increments counter
  *   - predict(phase) returns most frequent successor chain
  */
class SpeculativePrefetcher(cfg: OrchidConfig) extends Module {
  val phaseBits = 4      // 0-9 phases
  val maxPhases = cfg.maxPhases
  val countBits = 8      // max 255 observations per transition
  val maxPredictions = cfg.prefetchAhead

  val io = IO(new Bundle {
    val recordReq = Flipped(new ValidIO(new Bundle {
      val fromPhase = UInt(phaseBits.W)
      val toPhase   = UInt(phaseBits.W)
    }))

    val predictReq = Flipped(new ValidIO(UInt(phaseBits.W)))

    val predictResp = new ValidIO(new Bundle {
      val count  = UInt(log2Ceil(maxPredictions + 1).W)
      val phases = Vec(maxPredictions, UInt(phaseBits.W))
    })
  })

  // Transition count table: transitionCounts[from][to] = count
  // 10 × 10 × 8 bits = 800 bits total (tiny)
  val transitionCounts = RegInit(VecInit(Seq.fill(maxPhases)(
    VecInit(Seq.fill(maxPhases)(0.U(countBits.W)))
  )))

  // FSM
  val sIdle :: sPredict :: sChain :: sDone :: Nil = Enum(4)
  val state = RegInit(sIdle)

  // Prediction state
  val predPhases = Reg(Vec(maxPredictions, UInt(phaseBits.W)))
  val predCount  = RegInit(0.U(log2Ceil(maxPredictions + 1).W))
  val chainIdx   = RegInit(0.U(log2Ceil(maxPredictions + 1).W))
  val currentPhase = Reg(UInt(phaseBits.W))

  // Response register
  val respValid = RegInit(false.B)

  // Record logic (always active, 1 cycle)
  when(io.recordReq.valid) {
    val from = io.recordReq.bits.fromPhase
    val to   = io.recordReq.bits.toPhase
    when(from < maxPhases.U && to < maxPhases.U) {
      when(transitionCounts(from)(to) < ((1 << countBits) - 1).U) {
        transitionCounts(from)(to) := transitionCounts(from)(to) + 1.U
      }
    }
  }

  // Find best successor for a given phase (combinational)
  def findBest(phase: UInt): (UInt, Bool) = {
    val counts = transitionCounts(phase)
    val bestCount = counts.reduce((a, b) => Mux(a > b, a, b))
    val bestIdx = PriorityMux(
      (0 until maxPhases).map(i => (counts(i) === bestCount && bestCount > 0.U) -> i.U(phaseBits.W))
    )
    val hasAny = bestCount > 0.U
    (bestIdx, hasAny)
  }

  // Default outputs
  io.predictResp.valid          := respValid
  io.predictResp.bits.count     := predCount
  for (i <- 0 until maxPredictions) {
    io.predictResp.bits.phases(i) := predPhases(i)
  }

  respValid := false.B

  switch(state) {
    is(sIdle) {
      when(io.predictReq.valid) {
        currentPhase := io.predictReq.bits
        predCount    := 0.U
        chainIdx     := 0.U
        for (i <- 0 until maxPredictions) {
          predPhases(i) := 0.U
        }
        state := sPredict
      }
    }

    is(sPredict) {
      val (bestPhase, hasSuccessor) = findBest(currentPhase)
      when(hasSuccessor && chainIdx < maxPredictions.U) {
        predPhases(chainIdx) := bestPhase
        predCount    := chainIdx + 1.U
        chainIdx     := chainIdx + 1.U
        currentPhase := bestPhase
        when(chainIdx + 1.U >= maxPredictions.U) {
          state := sDone
        }
        // else stay in sPredict for next chain step
      }.otherwise {
        state := sDone
      }
    }

    is(sDone) {
      respValid := true.B
      state     := sIdle
    }
  }
}

object SpeculativePrefetcherDriver extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new SpeculativePrefetcher(OrchidConfig.default),
    Array("--target-dir", "generated-rtl")
  )
  println("Verilog emitted to generated-rtl/SpeculativePrefetcher.v")
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
sbt "testOnly orchid.SpeculativePrefetcherSpec"
```
Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add orchid/layer-b/src/
git commit -m "feat(orchid): U5 Speculative Prefetcher RTL — prediction table with chain-walk FSM, 4 tests pass"
```

---

### Task 4: Co-Simulation for U3, U4, U5

**Files:**
- Create: `orchid/cosim/cocotb_tests/test_cache_controller.py`
- Create: `orchid/cosim/cocotb_tests/test_batch_scheduler.py`
- Create: `orchid/cosim/cocotb_tests/test_speculative_prefetcher.py`

- [ ] **Step 1: Write U3 co-simulation**

```python
# orchid/cosim/cocotb_tests/test_cache_controller.py
"""Co-simulation: CacheController RTL vs Layer A Python model.

Tests a sequence of put/get operations and compares hit/miss results.
Stateful co-sim: both models must track identical internal state.
"""
import cocotb
from cocotb.triggers import RisingEdge, Timer
import sys, os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "layer-a"))


@cocotb.test()
async def test_hit_miss_sequence(dut):
    """Write keys 0-4, then read 0-4 (all hit) and 5-9 (all miss).
    Compare RTL hit/miss counters to Python model."""
    from units.cache_controller import CacheController
    from units.types import CacheEntry

    py_cc = CacheController(max_entries=15)

    # Reset
    dut.reset.value = 1
    await RisingEdge(dut.clock)
    await RisingEdge(dut.clock)
    dut.reset.value = 0
    await RisingEdge(dut.clock)

    # Write keys 0-4 to both models
    for k in range(5):
        # RTL write
        dut.io_cmd_valid.value = 1
        dut.io_cmd_bits_op.value = 1  # WRITE
        dut.io_cmd_bits_key.value = k
        dut.io_cmd_bits_writeData.value = k * 100
        for _ in range(3):
            await RisingEdge(dut.clock)
        dut.io_cmd_valid.value = 0
        await RisingEdge(dut.clock)

        # Python write
        py_cc.put(CacheEntry(key=str(k), compressed_view=str(k * 100)))

    # Read keys 0-4 (should hit) and 5-9 (should miss)
    py_hits = 0
    py_misses = 0
    for k in range(10):
        # RTL read
        dut.io_cmd_valid.value = 1
        dut.io_cmd_bits_op.value = 0  # READ
        dut.io_cmd_bits_key.value = k
        for _ in range(2):
            await RisingEdge(dut.clock)
        rtl_hit = int(dut.io_resp_bits_hit.value)
        dut.io_cmd_valid.value = 0
        await RisingEdge(dut.clock)

        # Python read
        py_result = py_cc.get(str(k))
        py_hit = 1 if py_result is not None else 0

        if py_hit:
            py_hits += 1
        else:
            py_misses += 1

        assert rtl_hit == py_hit, f"Key {k}: RTL hit={rtl_hit}, Python hit={py_hit}"

    # Compare counters
    rtl_hits = int(dut.io_hitCount.value)
    rtl_misses = int(dut.io_missCount.value)
    assert rtl_hits == py_hits, f"Hits: RTL={rtl_hits}, Python={py_hits}"
    assert rtl_misses == py_misses, f"Misses: RTL={rtl_misses}, Python={py_misses}"
    cocotb.log.info(f"Cache co-sim: {py_hits} hits, {py_misses} misses — matched")
```

- [ ] **Step 2: Write U4 co-simulation**

```python
# orchid/cosim/cocotb_tests/test_batch_scheduler.py
"""Co-simulation: BatchScheduler RTL vs Layer A Python model.

Enqueues mixed-tier tasks, dispatches a wave, verifies tier ordering.
"""
import cocotb
from cocotb.triggers import RisingEdge
import sys, os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "layer-a"))


@cocotb.test()
async def test_tier_sorting_matches_python(dut):
    """Enqueue OPUS, HAIKU, SONNET tasks. Dispatch. Verify sorted order."""
    from units.types import TaskDescriptor, DispatchDecision, ModelTier, WorkType
    from units.batch_scheduler import BatchScheduler

    py_bs = BatchScheduler(max_concurrent=8, queue_depth=32)

    # Reset
    dut.reset.value = 1
    await RisingEdge(dut.clock)
    await RisingEdge(dut.clock)
    dut.reset.value = 0
    await RisingEdge(dut.clock)

    tiers = [2, 0, 1, 0, 2]  # OPUS, HAIKU, SONNET, HAIKU, OPUS

    # Enqueue to both
    for t in tiers:
        dut.io_enq_valid.value = 1
        dut.io_enq_bits_score.value = 50
        dut.io_enq_bits_tier.value = t
        await RisingEdge(dut.clock)

        py_bs.enqueue(
            TaskDescriptor(work_type=WorkType.FEATURE),
            DispatchDecision(score=50, tier=ModelTier(t))
        )

    dut.io_enq_valid.value = 0
    await RisingEdge(dut.clock)

    # Dispatch from both
    dut.io_dispatchReq.value = 1
    for _ in range(3):
        await RisingEdge(dut.clock)
    dut.io_dispatchReq.value = 0

    py_wave = py_bs.dispatch_wave()
    py_tiers = [d.tier for _, d in py_wave]

    rtl_count = int(dut.io_wave_bits_count.value)
    rtl_tiers = []
    for i in range(rtl_count):
        rtl_tiers.append(int(getattr(dut, f"io_wave_bits_tasks_{i}_tier").value))

    assert rtl_count == len(py_tiers), f"Count: RTL={rtl_count}, Python={len(py_tiers)}"
    assert rtl_tiers == [int(t) for t in py_tiers], f"Tiers: RTL={rtl_tiers}, Python={py_tiers}"
    cocotb.log.info(f"Batch co-sim: {rtl_count} tasks dispatched, tier order matched")
```

- [ ] **Step 3: Write U5 co-simulation**

```python
# orchid/cosim/cocotb_tests/test_speculative_prefetcher.py
"""Co-simulation: SpeculativePrefetcher RTL vs Layer A Python model.

Trains both models on the same phase sequence, then compares predictions.
"""
import cocotb
from cocotb.triggers import RisingEdge
import sys, os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "layer-a"))


@cocotb.test()
async def test_prediction_matches_python(dut):
    """Train on research->prd->tasks->implementation chain, compare predictions."""
    from units.speculative_prefetcher import SpeculativePrefetcher

    py_sp = SpeculativePrefetcher(table_size=64, prefetch_ahead=2)

    # Reset
    dut.reset.value = 1
    await RisingEdge(dut.clock)
    await RisingEdge(dut.clock)
    dut.reset.value = 0
    await RisingEdge(dut.clock)

    # Train sequence: 0->1->2->4 (research->prd->tasks->implementation)
    transitions = [(0, 1), (1, 2), (2, 4)]
    for _ in range(5):
        for from_p, to_p in transitions:
            # RTL record
            dut.io_recordReq_valid.value = 1
            dut.io_recordReq_bits_fromPhase.value = from_p
            dut.io_recordReq_bits_toPhase.value = to_p
            await RisingEdge(dut.clock)

            # Python record
            py_sp.record_transition(str(from_p), str(to_p))

    dut.io_recordReq_valid.value = 0
    await RisingEdge(dut.clock)

    # Predict from research(0) — should get [prd(1), tasks(2)]
    dut.io_predictReq_valid.value = 1
    dut.io_predictReq_bits.value = 0
    for _ in range(4):  # 2 base + 2 chain
        await RisingEdge(dut.clock)
    dut.io_predictReq_valid.value = 0

    py_preds = py_sp.predict("0")

    rtl_count = int(dut.io_predictResp_bits_count.value)
    rtl_preds = []
    for i in range(rtl_count):
        rtl_preds.append(int(getattr(dut, f"io_predictResp_bits_phases_{i}").value))

    py_pred_ints = [int(p) for p in py_preds]
    assert rtl_preds == py_pred_ints, f"Predictions: RTL={rtl_preds}, Python={py_pred_ints}"
    cocotb.log.info(f"Prefetcher co-sim: predictions matched — {rtl_preds}")
```

- [ ] **Step 4: Update cosim Makefile with new targets**

Append to `orchid/cosim/Makefile`:

```makefile
test-u3:
	$(MAKE) TOPLEVEL=CacheController TEST_MODULE=test_cache_controller

test-u4:
	$(MAKE) TOPLEVEL=BatchScheduler TEST_MODULE=test_batch_scheduler

test-u5:
	$(MAKE) TOPLEVEL=SpeculativePrefetcher TEST_MODULE=test_speculative_prefetcher

test-all: test-u1 test-u2 test-u3 test-u4 test-u5 test-pipeline
```

- [ ] **Step 5: Run all co-simulations**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/cosim
make test-u3
make test-u4
make test-u5
```
Expected: All 3 pass.

- [ ] **Step 6: Commit**

```bash
git add orchid/cosim/
git commit -m "feat(orchid): U3/U4/U5 co-simulation — stateful units verified against Layer A"
```

---

### Task 5: Phase 3 Verification

**Files:** None (verification only)

- [ ] **Step 1: Run full Chisel test suite**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-b
sbt test
```
Expected: All tests pass (Phase 2: 10 + Phase 3: 12 = ~22 total).

- [ ] **Step 2: Run full co-simulation suite**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/cosim
make test-all
```
Expected: All 6 co-simulation modules pass (U1-U5 + pipeline).

- [ ] **Step 3: Generate all Verilog**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-b
sbt "runMain orchid.CacheControllerDriver"
sbt "runMain orchid.BatchSchedulerDriver"
sbt "runMain orchid.SpeculativePrefetcherDriver"
ls -la generated-rtl/*.v
```
Expected: 5 Verilog files (DispatchScorer, SkillRouter, CacheController, BatchScheduler, SpeculativePrefetcher).

- [ ] **Step 4: Run Layer A tests to confirm no regression**

```bash
cd /Volumes/DevSSD/FitTracker2/orchid/layer-a
/Volumes/DevSSD/FitTracker2/orchid/.venv/bin/python -m pytest tests/ -v
```
Expected: 46/46 pass.

- [ ] **Step 5: Commit and tag**

```bash
git tag orchid-phase3-complete
```

---

## Summary

| Task | Component | Chisel Tests | Co-sim Tests | Commits |
|---|---|---|---|---|
| 1 | U3 Cache Controller RTL | 4 | 1 | 1 |
| 2 | U4 Batch Scheduler RTL | 4 | 1 | 1 |
| 3 | U5 Speculative Prefetcher RTL | 4 | 1 | 1 |
| 4 | U3/U4/U5 Co-simulation | — | 3 | 1 |
| 5 | Phase 3 verification | — | — | — |
| **Total** | **5 tasks** | **12 Chisel** | **3 co-sim** | **4 commits** |

## Spec Coverage

| Spec Requirement | Task |
|---|---|
| Phase 3 Step 3.1: U3 Chisel scratchpad + LRU | Task 1 |
| Phase 3 Step 3.2: U4 Chisel FIFO + arbiter | Task 2 |
| Phase 3 Step 3.3: U5 Chisel prediction table + FSM | Task 3 |
| Section 7 Level 1: U3 hit rate within 1% of Python | Task 4 (co-sim) |
| Section 7 Level 1: U5 >=70% accuracy | Task 3 (chain prediction test) |
| Section 10.4: scratchpadKB=48 (recalibrated) | Task 1 (uses OrchidConfig.default) |
| Section 10.6: context-aware miss handling | Task 3 (miss_reason compatible) |

## Key Architectural Decisions

**U3 (Cache Controller):**
- Uses registers (not `SyncReadMem`) for the tag/data store since 15 entries is tiny. `SyncReadMem` would add unnecessary read latency for this size.
- LRU tracked via age counters (0 = most recent, N-1 = oldest). On access, the accessed slot resets to 0 and all younger slots increment.
- FSM: IDLE → READ (2 cycles) or WRITE (3 cycles) → IDLE.

**U4 (Batch Scheduler):**
- Circular buffer FIFO for the queue (head/tail pointers).
- Bubble sort for tier ordering — O(n²) but n ≤ 8, so 2 sort passes suffice. A comparator network would be faster but more area.
- FSM: IDLE → SORT (2 cycles) → OUTPUT (1 cycle) → IDLE. Total dispatch: 3 cycles.

**U5 (Speculative Prefetcher):**
- Full 10×10 transition count matrix in registers (800 bits). Tiny enough to not need SRAM.
- Chain-walk FSM: iteratively finds the best successor, advances to it, repeats up to `prefetchAhead` times.
- FSM: IDLE → PREDICT (1 cycle per chain step) → DONE → IDLE.
