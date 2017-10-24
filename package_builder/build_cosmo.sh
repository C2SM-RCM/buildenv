#!/usr/bin/env bash

exitError()
{
	echo "ERROR $1: $3" 1>&2
	echo "ERROR     LOCATION=$0" 1>&2
	echo "ERROR     LINE=$2" 1>&2
	exit "$1"
}

tryExit()
{
	status=$1
	action=$2
	if [ "${status}" -ne 0 ]; then
		echo "ERROR in ${action} with ${status}" >&2
		exit "${status}"
  fi
}

showUsage()
{
	usage="usage: $(basename "$0") -c compiler -t target -o stella_org -q cosmo_org"
	usage="${usage} [-g] [-d] [-p] [-h] [-n name] [-s slave] [-b branch] [-f flat] [-l level] [-a branch] [-4] [-v] [-z] [-i prefix] [-x]"

	echo "Clone, compile and install COSMO-POMPA. "
	echo "WARNING: the script deletes "
	echo "${usage}"
	echo ""
	echo "-h        Show help"
	echo ""
	echo "mandatory arguments:"
	echo "-c        Compiler (e.g. gnu, cray or pgi)"
	echo "-t        Target (e.g. cpu or gpu)"					
	echo "-o        The STELLA github repository organisation (e.g. MeteoSwiss-APN), if build requested (with -g)"	
	echo "-q        The COSMO-POMPA github repository organisation (e.g. C2SM-RCM), if build requested (with -d or -p)"
	echo ""
	echo "optional arguments:"	
	echo "-n        The name of the project, default EMPTY"
	echo "-s        Slave (the machine), default EMPTY"
	echo "-b        The STELLA branch to checkout (e.g. crclim), default: master"
	echo "-f        STELLA K-Flat, default 19"
	echo "-l        STELLA K-Level, default 60"
	echo "-a        The COSMO-POMPA branch to checkout (e.g. crclim), default: master"
	echo "-4        Single precision, default: OFF"
	echo "-v        Verbose mode, default: OFF"
	echo "-z        Clean builds, default: OFF"
	echo "-g        Do Stella GNU build, default: OFF"
	echo "-d        Do CPP Dycore GNU build, default: OFF"
	echo "-p        Do Cosmo-Pompa build, default: OFF"
	echo "-i        Install prefix, default: ."
	echo "-x        Do bit-reproducible build, default: OFF"
}

# set defaults and process command line options
parseOptions()
{	
	local OPTIND
	singleprec=OFF
	projName=""
	compiler=""
	target=""
	slave=""
	kflat=""
	klevel=""
	stellaBranch="master"
	stellaOrg=""
	cosmoBranch="master"
	cosmoOrg=""
	instPrefix=$(pwd)
	verbosity=OFF
	cleanup=OFF
	doStella=OFF
	doDycore=OFF
	doPompa=OFF
	doRepro=OFF

	while getopts "h4n:c:b:o:a:q:t:s:f:l:vzgdpi:x" opt; do
		case "${opt}" in
		h) 
		    showUsage
		    exit 0 
		  	;;
		4) 
		    singleprec=ON 
		    ;;
		n)
		    projName=$OPTARG 
		    ;;
		c) 
		    compiler=$OPTARG 
		    ;;
		b)
		    stellaBranch=$OPTARG 
		    ;;
		o) 
		    stellaOrg=$OPTARG 
		    ;;
		a)
		    cosmoBranch=$OPTARG 
		    ;;
		q) 
		    cosmoOrg=$OPTARG
		    ;;
		t) 			
		    target=$OPTARG
		    ;;
		s)
		    slave=$OPTARG
		    ;;
		f)
		    kflat=$OPTARG
		    ;;
		l)
		    klevel=$OPTARG
		    ;;
		v) 
		    verbosity=ON
		    ;;
		z) 
		    cleanup=ON
		    ;;
		g) 
		    doStella=ON
		    ;;
		d) 
		    doDycore=ON
		    ;;
		p) 
		    doPompa=ON
		    ;;
		i)
		    instPrefix=$OPTARG
		    ;;
		x)
		    doRepro=ON
		    ;;
		\?) 
		    showUsage
		    exitError 601 ${LINENO} "invalid command line option (-${OPTARG})"
		    ;;
		esac
	done
	shift $((OPTIND-1))
}

