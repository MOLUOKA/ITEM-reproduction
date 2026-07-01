# ITEM Reproduction with Qwen3-8B-GPTQ

This repository contains the reproduction code and results for the paper:

> **"An Iterative Utility Judgment Framework Inspired by Philosophical Relevance via LLMs"**  
> Zhang et al., ACL 2026 Findings

We reproduce the ITEM framework using a 4-bit GPTQ-quantized Qwen3-8B model on consumer-grade hardware (NVIDIA RTX 5070, 12GB VRAM) under WSL2/Ubuntu 22.04.

## Quick Links

- **Original Paper**: [arXiv 2406.11290v3](https://arxiv.org/abs/2406.11290)
- **Original Code**: [Trustworthy-Information-Access/ITEM](https://github.com/Trustworthy-Information-Access/ITEM)

## Environment

| Component | Version / Detail |
|-----------|-----------------|
| OS | Windows 11 + WSL2 (Ubuntu 22.04) |
| GPU | NVIDIA GeForce RTX 5070, 12GB VRAM |
| CUDA | 12.x |
| Python | 3.10 |
| Model | Qwen3-8B (4-bit GPTQ quantized) |
| Inference | vLLM |
| Conda Env | `item` |

## Project Structure

```
├── ITEM-main/                         # Adapted codebase (forked from original)
│   ├── data/                          # TREC-DL, WebAP, GTI-NQ, NQ datasets
│   ├── mistral/                       # Experiment scripts (adapted for Qwen3)
│   │   ├── single-shot-utility-judgmentspy.py   # Single-shot baselines
│   │   ├── trec-item-As-ExpA.py                 # ITEM-A(set) ExpA — TREC-DL
│   │   ├── webap-item-As-ExpA.py                # ITEM-A(set) ExpA — WebAP
│   │   ├── item-As-ImpA.py                      # ITEM-A(set) ImpA — Both datasets
│   │   ├── TREC-item-ARs.py                     # ITEM-AR(set) — TREC-DL
│   │   ├── webap-item-ARs.py                    # ITEM-AR(set) — WebAP
│   │   ├── trec-item-Ar.py                      # ITEM-AR(rank) — TREC-DL
│   │   └── k-sampling.py                        # K-Sampling baseline
│   ├── llama3/
│   │   └── item-As-ExpA.py                      # ITEM-A(set) ExpA (llama3 variant)
│   ├── metrics/
│   │   └── evaluate_all.py                      # Evaluation script (bug-fixed)
│   ├── utils/
│   │   └── utils.py                             # Tokenization, metrics, helpers
│   └── models/
│       └── Qwen3-8B-GPTQ/                       # 4-bit GPTQ model weights
├── run_item_qwen3.sh                  # Automated reproduction script
└── README.md
```

## Model Setup

Download Qwen3-8B-GPTQ into `ITEM-main/models/Qwen3-8B-GPTQ/`. The model is a 4-bit GPTQ-quantized version of Qwen3-8B available from Hugging Face:

```bash
# From Hugging Face (requires git-lfs)
git lfs install
git clone https://huggingface.co/AlphaGaO/Qwen3-8B-GPTQ ITEM-main/models/Qwen3-8B-GPTQ
```

The `models/` directory is gitignored and must be set up manually.

## Datasets

Both TREC-DL and WebAP are provided in `ITEM-main/data/`. The original datasets are from:

- **TREC-DL**: MS MARCO passage corpus, TREC Deep Learning tracks 2019–2020
- **WebAP**: Gov2 web corpus

GTI-NQ and NQ are excluded from this reproduction due to computational resource constraints.

## Quick Start — Automated Reproduction

The shell script `run_item_qwen3.sh` runs all experiments in sequence (8 steps, ~15 hours total):

```bash
# 1. Activate conda environment
conda activate item

# 2. Verify model and vLLM
python ITEM-main/test_vllm.py

# 3. Run the full pipeline
cd ITEM-main
bash ../run_item_qwen3.sh 2>&1 | tee run_$(date +%Y%m%d_%H%M%S).log
```

### Step-by-step breakdown

| Step | Script | Description | Approx. Time |
|------|--------|-------------|-------------|
| 1 | `mistral/single-shot-utility-judgmentspy.py` | Vanilla, UJ-ExpA, UJ-ImpA (listwise + pointwise) | 2.0 h |
| 2 | `llama3/item-As-ExpA.py` | ITEM-A(set) ExpA — TREC-DL | 2.0 h |
| 3 | `mistral/webap-item-As-ExpA.py` | ITEM-A(set) ExpA — WebAP | 2.0 h |
| 4 | `mistral/item-As-ImpA.py` | ITEM-A(set) ImpA — Both datasets | 3.0 h |
| 5 | `mistral/TREC-item-ARs.py` | ITEM-AR(set) — TREC-DL | 1.5 h |
| 6 | `mistral/webap-item-ARs.py` | ITEM-AR(set) — WebAP | 1.5 h |
| 7 | `mistral/trec-item-Ar.py` | ITEM-AR(rank) — TREC-DL | 1.5 h |
| 8 | `mistral/k-sampling.py` | K-Sampling | 1.0 h |

### Resuming from a failed step

Set the corresponding `SKIP_STEP` variable to `yes` in `run_item_qwen3.sh`:

```bash
SKIP_STEP1="yes"   # Skip single-shot baselines (already completed)
SKIP_STEP2="no"    # Run ITEM-A(set) ExpA TREC
# ...etc
```

### Evaluation

After all steps complete, run the evaluation:

```bash
python metrics/evaluate_all.py
```

This produces `metrics/evaluation_results.xlsx` with 7 sheets covering all experiments.

## Key Engineering Adaptations for Qwen3

Porting from Mistral/Llama3 to Qwen3 required several non-trivial changes:

### 1. `enable_thinking=False` (Critical)

Qwen3's chat template enables chain-of-thought reasoning by default. Without this flag, the model generates hidden reasoning traces that are mistakenly parsed as structured output, causing `clean_response()` to fail. This parameter must be added to **every** `apply_chat_template()` call:

```python
tokenizer.apply_chat_template(
    messages,
    tokenize=False,
    add_generation_prompt=True,
    enable_thinking=False   # ← REQUIRED for Qwen3
)
```

Added to 16+ call sites across 8 Python scripts.

### 2. `trust_remote_code=True`

Required for Qwen3's custom tokenizer configuration:

```python
llm = LLM(
    model="./models/Qwen3-8B-GPTQ",
    trust_remote_code=True,        # ← REQUIRED
    gpu_memory_utilization=0.85,
    max_model_len=16384
)
```

### 3. Phantom imports removed

Seven scripts imported `utils.template` and `utils.prompt` — these modules do not exist in the repository. Removed.

### 4. Data key inconsistencies

Scripts access the same fields under different key names (`passage` vs. `passages`, `ground_truth_label` vs. `labels`). Added compatibility checks to all data-loading paths.

### 5. Missing dependencies

- `rouge` package requires `six` (not listed as a dependency)
- Accidentally stripped `import json` and `import argparse` from `llama3/item-As-ExpA.py` during cleanup; restored.

### 6. GTI-NQ and NQ excluded

GTI-NQ and NQ are excluded from this reproduction due to computational resource constraints.

## Evaluation Bug Fix

Discovered and corrected a bug in `metrics/evaluate_all.py`:

**Problem**: The `evaluate_single_shot` function parsed pointwise outputs by comparing each element to the integer `1`:

```python
selected = [i for i, v in enumerate(raw) if v == 1]
```

Since each element of `raw` is a string (e.g., "My judgment: Yes, the passage has utility..."), the comparison always evaluated to `False`, producing an empty utility set and 0.00 for all pointwise metrics.

**Fix**: Use the `model_out_label` field (correctly populated as a 0/1 list by the inference script) with a fallback to string matching:

```python
if isinstance(raw, str):
    selected = clean_response_to_indices(raw)
else:
    ml = js.get("model_out_label", [])
    if ml:
        selected = [i for i, v in enumerate(ml) if v == 1]
    else:
        selected = [i for i, v in enumerate(raw) if isinstance(v, str) and 'yes' in v.lower()]
```

This correction changed pointwise baseline F1 from 0.00 to 24.23–49.74%.

## Key Results Summary

| Method | TREC-DL F1 | WebAP F1 |
|--------|-----------|----------|
| Vanilla (Pointwise) | **49.74** | **30.37** |
| ITEM-A(set) ExpA (Listwise) | 49.16 | 25.90 |
| ITEM-A(set) ExpA (Pointwise) | 47.83 | 31.12 |
| ITEM-A(set) ImpA (Listwise) | 45.59 | 25.47 |
| ITEM-AR(set) ExpA | 43.52 | 22.62 |
| ITEM-AR(rank) | 35.60 | — |
| K-Sampling | 38.55 | 14.77 |

## Divergences from Original Paper

1. **Pointwise ≥ Listwise**: Pointwise baselines are competitive with or better than listwise, contrary to the expected advantage of listwise prompting on this model.
2. **ITEM-AR(set) < ITEM-A(set)**: Three-component iteration underperforms two-component, contrary to the claim that relevance ranking helps.
3. **Iteration peaks at round 1–2**: Performance degrades after round 2; no monotonic improvement.
4. **K-Sampling underperforms**: Majority voting over 5 random orders does not improve results on this model.

## Citation

If you use this reproduction in your research, please cite the original paper:

```bibtex
@inproceedings{zhang_iterative_2026,
  title     = {An Iterative Utility Judgment Framework Inspired by Philosophical Relevance via {LLMs}},
  author    = {Zhang, et al.},
  booktitle = {Findings of ACL},
  year      = {2026}
}
```

## License

This reproduction work is released for academic use. The original ITEM codebase is from the paper authors: [Trustworthy-Information-Access/ITEM](https://github.com/Trustworthy-Information-Access/ITEM). Model weights follow Qwen3's license terms.
