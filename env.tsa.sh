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
    compilers=(pgi claw-pgi gnu)
    fcompiler_cmds=(mpif90 pgfortran gfortran)


    export BASE_MODULES="craype-x86-skylake"
    export NVIDIA_CUDA_ARCH="sm_70"

    # BOOST
    export Boost_NO_SYSTEM_PATHS=true
    export Boost_NO_BOOST_CMAKE=true

    export BOOST_ROOT=/project/c14/install/tsa/boost/boost_1_67_0/
    export BOOST_PATH=${BOOST_ROOT}
    export BOOST_INCLUDE=${BOOST_ROOT}/include/
 
    export YACC="bison -y"

    # default options
    if [ -z "${target}" ] ; then
        target="gpu"
    fi
    if [ -z "${compiler}" ] ; then
        compiler="pgi"
    fi
    if [ -z "${cuda_arch}" ] ; then
        cuda_arch="${NVIDIA_CUDA_ARCH}"
    fi

    # fortran compiler command
    if [ -z "${fcompiler_cmd}" ] ; then
        if [ "${compiler}" == "gnu" ] ; then
            fcompiler_cmd="gfortran"
        else
            fcompiler_cmd="pgfortran"
        fi
    fi
}

get_fcompiler_cmd()
{
    local __resultvar=$1
    local __compiler=$2
    if [ "${compiler}" == "gnu" ] || [ "${compiler}" == "claw-gnu" ]; then
        myresult="gfortran"
    else
        myresult="pgfortran"
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
        echo "Note : ${compiler} is not supported for c++ environment, forcing gnu"
        ;;
    esac

    export ENVIRONMENT_TEMPFILE=$(mktemp)

    cat > $ENVIRONMENT_TEMPFILE <<- EOF
        # Generated with the build script
        # implicit module purge
        module load cmake/3.14.5
        module load craype-x86-skylake
        module load craype-network-infiniband
        module load slurm
        # Gnu env
        module load PrgEnv-gnu/19.2
EOF
        # Export UCX env variables for gpu nodes
        if [ "${target}" == "gpu" ] ; then
            cat >> $ENVIRONMENT_TEMPFILE <<-EOF
        # UCX env variables
        export UCX_MEMTYPE_CACHE=n
        export UCX_TLS=rc_x,ud_x,mm,shm,cuda_copy,cuda_ipc,cma
EOF
        fi

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

    # Set grib-api version and cosmo ressources
    export GRIBAPI_VERSION="libgrib_api_1.20.0p4"
    export GRIBAPI_COSMO_RESOURCES_VERSION="v1.20.0.2"

    case "${compiler}" in
    *gnu )
        cat > $ENVIRONMENT_TEMPFILE <<-EOF
            # Generated with the build script
            # implicit module purge
            module load cmake/3.14.5
            module load craype-x86-skylake
            module load craype-network-infiniband
            module load slurm
            module load PrgEnv-gnu/19.2
            # Set GCC_PATH (used for c and c++ compilation within the Fortran env) 
            export GCC_PATH=/apps/arolla/UES/jenkins/RH7.6/generic/easybuild/software/GCCcore/8.3.0
            module load netcdf-fortran/4.4.5-fosscuda-2019b
            export JAVA_HOME="/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.222.b10-0.el7_6.x86_64"
            export GRIBAPI_COSMO_RESOURCES_VERSION=${GRIBAPI_COSMO_RESOURCES_VERSION}
            if ([ -z \${GRIBAPI_DIR} ]) then
                export GRIBAPI_DIR=/project/c14/install/tsa/libgrib_api/${GRIBAPI_COSMO_RESOURCES_VERSION}/gnu
            fi
            if ([ -f \${GRIBAPI_DIR}/configuration.sh ]) then
                echo "using \${GRIBAPI_DIR}/configuration.sh"
                source \${GRIBAPI_DIR}/configuration.sh
            fi
EOF
        export FC=mpif90
        ;;
    *pgi )
        cat > $ENVIRONMENT_TEMPFILE <<-EOF
            # Generated with the build script
            # implicit module purge
            module load cmake/3.14.5
            module load craype-x86-skylake
            module load craype-network-infiniband
            module load slurm
            module load PrgEnv-pgi/19.9
            module load netcdf-fortran/4.4.5-pgi-19.9-gcc-8.3.0
            # Set GCC_PATH used for c and c++ compilation within the Fortran env
            export GCC_PATH=/apps/arolla/UES/jenkins/RH7.6/generic/easybuild/software/GCCcore/8.3.0
            export JAVA_HOME="/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.222.b10-0.el7_6.x86_64" 
            export MPI_ROOT=\${EBROOTOPENMPI}
            export GRIBAPI_COSMO_RESOURCES_VERSION=${GRIBAPI_COSMO_RESOURCES_VERSION}
            if ([ -z \${GRIBAPI_DIR} ]) then
                export GRIBAPI_DIR=/project/c14/install/tsa/libgrib_api/${GRIBAPI_COSMO_RESOURCES_VERSION}/pgi
            fi
            if ([ -f \${GRIBAPI_DIR}/configuration.sh ]) then
                echo "using \${GRIBAPI_DIR}/configuration.sh"
                source \${GRIBAPI_DIR}/configuration.sh
            fi
EOF
        # Export UCX env variables for gpu nodes
        if [ "${target}" == "gpu" ] ; then
            cat >> $ENVIRONMENT_TEMPFILE <<-EOF
            # UCX env variables
            export UCX_MEMTYPE_CACHE=n
            export UCX_TLS=rc_x,ud_x,mm,shm,cuda_copy,cuda_ipc,cma
EOF
        fi
        export FC=mpif90
        ;;
    * )
        echo "ERROR: ${compiler} Unsupported compiler encountered in setFortranEnvironment" 1>&2
        exit 1
    esac

    source $ENVIRONMENT_TEMPFILE

    # Add an explicit linker line for GCC 4.9.3 library to provide C++11 support
    export LDFLAGS="-L$EBROOTGCC/lib64 ${LDFLAGS}"

    export OLD_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}

    # Always use gcc for C and C++ compilation within Fortran environment
    # this is required by serialbox
    if [ -z "${GCC_PATH}" ]; then
       echo "Error : GCC_PATH must be set"
       exit 1
    fi
    export CXX=${GCC_PATH}/bin/g++
    export CC=${GCC_PATH}/bin/gcc

    if [[ -z "$CLAWFC" ]]; then
        # CLAW Compiler using the correct preprocessor
        export CLAWFC="${installdir}/claw/v2.0.1/${compiler}/bin/clawfc"
    fi
    export CLAWXMODSPOOL="${installdir}/../omni-xmod-pool"

}

# This function unloads modules and removes variables for compiling the Fortran parts
#
# upon entry, the following global variables need to be set:
#   compiler          Compiler to use to compile the Fortran parts of the code
#   old_prgenv        Default PrgEnv-XXX module loaded on Cray machines
#
unsetFortranEnvironment()
{

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
