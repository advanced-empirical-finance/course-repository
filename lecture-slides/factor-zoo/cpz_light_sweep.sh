#!/usr/bin/env bash
# Hyperparameter search for cpz_light.py: 72 settings, 9 networks per ensemble.
# Every run appends its settings and Sharpe ratios to
# lecture-slides/factor-zoo/results/cpz_light_runs.csv.
#
# Run from the course repository:
#   bash lecture-slides/factor-zoo/cpz_light_sweep.sh
# Several settings side by side on a CPU machine, e.g. 64 vCPUs:
#   JOBS=64 THREADS=1 bash lecture-slides/factor-zoo/cpz_light_sweep.sh
# JOBS: settings that run at the same time; THREADS: CPU threads per setting.
set -euo pipefail

jobs="${JOBS:-1}"
threads="${THREADS:-$(nproc)}"
seeds=9   # ensemble size, as in Chen, Pelger & Zhu
script=lecture-slides/factor-zoo/cpz_light.py
logs=lecture-slides/factor-zoo/logs
mkdir -p "$logs"

settings() {
  for hidden in 32 64 128; do
    for dropout in 0 0.05 0.2; do
      for weight_decay in 1e-5 1e-3; do
        for pcs in 0 10; do
          for macro in "" "--no-macro"; do
            echo "--hidden $hidden --dropout $dropout --weight-decay $weight_decay --pcs $pcs $macro"
          done
        done
      done
    done
  done
}

# Install the dependencies and download the data once, before the runs start
uv run --quiet "$script" --prepare

export script seeds threads logs
settings | xargs -P "$jobs" -I{} bash -c '
  name=$(echo "{}" | tr -d "-" | tr " " "_")
  echo "$(date +%H:%M:%S) start {}"
  OMP_NUM_THREADS=$threads uv run --quiet "$script" --seeds "$seeds" {} > "$logs/$name.log" 2>&1 \
    && echo "$(date +%H:%M:%S) done  {}" \
    || echo "$(date +%H:%M:%S) FAILED {} (see $logs/$name.log)"
'
echo "all settings finished"
