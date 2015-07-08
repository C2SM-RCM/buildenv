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
    compilers=(cray)
    fcompiler_cmds=(ftn)

    cudatk_path="/global/opt/nvidia/cudatoolkit/6.5.14"

    # default options
    if [ -z "${target}" ] ; then
        target="gpu"
    fi
    if [ -z "${compiler}" ] ; then
        compiler="cray"
    fi
    if [ -z "${cuda_arch}" ] ; then
        cuda_arch="sm_35"
    fi

    # fortran compiler command
    if [ -z "${fcompiler_cmd}" ] ; then
        fcompiler_cmd="ftn"
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
#   mpi_path          path to the MPI installation to use
#
setCppEnvironment()
{
    echo 'Setting up CPP Environment'
    echo '=========================='
    # switch to programming environment (only on Cray)
    #old_prgenv=" "
    old_prgenv=`module list -t 2>&1 | grep 'PrgEnv-'`
    if [ -z "${old_prgenv}" ] ; then
        module load PrgEnv-cray
    else
        module switch ${old_prgenv} PrgEnv-cray
    fi

    #  module list
    
    module load craype-ivybridge
    # standard modules (part 1)
    module load cmake
    module unload gcc
    module load gcc/4.8.0
    module unload mvapich
    module unload mvapich2_cce
    module load mvapich/2.0.2

    if [ "${target}" == "gpu" ] ; then
        module unload cudatoolkit
        module unload craype-accel-nvidia35
        module load craype-accel-nvidia35
    fi
    old_ldlibrarypath=${LD_LIBRARY_PATH}
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${CRAY_LD_LIBRARY_PATH}

    # Fortran compiler specific modules and setup
    case "${compiler}" in
    cray )
        module unload cce
        module load cce/8.3.8.102
        ;;
    * )
        echo "ERROR: Unsupported compiler encountered in setCppEnvironment" 1>&2
        exit 1
    esac

    # standard modules (part 2)

    # set global variables
    if [ "${compiler}" == "gnu" ] ; then
        dycore_openmp=ON   # OpenMP only works if GNU is also used for Fortran parts
    else
        dycore_openmp=OFF  # Otherwise, switch off
    fi
    dycore_gpp='g++'
    dycore_gcc='gcc'
    cuda_gpp='g++'
    boost_path=/cray/css/pe_tools/malice/builds/cosmo/2015Feb17/COSMO/n17183.install/boost/1.49/include
    cudatk_include_path=/global/opt/nvidia/cudatoolkit/6.5.14
    use_mpi_compiler=OFF
    mpi_path=/opt/cray/mvapich/${mpi_vers}/cray/8.3

    module list 
    echo 'DONE Setting up CPP Environment'
    echo '==============================='
}

# This function unloads modules and removes variables for compiling in C++
#
# upon entry, the following global variables need to be set:
#   compiler          Compiler to use to compile the Fortran parts of the code
#   old_prgenv        Default PrgEnv-XXX module loaded on Cray machines
#
unsetCppEnvironment()
{
    echo 'UNsetting  CPP Environment'
    echo '=========================='
    # remove standard modules (part 2)

    # remove Fortran compiler specific modules
    case "${compiler}" in
    cray )
        ;;
    * )
        echo "ERROR: Unsupported compiler encountered in unsetCppEnvironment" 1>&2
        exit 1
    esac

    # remove standard modules (part 1)
    module unload cmake
    module unload craype-ivybridge
    export LD_LIBRARY_PATH=${old_ldlibrarypath}
    old_ldlibrarypath=""
    if [ "${target}" == "gpu" ] ; then
        module unload cudatoolkit
        module unload craype-accel-nvidia35
    fi
    module unload mvapich
    module unload mvapich2_cce
    module load mvapich2_cce/1.9_cray83
    module unload gcc/4.8.0

    # restore programming environment (only on Cray)
    if [ -z "${old_prgenv}" ] ; then
        module unload PrgEnv-cray
    else
        module switch PrgEnv-cray ${old_prgenv}
    fi
    unset old_prgenv

    # unset global variables
    unset dycore_openmp
    unset dycore_gpp
    unset dycore_gcc
    unset cuda_gpp
    unset boost_path
    unset use_mpi_compiler
    unset mpi_path

    module list
    echo 'DONE UNsetting  CPP Environment'
    echo '==============================='
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
    echo 'Setting up Fortran Environment'
    echo '=============================='
    # switch to GNU programming environment (only on Cray machines)
    #old_prgenv=" "
    old_prgenv=`module list -t 2>&1 | grep 'PrgEnv-'`
    if [ -z "${old_prgenv}" ] ; then
        module load PrgEnv-${compiler}
    else
        module swap ${old_prgenv} PrgEnv-${compiler}
    fi
    module load craype-ivybridge

    # standard modules (part 1)
    module load cmake
    module unload gcc
    module load gcc/4.8.0
    module unload mvapich
    module unload mvapich2_cce
    module load mvapich/2.0.2

    if [ "${target}" == "gpu" ] ; then
        module unload cudatoolkit
        module unload craype-accel-nvidia35
        module load craype-accel-nvidia35
    fi

    old_ldlibrarypath=${LD_LIBRARY_PATH}
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${CRAY_LD_LIBRARY_PATH}

    # compiler specific modules
    case "${compiler}" in
    cray )
        module unload cce
        module load cce/8.3.8.102
        ;;
    * )
        echo "ERROR: Unsupported compiler encountered in setFortranEnvironment" 1>&2
        exit 1
    esac

    # standard modules (part 2)
    module load netcdf4/4.3.2_cce83
    module list
    echo 'DONE Setting up Fortran Environment'
    echo '==================================='
}

# This function unloads modules and removes variables for compiling the Fortran parts
#
# upon entry, the following global variables need to be set:
#   compiler          Compiler to use to compile the Fortran parts of the code
#   old_prgenv        Default PrgEnv-XXX module loaded on Cray machines
#
unsetFortranEnvironment()
{
    echo 'UNsetting Fortran Environment'
    echo '============================='
    # remove standard modules (part 2)
    module unload netcdf4/4.3.2_cce83


    # remove compiler specific modules
    case "${compiler}" in
    cray )
        module swap cce cce
        ;;
    * )
        echo "ERROR: Unsupported compiler encountered in unsetFortranEnvironment" 1>&2
        exit 1
    esac

    # remove standard modules (part 1)
    module unload cmake
    module unload craype-ivybridge

    export LD_LIBRARY_PATH=${old_ldlibrarypath}
    old_ldlibrarypath=""
    if [ "${target}" == "gpu" ] ; then
        module unload cudatoolkit
        module unload craype-accel-nvidia35
    fi
    module unload mvapich
    module unload mvapich2_cce
    module load mvapich2_cce/1.9_cray83
    module unload gcc



    # swap back to original programming environment (only on Cray machines)
    if [ -z "${old_prgenv}" ] ; then
        module unload PrgEnv-${compiler}
    else
        module swap PrgEnv-${compiler} ${old_prgenv}
    fi
    unset old_prgenv
    module list
    echo 'DONE UNsetting Fortran Environment'
    echo '=================================='
}

