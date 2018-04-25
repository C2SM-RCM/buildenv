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
#   BOOST_PATH        The boost installation path (for both fortran and C++ dependencies)        
#   compiler          default compiler to use for Fortran parts
#   debug             build in debugging mode (yes/no)
#   cleanup           clean before build (yes/no)
#   cuda_arch         CUDA architecture version to use (e.g. sm_35, use blank for CPU target)
setupDefaults()
{
    # available options
    targets=(cpu gpu)
    compilers=(gnu cray pgi)
    fcompiler_cmds=(ftn)

    # Daint and DOM environement should be indentical and using 
    # the Daint installed Boost is fine
    # Module display boost
    export BOOST_PATH="/project/c14/install/daint/boost/boost_1_49_0"

    # Check if ncurses was loaded before
    export BUILDENV_NCURSES_LOADED=`module list -t 2>&1 | grep "ncurses"`
    
    # default options
    if [ -z "${target}" ] ; then
        target="gpu"
    fi
    if [ -z "${compiler}" ] ; then
        compiler="cray"
    fi
    if [ -z "${cuda_arch}" ] ; then
        cuda_arch="sm_60"
    fi

    # fortran compiler command
    if [ -z "${fcompiler_cmd}" ] ; then
        fcompiler_cmd="ftn"
    fi
}

get_fcompiler_cmd()
{
    local __resultvar=$1
    local __compiler=$2
    if [ "${compiler}" == "gnu" ] ; then
        myresult="gfortran"
    else
        myresult="ftn"
    fi

    if [[ "$__resultvar" ]]; then
        eval $__resultvar="'$myresult'"
    else
        echo "$myresult"
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
#   boost_path        path to the Boost installation to use (deprecated, see BOOST_PATH)
#   use_mpi_compiler  use MPI compiler wrappers?
#   mpi_path          path to the MPI installation to use
#
setCppEnvironment()
{
    # switch to programming environment (only on Cray)
    #old_prgenv=" "
    old_prgenv=`module list -t 2>&1 | grep 'PrgEnv-'`
    if [ -z "${old_prgenv}" ] ; then
        module load PrgEnv-gnu
    else
        module swap ${old_prgenv} PrgEnv-gnu
    fi
    
    # standard modules (part 1)
    if [ "${target}" == "gpu" ] ; then
        module load craype-accel-nvidia60
    fi
    
    module load CMake

    # Fortran compiler specific modules and setup
    case "${compiler}" in
    cray )
        ;;
    gnu )
        ;;
    pgi )
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
    dycore_gpp='CC'
    dycore_gcc='cc'
    cuda_gpp='g++'
    boost_path="${BOOST_PATH}/include"
    use_mpi_compiler=OFF
    mpi_path=${CRAY_MPICH2_DIR}

    export CXX=g++
    export CC=gcc
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
    pgi )
        ;;
    * )
        echo "ERROR: Unsupported compiler encountered in unsetCppEnvironment" 1>&2
        exit 1
    esac

    module unload CMake
    
    # unload curses in case it was already loaded
    if [ -z "${BUILDENV_NCURSES_LOADED}" ] ; then
        module unload ncurses
    fi
    
    # remove standard modules (part 1)
    if [ "${target}" == "gpu" ] ; then
        module unload craype-accel-nvidia60
    fi


    # restore programming environment (only on Cray)
    if [ -z "${old_prgenv}" ] ; then
        module unload PrgEnv-gnu
    else
        module swap PrgEnv-gnu ${old_prgenv}
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

    unset CXX
    unset CC
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
    # switch to GNU programming environment (only on Cray machines)
    #old_prgenv=" "
    old_prgenv=`module list -t 2>&1 | grep 'PrgEnv-'`
    if [ -z "${old_prgenv}" ] ; then
        module load PrgEnv-${compiler}
    else
        module swap ${old_prgenv} PrgEnv-${compiler}
    fi
    
    old_ldflags="${LDFLAGS}"
    
    # standard modules (part 1)
    module load CMake
    if [ "${target}" == "gpu" ] ; then
        module load craype-accel-nvidia60
    fi

    # compiler specific modules
    case "${compiler}" in
    cray )
        module load cce/8.6.1
        # Load gcc/5.3.0 to link with the C++ Dynamical Core
        module load gcc/5.3.0
        # Override C++ and C compiler
        export CXX=$GCC_PATH/snos/bin/g++
        export CC=$GCC_PATH/snos/bin/gcc
        export FC=ftn
        export LDFLAGS="-L$GCC_PATH/snos/lib64 ${LDFLAGS}"
        ;;
    gnu )
        module unload gcc
        module load gcc/5.3.0
        export CXX=CC
        export CC=cc
        export FC=ftn
        ;;
    pgi )
        module unload pgi
        module load pgi/16.9.0
        # Load gcc/5.3.0 to link with the C++ Dynamical Core
        module load gcc/5.3.0
        export CXX=$GCC_PATH/snos/bin/g++
        export CC=$GCC_PATH/snos/bin/gcc
        export FC=ftn
        export LDFLAGS="-L/opt/gcc/5.3.0/snos/lib64 ${LDFLAGS}"
        ;;
    * )
        echo "ERROR: Unsupported compiler encountered in setFortranEnvironment" 1>&2
        exit 1
    esac

    # standard modules (part 2)
    module load cray-netcdf
}

# This function unloads modules and removes variables for compiling the Fortran parts
#
# upon entry, the following global variables need to be set:
#   compiler          Compiler to use to compile the Fortran parts of the code
#   old_prgenv        Default PrgEnv-XXX module loaded on Cray machines
#
unsetFortranEnvironment()
{
    # remove standard modules (part 2)
    module unload cray-netcdf

    # remove compiler specific modules
    case "${compiler}" in
    cray )
        module unload gcc/5.3.0
        ;;
    gnu )
        module unload gcc/5.3.0
        module load gcc
        ;;
    pgi )
        module unload gcc/5.3.0
        ;;
    * )
        echo "ERROR: Unsupported compiler encountered in unsetFortranEnvironment" 1>&2
        exit 1
    esac

    # remove standard modules (part 1)
    module unload CMake
    # unload curses in case it was already loaded
    if [ -z "${BUILDENV_NCURSES_LOADED}" ] ; then
        module unload ncurses
    fi
    
    # GPU specific unload
    if [ "${target}" == "gpu" ] ; then
        module unload craype-accel-nvidia60
    fi

    # swap back to original programming environment (only on Cray machines)
    if [ -z "${old_prgenv}" ] ; then
        module unload PrgEnv-${compiler}
    else
        module swap PrgEnv-${compiler} ${old_prgenv}
    fi
    unset old_prgenv
    
    export LDFLAGS="${old_ldflags}"
    unset old_ldflags
    
    unset CXX
    unset CC
    unset FC
}

export -f setFortranEnvironment
export -f unsetFortranEnvironment
export -f unsetCppEnvironment
export -f setupDefaults
export -f setCppEnvironment
export -f get_fcompiler_cmd
