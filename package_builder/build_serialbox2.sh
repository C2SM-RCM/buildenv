#!/usr/bin/env bash

TEMP=$@
eval set -- "$TEMP --"
fwd_args=""

# SERIALBOX2
resources_repo="https://github.com/eth-cscs/serialbox2.git"
resources_version="master"

while true; do
    case "$1" in
        --dir|-d) package_basedir=$2; shift 2;;
        --idir|-i) install_dir=$2; shift 2;;
        --local|-l) install_local="yes"; shift;;
        --compiler|-c) compiler_target=$2; shift 2;;
        --resources_version|-r) resources_version=$2; shift 2;;
        -- ) shift; break ;;
        * ) fwd_args="$fwd_args $1"; shift ;;
    esac
done

if [[ "${help_enabled}" == "yes" ]]; then
    echo "Available Options for Serialbox 2:"
    echo "* --local             |-l {install locally}         Default=No"
    echo "* --compiler          |-c {compiler}                Default=all"
    echo "* --resources_version |-r {resources version}       Default=master (git object: branch, tag, etc..)"
    exit 0
fi

if [[ -z ${package_basedir} ]]; then
    exitError 4201 ${LINENO} "package basedir has to be specified"
fi
if [[ -z ${install_dir} ]]; then
    exitError 4202 ${LINENO} "package install dir has to be specified"
fi

# Setup
echo $@
# The current directory
base_path=$PWD
setupDefaults

# Build grib for compiler and install_path
build_compiler_target()
{
    local install_path=$2

    # Set fortran environment
    export compiler=$1
    setFortranEnvironment

    # Set F77 compiler to F90
    export F77=$FC

    echo "Compiling and installing for $compiler (install path: $install_path)"

    if [ "${host}" == "daint" ] || [ "${host}" == "dom" ] ; then
        # Remove accelerator target to avoid issue with CUDA
        export CRAY_ACCEL_TARGET=
    fi
    if [ $? -ne 0 ]; then
        exitError 4331 ${LINENO} "Invalid fortran environment"
    fi

    writeModuleList ${base_path}/modules.log loaded "FORTRAN MODULES" ${base_path}/modules_fortran.env

    echo "Building for ${compiler} compiler"

    # Go to the SERIALBOX2 dir to call make
    cd "${package_basedir}/serialbox2" || exit 1
    mkdir build
    cd build || exit 1

    if [[ "${compiler}" == "pgi" ]]; then
      export FC=pgfortran
      export CC=gcc
      export CXX=g++
    fi

    module list
    cmake -DCMAKE_INSTALL_PREFIX="${install_path}" -DSERIALBOX_ENABLE_FORTRAN=ON ..

    echo ">>>Compiling $packageName (make)"
    make &>> build.log
    if [ $? -ne 0 ]; then
      cat build.log
       exitError 4334 "Unable to compile Serialbox 2."
    fi
    unsetFortranEnvironment
    cd ../.. || exit 1
}

# Install the package
install_to_target() 
{
  local install_path=$1
  echo ">>>Purging ${install_path}"
  rm -rf ${install_path}
  echo ">>>Installing to ${install_path}"
  cd "${package_basedir}/serialbox2" || exit 1
  cd build || exit 1
  make install &> install.log
  if [[ $? -ne 0 ]]; then
    cat build.log
    cat install.log
    echo "Cannot install Serialbox2 to ${install_path}"
    exit 1
  fi
}

git clone "${resources_repo}"

if [[ ${install_local} == "yes" ]]; then
  install_path_prefix_="${base_path}/install"
else
  install_path_prefix_="${install_dir}/serialbox2/${resources_version}"
fi

if [ "${compiler_target}" != "all" ]; then
  if [ "${install_local}" != "yes" ] ; then
    install_path_prefix_="${install_path_prefix_}/${compiler_target}"
  fi
  build_compiler_target "${compiler_target}" "${install_path_prefix_}"
  install_to_target "${install_path_prefix_}"
else
  for c_ in ${compilers[@]}; do
    build_compiler_target "${c_}" "${install_path_prefix_}/$c_/"
    install_to_target "${install_path_prefix_}"
  done
fi

echo ">>> Finished"
