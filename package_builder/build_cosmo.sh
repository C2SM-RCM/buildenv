#!/usr/bin/env bash

pWarning()
{
  msg=$1
  YELLOW='\033[1;33m'
  NC='\033[0m'
  echo -e "${YELLOW}[WARNING]${NC} ${msg}"
}

pInfo()
{
  msg=$1
  BLUE='\033[1;34m'
  NC='\033[0m'
  echo -e "${BLUE}[INFO]${NC} ${msg}"
}

pOk()
{
  msg=$1
  GREEN='\033[1;32m'
  NC='\033[0m'
  echo -e "${GREEN}[OK]${NC} ${msg}"
}

exitError()
{
    RED='\033[0;31m'
    NC='\033[0m'
	echo -e "${RED}EXIT WITH ERROR${NC}"
	echo "ERROR $1: $3" 1>&2
	echo "ERROR     LOCATION=$0" 1>&2
	echo "ERROR     LINE=$2" 1>&2
	exit "$1"
}

countDown()
{	
	YELLOW='\033[1;33m'
	NC='\033[0m'
	secs=$1
	msg=$2
	while [ $secs -ge 0 ]; do
   		echo -ne "${YELLOW}[WARNING]${NC} ${msg} $secs \033[0K\r"
		sleep 1
		: $((secs--))
	done
}

clean5Down()
{
	countDown 5 "cleaning in"
	pInfo "directory removed"
}

tryExit()
{
	status=$1
	action=$2
	if [ "${status}" -ne 0 ]; then
		echo "ERROR in ${action} with ${status}" >&2
		exit "${status}"
	else
		pOk "${action}"
	fi
}

showUsage()
{	
	echo "Clone, compile and install COSMO-POMPA."
	echo ""
	echo "WARNING:"
	echo " - the script clones the repositories in the working directory"
	echo " - the script clones only what is built (see -g, -d or -p)"
	echo " - the script deletes the stella and cosmo-pompa in the working directory before doing a clone (if needed)"
	echo ""
	echo "USAGE:"
	usage="$(basename "$0") -c compiler -t target -o stella_org -q cosmo_org"
	usage="${usage} [-g] [-d] [-p] [-h] [-n name] [-s slave] [-b branch] [-f flat] [-l level] [-a branch] [-4] [-v] [-z] [-i prefix] [-x config]"

	echo "${usage}"
	echo ""
	echo "-h        Show help"
	echo ""
	echo "Mandatory arguments:"
	echo "-c        Compiler (e.g. gnu, cray or pgi)"
	echo "-t        Target (e.g. cpu or gpu)"					
	echo "-o        The STELLA github repository organization (e.g. MeteoSwiss-APN), if build requested (with -g)"	
	echo "-q        The COSMO-POMPA github repository organization (e.g. C2SM-RCM), if build requested (with -d or -p)"
	echo ""
	echo "Optional arguments, see default:"	
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
	echo "-i        Install prefix, default: current working directory"
	echo "-x        Do bit-reproducible build and provide config file, default: OFF"
	echo "-j        Use the default install path instead of the constructed installation path"
	echo "-e        Debug build, default: OFF"
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
	debugBuild=OFF
	cleanup=OFF
	# compile stella
	doStella=OFF
	# compile the dycore
	doDycore=OFF
	# compile cosmo
	doPompa=OFF
	# make reproducible executable
	doRepro=OFF
	configFile=""
	# the CRCLIM branch
	jenkinsPath=OFF

	while getopts "h4n:c:b:o:a:q:t:s:f:l:vzgdpi:x:je" opt; do
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
		    configFile=$OPTARG
		    ;;
		j)
			jenkinsPath=ON
			;;
		e)
			debugBuild=ON
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
	test -n "${compiler}" || exitError 603 ${LINENO} "Option <compiler> is not set"
	test -n "${target}" || exitError 604 ${LINENO} "Option <target> is not set"

	if [ ${doStella} == "ON" ] ; then
		test -n "${stellaOrg}" || exitError 666 ${LINENO} "Option <stellaOrg> is not set"
	fi

	if [ ${doDycore} == "ON" ] ; then
		test -n "${cosmoOrg}" || exitError 668 ${LINENO} "Option <cosmoOrg> is not set"
	fi
	
	if [ ${doPompa} == "ON" ] ; then
		test -n "${cosmoOrg}" || exitError 668 ${LINENO} "Option <cosmoOrg> is not set"
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
	if [ "${configFile}x" != "x" ]; then
		echo "  CONFIG FILE (JSON):       ${configFile}"
	else
		echo "  CONFIG FILE (JSON):       N/A"
	fi	
	echo "  VERBOSE:                  ${verbosity}"
	echo "  CLEAN:                    ${cleanup}"
	echo "  DEBUG:                    ${debugBuild}"
	echo "REPOSITORIES"
	echo "  STELLA ORGANIZATION:      ${stellaOrg}"
	echo "  STELLA BRANCH:            ${stellaBranch}"
	if [ "${kflat}x" != "x" ]; then
		echo "  K-FLAT:                   ${kflat}"
	else
		echo "  K-FLAT:                   DEFAULT"
	fi
	if [ "${klevel}x" != "x" ]; then
		echo "  K-LEVEL:                  ${klevel}"
	else
		echo "  K-LEVEL:                  DEFAULT"
	fi	
	echo "  COSMO ORGANIZATION:       ${cosmoOrg}"
	echo "  COSMO BRANCH:             ${cosmoBranch}"
	echo "INSTALL PATHS"
	if [ "${slave}x" != "x" ]; then	
		echo "  SLAVE:                    ${slave}"
	else
		echo "  SLAVE:                    N/A"
	fi
	if [ "${projName}x" != "x" ]; then
		echo "  PROJECT NAME:             ${projName}"
	else
		echo "  PROJECT NAME:             N/A"
	fi
	echo "  INSTALL PREFIX:           ${instPrefix}"
	echo "  STELLA INSTALL:           ${stellapath}"
	echo "  DYCORE INSTALL:           ${dycorepath}"
	echo "  COSMO INSTALL:            ${cosmopath}"
	echo "==============================================================="
}

