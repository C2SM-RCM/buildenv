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
if [ "`hostname | grep todi`" != "" ] ; then
    . /etc/bash.bashrc
    . /opt/modules/default/init/bash
    host="todi"
    queue="day"
    nthreads=16
    mpilaunch="aprun"
    installdir=/project/c01/install/${host}
    testdata=/scratch/todi/jenkins/data
elif [ "`hostname | grep opcode`" != "" ] ; then
    . /etc/bashrc
    . /etc/profile.d/modules.sh
    shopt -s expand_aliases
    alias sbatch='eval'
    alias squeue='echo'
    host="opcode"
    queue="primary"
    nthreads=8
    mpilaunch="mpirun"
    installdir=/project/c01/install/${host}
    testdata=/scratch/jenkins/data
elif [ "`hostname | grep lema`" != "" ] ; then
    . /etc/bash.bashrc
    . /opt/modules/default/init/bash
    host="lema"
    queue="dev"
    nthreads=12
    mpilaunch="aprun"
    installdir=/project/c01/install/${host}
    testdata=/scratch/jenkins/data
elif [ "`hostname | grep dom`" != "" ] ; then
    . /etc/bashrc
    . /apps/dom/Modules/3.2.10/init/bash
    modulepathadd /apps/dom/modulefiles
    host="dom"
    queue="normal"
    nthreads=8
    mpilaunch="mpiexec"
    installdir=/project/c01/install/${host}
    testdata=/scratch/dom/jenkins/dom/data
elif [ "`hostname | grep daint`" != "" ] ; then
    . /etc/bash.bashrc
    . /opt/modules/default/init/bash
    host="daint"
    queue="normal"
    nthreads=8
    mpilaunch="aprun"
    installdir=/project/c01/install/${host}
    testdata=/scratch/daint/jenkins/data
elif [ "`hostname | grep dora`" != "" ] ; then
    . /etc/bash.bashrc
    . /opt/modules/default/init/bash
    host="dora"
    queue="normal"
    nthreads=8
    mpilaunch="aprun"
    installdir=/project/c01/install/${host}
    testdata=/scratch/dora/jenkins/data
elif [ "`hostname | grep jupiter`" != "" ] ; then
    . /etc/bash.bashrc
    . /opt/modules/default/init/bash
    host="jupiter"
    queue="batch"
    nthreads=8
    mpilaunch="aprun"
    installdir="???"
    testdata="???"
elif [ "`hostname | grep castor`" != "" ] ; then
    . /etc/bashrc
    . /apps/castor/Modules/default/init/bash
    module load slurm
    host="castor"
    queue="normal"
    nthreads=6
    mpilaunch="mpiexec"
    installdir=/project/c01/install/${host}
    testdata=/scratch/castor/jenkins/castor/data
elif [ "`hostname | grep santis`" != "" ] ; then
    . /etc/bash.bashrc
    . /opt/modules/default/init/bash
    host="santis"
    queue="normal"
    nthreads=8
    mpilaunch="aprun"
    installdir="???"
    testdata="???"
elif [ "`hostname | grep durian`" != "" ] ; then
    shopt -s expand_aliases
    alias sbatch='eval'
    alias squeue='echo'
    alias module='echo $* 2>/dev/null 1>/dev/null'
    host="durian"
    queue="normal"
    nthreads=4
    mpilaunch="mpirun"
    installdir="/Users/fuhrer/Desktop/install"
    testdata="/Users/fuhrer/Desktop/install/testdata"
elif [ "`hostname | grep bertie`" != "" ] ; then
    shopt -s expand_aliases
    alias sbatch='eval'
    alias squeue='echo'
    alias module='echo $* 2>/dev/null 1>/dev/null'
    host="bertie"
    queue="normal"
    nthreads=4
    mpilaunch="mpirun"
    installdir="/home/spiros/Work/install"
    testdata="/home/spiros/Work/install/testdata"
elif [ "`hostname | grep osprey`" != "" ] ; then
    . /etc/bashrc
    . /usr/Modules/3.2.10/init/bash
    #  module swap craype-sandybridge craype-haswell
    host="osprey"
    queue="workq"
    nthreads=1
    mpilaunch="mpiexec.hydra -bootstrap slurm"
    #  installdir="/cray/css/users/n17183/install"
    #  testdata="/cray/css/users/n17183/data"
    installdir="/cray/css/pe_tools/malice/builds/cosmo/2015Feb17/COSMO/stella/install"
    testdata="/cray/css/pe_tools/malice/builds/cosmo/2015Feb17/COSMO/stella/data"
elif [ "`hostname | grep kesch`" != "" -o "`hostname | grep escha`" != "" ] ; then
    . /etc/bashrc
    . /usr/Modules/3.2.10/init/bash
    . /etc/profile.d/cray_pe.sh
    host="kesch"
    queue="debug"
    nthreads=6
    mpilaunch="srun"
    installdir="/project/c01/install/${host}"
    testdata="/lus/scratch/jenkins/data"
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

