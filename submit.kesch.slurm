#!/bin/bash
#SBATCH --job-name=<NAME>
#SBATCH --ntasks=<NTASKS>
#SBATCH --ntasks-per-node=<NTASKSPERNODE>
#SBATCH --cpus-per-task=<CPUSPERTASK>
#SBATCH --output=<OUTFILE>
#SBATCH --time=00:30:00
#SBATCH --gres=gpu:1
#SBATCH --partition=debug
#SBATCH --account=s83

########################################################

set -x
#We have to source the appropiate module_xxx.env before launching this submit script
module list -l

ldd $BINNAME

export OMP_NUM_THREADS=1
export MALLOC_MMAP_MAX_=0
export MALLOC_TRIM_THRESHOLD_=536870912
export G2G=1
export MV2_USE_GPUDIRECT=0 #with this perf are ok


<CMD>

########################################################