# clone the repositories
cloneTheRepos()
{
	cwd=$(pwd)
	pInfo "cloning needed repositories"
	# note that we clean the previous clone and they're supposed to be installed   
	# on another directory (simpler solution)	
	if [ ${doStella} == "ON" ] ; then
		#echo "WARNING: Cleaning previous stella source directories in 5 [s]"
		#echo "WARNING: ${cwd}/stella"
		pWarning "cleaning previous stella source directories in 5 [s]"
		pWarning "${cwd}/stella"
		clean5Down
		if [ -d stella ]; then
			\rm -rf stella
		fi
		pInfo "cloning stella"
		git clone git@github.com:"${stellaOrg}"/stella.git --branch "${stellaBranch}"
	fi

	if [ ${doDycore} == "ON" ] || [ ${doPompa} == "ON" ] ; then
		#echo "WARNING: cleaning previous cosmo-pompa source directories in 5 [s]"
		#echo "WARNING: ${cwd}/cosmo-pompa"
		pWarning "cleaning previous cosmo-pompa source directories in 5 [s]"
		pWarning "${cwd}/cosmo-pompa"		
		clean5Down
		if [ -d cosmo-pompa ]; then
			\rm -rf cosmo-pompa
		fi
		pInfo "cloning cosmo-pompa (with dycore)"
		git clone git@github.com:"${cosmoOrg}"/cosmo-pompa.git --branch "${cosmoBranch}"
		pInfo "updating submodules"
		cd cosmo-pompa
		git submodule update --init
		cd ..
	fi
}

