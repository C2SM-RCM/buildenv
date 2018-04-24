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
#   BOOST_PATH        The boost installation path (for both fortran and C++ dependencies)        
#   compiler          default compiler to use for Fortran parts
#   debug             build in debugging mode (yes/no)
#   cleanup           clean before build (yes/no)
#   cuda_arch         CUDA architecture version to use (e.g. sm_35, use blank for CPU target)
#
setupDefaults()
{
    # available options
    targets=(cpu gpu)
    compilers=(gnu cray pgi)
    fcompiler_cmds=(ftn)


    export BASE_MODULES="craype-haswell"
    export NVIDIA_CUDA_ARCH="sm_37"

    # # MVAPICH
    export MVAPICH_MODULE="mvapich2_gnu/2.2rc1.0.2"
    # # BOOST
    export BOOST_PATH="/users/jenkins/Code/boost-1.49.0/"

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
        module purge
        module load craype-network-infiniband
        module load craype-haswell
        module load craype-accel-nvidia35
        module load cray-libsci
        module load cudatoolkit/8.0.61
        module load mvapich2gdr_gnu/2.2_cuda_8.0
        #XL: HACK needed with this mvapich2 for the dycore test, removed once fixed
        export LD_PRELOAD=/opt/mvapich2/gdr/no-mcast/2.2/cuda8.0/mpirun/gnu4.8.5/lib64/libmpi.so
        module load gcc/5.4.0-2.26
        module load cmake/3.9.1
EOF
   
    module purge
    source $ENVIRONMENT_TEMPFILE
    dycore_gpp='g++'
    dycore_gcc='gcc'
    cuda_gpp='g++'
    boost_path="${BOOST_PATH}/include"
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
    #XL: HACK, unset LD_PRELOAD
    unset LD_PRELOAD
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
    createModuleCheckPoint

    old_prgenv=`module list -t 2>&1 | grep 'PrgEnv-'`

    export ENVIRONMENT_TEMPFILE=$(mktemp)
    
    case "${compiler}" in
    cray )
        # Provided by CSCS
        cat > $ENVIRONMENT_TEMPFILE <<-EOF
            # Generated with the build script
            # implicit module purge
            module load craype-haswell
            module load craype-accel-nvidia35
            module load craype-network-infiniband
            module load netCDF-Fortran/4.4.4-CrayCCE-17.06
            module switch mvapich2_cce/2.2rc1.0.3_cuda80 mvapich2gdr_gnu/2.2_cuda_8.0
            module load gcc/5.4.0-2.26
            module load cmake/3.9.1
EOF

        if [ "${target}" == "cpu" ]; then
            cat > $ENVIRONMENT_TEMPFILE <<-EOF
                # Generated with the build script
                # implicit module purge
                module load craype-haswell
                module load craype-accel-nvidia35
                module load craype-network-infiniband
                module load netCDF-Fortran/4.4.4-CrayCCE-17.06
                module switch mvapich2_cce/2.2rc1.0.3_cuda80 mvapich2_cce/2.2rc1.0.3
                module load gcc/5.4.0-2.26
                module load cmake/3.9.1
EOF
        fi
        export FC="ftn -D__CRAY_FORTRAN__"
        ;;
    gnu )
        cat > $ENVIRONMENT_TEMPFILE <<-EOF
            # Generated with the build script
            # implicit module purge
            module load craype-haswell
            module load craype-network-infiniband
            module load PrgEnv-gnu/17.02
            module load cmake/3.9.1
            module load netcdf-fortran/4.4.4-gmvolf-17.02
            module load hdf5/1.8.18-gmvolf-17.02
EOF
        export FC=gfortran
        ;;
    pgi ) 
        cat > $ENVIRONMENT_TEMPFILE <<-EOF
            # Generated with the build script
            # implicit module purge
            module load craype-haswell
            module load PrgEnv-pgi/17.10
            module unload openmpi/2.1.2/2017
            module load mvapich2gdr_gnu/2.3a_cuda_8.0_pgi17.10
            module load gcc/5.4.0-2.26
            module load cmake/3.9.1
EOF
        export FC=mpif90
        ;;	
    * )
        echo "ERROR: ${compiler} Unsupported compiler encountered in setFortranEnvironment" 1>&2
        exit 1
    esac
    
    module purge
    source $ENVIRONMENT_TEMPFILE
    
    # Add an explicit linker line for GCC 4.9.3 library to provide C++11 support
    export LDFLAGS="-L$EBROOTGCC/lib64 ${LDFLAGS}"

    export OLD_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}

    # We have gcc for gnu, cray and pgi environments
    export CXX=g++
    export CC=gcc

    # Workaround for Cray CCE licence on kesh: if no licence available use escha licence file
    if [ ${compiler} == "cray" ] && `${FC} -V 2>&1 | grep -q "Unable to obtain a Cray Compiling Environment License"` ; then
	echo "Info : No Cray CCE licence available, setting CRAYLMD_LICENSE_FILE to escha"
	export CRAYLMD_LICENSE_FILE=27010@escha-mgmt1,27010@escha-mgmt2,27010@escha-login3
	# Test if the licence is now available otherwise print info message
	if `${FC} -V 2>&1 | grep -q "Unable to obtain a Cray Compiling Environment License"` ; then
	    echo "!! Warning !! No Cray CCE licence available"
	    echo "Licence usage on kesch:"
	    klicstat
	    echo "Licence usage on escha:"
	    elistat
	fi
    fi

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

    unset CXX
    unset CC
    unset FC
}


export -f setFortranEnvironment
export -f createModuleCheckPoint
export -f writeModuleEnv
export -f setupDefaults
export -f get_fcompiler_cmd 
export -f unsetFortranEnvironment
export -f restoreModuleCheckPoint

