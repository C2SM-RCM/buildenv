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
    compilers=(gnu cray)
    fcompiler_cmds=(gfortran)

    export BOOST_PATH="/apps/escha/easybuild/software/Boost/1.49.0-gmvolf-2015b-Python-2.7.10/"

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

    module load gcc/4.8.4
    #we need a decent cmake version in order to pass the HOST_COMPILER to nvcc
    module load /home/cosuna/privatemodules/cmake-3.3.2
    module load python/3.4.3
    module load boost/1.56_gcc4.8.4
    module load mvapich2/gcc/64/2.0-gcc-4.8.2-cuda-6.0
    module load cuda70/toolkit/7.0.28
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD:${VENV_PATH}/lib/python3.4/site-packages/PySide-1.2.2-py3.4-linux-x86_64.egg/PySide
    export CUDATOOLKIT_HOME=${CUDA_ROOT}


    case "${compiler}" in
    cray )
        ;;
    gnu )
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
    boost_path="${BOOST_PATH}/include"
    use_mpi_compiler=OFF
    mpi_path=${CRAY_MPICH2_DIR}
    old_prgenv="none"
}

# This function unloads modules and removes variables for compiling in C++
#
# upon entry, the following global variables need to be set:
#   compiler          Compiler to use to compile the Fortran parts of the code
#   old_prgenv        Default PrgEnv-XXX module loaded on Cray machines
#
unsetCppEnvironment()
{
    # remove standard modules (part 2)

    # remove Fortran compiler specific modules
    case "${compiler}" in
    cray )
        ;;
    gnu )
        ;;
    * )
        echo "ERROR: Unsupported compiler encountered in unsetCppEnvironment" 1>&2
        exit 1
    esac

    module unload gcc/4.8.4
    #we need a decent cmake version in order to pass the HOST_COMPILER to nvcc
    module unload cmake-3.3.2
    module unload python/3.4.3
    module unload boost/1.56_gcc4.8.4
    module unload mvapich2/gcc/64/2.0-gcc-4.8.2-cuda-6.0
    module unload cuda70/toolkit/7.0.28

    unset dycore_openmp   # OpenMP only works if GNU is also used for Fortran parts
    unset dycore_gpp
    unset dycore_gcc
    unset cuda_gpp
    unset boost_path
    unset use_mpi_compiler
    unset mpi_path
    unset old_prgenv
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
    module load cmake
    module load gcc/4.9.0
    module load boost/1.56_gcc4.8.4

    dycore_gpp='g++'
    dycore_gcc='gcc'
    cuda_gpp='g++'
    boost_path=/users/cosuna/software/boost_1_49_0
    use_mpi_compiler=OFF
    mpi_path=${CRAY_MPICH2_DIR}
    old_prgenv="none"
}

# This function unloads modules and removes variables for compiling the Fortran parts
#
# upon entry, the following global variables need to be set:
#   compiler          Compiler to use to compile the Fortran parts of the code
#   old_prgenv        Default PrgEnv-XXX module loaded on Cray machines
#
unsetFortranEnvironment()
{
    module unload cmake
    module unload gcc/4.9.0
    module unload boost/1.56_gcc4.8.4
    unset dycore_openmp   # OpenMP only works if GNU is also used for Fortran parts
    unset dycore_gpp
    unset dycore_gcc
    unset cuda_gpp
    unset boost_path
    unset use_mpi_compiler
    unset mpi_path
    unset old_prgenv
}

get_fcompiler_cmd()
{
    local __resultvar=$1
    local __compiler=$2
    myresult="gfortran"

    if [[ "$__resultvar" ]]; then
        eval $__resultvar="'$myresult'"
    else
        echo "$myresult"
    fi
}


export -f setFortranEnvironment
export -f unsetFortranEnvironment
export -f unsetCppEnvironment
export -f setupDefaults
export -f setCppEnvironment
export -f get_fcompiler_cmd
