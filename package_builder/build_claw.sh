#!/usr/bin/env bash

# set default variables

test -n "${REBUILD}"  || REBUILD=YES
test -n "${slave}" || exitError "Error : slave must be defined"

# hack for tsa
if [ "$slave" == "tsa" ] ; then
  export COSMO_TESTENV=ON
  slave=arolla
fi

exitError()
{
    echo "ERROR $1: $3" 1>&2
    echo "ERROR     LOCATION=$0" 1>&2
    echo "ERROR     LINE=$2" 1>&2
    exit $1
}

TEMP=$@
eval set -- "$TEMP --"
fwd_args=""
compiler_target="all"
while true; do
    case "$1" in
        --dir|-d) package_basedir=$2; shift 2;;
        --idir|-i) install_dir=$2; shift 2;;
        --local) install_local="yes"; shift;;
        --compiler|-c) compiler_target=$2; shift 2;;
        -- ) shift; break ;;
        * ) fwd_args="$fwd_args $1"; shift ;;
    esac
done

if [[ -z ${package_basedir} ]]; then
    exitError 3221 ${LINENO} "package basedir has to be specified"
fi
if [[ -z ${install_dir} ]]; then
    exitError 3225 ${LINENO} "package install dir has to be specified"
fi

# Setup
echo $@
base_path=$PWD
setupDefaults

if [[ ${install_local} == "yes" ]]; then
    install_path_prefix_="${base_path}/install"
else
    install_path_prefix_="${install_dir}/claw"
fi

build_compiler_target()
{

export compiler=$1
local install_path=$2
echo "Compiling and installing for $compiler (install path: $install_path)"

install_args="-i ${install_path}/"

if [ ! -d ${install_path} ] ; then
  mkdir -p ${install_path}
fi

setFortranEnvironment

if [ $? -ne 0 ]; then
    exitError 3331 ${LINENO} "Invalid fortran environment"
fi

writeModuleList ${base_path}/modules.log loaded "FORTRAN MODULES" ${base_path}/modules_fortran.env

echo "Building for ${compiler} compiler"

# Build claw-compiler dependency apache-ant
echo "=============================="
echo "Build claw-compiler dependency: apache-ant"
if [ ! -d ${package_basedir}/hpc-scripts ] ; then
  git clone git@github.com:clementval/hpc-scripts.git ${package_basedir}/hpc-scripts
fi
cd ${package_basedir}/hpc-scripts/cscs
if [[ ! -f ../../ant/apache-ant-1.10.2/bin/ant || $REBUILD == YES ]] ; then
  if [ $REBUILD == YES ] ; then
    echo `pwd`
    echo "Rebuilding apache-ant"
    echo "rm -rf ../../ant"
    rm -rf ../../ant
  fi
  ./install.ant -i ../../ant || error_exit "Error : apach-ant build failed"
fi 
cd ../../ant/apache-ant-1.10.2
export ANT_HOME=`pwd`

cd $base_path

# Build claw-compiler 
echo "=============================="
echo "Build claw-compiler"
if [ ! -d ${package_basedir}/claw-compiler ] ; then
  git clone git@github.com:claw-project/claw-compiler.git ${package_basedir}/claw-compiler
fi

cd ${package_basedir}/claw-compiler

export claw_compiler_install=$install_path_prefix_

if [[ ! -f $claw_compiler_install/bin/clawfc || $REBUILD == YES ]]; then
  if [ $REBUILD == YES ] ; then
   echo `pwd`
   echo "Rebuilding claw-compiler"
   echo "rm -rf build"
   rm -rf build
  fi
 
  export PATH=$ANT_HOME/bin:$PATH

  # Get OMNI Compiler as submodule
  git submodule init
  git submodule update

  if [ ! -d build ] ; then
    mkdir build
  fi
  cd build

  if [[ "${slave}" == "kesch" ]] || [[ "${slave}" == "arolla" ]] ; then
    cmake -DCMAKE_INSTALL_PREFIX="$claw_compiler_install" ..
  elif [[ "${slave}" == "daint" ]] || [[ "${slave}" == "tave" ]]; then
    cmake -DCMAKE_INSTALL_PREFIX="$claw_compiler_install" -DOMNI_MPI_CC="MPI_CC=cc" -DOMNI_MPI_FC="MPI_FC=ftn" ..
  fi

  # Compile and run unit tests
  # make all transformation test && make install
  make 
  make install

  #remove build directories
  cd $base_path
  rm -rf ant/ claw-compiler/ hpc-scripts/
fi

if [ $? -ne 0 ]; then
    exitError 3333 "Unable to compile claw with ${compiler}"
fi

# Copy module files
cp modules_fortran.env ${install_path}/modules.env
unsetFortranEnvironment

}

# Build
if [ "${compiler_target}" != "all" ]; then
    if [ "${install_local}" != "yes" ] ; then
        install_path_prefix_="${install_path_prefix_}/${compiler_target}"
    fi
    build_compiler_target "${compiler_target}" "${install_path_prefix_}"
else
    for c_ in ${compilers[@]}; do
        build_compiler_target "${c_}" "${install_path_prefix_}/$c_/"
    done
fi
