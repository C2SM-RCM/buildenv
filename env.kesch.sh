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

    export MY_CPU=haswell
    export MY_CRAYPE_VERS=2.3.0
    export MY_CMAKE_VERS=3.1.3
    export MY_CCE_VERS=8.3.10
    export MY_GCC_VERS=4.8.1
    export MY_MVAPICH_VERS=2.0.1
    export MY_LIBSCI_VERS=13.0.3
    export MY_CUDA_VERS=6.5.14
    export MY_LIBSCI_ACC_VERS=3.1.2
    export MY_NETCDF_VERS=4.3.2
    export MY_HDF5_VERS=1.8.13
    export MY_PERFTOOLS_VERS=6.2.3
    export MY_MPI_PATH=/opt/cray/mvapich2_gnu/${MY_MVAPICH_VERS}/GNU/48
    export MY_BOOST_PATH=/lus/scratch/olifu/kesch/BUILD/boost_1.49.0/include
    
    cpu_vers="${MY_CPU}"

    # Set version numbers here to avoid duplication and mistakes
    #    later in the file.
    # Import using env variables vi build_all.sh script
    #
    craype_vers="${MY_CRAYPE_VERS}"
#    cmake_vers="${MY_CMAKE_VERS}"
    gcc_vers="${MY_GCC_VERS}"
    cce_vers="${MY_CCE_VERS}"
    mvapich_vers="${MY_MVAPICH_VERS}_gnu48"
    libsci_vers="${MY_LIBSCI_VERS}"
    cuda_vers="${MY_CUDA_VERS}"
    libsci_acc_vers="${MY_LIBSCI_ACC_VERS}"
    netcdf_vers="${MY_NETCDF_VERS}"
    hdf5_vers="${MY_HDF5_VERS}"
    perftools_vers="${MY_PERFTOOLS_VERS}"


    craype_module="craype/${craype_vers}"
#    cmake_module="cmake/${cmake_vers}"
    gcc_module="gcc/${gcc_vers}"
    cce_module="cce/${cce_vers}"
    mvapich_module="mvapich2_gnu/${mvapich_vers}"
    mvapich_path="${MY_MPI_PATH}"
    libsci_module="cray-libsci/${libsci_vers}"
    cudatk_module="cudatoolkit/${cuda_vers}"
    cudatk_path="/global/opt/nvidia/cudatoolkit/${cuda_vers}"
    libsci_acc_module="cray-libsci_acc/${libsci_acc_vers}"
    netcdf_module="cray-netcdf/${netcdf_vers}"
    hdf5_module="cray-hdf5/${hdf5_vers}"

    export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}
    export LD_LIBRARY_PATH=${MY_MPI_PATH}:${LD_LIBRARY_PATH}

    # default options
    if [ -z "${target}" ] ; then
        target="gpu"
    fi
    if [ -z "${compiler}" ] ; then
        compiler="cray"
    fi
    if [ -z "${cuda_arch}" ] ; then
        cuda_arch="sm_37"
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
    module load "craype-${cpu_vers}"
    module unload gcc
    module load "${gcc_module}"
    # switch to programming environment (only on Cray)
    #old_prgenv=" "
    old_prgenv=`module list -t 2>&1 | grep 'PrgEnv-'`
    if [ -z "${old_prgenv}" ] ; then
        module load PrgEnv-cray
    else
        module switch ${old_prgenv} PrgEnv-cray
    fi

    
    # standard modules (part 1)
    module unload craype
    module load "${craype_module}"
#    module load "${cmake_module}"
    module unload mvapich2_cce
    module load "${mvapich_module}"
    module unload cray-libsci
    module load "${libsci_module}"

    #if [ "${target}" == "gpu" ] ; then
        module unload cudatoolkit
        module unload craype-accel-nvidia35
        module load craype-accel-nvidia35
        module unload cray-libsci_acc
        module load "${libsci_acc_module}"
    #fi
    old_ldlibrarypath=${LD_LIBRARY_PATH}
    export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}

    # Fortran compiler specific modules and setup
    case "${compiler}" in
    cray )
        module unload cce
        module load "${cce_module}"
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
    boost_path="${MY_BOOST_PATH}"
    cudatk_include_path="${cudatk_path}"
    use_mpi_compiler=OFF
    mpi_path="${mvapich_path}"
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
    * )
        echo "ERROR: Unsupported compiler encountered in unsetCppEnvironment" 1>&2
        exit 1
    esac

    # remove standard modules (part 1)
    module unload perftools
#    module unload cmake
    module unload "craype-${cpu_vers}"
    export LD_LIBRARY_PATH=${old_ldlibrarypath}
    old_ldlibrarypath=""
    #if [ "${target}" == "gpu" ] ; then
        module unload craype-accel-nvidia35
        module unload cudatoolkit
        module unload cray-libsci_acc
    #fi
    module unload mvapich2_gnu
    module unload mvapich2_cce
    module load mvapich2_cce
    module unload "${gcc_module}"

    module unload cray-libsci
    module load cray-libsci

    module unload craype
    module load craype

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
    module load "craype-${cpu_vers}"
    module unload gcc
    module load "${gcc_module}"
    # switch to GNU programming environment (only on Cray machines)
    #old_prgenv=" "
    old_prgenv=`module list -t 2>&1 | grep 'PrgEnv-'`
    if [ -z "${old_prgenv}" ] ; then
        module load PrgEnv-${compiler}
    else
        module swap ${old_prgenv} PrgEnv-${compiler}
    fi

    # standard modules (part 1)
    module unload craype
    module load "${craype_module}"
    module unload mvapich2_cce
    module load "${mvapich_module}"
    module unload cray-libsci
    module load "${libsci_module}"

    #if [ "${target}" == "gpu" ] ; then
        module unload cudatoolkit
        module unload craype-accel-nvidia35
        module load craype-accel-nvidia35
        module unload cray-libsci_acc
        module load "${libsci_acc_module}"
    #fi

    old_ldlibrarypath=${LD_LIBRARY_PATH}
    #  export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${CRAY_LD_LIBRARY_PATH}
    export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}



    # compiler specific modules
    case "${compiler}" in
    cray )
        module unload cce
        module load "${cce_module}"
        ;;
    * )
        echo "ERROR: Unsupported compiler encountered in setFortranEnvironment" 1>&2
        exit 1
    esac

    # standard modules (part 2)
    module load "${netcdf_module}"
    module load "${hdf5_module}"
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
    module unload perftools
    module unload "${netcdf_module}"
    module unload "${hdf5_module}"


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
    module unload "craype-${cpu_vers}"

    export LD_LIBRARY_PATH=${old_ldlibrarypath}
    old_ldlibrarypath=""
    #if [ "${target}" == "gpu" ] ; then
        module unload craype-accel-nvidia35
        module unload cudatoolkit
        module unload cray-libsci_acc
    #fi
    #  module unload mvapich
    module unload mvapich2_gnu
    module unload mvapich2_cce
    module load mvapich2_cce
    module unload gcc

    module unload cray-libsci
    module load cray-libsci

    module unload craype
    module load craype

    # swap back to original programming environment (only on Cray machines)
    if [ -z "${old_prgenv}" ] ; then
        module unload PrgEnv-${compiler}
    else
        module swap PrgEnv-${compiler} ${old_prgenv}
    fi
    unset old_prgenv
}

