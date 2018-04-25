#!/bin/bash

# setup environment for different systems
# 
# NOTE: the location of the base bash script and module initialization
#       vary from system to system, so you will have to add the location
#       if your system is not supported below

exitError()
{
    \rm -f /tmp/tmp.${user}.$$ 1>/dev/null 2>/dev/null
    echo "ERROR $1: $3" 1>&2
    echo "ERROR     LOCATION=$0" 1>&2
    echo "ERROR     LINE=$2" 1>&2
    exit $1
}

showWarning()
{
    echo "WARNING $1: $3" 1>&2
    echo "WARNING       LOCATION=$0" 1>&2
    echo "WARNING       LINE=$2" 1>&2
}

modulepathadd() {
    if [ -d "$1" ] && [[ ":$MODULEPATH:" != *":$1:"* ]]; then
        MODULEPATH="${MODULEPATH:+"$MODULEPATH:"}$1"
    fi
}

# setup empty defaults
host=""         # name of host
queue=""        # standard queue to submit jobs to
nthreads=""     # number of threads to use for parallel builds
mpilaunch=""    # command to launch an MPI executable (e.g. aprun)
installdir=""   # directory where libraries are installed
testdata=""     # directory where unittestdata is stored

# setup machine specifics
if [ "`hostname | grep daint`" != "" ] ; then
    . /etc/bash.bashrc
    . /opt/modules/default/init/bash
    . /etc/bash.bashrc.local
    export host="daint"
    queue="normal"
    nthreads=8
    mpilaunch="srun"
    installdir=/project/c14/install/${host}
    testdata=/scratch/snx3000/jenkins/data
elif [ "`hostname | grep dom`" != "" ] ; then
    . /etc/bash.bashrc
    . /opt/modules/default/init/bash
    . /etc/bash.bashrc.local
    export host="dom"
    queue="normal"
    nthreads=8
    mpilaunch="srun"
    installdir=/project/c14/install/${host}
    testdata=/scratch/snx1600tds/jenkins/data
elif [ "`hostname | grep dora`" != "" ] ; then
    . /etc/bash.bashrc
    . /opt/modules/default/init/bash
    export host="dora"
    queue="normal"
    nthreads=8
    mpilaunch="aprun"
    installdir=/project/c14/install/daint
    testdata=/scratch/dora/jenkins/data
## Disabled block for testing a particular kesch node with special environment
#elif [[ "$(hostname)" == "keschcn-"* ]]; then
#    . /etc/bashrc && true # In some conditions the omitted true triggered an error.
#    export host="kesch-test"
#    echo "The host is ${host}"
#    queue="debug"
#    nthreads=1
#    mpilaunch="srun"
#    installdir="/project/c14/install/${host}"
#    testdata="/scratch/jenkins/data"
elif [ "`hostname | grep kesch`" != "" -o "`hostname | grep escha`" != "" ] ; then
    . /etc/bashrc && true # In some conditions the omitted true triggered an error.
    if [ "${NODE_NAME}" == kesch-pgi ] ; then
	export host="kesch-pgi"
    else
	export host="kesch"
    fi
    queue="debug"
    nthreads=1
    mpilaunch="srun"
    installdir="/project/c14/install/${host}"
    testdata="/scratch/jenkins/data"
elif [ "`hostname | grep greina`" != "" ] ; then
    . /etc/bashrc
    . /cm/local/apps/environment-modules/3.2.10/init/bash
    export host="greina"
    queue="none"
    nthreads=4
    mpilaunch="none"
    installdir="/users/jenkins/install/${host}/"
    testdata=???
fi

# make sure everything is set
test -n "${host}" || exitError 2001 ${LINENO} "Variable <host> could not be set (unknown machine `hostname`?)"
test -n "${queue}" || exitError 2002 ${LINENO} "Variable <queue> could not be set (unknown machine `hostname`?)"
test -n "${nthreads}" || exitError 2003 ${LINENO} "Variable <nthreads> could not be set (unknown machine `hostname`?)"
test -n "${mpilaunch}" || exitError 2004 ${LINENO} "Variable <mpilaunch> could not be set (unknown machine `hostname`?)"
test -n "${installdir}" || exitError 2005 ${LINENO} "Variable <installdir> could not be set (unknown machine `hostname`?)"

# export installation directory
export INSTALL_DIR="${installdir}"
export TESTDATA_DIR="${testdata}"

