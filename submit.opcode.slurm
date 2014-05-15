#!/bin/bash
#SBATCH --job-name=<NAME>
#SBATCH --nodes=<NTASKS>
#SBATCH --output=<OUTFILE>
#SBATCH --time=00:30:00
#SBATCH --partition=primary
#SBATCH --nodelist=opcode3
#SBATCH --gres=gpu:8

########################################################

set -x
export OMP_NUM_THREADS=1
export MV2_USE_CUDA=0

<CMD>

########################################################
