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
unset G2G

# Default grib_api ressources
if ([ -z $GRIB_DEFINITION_PATH ]) then
    GRIBAPI_DIR=/project/c14/install/tsa/libgrib_api/${GRIBAPI_COSMO_RESOURCES_VERSION}/pgi
    echo "GRIBAPI_DIR=$GRIBAPI_DIR"
    source $GRIBAPI_DIR/configuration.sh
fi

<CMD>

########################################################
