#!/bin/bash
#SBATCH --job-name=<NAME>
#SBATCH --ntasks=<NTASKS>
#SBATCH --output=<OUTFILE>
#SBATCH --time=00:30:00
#SBATCH --gres=gpu:1
#SBATCH --account=c01

########################################################

set -x
export OMP_NUM_THREADS=1

<CMD>

########################################################
