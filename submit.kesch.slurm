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

#XL_TODO: this should be changed once the env is stable !!
module purge
module load craype-haswell
module load PrgEnv-cray
module load cudatoolkit

# Expose the netcdf and hdf5 modules
module use /home/test/ahart/global/modules

module load netcdf4/4.3.2_cce83
module load hdf5/1.8.13_cce83

module load gcc

module list -l

export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}:/opt/cray/lib64:/usr/lib64:/opt/local/slurm/default/lib64
echo $LD_LIBRARY_PATH
ldd $BINNAME


export OMP_NUM_THREADS=<CPUSPERTASK>
export MPICH_RDMA_ENABLED_CUDA=1
export MPICH_G2G_PIPELINE=256
export CRAY_CUDA_PROXY=0

<CMD>

########################################################
