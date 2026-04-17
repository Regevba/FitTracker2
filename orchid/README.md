# Orchid — AI Agent Orchestration Accelerator

Open-source RISC-V chip design for accelerating AI agent dispatch decisions.
This is Layer A — Python behavioral models that validate architecture before RTL.

## Quick Start

```bash
cd orchid/layer-a
python -m pytest tests/ -v
```

## Structure

- `layer-a/units/` — 7 functional units as Python modules
- `layer-a/orchestrator.py` — wires units into a pipeline
- `layer-a/trace_replayer.py` — replays traces through the pipeline
- `traces/` — real (from v6.0) and synthetic trace files
- `results/` — benchmark outputs
