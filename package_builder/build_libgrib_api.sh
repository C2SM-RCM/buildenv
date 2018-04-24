#!/usr/bin/env bash

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

# COSMO Resources repository default
resources_repo="git@github.com:C2SM-RCM/libgrib-api-cosmo-resources.git"
# COSMO Resources version default
resources_version="master"
# Compiler target default
compiler_target="all"

while true; do
    case "$1" in
        --dir|-d) package_basedir=$2; shift 2;;
        --idir|-i) install_dir=$2; shift 2;;
        --local|-l) install_local="yes"; shift;;
        --compiler|-c) compiler_target=$2; shift 2;;
        --jasper_dir|-j) jasper_dir=$2; shift 2;;
        --resources_version|-r) resources_version=$2; shift 2;;
        --resources_repo) resources_repo=$2; shift 2;;
        --thread_safe|-n) thread_safe=yes; shift 2;;
        -- ) shift; break ;;
        * ) fwd_args="$fwd_args $1"; shift ;;
    esac
done

if [[ "${help_enabled}" == "yes" ]]; then
    echo "Available Options for libgrib:"
    echo "* --local             |-l {install locally}         Default=No"
    echo "* --compiler          |-c {compiler}                Default=all"
    echo "* --jasper_dir        |-j {jasper installation dir} Default=install_path/libjasper"
    echo "* --resources_version |-r {resources version}       Default=master (git object: branch, tag, etc..)"
    echo "* --resources_repo    |-r {resources repository}    COSMO Definitions Git Repository"
    echo "                                                    Default=git@github.com:MeteoSwiss-APN/libgrib-api-cosmo-resources.git"
    echo "* --thread_safe       |-n {thread_safe mode}        Default=False"
    exit 0
fi

if [[ -z ${package_basedir} ]]; then
    exitError 4201 ${LINENO} "package basedir has to be specified"
fi
if [[ -z ${install_dir} ]]; then
    exitError 4202 ${LINENO} "package install dir has to be specified"
fi
if [[ -z ${resources_version} ]]; then
    exitError 4203 ${LINENO} "resources_version has to be specified (coupling to libgrib)"
fi

# Setup
echo $@
# The current directory
base_path=$PWD
setupDefaults

# Obtain 
source ${package_basedir}/version.sh
grib_api_version="${GRIB_API_MAJOR_VERSION}.${GRIB_API_MINOR_VERSION}.${GRIB_API_REVISION_VERSION}${GRIB_API_MCH_PATCH}"

if [[ -z "${jasper_dir}" ]]; then
    jasper_dir="${install_dir}/libjasper"
fi

# Name of the COSMO Definitions Dir
cosmo_definitions_dir="cosmo_definitions"
# Temporary COSMO Definitions download location
cosmo_definitions_path=${base_path}/${cosmo_definitions_dir}

# Download the cosmo_definitions to the current base_path
get_cosmo_definitions() 
{   
    echo ">>> Downloading the COSMO definitions"
    if [ ! -d "${cosmo_definitions_path}" ]; then
        git clone $resources_repo "${cosmo_definitions_path}"
        if [ $? -ne 0 ]; then
            exitError 4211 ${LINENO} "unable to obtain ${resources_repo}"
        fi
    fi
    echo ">>> Checking out ${resources_version}"
    pushd "${cosmo_definitions_path}" &>/dev/null
        git fetch
        git checkout "${resources_version}"
        if [ $? -ne 0 ]; then
            exitError 4212 ${LINENO} "unable to checkout ${resources_version}"
        fi
    popd

    local cosmo_definitions_version_=$(cat $cosmo_definitions_path/RELEASE)
    local grib_api_version_short=${GRIB_API_MAJOR_VERSION}.${GRIB_API_MINOR_VERSION}.${GRIB_API_REVISION_VERSION}

    if [[ "${cosmo_definitions_version_}" != "v${grib_api_version_short}"* ]]; then
        exitError 4213 ${LINENO} "grib api ${grib_api_version_} and cosmo definitions version ${cosmo_definitions_version_} mismatch. "
    fi
}

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

    # Build config command
    config_command="./configure --build=x86_64 --host=x86_64 --prefix=${install_path} --with-jasper=${jasper_dir} --enable-static enable_shared=no --disable-jpeg"
    if [[ "${thread_safe}" == "yes" ]]; then
        config_command="${config_command} --enable-pthread --enable-omp-packing"
    fi

    writeModuleList ${base_path}/modules.log loaded "FORTRAN MODULES" ${base_path}/modules_fortran.env
    
    echo "Building for ${compiler} compiler"

    # Go to the grib api dir to call make
    pushd "${package_basedir}" &> /dev/null
        echo ">>>Running distclean"
        make distclean 2>/dev/null 1>/dev/null
        echo ">>>Running autoreconf"
        autoreconf &> build.log
        echo ">>>Running configure ($config_command)"
        $config_command &>> build.log
        if [ $? -ne 0 ]; then
            cat build.log
            exitError 4333 "Unable to configure libgrib_api with ${config_command}. See config.log for details."
        fi
        echo ">>>Compiling $packageName (make)"
        make &>> build.log
        if [ $? -ne 0 ]; then
            cat build.log
            exitError 4334 "Unable to compile libgrib_api."
        fi
        if [[ "${compiler}" != "cray" && "$(hostname)" != kesch* ]] ; then
            echo ">>>Checking (make check)"
            make check &>> build.log
            if [ $? -ne 0 ]; then
                cat build.log
                exitError 4335 "Check failed."
            fi
        else
            echo ">>> Check ignored for CRAY on Kesch"
        fi
        unsetFortranEnvironment
    popd &> /dev/null
}

# Install the package
install_to_target() 
{
    local install_path=$1
    pushd "${package_basedir}" &> /dev/null
        echo ">>>Purging ${install_path}"
        rm -rf ${install_path}
        echo ">>>Installing to ${install_path}"
        make install &> install.log
        if [ $? -ne 0 ]; then
            cat build.log
            cat install.log
            exitError 4341 "Installation failed."
        fi
    popd 
    cp -a ${cosmo_definitions_path} ${install_path}

    # Copy module files
    cp ${base_path}/modules_fortran.env ${install_path}/modules.env
    cat > ${install_path}/configuration.sh <<-EOF
# Generated by the package script
export GRIB_DEFINITION_PATH=${install_path}/cosmo_definitions/definitions/:${install_path}/share/grib_api/definitions/
export GRIB_SAMPLES_PATH=${install_path}/cosmo_definitions/samples/
EOF
}

# Build
get_cosmo_definitions

resource_version=$(cat $cosmo_definitions_path/RELEASE)

if [[ ${install_local} == "yes" ]]; then
    install_path_prefix_="${base_path}/install"
else
    install_path_prefix_="${install_dir}/libgrib_api/${resource_version}"
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
