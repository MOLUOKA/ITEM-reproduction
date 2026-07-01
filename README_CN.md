# ITEM 框架复现：基于 Qwen3-8B-GPTQ

本仓库包含对以下论文的复现代码与实验结果：

> **"An Iterative Utility Judgment Framework Inspired by Philosophical Relevance via LLMs"**  
> Zhang et al., ACL 2026 Findings

我们使用 4-bit GPTQ 量化的 Qwen3-8B 模型在消费级硬件（NVIDIA RTX 5070, 12GB 显存）上复现了 ITEM 框架的核心实验，实验环境为 WSL2 / Ubuntu 22.04。

## 快速导航

- **原论文**: [arXiv 2406.11290v3](https://arxiv.org/abs/2406.11290)
- **官方代码**: [Trustworthy-Information-Access/ITEM](https://github.com/Trustworthy-Information-Access/ITEM)

## 实验环境

| 组件 | 版本 / 详情 |
|------|-------------|
| 操作系统 | Windows 11 + WSL2 (Ubuntu 22.04) |
| GPU | NVIDIA GeForce RTX 5070, 12GB 显存 |
| CUDA | 12.x |
| Python | 3.10 |
| 模型 | Qwen3-8B（4-bit GPTQ 量化） |
| 推理框架 | vLLM |
| Conda 环境 | `item` |

## 项目结构

```
├── ITEM-main/                         # 适配后的代码（基于官方仓库修改）
│   ├── data/                          # TREC-DL、WebAP 等数据集
│   ├── mistral/                       # 实验脚本（已适配 Qwen3）
│   │   ├── single-shot-utility-judgmentspy.py   # 单次基线（Vanilla / UJ-ExpA / UJ-ImpA）
│   │   ├── trec-item-As-ExpA.py                 # ITEM-A(set) ExpA — TREC-DL
│   │   ├── webap-item-As-ExpA.py                # ITEM-A(set) ExpA — WebAP
│   │   ├── item-As-ImpA.py                      # ITEM-A(set) ImpA — 两个数据集
│   │   ├── TREC-item-ARs.py                     # ITEM-AR(set) — TREC-DL
│   │   ├── webap-item-ARs.py                    # ITEM-AR(set) — WebAP
│   │   ├── trec-item-Ar.py                      # ITEM-AR(rank) — TREC-DL
│   │   └── k-sampling.py                        # K-Sampling 基线
│   ├── llama3/
│   │   └── item-As-ExpA.py                      # ITEM-A(set) ExpA（Llama3 变体）
│   ├── metrics/
│   │   └── evaluate_all.py                      # 评估脚本（已修复 bug）
│   ├── utils/
│   │   └── utils.py                             # 分词器、指标、辅助函数
│   └── models/
│       └── Qwen3-8B-GPTQ/                       # 4-bit GPTQ 模型权重
├── run_item_qwen3.sh                  # 一键复现脚本
└── README.md
```

## 模型准备

将 Qwen3-8B-GPTQ 下载到 `ITEM-main/models/Qwen3-8B-GPTQ/`。该模型为 4-bit GPTQ 量化版本，可从 Hugging Face 获取：

```bash
# 从 Hugging Face 下载（需要 git-lfs）
git lfs install
git clone https://huggingface.co/AlphaGaO/Qwen3-8B-GPTQ ITEM-main/models/Qwen3-8B-GPTQ
```

`models/` 目录已被 `.gitignore` 忽略，需手动设置。

## 数据集

TREC-DL 和 WebAP 两个数据集已包含在 `ITEM-main/data/` 中。原始数据来源：

- **TREC-DL**: MS MARCO 段落语料库，TREC Deep Learning 2019–2020 赛道
- **WebAP**: Gov2 网页语料库

GTI-NQ 和 NQ 因算力限制未被纳入本次复现。

## 快速开始——一键复现

脚本 `run_item_qwen3.sh` 按顺序执行 8 个步骤，总计约 15 小时：

```bash
# 1. 激活 conda 环境
conda activate item

# 2. 验证模型和 vLLM
python ITEM-main/test_vllm.py

# 3. 运行全流程
cd ITEM-main
bash ../run_item_qwen3.sh 2>&1 | tee run_$(date +%Y%m%d_%H%M%S).log
```

### 步骤分解

| 步骤 | 脚本 | 说明 | 约需时间 |
|------|------|------|---------|
| 1 | `mistral/single-shot-utility-judgmentspy.py` | Vanilla, UJ-ExpA, UJ-ImpA（listwise + pointwise） | 2.0 h |
| 2 | `llama3/item-As-ExpA.py` | ITEM-A(set) ExpA — TREC-DL | 2.0 h |
| 3 | `mistral/webap-item-As-ExpA.py` | ITEM-A(set) ExpA — WebAP | 2.0 h |
| 4 | `mistral/item-As-ImpA.py` | ITEM-A(set) ImpA — 两个数据集 | 3.0 h |
| 5 | `mistral/TREC-item-ARs.py` | ITEM-AR(set) — TREC-DL | 1.5 h |
| 6 | `mistral/webap-item-ARs.py` | ITEM-AR(set) — WebAP | 1.5 h |
| 7 | `mistral/trec-item-Ar.py` | ITEM-AR(rank) — TREC-DL | 1.5 h |
| 8 | `mistral/k-sampling.py` | K-Sampling | 1.0 h |

### 断点续跑

在 `run_item_qwen3.sh` 中将已完成步骤的 `SKIP_STEP` 设为 `yes`：

```bash
SKIP_STEP1="yes"   # 已完成的单次基线实验跳过
SKIP_STEP2="no"    # 运行 ITEM-A(set) ExpA TREC
# ...
```

### 评估

全部步骤完成后运行评估：

```bash
python metrics/evaluate_all.py
```

输出为 `metrics/evaluation_results.xlsx`，包含 7 个工作表，覆盖全部实验。

## Qwen3 适配的关键工程问题

从 Mistral/Llama3 迁移到 Qwen3 需要处理以下非平凡问题：

### 1. `enable_thinking=False`（最关键）

Qwen3 的聊天模板默认启用思维链推理。若不关闭，模型会生成隐式推理轨迹，被误析为结构化输出导致 `clean_response()` 失败。必须在 **每一处** `apply_chat_template()` 调用中加入此参数：

```python
tokenizer.apply_chat_template(
    messages,
    tokenize=False,
    add_generation_prompt=True,
    enable_thinking=False   # ← Qwen3 必须设置
)
```

共在 8 个 Python 脚本的 16+ 处调用位置添加。

### 2. `trust_remote_code=True`

Qwen3 使用了自定义分词器配置，需要信任远程代码：

```python
llm = LLM(
    model="./models/Qwen3-8B-GPTQ",
    trust_remote_code=True,        # ← 必需
    gpu_memory_utilization=0.85,
    max_model_len=16384
)
```

### 3. 删除不存在的引用

7 个脚本引用了 `utils.template` 和 `utils.prompt`，这两个模块在原仓库中并不存在，已全部移除。

### 4. 数据字段命名不一致

不同脚本以不同键名访问相同字段（`passage` vs. `passages`，`ground_truth_label` vs. `labels`）。已在所有数据读取路径添加兼容性检查。

### 5. 缺失依赖

- `rouge` 包的隐式依赖 `six` 未在 `requirements.txt` 中列出
- 在清理过程中意外删除了 `llama3/item-As-ExpA.py` 中的 `import json` 和 `import argparse`，导致运行时失败，已恢复

### 6. 排除 GTI-NQ 和 NQ

GTI-NQ 和 NQ 因算力限制未被纳入本次复现。

## 评估脚本 Bug 修复

在 `metrics/evaluate_all.py` 中发现并修复了一个 Bug：

**问题**：`evaluate_single_shot` 函数在解析 pointwise 输出时，将每个元素与整数 `1` 进行比较：

```python
selected = [i for i, v in enumerate(raw) if v == 1]
```

由于 `raw` 的每个元素是字符串（如 "My judgment: Yes, the passage has utility..."），比较永远为 `False`，导致所有 pointwise 指标的 F1 均为 0.00。

**修复**：改用推理脚本已经正确计算好的 `model_out_label` 字段（0/1 列表），并增加字符串兜底判断：

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

修复后 pointwise 基线 F1 从统一为 0.00 恢复为 24.23–49.74%。

## 主要结果

| 方法 | TREC-DL F1 | WebAP F1 |
|------|-----------|----------|
| Vanilla (Pointwise) | **49.74** | **30.37** |
| ITEM-A(set) ExpA (Listwise) | 49.16 | 25.90 |
| ITEM-A(set) ExpA (Pointwise) | 47.83 | 31.12 |
| ITEM-A(set) ImpA (Listwise) | 45.59 | 25.47 |
| ITEM-AR(set) ExpA | 43.52 | 22.62 |
| ITEM-AR(rank) | 35.60 | — |
| K-Sampling | 38.55 | 14.77 |

## 与原论文的差异

1. **Pointwise ≥ Listwise**：Pointwise 基线在 Qwen3-8B-GPTQ 上与 listwise 持平或更优，与原文 listwise 更优的预期不一致。
2. **ITEM-AR(set) < ITEM-A(set)**：三组件迭代不如双组件，与原文加入相关性排序能提升性能的说法相悖。
3. **迭代在 1–2 轮达到峰值**：第 2 轮后性能下降，不存在原文描述的持续单调提升。
4. **K-Sampling 全面落后**：在 5 次随机排序上的多数投票在此模型上不能提升效果。

## 引用

若您的研究使用了本复现工作，请引用原论文：

```bibtex
@inproceedings{zhang_iterative_2026,
  title     = {An Iterative Utility Judgment Framework Inspired by Philosophical Relevance via {LLMs}},
  author    = {Zhang, et al.},
  booktitle = {Findings of ACL},
  year      = {2026}
}
```

## 许可证

本复现工作仅供学术使用。原始 ITEM 代码版权归原作者所有：<https://github.com/Trustworthy-Information-Access/ITEM>，模型权重遵循 Qwen3 的许可条款。
