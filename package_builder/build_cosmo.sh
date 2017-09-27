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
	echo "usage: $(basename "$0") -t target -c compiler -s slave -b stella branch -o stella org -a cosmo branch -q cosmo org [-4] [-f kflat] [-l klevel] [-z] [-h]"
	echo ""
	echo "optional arguments:"
	echo "-4        Single precision (default: OFF)"
	echo "-n        The name of the project"
	echo "-o        The STELLA github repository organisation"
	echo "-b        The STELLA branch to checkout"	
	echo "-q        The COSMO-POMPA github repository organisation"
	echo "-a        The COSMO-POMPA branch to checkout"	
	echo "-t        Target (e.g. cpu or gpu)"
	echo "-c        Compiler (e.g. gnu, cray or pgi)"
	echo "-s        Slave (the machine)"
	echo "-f        STELLA K-Flat"
	echo "-l        STELLA K-Level"
	echo "-z        Clean builds"
	echo "-g        Do GNU build: Stella"
	echo "-d        Do GNU build: the CPP Dycore"
	echo "-p        Do Cosmo-Pompa build"
	echo "-x        Do bit-reproducible build"	
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
	stellaBranch=""
	stellaOrg=""
	cosmoBranch=""
	cosmoOrg=""
	verbosity=OFF
	cleanup=OFF
	doStella=OFF
	doDycore=OFF
	doPompa=OFF
	doRepro=OFF

	while getopts "h4n:c:t:s:f:l:b:o:a:q:vzgdpx" opt; do
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
	test -n "${compiler}" || exitError 603 ${LINENO} "Option <compiler> is not set"
	test -n "${target}" || exitError 604 ${LINENO} "Option <target> is not set"
	test -n "${slave}" || exitError 605 ${LINENO} "Option <slave> is not set"
	test -n "${kflat}" || exitError 606 ${LINENO} "Option <flat> is not set"
	test -n "${klevel}" || exitError 607 ${LINENO} "Option <klevel> is not set"
}

printConfig()
{
	echo "==============================================================="
	echo "BUILD CONFIGURATION"
	echo "==============================================================="
	echo "PROJECT NAME:             ${projName}"
	echo "SINGLE PRECISION:         ${singleprec}"
	echo "STELLA ORGANISATION:      ${stellaOrg}"
	echo "STELLA BRANCH:            ${stellaBranch}"
	echo "COSMO ORGANISATION:       ${cosmoOrg}"
	echo "COSMO BRANCH:             ${cosmoBranch}"
	echo "COMPILER:                 ${compiler}"
	echo "TARGET:                   ${target}"
	echo "SLAVE:                    ${slave}"
	echo "K-FLAT:                   ${kflat}"
	echo "K-LEVEL:                  ${klevel}"
	echo "BIT-REPRO:                ${doRepro}"
	echo "VERBOSE:                  ${verbosity}"
	echo "CLEAN:                    ${cleanup}"
	echo "DO STELLA COMPILATION:    ${doStella}"
	echo "DO DYCORE COMPILATION:    ${doDycore}"
	echo "DO POMPA COMPILATION:     ${doPompa}"
	echo "==============================================================="
}

# clone the repositories
cloneTheRepos()
{	
	# clean the previous clone (simpler solution)
	echo "Clean previous directories (stella and cosmo-pompa)"
	\rm -rf stella
	\rm -rf cosmo-pompa
	echo "Clone stella and cosmo-pompa"
	git clone git@github.com:"${stellaOrg}"/stella.git --branch "${stellaBranch}"
	git clone git@github.com:"${cosmoOrg}"/cosmo-pompa.git --branch "${cosmoBranch}"
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
	# path and directory structures
	stellapath="/project/c14/install/${slave}/crclim/stella_kflat${kflat}_klevel${klevel}/${projName}/${target}/${gnuCompiler}"
	dycorepath="/project/c14/install/${slave}/crclim/dycore/${projName}/${target}/${gnuCompiler}"
	cosmopath="/project/c14/install/${slave}/crclim/cosmo/${projName}/${target}/${compiler}"

	# clean previous install path if needed
	if [ ${doStella} == "ON" ] ; then
		\rm -rf "${stellapath:?}/"*
	fi
	
	if [ ${doDycore} == "ON" ] ; then
		\rm -rf "${dycorepath:?}/"*
	fi
	
	if [ ${doPompa} == "ON" ] ; then
		\rm -rf "${cosmopath:?}/"*
	fi
}

# compile and install stella
doStellaCompilation()
{
	cd stella || exitError 608 ${LINENO} "Unable to change directory into stella"
	if [ ${doRepro} == "ON" ] ; then
		test/jenkins/build.sh "${moreFlag}" -c "${gnuCompiler}" -i "${stellapath}" -f "${kflat}" -k "${klevel}" -z -x
		retCode=$?
	else
		test/jenkins/build.sh "${moreFlag}" -c "${gnuCompiler}" -i "${stellapath}" -f "${kflat}" -k "${klevel}" -z
		retCode=$?
	fi
	
	tryExit $retCode "STELLA BUILD"
	cd .. || exitError 609 ${LINENO} "Unable to go back"
}

# compile and install the dycore
doDycoreCompilation()
{
	cd cosmo-pompa/dycore || exitError 610 ${LINENO} "Unable to change directory into cosmo-pompa/dycore"
	test/jenkins/build.sh "${moreFlag}" -c "${gnuCompiler}" -t "${target}" -s "${stellapath}" -i "${dycorepath}" -s "${stellapath}" -z
	retCode=$?
	tryExit $retCode "DYCORE BUILD"
	cd ../.. || exitError 611 ${LINENO} "Unable to go back"
}

# compile and install cosmo-pompa
doCosmoCompilation()
{
	cd cosmo-pompa/cosmo || exitError 612 ${LINENO} "Unable to change directory into cosmo-pompa/cosmo"
	test/jenkins/build.sh "${moreFlag}" -c "${compiler}" -t "${target}" -i "${cosmopath}" -x "${dycorepath}" -z
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

printConfig

# clone
cloneTheRepos

# setup
setupBuilds

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
