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
while true; do
    case "$1" in
        --dir|-d) package_basedir=$2; shift 2;;
        --idir|-i) install_dir=$2; shift 2;;
        --local) install_local="yes"; shift;; 
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

echo $@
base_path=$PWD
setupDefaults

if [[ ${install_local} == "yes" ]]; then
    install_args="--local"
else
    install_args="-i ${install_dir}/serialbox/${c_}/"
fi

for c_ in ${compilers[@]}; do
    echo "Compiling and installing for $c_"
    export compiler=${c_}

    if [[ ${install_local} == "yes" ]]; then
        install_path_="${base_path}/install/${c_}/"
        install_args="-i ${install_path_}"
    else
        install_path_="${install_dir}/serialbox/${c_}/"
        install_args="-i ${install_path_}/"
    fi

    setFortranEnvironment
    writeModuleList ${base_path}/modules.log loaded "FORTRAN MODULES" ${base_path}/modules_fortran.env

    get_fcompiler_cmd fcomp_cmd ${c_}
    if [[ -z ${fcomp_cmd} ]]; then
        exitError 3387 ${LINENO} "could not set the fortran compiler you are building with"
    fi
    echo "Building for fortran compiler: ${fcomp_cmd}"
    ${package_basedir}/test/build.sh --fcompiler ${fcomp_cmd} ${install_args} -z ${fwd_args}
    
    # Copy module files
    cp modules_fortran.env ${install_path_}/modules.env
    unsetFortranEnvironment
done

