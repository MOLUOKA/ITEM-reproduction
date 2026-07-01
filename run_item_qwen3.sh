#!/bin/bash
# ============================================================
# ITEM 论文复现自动化脚本（Qwen3-8B-GPTQ）
# 用法：
#   cd ITEM-main
#   bash ../run_item_qwen3.sh 2>&1 | tee run_$(date +%Y%m%d_%H%M%S).log
# 如需断点续跑，将下方对应 SKIP_STEP 改为 yes 即可
# ============================================================

set -o pipefail

# ---- 请根据你的环境修改这两行 ----
CONDA_SH="${HOME}/miniconda3/etc/profile.d/conda.sh"
CONDA_ENV="item"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="./logs"
MAIN_LOG="${LOG_DIR}/main_${TIMESTAMP}.log"

source "${CONDA_SH}" && conda activate "${CONDA_ENV}" || {
    echo "ERROR: 无法激活 conda 环境 ${CONDA_ENV}，请检查 CONDA_SH 路径"
    echo "  CONDA_SH=${CONDA_SH}"
    exit 1
}

mkdir -p "$LOG_DIR"

# ---- 断点续跑：想跳过哪些已完成步骤，设为 no 即可 ----
SKIP_STEP1="no"   # Single-shot Baselines
SKIP_STEP2="no"   # ITEM-As TREC (ExpA)
SKIP_STEP3="no"   # ITEM-As WebAP (ExpA)
SKIP_STEP4="no"   # ITEM-As-ImpA (TREC+WebAP)
SKIP_STEP5="no"   # ITEM-ARs TREC
SKIP_STEP6="no"   # ITEM-ARs WebAP
SKIP_STEP7="no"   # ITEM-Ar TREC
SKIP_STEP8="no"   # K-Sampling

# ============================================================
run_step() {
    local step_num=$1
    local step_desc=$2
    local script=$3
    local extra_args=${4:-""}

    echo ""
    echo "============================================================"
    echo " STEP ${step_num}: ${step_desc}"
    echo " Script : ${script}"
    echo " Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================================"

    local step_log="${LOG_DIR}/step${step_num}_${TIMESTAMP}.log"

    python -u "${script}" ${extra_args} 2>&1 | tee "${step_log}"
    local exit_code=${PIPESTATUS[0]}

    if [ $exit_code -ne 0 ]; then
        echo ""
        echo ">>> [FAILED] Step ${step_num} exited with code ${exit_code}"
        echo "    Check log: ${step_log}"
        echo "    Tail of error:"
        echo "============================================================"
        tail -30 "${step_log}"
        echo "============================================================"
        return 1
    fi

    echo ""
    echo "<<< [OK] Step ${step_num} finished at $(date '+%Y-%m-%d %H:%M:%S')"

    echo "${step_num}|${step_desc}|OK|$(date '+%Y-%m-%d %H:%M:%S')|${script}" >> "$MAIN_LOG"
}

# ============================================================
# Step 1: Single-shot Baselines (Vanilla, UJ-ExpA, UJ-ImpA)
# ============================================================
if [ "$SKIP_STEP1" != "yes" ]; then
    run_step 1 "Single-shot Baselines (TREC+WebAP)" "mistral/single-shot-utility-judgmentspy.py"
    if [ $? -ne 0 ]; then echo "Aborting due to Step 1 failure."; exit 1; fi
else
    echo "[SKIP] Step 1"
fi

# ============================================================
# Step 2: ITEM-As TREC (ExpA, listwise + pointwise)
# ============================================================
if [ "$SKIP_STEP2" != "yes" ]; then
    run_step 2 "ITEM-As TREC ExpA (listwise+pointwise)" "llama3/item-As-ExpA.py"
    if [ $? -ne 0 ]; then echo "Aborting due to Step 2 failure."; exit 1; fi
else
    echo "[SKIP] Step 2"
fi

# ============================================================
# Step 3: ITEM-As WebAP (ExpA, listwise + pointwise)
# ============================================================
if [ "$SKIP_STEP3" != "yes" ]; then
    run_step 3 "ITEM-As WebAP ExpA" "mistral/webap-item-As-ExpA.py"
    if [ $? -ne 0 ]; then echo "Aborting due to Step 3 failure."; exit 1; fi
else
    echo "[SKIP] Step 3"
fi

# ============================================================
# Step 4: ITEM-As-ImpA (TREC + WebAP, listwise + pointwise)
# ============================================================
if [ "$SKIP_STEP4" != "yes" ]; then
    run_step 4 "ITEM-As-ImpA (TREC+WebAP)" "mistral/item-As-ImpA.py"
    if [ $? -ne 0 ]; then echo "Aborting due to Step 4 failure."; exit 1; fi
else
    echo "[SKIP] Step 4"
fi

# ============================================================
# Step 5: ITEM-ARs TREC（三组件迭代，含相关性排序）
# ============================================================
if [ "$SKIP_STEP5" != "yes" ]; then
    run_step 5 "ITEM-ARs TREC" "mistral/TREC-item-ARs.py"
    if [ $? -ne 0 ]; then echo "Aborting due to Step 5 failure."; exit 1; fi
else
    echo "[SKIP] Step 5"
fi

# ============================================================
# Step 6: ITEM-ARs WebAP
# ============================================================
if [ "$SKIP_STEP6" != "yes" ]; then
    run_step 6 "ITEM-ARs WebAP" "mistral/webap-item-ARs.py"
    if [ $? -ne 0 ]; then echo "Aborting due to Step 6 failure."; exit 1; fi
else
    echo "[SKIP] Step 6"
fi

# ============================================================
# Step 7: ITEM-Ar TREC（效用排序方法）
# ============================================================
if [ "$SKIP_STEP7" != "yes" ]; then
    run_step 7 "ITEM-Ar TREC (utility ranking)" "mistral/trec-item-Ar.py"
    if [ $? -ne 0 ]; then echo "Aborting due to Step 7 failure."; exit 1; fi
else
    echo "[SKIP] Step 7"
fi

# ============================================================
# Step 8: K-Sampling（仅 TREC + WebAP，跳过 GTI-NQ）
# ============================================================
if [ "$SKIP_STEP8" != "yes" ]; then
    run_step 8 "K-Sampling (TREC+WebAP)" "mistral/k-sampling.py"
    if [ $? -ne 0 ]; then echo "Aborting due to Step 8 failure."; exit 1; fi
else
    echo "[SKIP] Step 8"
fi

# ============================================================
# 汇总
# ============================================================
echo ""
echo "============================================================"
echo " ALL STEPS COMPLETED — $(date '+%Y-%m-%d %H:%M:%S')"
echo " Main log: ${MAIN_LOG}"
echo " Per-step logs: ${LOG_DIR}/step*_${TIMESTAMP}.log"
echo "============================================================"