# make sure the working variable are set
checkOptions()
{	
	echo "INFO: checking mandatory options"
	test -n "${compiler}"     || exitError 603 ${LINENO} "Option <compiler> is not set"
	test -n "${target}"       || exitError 604 ${LINENO} "Option <target> is not set"
	#test -n "${slave}"        || exitError 605 ${LINENO} "Option <slave> is not set"
	#test -n "${projName}"     || exitError 663 ${LINENO} "Option <projName> is not set"

	if [ ${doStella} == "ON" ] ; then
		#test -n "${kflat}"        || exitError 606 ${LINENO} "Option <flat> is not set"
		#test -n "${klevel}"       || exitError 607 ${LINENO} "Option <klevel> is not set"
		#test -n "${stellaBranch}" || exitError 665 ${LINENO} "Option <stellaBranch> is not set"
		test -n "${stellaOrg}"    || exitError 666 ${LINENO} "Option <stellaOrg> is not set"
	fi

	if [ ${doDycore} == "ON" ] ; then
		#test -n "${kflat}"        || exitError 606 ${LINENO} "Option <flat> is not set"
		#test -n "${klevel}"       || exitError 607 ${LINENO} "Option <klevel> is not set"
		#test -n "${cosmoBranch}"  || exitError 667 ${LINENO} "Option <cosmoBranch> is not set"
		test -n "${cosmoOrg}"     || exitError 668 ${LINENO} "Option <cosmoOrg> is not set"
	fi
	
	if [ ${doPompa} == "ON" ] ; then
		#test -n "${cosmoBranch}"  || exitError 667 ${LINENO} "Option <cosmoBranch> is not set"
		test -n "${cosmoOrg}"     || exitError 668 ${LINENO} "Option <cosmoOrg> is not set"
	fi
}

printConfig()
{
	echo "==============================================================="
	echo "BUILD CONFIGURATION"
	echo "==============================================================="
	echo "TASKS"
	echo "  DO STELLA COMPILATION:    ${doStella}"
	echo "  DO DYCORE COMPILATION:    ${doDycore}"
	echo "  DO POMPA COMPILATION:     ${doPompa}"
	echo "COMPILATION"
	echo "  COMPILER:                 ${compiler}"
	echo "  TARGET:                   ${target}"
	echo "  SINGLE PRECISION:         ${singleprec}"
	echo "  BIT-REPRODUCIBLE:         ${doRepro}"
	echo "  VERBOSE:                  ${verbosity}"
	echo "  CLEAN:                    ${cleanup}"
	echo "REPOSITORIES"
	echo "  STELLA ORGANISATION:      ${stellaOrg}"
	echo "  STELLA BRANCH:            ${stellaBranch}"
	if [ -z ${kflat+x} ]; then
		echo "  K-FLAT:                   ${kflat}"
	else
		echo "  K-FLAT:                   DEFAULT"
	fi
	if [ -z ${klevel+x} ]; then
		echo "  K-LEVEL:                  ${klevel}"
	else
		echo "  K-LEVEL:                  DEFAULT"
	fi	
	echo "  COSMO ORGANISATION:       ${cosmoOrg}"
	echo "  COSMO BRANCH:             ${cosmoBranch}"
	echo "INSTALL PATHS"
	echo "  SLAVE:                    ${slave}"
	echo "  PROJECT NAME:             ${projName}"
	echo "  INSTALL PREFIX:           ${instPrefix}"
	echo "  STELLA INSTALL:           ${stellapath}"
	echo "  DYCORE INSTALL:           ${dycorepath}"
	echo "  COSMO INSTALL:            ${cosmopath}"
	echo "==============================================================="
}

# clone the repositories
cloneTheRepos()
{		
	echo "INFO: Cloning needed repositories"
	# note that we clean the previous clone and they're supposed to be installed   
	# on another directory (simpler solution)	
	if [ ${doStella} == "ON" ] ; then
		echo "WARNING: Cleaning previous stella directories in 5 [s]"
		sleep 5
		if [ -d stella ]; then
			\rm -rf stella
		fi
		echo "Clone stella"
		git clone git@github.com:"${stellaOrg}"/stella.git --branch "${stellaBranch}"
	fi

	if [ ${doDycore} == "ON" ] || [ ${doPompa} == "ON" ] ; then
		echo "WARNING: cleaning previous cosmo-pompa directories in 5 [s]"
		sleep 5
		if [ -d cosmo-pompa ]; then
			\rm -rf cosmo-pompa
		fi
		echo "Clone cosmo-pompa (with dycore)"
		git clone git@github.com:"${cosmoOrg}"/cosmo-pompa.git --branch "${cosmoBranch}"
	fi
}

