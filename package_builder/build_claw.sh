#!/usr/bin/env bash

# set default variables

test -n "${REBUILD}"  || REBUILD=YES
test -n "${slave}" || exitError "Error : slave must be defined"

# hack for tsa
if [ "$slave" == "tsa" ] ; then
  export COSMO_TESTENV=ON
  slave=arolla
fi

# CLAW
resources_repo="git@github.com:claw-project/claw-compiler.git"
resources_version="master"
package_name="claw" # name of repository

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
        --resources_version|-r) resources_version=$2; shift 2;;
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
    install_path_prefix_="${base_path}/claw/${resources_version}"
else
    install_path_prefix_="${install_dir}/claw//${resources_version}"
fi

build_compiler_target()
{

export compiler=$1
local install_path=$2
echo "Compiling and installing for $compiler (install path: $install_path)"

install_args="-i ${install_path}/"

if [ ! -d ${install_dir} ] ; then
  mkdir -p ${install_dir}
fi

setFortranEnvironment

if [ $? -ne 0 ]; then
    exitError 3331 ${LINENO} "Invalid fortran environment"
fi

writeModuleList ${base_path}/modules.log loaded "FORTRAN MODULES" ${base_path}/modules_fortran.env

echo "Building for ${compiler} compiler"

cd $base_path

if [ "${install_path_prefix_:0:1}" != "/" ]; then
  install_path_prefix_=$base_path/$install_path_prefix_
fi   

export claw_compiler_install=$install_path_prefix_

if [[ ! -f $claw_compiler_install/libexec/claw_f_lib.sh || $REBUILD == YES ]]; then

  if [ $REBUILD == YES ] ; then
    echo `pwd`
    echo "Rebuilding claw-compiler"
    echo "rm -rf $claw_compiler_install"
    rm -rf $claw_compiler_install
  fi  
  
  # Build claw-compiler dependency apache-ant
  echo "=============================="
  echo "Build claw-compiler dependency: apache-ant"
  if [ ! -d ${package_basedir}/hpc-scripts ] ; then
    git clone git@github.com:clementval/hpc-scripts.git ${package_basedir}/hpc-scripts
  fi

  cd ${package_basedir}/hpc-scripts/cscs
  ./install.ant -i ../../ant || error_exit "Error : apach-ant build failed"
   
  cd ../../ant/apache-ant-1.10.2
  export ANT_HOME=`pwd`

  cd $base_path

  # Build claw-compiler 
  echo "=============================="
  echo "Build claw-compiler"
  if [ ! -d ${package_basedir}/claw-compiler ] ; then
    git clone "${resources_repo}" -b add_cmake_flags_option
  fi

  cd ${package_basedir}/claw-compiler

  export PATH=$ANT_HOME/bin:$PATH

  # Get OMNI Compiler as submodule
  git submodule init
  git submodule update

  if [ ! -d build ] ; then
    mkdir build
  fi
  cd build
  
  if [[ "${slave}" == "kesch" ]] ; then
    cmake -DCMAKE_INSTALL_PREFIX="$claw_compiler_install" .. 
  elif [[ "${slave}" == "arolla" ]] ; then
    cmake -DCMAKE_C_FLAGS="-std=c99" -DCMAKE_INSTALL_PREFIX="$claw_compiler_install" ..
  elif [[ "${slave}" == "daint" ]] || [[ "${slave}" == "tave" ]]; then
    cmake -DCMAKE_INSTALL_PREFIX="$claw_compiler_install" -DOMNI_MPI_CC="MPI_CC=cc" -DOMNI_MPI_FC="MPI_FC=ftn" ..
  fi

  # Compile and run unit tests
  # make all transformation test && make install
  make 
  make install

  #remove build directories
  cd $base_path
  cd $package_basedir
  rm -rf ant/ claw-compiler/ hpc-scripts/ 
else
  echo "claw-compiler already installed under $claw_compiler_install"
fi

if [ $? -ne 0 ]; then
    exitError 3333 "Unable to compile claw with ${compiler}"
fi

cd $base_path

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
