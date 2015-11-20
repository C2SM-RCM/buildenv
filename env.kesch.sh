#!/bin/bash

# This script contains functions for setting up machine specific compile
# environments for the dycore and the Fortran parts. Namely, the following
# functions must be defined in this file:
#
# setupDefaults            setup global default options for this platform
# setCppEnvironment        setup environment for dycore compilation
# unsetCppEnvironment      restore environment after dycore compilation
# setFortranEnvironment    setup environment for Fortran compilation
# unsetFortranEnvironment  restore environment after Fortran compilation

writeModuleEnv()
{
    module list -t 2>&1 | grep -v alps | grep -v '^- Package' | grep -v '^Currently Loaded' | sed 's/^/module load /g' > $1
}

createModuleCheckPoint()
{
    previous_module_tmp=$(mktemp)
    writeModuleEnv ${previous_module_tmp}
    module purge
}

restoreModuleCheckPoint()
{
    module purge
    source ${previous_module_tmp}
    rm ${previous_module_tmp}
    unset previous_module_tmp
}

# Setup global defaults and variables
#
# upon exit, the following global variables need to be set:
#   targets           list of possible targets (e.g. gpu, cpu)
#   compilers         list of possible compilers for Fortran parts
#   target            default target
#   compiler          default compiler to use for Fortran parts
#   debug             build in debugging mode (yes/no)
#   cleanup           clean before build (yes/no)
#   cuda_arch         CUDA architecture version to use (e.g. sm_35, use blank for CPU target)
#
setupDefaults()
{
    # available options
    targets=(cpu gpu)
    compilers=(gnu cray)
    fcompiler_cmds=(ftn)


    export BASE_MODULES="craype-haswell cmake/3.1.3"
    export NVIDIA_CUDA_ARCH="sm_37"

    # # MVAPICH
    export MVAPICH_MODULE="mvapich2gdr_gnu/2.1"
    # # BOOST
    export BOOST_PATH=/apps/escha/easybuild/software/Boost/1.49.0-gmvolf-2015b-Python-2.7.10/include

    # default options
    if [ -z "${target}" ] ; then
        target="gpu"
    fi
    if [ -z "${compiler}" ] ; then
        compiler="cray"
    fi
    if [ -z "${cuda_arch}" ] ; then
        cuda_arch="${NVIDIA_CUDA_ARCH}"
    fi

    # fortran compiler command
    if [ -z "${fcompiler_cmd}" ] ; then
        if [ "${compiler}" == "gnu" ] ; then
            fcompiler_cmd="gfortran"
        else
            fcompiler_cmd="ftn"
        fi
    fi
}

# This function loads modules and sets up variables for compiling in C++
#
# upon entry, the following global variables need to be set:
#   compiler          Compiler to use to compile the Fortran parts of the code
#
# upon exit, the following global variables need to be set:
#   old_prgenv        Default PrgEnv-XXX module loaded on Cray machines
#   dycore_gpp        C++ compiler for dycore
#   dycore_gcc        C compiler for dycore
#   cuda_gpp          C++ used by nvcc as backend
#   boost_path        path to the Boost installation to use
#   use_mpi_compiler  use MPI compiler wrappers?
#
setCppEnvironment()
{
    createModuleCheckPoint

    old_prgenv=`module list -t 2>&1 | grep 'PrgEnv-'`

    case "${compiler}" in
    gnu )
        # Do nothing
        ;;
    * )
        echo "Note : ${compiler} is not supported on kesch for c++ compilation, forcing gnu"
        ;;
    esac

    export ENVIRONMENT_TEMPFILE=$(mktemp)
    cat > $ENVIRONMENT_TEMPFILE <<- EOF
        # Generated with the build script
        # implicit module purge
        module load craype-haswell
        module load craype-network-infiniband
        module load mvapich2gdr_gnu/2.1_cuda_7.0
        module load GCC/4.9.3-binutils-2.25
        module load cray-libsci_acc/3.3.0
EOF
   
    module purge
    source $ENVIRONMENT_TEMPFILE
    dycore_gpp='g++'
    dycore_gcc='gcc'
    cuda_gpp='g++'
    boost_path="${BOOST_PATH}"
    #cudatk_include_path="${cudatk_path}"
    use_mpi_compiler=OFF

        # set global variables
    if [ "${compiler}" == "gnu" ] ; then
        dycore_openmp=ON   # OpenMP only works if GNU is also used for Fortran parts
    else
        dycore_openmp=OFF  # Otherwise, switch off
    fi
    
    export OLD_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}
}

# This function unloads modules and removes variables for compiling in C++
#
# upon entry, the following global variables need to be set:
#   compiler          Compiler to use to compile the Fortran parts of the code
#   old_prgenv        Default PrgEnv-XXX module loaded on Cray machines
#
unsetCppEnvironment()
{
    restoreModuleCheckPoint
    
    rm $ENVIRONMENT_TEMPFILE
    unset ENVIRONMENT_TEMPFILE

    unset dycore_openmp
    unset dycore_gpp
    unset dycore_gcc
    unset cuda_gpp
    unset boost_path
    unset use_mpi_compiler

    unset old_prgenv

    export LD_LIBRARY_PATH=${OLD_LD_LIBRARY_PATH}
    unset OLD_LD_LIBRARY_PATH
}

# This function loads modules and sets up variables for compiling the Fortran part
#
# upon entry, the following global variables need to be set:
#   compiler          Compiler to use to compile the Fortran part of the code
#
# upon exit, the following global variables need to be set:
#   old_prgenv        Default PrgEnv-XXX module loaded on Cray machines
#
setFortranEnvironment()
{
    createModuleCheckPoint

    old_prgenv=`module list -t 2>&1 | grep 'PrgEnv-'`

    export ENVIRONMENT_TEMPFILE=$(mktemp)
    
    case "${compiler}" in
    cray )
        # Copied from
        # https://github.com/eth-cscs/mchquickstart/blob/master/mpicuda/readme.cce


        ;;
    gnu )
        # Copied from
        # https://github.com/eth-cscs/mchquickstart/blob/master/mpicuda/readme.gnu
        echo "GNU Fortran is not supported at the moment, forcing cray"
        ;;
    * )
        echo "ERROR: Unsupported compiler encountered in setCppEnvironment" 1>&2
        exit 1
    esac
   
    cat > $ENVIRONMENT_TEMPFILE <<-EOF
        # Generated with the build script
        # implicit module purge
        module load craype-haswell
        module load craype-accel-nvidia35
        module load PrgEnv-cray/15.10_cuda_7.0
        module load cmake/3.1.3
        module swap cce/8.4.0a
        module unload mvapich2_cce
        module load cray-libsci_acc/3.3.0
        module load mvapich2gdr_gnu/2.1_cuda_7.0
        module load cray-netcdf/4.3.2
        module load cray-hdf5/1.8.13
        module load GCC/4.9.3-binutils-2.25
EOF
    module purge
    source $ENVIRONMENT_TEMPFILE

    export OLD_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}
}

# This function unloads modules and removes variables for compiling the Fortran parts
#
# upon entry, the following global variables need to be set:
#   compiler          Compiler to use to compile the Fortran parts of the code
#   old_prgenv        Default PrgEnv-XXX module loaded on Cray machines
#
unsetFortranEnvironment()
{
    restoreModuleCheckPoint

    rm $ENVIRONMENT_TEMPFILE
    unset ENVIRONMENT_TEMPFILE

    unset old_prgenv

    export LD_LIBRARY_PATH=${OLD_LD_LIBRARY_PATH}
    unset OLD_LD_LIBRARY_PATH
}

