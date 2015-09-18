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

    export OLD_LD_LIBRARY_PATH=${LD_LIBRARY_PATH}

    export MY_MPI_PATH=/opt/cray/mvapich2_gnu/${MY_MVAPICH_VERS}/GNU/48
    export MY_BOOST_PATH=/scratch/olifu/kesch/BUILD/boost_1.49.0/include

    export MY_BASE_MODULES="craype-haswell cmake/3.1.3"
    export MY_CRAY_PRG_ENV="PrgEnv-cray"
    export MY_GNU_PRG_ENV="PrgEnv-gnu/2015b"

    # Cray Compiler
    export MY_CRAY_COMPILER="cce/8.3.14"

    # NVIDIA
    export MY_NVIDIA_PRG_ENV="craype-accel-nvidia35"
    export MY_NVIDIA_CUDA_ARCH="sm_37"

    # MVAPICH
    export MY_CRAY_MVAPICH_VERS=2.0.1
    export MY_CRAY_MVAPICH_MODULE="mvapich2_gnu/${MY_CRAY_MVAPICH_VERS}"
    export MY_CRAY_MPI_PATH=/opt/cray/mvapich2_gnu/${MY_MVAPICH_VERS}/GNU/48

    export MY_GNU_MVAPICH_VERS=2.0.1-GCC-4.8.2-EB
    export MY_GNU_MVAPICH_MODULE="MVAPICH2/"
    export MY_GNU_MPI_PATH=/apps/escha/easybuild/software/MVAPICH2/${MY_GNU_MVAPICH_VERS}
    # BOOST
    export MY_BOOST_PATH=/scratch/olifu/kesch/BUILD/boost_1.49.0/include

    # Also don't forget to update Options.kesch.gnu.cpu when this value is changed
    # get the path from module display
    # Netcdf
    export MY_CRAY_NETCDF_MODULE="cray-netcdf"
    export MY_GNU_NETCDF_MODULE="netCDF-Fortran/4.4.2-gmvolf-2015b"
    # Hdf5
    export MY_CRAY_HDF5_MODULE="cray-hdf5"
    export MY_GNU_HDF5_MODULE="HDF5/1.8.15-gmvolf-2015b"

    hdf5_module="cray-hdf5"

    # default options
    if [ -z "${target}" ] ; then
        target="gpu"
    fi
    if [ -z "${compiler}" ] ; then
        compiler="cray"
    fi
    if [ -z "${cuda_arch}" ] ; then
        cuda_arch="${MY_NVIDIA_CUDA_ARCH}"
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
#   mpi_path          path to the MPI installation to use
#
setCppEnvironment()
{
    createModuleCheckPoint

    old_prgenv=`module list -t 2>&1 | grep 'PrgEnv-'`
    # CXX compiler specific modules and setup
    case "${compiler}" in
    cray )
        # Copied from
        # https://github.com/eth-cscs/mchquickstart/blob/master/mpicuda/readme.cce
        #module load "${MY_BASE_MODULES}"
        #module load "${MY_CRAY_PRG_ENV}"
        #module load "${MY_NVIDIA_PRG_ENV}"
        #module load GCC/4.8.2-EB # to prevent: /usr/lib64/libstdc++.so.6: version `GLIBCXX_3.4.15' not found 
        #mvapich_path="${MY_CRAY_MPI_PATH}"
        #dycore_gpp="CC"
        #dycore_gcc="cc"
        #cuda_gpp="g++"
        # ;;
        echo "The cray compiler is not supported for C++ on kesch, forcing GNU"
        # Bash doesn't support case fall throughs :/ hence the copy
        module load "${MY_BASE_MODULES}"
        module load "${MY_GNU_PRG_ENV}"
        module load "${MY_NVIDIA_PRG_ENV}"
        mvapich_path="${MY_GNU_MPI_PATH}"

        dycore_gpp="g++"
        dycore_gcc="gcc"
        cuda_gpp="g++"
        ;;
    gnu )
        # Copied from
        # https://github.com/eth-cscs/mchquickstart/blob/master/mpicuda/readme.gnu
        module load "${MY_BASE_MODULES}"
        module load "${MY_GNU_PRG_ENV}"
        module load "${MY_NVIDIA_PRG_ENV}"
        mvapich_path="${MY_GNU_MPI_PATH}"

        dycore_gpp="g++"
        dycore_gcc="gcc"
        cuda_gpp="g++"
        ;;
    * )
        echo "ERROR: Unsupported compiler encountered in setCppEnvironment" 1>&2
        exit 1
    esac
    
    # set global variables
    if [ "${compiler}" == "gnu" ] ; then
        dycore_openmp=ON   # OpenMP only works if GNU is also used for Fortran parts
    else
        dycore_openmp=OFF  # Otherwise, switch off
    fi

#    dycore_gpp='g++'
#    dycore_gcc='gcc'
#    cuda_gpp='g++'
    boost_path="${MY_BOOST_PATH}"
    #cudatk_include_path="${cudatk_path}"
    use_mpi_compiler=OFF
    mpi_path="${mvapich_path}"

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
    
    unset dycore_openmp
    unset dycore_gpp
    unset dycore_gcc
    unset cuda_gpp
    unset boost_path
    unset use_mpi_compiler
    unset mpi_path

    unset old_prgenv

    export LD_LIBRARY_PATH=${OLD_LD_LIBRARY_PATH}
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

    case "${compiler}" in
    cray )
        # Copied from
        # https://github.com/eth-cscs/mchquickstart/blob/master/mpicuda/readme.cce
        module load "${MY_BASE_MODULES}"
        module load "${MY_CRAY_PRG_ENV}"
        if [ -n "${MY_CRAY_COMPILER}" ] ; then
            module swap cce "${MY_CRAY_COMPILER}"
        fi
        module load "${MY_NVIDIA_PRG_ENV}"
#        module load GCC/4.8.2-EB # to prevent: /usr/lib64/libstdc++.so.6: version `GLIBCXX_3.4.15' not found 
        module load "${MY_CRAY_NETCDF_MODULE}"
        module load "${MY_CRAY_HDF5_MODULE}"

        netcdf_module="${MY_CRAY_NETCDF_MODULE}"
        hdf5_module="${MY_CRAY_HDF5_MODULE}"
        ;;
    gnu )
        # Copied from
        # https://github.com/eth-cscs/mchquickstart/blob/master/mpicuda/readme.gnu
        module load "${MY_BASE_MODULES}"
        module load "${MY_GNU_PRG_ENV}"
        module load "${MY_NVIDIA_PRG_ENV}"
        module load "${MY_GNU_NETCDF_MODULE}"
        module load "${MY_GNU_HDF5_MODULE}"

        netcdf_module="${MY_GNU_NETCDF_MODULE}"
        hdf5_module="${MY_GNU_HDF5_MODULE}"
        ;;
    * )
        echo "ERROR: Unsupported compiler encountered in setCppEnvironment" 1>&2
        exit 1
    esac

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

    unset old_prgenv

    export LD_LIBRARY_PATH=${OLD_LD_LIBRARY_PATH}
    unset OLD_LD_LIBRARY_PATH
}

