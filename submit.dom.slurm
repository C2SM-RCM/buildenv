#!/bin/bash
#SBATCH --job-name=<NAME>
#SBATCH --ntasks=<NTASKS>
#SBATCH --output=<OUTFILE>
#SBATCH --time=00:30:00
#SBATCH --gres=gpu:2
#SBATCH --account=c01

########################################################

set -x
export OMP_NUM_THREADS=1
export MV2_USE_CUDA=0

<CMD>

########################################################
