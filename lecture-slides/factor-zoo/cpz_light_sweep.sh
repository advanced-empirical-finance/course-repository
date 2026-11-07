#!/usr/bin/env bash
# Hyperparameter search for cpz_light.py, meant for a GPU machine such as UCloud.
# Every run appends its settings and Sharpe ratios to
# lecture-slides/factor-zoo/results/cpz_light_runs.csv.
#
# Run from the course repository: bash lecture-slides/factor-zoo/cpz_light_sweep.sh
set -euo pipefail

seeds=9   # ensemble size, as in Chen, Pelger & Zhu

for hidden in 32 64 128; do
  for dropout in 0 0.05 0.2; do
    for weight_decay in 1e-5 1e-3; do
      for pcs in 0 10; do
        for macro in "" "--no-macro"; do
          echo "hidden=$hidden dropout=$dropout weight_decay=$weight_decay pcs=$pcs $macro"
          uv run --quiet lecture-slides/factor-zoo/cpz_light.py \
            --seeds "$seeds" --hidden "$hidden" --dropout "$dropout" \
            --weight-decay "$weight_decay" --pcs "$pcs" $macro
        done
      done
    done
  done
done