setupBuilds()
{
	# single precision flag
	moreFlag=""
	if [ ${singleprec} == "ON" ] ; then
		moreFlag="${moreFlag} -4"
	fi

	if [ ${verbosity} == "ON" ] ; then
		moreFlag="${moreFlag} -v"
	fi

	if [ ${cleanup} == "ON" ] ; then
		moreFlag="${moreFlag} -z"
	fi

	# compiler (for Stella and the Dycore)
	gnuCompiler="gnu"

	stellaDirName="stella"
	if [ "${kflat}x" != "x" ]; then
		stellaDirName="${stellaDirName}_kflat${kflat}"
	fi

	if [ "${klevel}x" != "x" ]; then
		stellaDirName="${stellaDirName}_klevel${klevel}"
	fi
	
	# path and directory structures
	stellapath="${instPrefix}/${slave}/${projName}/${stellaDirName}/${target}/${gnuCompiler}"
	dycorepath="${instPrefix}/${slave}/${projName}/dycore/${target}/${gnuCompiler}"
	cosmopath="${instPrefix}/${slave}/${projName}/cosmo/${target}/${compiler}"
}

cleanPreviousInstall() 
{
	# clean previous install path if needed
	if [ ${doStella} == "ON" ] && [ -d "${stellapath}" ] ; then
		\rm -rf "${stellapath:?}/"*
	fi
	
	if [ ${doDycore} == "ON" ] && [ -d "${dycorepath}" ] ; then
		\rm -rf "${dycorepath:?}/"*
	fi
	
	if [ ${doPompa} == "ON" ] && [ -d "${cosmopath}" ] ; then
		\rm -rf "${cosmopath:?}/"*
	fi
}

# compile and install stella
doStellaCompilation()
{
	kFlatLevels=""
	if [ -z ${kflat+x} ]; then
		kFlatLevels="${kFlatLevels} -f ${kflat}"
	else
		echo "K-FLAT is unset using default"
	fi

	if [ -z ${klevel+x} ]; then
		kFlatLevels="${kFlatLevels} -k ${klevel}"
	else
		echo "K-LEVELS is unset using default"
	fi

	cd stella || exitError 608 ${LINENO} "Unable to change directory into stella"
	if [ ${doRepro} == "ON" ] ; then
		test/jenkins/build.sh "${moreFlag}" -c "${gnuCompiler}" -i "${stellapath}" "${kFlatLevels}" -x
		retCode=$?
	else
		test/jenkins/build.sh "${moreFlag}" -c "${gnuCompiler}" -i "${stellapath}" "${kFlatLevels}"
		retCode=$?
	fi
	
	tryExit $retCode "STELLA BUILD"
	cd .. || exitError 609 ${LINENO} "Unable to go back"
}

# compile and install the dycore
doDycoreCompilation()
{
	cd cosmo-pompa/dycore || exitError 610 ${LINENO} "Unable to change directory into cosmo-pompa/dycore"
	test/jenkins/build.sh "${moreFlag}" -c "${gnuCompiler}" -t "${target}" -s "${stellapath}" -i "${dycorepath}" -s "${stellapath}"
	retCode=$?
	tryExit $retCode "DYCORE BUILD"
	cd ../.. || exitError 611 ${LINENO} "Unable to go back"
}

# compile and install cosmo-pompa
doCosmoCompilation()
{
	cd cosmo-pompa/cosmo || exitError 612 ${LINENO} "Unable to change directory into cosmo-pompa/cosmo"
	test/jenkins/build.sh "${moreFlag}" -c "${compiler}" -t "${target}" -i "${cosmopath}" -x "${dycorepath}"
	retCode=$?
	tryExit $retCode "COSMO BUILD"
	cd ../.. || exitError 612 ${LINENO} "Unable to go back"
}

# ===================================================
# MAIN LIKE
# ===================================================

# parse command line options (pass all of them to function)
parseOptions "$@"

# check the command line options
checkOptions

# setup
setupBuilds

printConfig

# clone
cloneTheRepos

# clean
cleanPreviousInstall

# compile and install
if [ ${doStella} == "ON" ] ; then
	doStellaCompilation
fi

if [ ${doDycore} == "ON" ] ; then
	doDycoreCompilation
fi

if [ ${doPompa} == "ON" ] ; then
	doCosmoCompilation
fi

# end without errors
echo "####### finished: $0 $* (PID=$$ HOST=$HOSTNAME TIME=$(date '+%D %H:%M:%S'))"
exit 0
