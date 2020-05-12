#!/bin/bash
#SBATCH --constraint=gpu
#SBATCH --job-name=<NAME>
#SBATCH --ntasks=<NTASKS>
#SBATCH --ntasks-per-node=<NTASKSPERNODE>
#SBATCH --cpus-per-task=<CPUSPERTASK>
#SBATCH --output=<OUTFILE>
#SBATCH --time=00:45:00
#SBATCH --gres=gpu:1
#SBATCH --account=c14

########################################################

set -x
export OMP_NUM_THREADS=<CPUSPERTASK>
export MPICH_RDMA_ENABLED_CUDA=1
export MPICH_G2G_PIPELINE=256
export CRAY_CUDA_PROXY=0

# Default grib_api ressources
if ([ -z $GRIB_DEFINITION_PATH ]) then
    GRIBAPI_DIR=/project/c14/install/tsa/libgrib_api/${GRIBAPI_COSMO_RESOURCES_VERSION}/pgi
    echo "GRIBAPI_DIR=$GRIBAPI_DIR"
    source $GRIBAPI_DIR/configuration.sh
fi

<CMD>

########################################################
