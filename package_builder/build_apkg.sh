#!/usr/bin/env bash

exitError()
{
    echo "ERROR $1: $3" 1>&2
    echo "ERROR     LOCATION=$0" 1>&2
    echo "ERROR     LINE=$2" 1>&2
    exit $1
}

package_basedir=$(pwd)

TEMP=$@
eval set -- "$TEMP --"
while true; do
    case "$1" in
        --package|-p) package=$2; shift 2;;
        --idir|-i) install_dir=$2; shift 2;;
        --dir|-d) package_basedir=$2; shift 2;;
        --help|-h) help_enabled=yes; fwd_args="$fwd_args $1"; shift;;
        -- ) shift; break ;;
        * ) fwd_args="$fwd_args $1"; shift ;;
    esac
done

if [[ "${help_enabled}" == "yes" ]]; then
    echo "Available Options:"
    echo "* --help.  |-h {print help}"
    echo "* --package|-p {package name}     Required"
    echo "* --dir.   |-i {install dir}      Default: from env"
    echo "* --idir.  |-d {package dir}      The package basedir. Default: \$(pwd)"
fi

if [[ -z ${package} ]]; then
    exitError 2220 ${LINENO} "package option has to be specified"
fi

if [[ -z ${package_basedir} ]]; then
    exitError 2221 ${LINENO} "package basedir has to be specified"
fi


BASEPATH_SCRIPT=$(dirname "${0}")
envloc="${BASEPATH_SCRIPT}/.."

# setup module environment and default queue
if [ ! -f ${envloc}/machineEnvironment.sh ] ; then
    exitError 2222 ${LINENO} "could not find ${envloc}/machineEnvironment.sh"
fi
source ${envloc}/machineEnvironment.sh
# load machine dependent functions
if [ ! -f ${envloc}/env.${host}.sh ] ; then
    exitError 2223 ${LINENO} "could not find ${envloc}/env.${host}.sh"
fi
source ${envloc}/env.${host}.sh

# load module tools
if [ ! -f ${envloc}/moduleTools.sh ] ; then
    exitError 1203 ${LINENO} "could not find ${envloc}/moduleTools.sh"
fi
source ${envloc}/moduleTools.sh

# if install not from option, get from machineEnvironment
if [[ -z ${install_dir} ]]; then
    install_dir=$installdir
fi


fwd_args="${fwd_args} -d ${package_basedir} -i ${install_dir}"

package_buildscript="${BASEPATH_SCRIPT}/build_${package}.sh"
if [ -f $package_buildscript ] ; then
    echo "Building specific package: ${package_buildscript} $fwd_args"
    . ${package_buildscript} $fwd_args
else
    exitError 2221 ${LINENO} "Package ${package} not known"
fi

