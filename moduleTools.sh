#!/bin/bash -ex

# module tools

##################################################
# functions
##################################################

exitError()
{
  	echo "ERROR $1: $2" 1>&2
    exit $1
}


containsElement()
{
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}


isOnOff()
{
    local switch=$1
    local onoff=(ON OFF)
    containsElement "${switch}" "${onoff[@]}" || exitError 101 "Invalid value for ON/OFF switch (${switch}) chosen"
}


checkModuleAvailable()
{
    local module=$1
    if [ -n "${module}" ] ; then
        module avail -t 2>&1 | grep "${module}" &> /dev/null
        if [ $? -ne 0 ] ; then
            exitError 201 "module ${module} is unavailable"
        fi
    fi
}


compareFiles()
{
    one=$1
    two=$2
    msg=$3

    if [ ! -f "${one}" ] ; then exitError 3001 "Must supply two valid files to compareFiles (${one})" ; fi
    if [ ! -f "${two}" ] ; then exitError 3002 "Must supply two valid files to compareFiles (${two})" ; fi

    # sort and compare the two files
    diff <(sort "${one}") <(sort "${two}")

    if [ $? -ne 0 ] ; then
        echo "ERROR: Difference detected between ${one} and ${two} in compareFiles"
        echo "       ${msg}"
        exit 1
    fi

}


compilerVersion()
{
    compiler=$1

    # check for zero strings
    if [ -z "${compiler}" ] ; then exitError 3101 "Must supply a compiler command to compilerVersion" ; fi

    # find absolute path of compiler
    which ${compiler} &> /dev/null
    if [ $? -eq 1 ] ; then exitError 3102 "Cannot find compiler command (${compiler})" ; fi
    compiler=`which ${compiler}`

    # check for GNU
    res=`${compiler} -v 2>&1 | grep '^gcc'`
    if [ -n "${res}" ] ; then
        version=`echo "${res}" | awk '{print $3}'`
        echo ${version}
        return
    fi

    # check for Cray
    res=`${compiler} -V 2>&1 | grep '^Cray'`
    if [ -n "${res}" ] ; then
        version=`echo "${res}" | awk '{print $5}'`
        echo ${version}
        return
    fi

    # check for PGI
    res=`${compiler} -V 2>&1 | grep '^pg'`
    if [ -n "${res}" ] ; then
        version=`echo "${res}" | awk '{print $2}'`
        echo ${version}
        return
    fi
    
    # could not determine compiler version
    exitError 3112 "Could not determine compiler version (${compiler})"

}


writeModuleList()
{
    local logfile=$1
    local mode=$2
    local msg=$3
    local modfile=$4

    # check arguments
    test -n "${logfile}" || exitError 601 "Option <logfile> is not set"
    test -n "${mode}" || exitError 602 "Option <mode> is not set"
    test -n "${msg}" || exitError 603 "Option <msg> is not set"

    # check correct mode
    local modes=(all loaded)
    containsElement "${mode}" "${modes[@]}" || exitError 610 "Invalid mode (${mode}) chosen"

    # clean log file for "all" mode
    if [ "${mode}" == "all" ] ; then
        /bin/rm -f ${logfile} 2>/dev/null
        touch ${logfile}
    fi
    
    # log modules to logfile
    echo "=============================================================================" >> ${logfile}
    echo "${msg}:" >> ${logfile}
    echo "=============================================================================" >> ${logfile}
    if [ "${mode}" == "all" ] ; then
        module avail -t >> ${logfile} 2>&1
    elif [ "${mode}" == "loaded" ] ; then
        module list -t 2>&1 | grep -v alps >> ${logfile}
    else
        exitError 620 "Invalid mode (${mode}) chosen"
    fi

    # save list of loaded modules to environment file (if required)
    if [ -n "${modfile}" ] ; then
        /bin/rm -f ${modfile}
        touch ${modfile}
        module list -t 2>&1 | grep -v alps | grep -v '^- Package' | grep -v '^Currently Loaded' | sed 's/^/module load /g' > ${modfile}
    fi
}


