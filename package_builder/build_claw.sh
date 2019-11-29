#!/usr/bin/env bash

slave=arolla

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

if [[ ${install_local} == "yes" ]]; then
    install_path_prefix_="${base_path}/install"
else
    install_path_prefix_="${install_dir}/claw"
fi

set_apache_ant_env()
{
  # Check the ${slave} machine, add modules and export variables accordingly
  if [[ "${slave}" == "arolla" ]]; then
    module load cmake
    export YACC="bison -y"
    export JAVA_HOME="/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.191.b12-0.el7_5.x86_64"
  elif [[ "${slave}" == "kesch" ]]; then
    export YACC="bison -y"
    module load PE/18.12
    module load cmake
    module load java
  elif [[ "${slave}" == "daint" ]]; then
    export JAVA_HOME=/usr/lib64/jvm/java-1.8.0-openjdk
  elif [[ "${slave}" == "tave" ]]; then
    module load java
  fi
}

set_claw_env()
{
 if [[ "${compiler}" == "gnu" ]]; then
    module rm PrgEnv-pgi && module rm PrgEnv-cray
    module load PrgEnv-gnu
    if [[ "${slave}" == "kesch" ]] || [[ "${slave}" == "tave" ]] || [[ "${slave}" == "arolla" ]]; then
      export FC=gfortran
      export CC=gcc
      export CXX=g++
    elif [[ "${slave}" == "daint" ]]; then
      module load cudatoolkit
      # On Daint the cray wrapper must be used regardless the compiling env.
      export FC=ftn
      export CC=cc
      export CXX=CC
    fi
  elif [[ "${compiler}" == "pgi" ]]; then
    module rm PrgEnv-gnu && module rm PrgEnv-cray
    if [[ "${slave}" == "kesch" ]] || [[ "${slave}" == "arolla" ]]; then
      if [[ "${slave}" == "kesch" ]]; then
        module load PrgEnv-pgi
      else
        module load PrgEnv-pgi/19.4
      fi
      module load gcc
      export FC=pgfortran
      export CC=gcc
      export CXX=g++
    elif [[ "${slave}" == "daint" ]]; then
      module load PrgEnv-pgi
      module load pgi-icon/19.9
      module load cudatoolkit
      module load gcc/7.1.0
      # On Daint the cray wrapper must be used regardless the compiling env.
      # Use GNU gcc for the C/C++ part as PGI is broken.
      export FC=ftn
      export CC=gcc
      export CXX=g++
    elif [[ "${slave}" == "tave" ]]; then
      module load PrgEnv-pgi
      export FC=ftn
      export CC=gcc
      export CXX=g++
    fi
  elif [[ "${compiler}" == "cray" ]]; then
    module load PrgEnv-cray
    if [[ "${slave}" == "kesch" ]]; then
      module load gcc
      export CC=cc
      export CXX=CC
    elif [[ "${slave}" == "arolla" ]]; then
      module load cce/8.7.7
      module load gcc/7.2.0
      export CC=gcc
      export CXX=g++
    elif [[ "${slave}" == "daint" ]]; then
      module load daint-gpu
      export CRAYPE_LINK_TYPE=dynamic
      export CC=cc
      export CXX=CC
    elif [[ "${slave}" == "tave" ]]; then
      module load gcc
      export CC=gcc
      export CXX=g++
    fi
    export FC=ftn
  elif [[ "${compiler}" == "intel" ]]; then
    # Only for Piz Daint and Grande Tave
    module rm PrgEnv-gnu
    module rm PrgEnv-cray
    module rm PrgEnv-pgi
    module load PrgEnv-intel
    module load gcc
    export FC=ftn
    export CC=gcc
    export CXX=g++
  fi
  # Workaround to avoid buggy Perl installation
  if [[ "${slave}" == "tave" ]]; then
    module rm Perl
  fi
}

build_compiler_target()
{
set_apache_ant_env


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
    echo "rm -r ../../ant"
    rm -r ../../ant
  fi
  ./install.ant -i ../../ant || error_exit "Error : apach-ant build failed"
fi 
cd ../../ant/apache-ant-1.10.2
export ANT_HOME=`pwd`

cd $base_path

set_claw_env

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
   echo "rm -r build"
   rm -r build
  fi
 
  export PATH=$ANT_HOME/bin:$PATH

  # Get OMNI Compiler as submodule
  git submodule init
  git submodule update

  if [ ! -d build ] ; then
    mkdir build
  fi
  cd build
 
  if [[ "${slave}" == "kesch" ]] || [[ "${slave}" == "arolla" ]]; then
    cmake -DCMAKE_INSTALL_PREFIX="$base_path/$claw_compiler_install" ..
  elif [[ "${slave}" == "daint" ]] || [[ "${slave}" == "tave" ]]; then
    cmake -DCMAKE_INSTALL_PREFIX="$base_path/$claw_compiler_install" -DOMNI_MPI_CC="MPI_CC=cc" -DOMNI_MPI_FC="MPI_FC=ftn" ..
  fi

  # Compile and run unit tests
  # make all transformation test && make install
  make 
  make install
fi
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