setupBuilds()
{
	cwd=$1
	
	# single precision flag
	moreFlag=""
	if [ ${singleprec} == "ON" ] ; then
		moreFlag="${moreFlag} -4"
	fi
	# verbosity flag
	if [ ${verbosity} == "ON" ] ; then
		moreFlag="${moreFlag} -v"
	fi
	# cleanup flag
	if [ ${cleanup} == "ON" ] ; then
		moreFlag="${moreFlag} -z"
	fi
	# debug flag
	if [ ${debugBuild} == "ON" ] ; then
		moreFlag="${moreFlag} -d"
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
	
	

	if [[ "${instPrefix}" = /* ]] ; then
	   pInfo "Absolute install prefix path"
	else
	   pInfo "Relative install prefix path. Appending current working directory"
	   pInfo ${instPrefix}
	   instPrefix="${cwd}/${instPrefix}"
	   pInfo ${instPrefix}
	fi
	
	# path and directory structures
	installDir="${instPrefix}/${slave}/${projName}"
	stellapath="${installDir}/${stellaDirName}/${target}/${gnuCompiler}"
	dycorepath="${installDir}/dycore/${target}/${gnuCompiler}"
	cosmopath="${installDir}/cosmo/${target}/${compiler}"
}

cleanPreviousInstall() 
{
	cwd=$(pwd)
	# clean previous install path if needed
	if [ ${doStella} == "ON" ] ; then
		if [ -d "${stellapath}" ] ; then
			pWarning "cleaning previous stella install directories in 5 [s] at:"
			pWarning "${stellapath}"
			clean5Down
		\rm -rf "${stellapath:?}/"*
		fi
		pInfo "creating directory: ${stellapath}"
		pInfo "at the current location: ${cwd}"
		mkdir -p "${stellapath}"
	fi
	
	if [ ${doDycore} == "ON" ] ; then
		if [ -d "${dycorepath}" ] ; then
			pWarning "cleaning previous dycore install directories in 5 [s] at:"
			pWarning "${dycorepath}"
			clean5Down
			\rm -rf "${dycorepath:?}/"*
		fi
		pInfo "creating directory: ${dycorepath}"
		pInfo "at the current location: ${cwd}"
		mkdir -p "${dycorepath}"
	fi
	
	if [ ${doPompa} == "ON" ] ; then
		if [ -d "${cosmopath}" ] ; then
			pWarning "cleaning previous cosmo install directories in 5 [s] at:"
			pWarning "${cosmopath}"
			clean5Down	
			\rm -rf "${cosmopath:?}/"*
		fi
		pInfo "creating directory: ${cosmopath}"
		pInfo "at the current location: ${cwd}"
		mkdir -p "${cosmopath}"
	fi
}

# compile and install stella
doStellaCompilation()
{
	kFlatLevels=""
	if [ "${kflat}x" != "x" ]; then
		kFlatLevels="${kFlatLevels} -f ${kflat}"		
	else
		pInfo "K-FLAT is unset using default"
	fi

	if [ "${klevel}x" != "x" ]; then
		kFlatLevels="${kFlatLevels} -k ${klevel}"
	else
		pInfo "K-LEVELS is unset using default"
	fi

	cd stella || exitError 608 ${LINENO} "Unable to change directory into stella"
	
	extraFlags="-c ${gnuCompiler} -i ${stellapath} ${kFlatLevels}"
	if [ ${doRepro} == "ON" ] ; then
		extraFlags="${extraFlags} -x"
	fi
	
	test/jenkins/build.sh "${moreFlag}" "${extraFlags}"
	retCode=$?
	tryExit $retCode "STELLA BUILD"
	cd .. || exitError 609 ${LINENO} "Unable to go back"
}

# compile and install the dycore
doDycoreCompilation()
{
	cd cosmo-pompa/dycore || exitError 610 ${LINENO} "Unable to change directory into cosmo-pompa/dycore"

	extraFlags="-c ${gnuCompiler} -t ${target} -i ${dycorepath}"
	if [ ${jenkinsPath} == "OFF" ] ; then
		extraFlags="${extraFlags} -s ${stellapath}"
	fi
	test/jenkins/build.sh "${moreFlag}" "${extraFlags}"
	retCode=$?
	tryExit $retCode "DYCORE BUILD"
	cd ../.. || exitError 611 ${LINENO} "Unable to go back"
}

# compile and install cosmo-pompa
doCosmoCompilation()
{
	cd cosmo-pompa/cosmo || exitError 612 ${LINENO} "Unable to change directory into cosmo-pompa/cosmo"	

	extraFlags="-c ${compiler} -t ${target} -i ${cosmopath}"
	if [ ${doRepro} == "ON" ] || [ ${jenkinsPath} == "OFF" ] ; then
		export CRCLIMJSON=${configFile}
		extraFlags="${extraFlags} -x ${dycorepath}"
	fi	

	test/jenkins/build.sh "${moreFlag}" "${extraFlags}"
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
rootWd=$(pwd)
setupBuilds $rootWd

printConfig

# clone
cloneTheRepos

# clean and create install structure
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
