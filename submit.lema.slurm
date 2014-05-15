#!/bin/bash
#SBATCH --job-name=<NAME>
#SBATCH --ntasks=<NTASKS>
#SBATCH --output=<OUTFILE>
#SBATCH --time=00:30:00
#SBATCH --partition=debug

########################################################

set -x
export OMP_NUM_THREADS=1

<CMD>

########################################################
