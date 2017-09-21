#!/usr/bin/env bash

exitError()
{
	echo "ERROR $1: $3" 1>&2
	echo "ERROR     LOCATION=$0" 1>&2
	echo "ERROR     LINE=$2" 1>&2
	exit $1
}

showUsage()
{
	echo "usage: `basename $0` [-h] [-4] [-t target] [-c compiler] [-s slave] [-f kflat] [-l klevel] [-z]"
	echo ""
	echo "optional arguments:"
	echo "-4        Single precision (default: OFF)"
	echo "-t        Target (e.g. cpu or gpu)"
  echo "-c        Compiler (e.g. gnu, cray or pgi)"
	echo "-s        Slave (the machine)"
	echo "-f        STELLA K-Flat"
	echo "-l        STELLA K-Level"
	echo "-z        Clean builds"
}

# set defaults and process command line options
parseOptions()
{	
	singleprec=OFF
	compiler=""
	target=""
	slave=""
	kflat=""
	klevel=""
	verbosity=OFF
	cleanup=OFF

	while getopts ":4cfhi:nlor:st:va:x:z" opt; do
		case $opt in
		h) 
				showUsage
			  exit 0 
		  	;;
		4) 
		    singleprec=ON 
		    ;;
		c) 
		    compiler=$OPTARG 
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
		\?) 
		    showUsage
		    exitError 601 ${LINENO} "invalid command line option (-${OPTARG})"
		    ;;
		:) 
		    showUsage
		    exitError 602 ${LINENO} "command line option (-${OPTARG}) requires argument"
		    ;;
		esac
	done
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

# clone the repositories
cloneTheRepos()
{	
	git clone git@github.com:MeteoSwiss-APN/stella.git --branch crclim
	git clone git@github.com:C2SM-RCM/cosmo-pompa.git  --branch crclim
}

setupPaths()
{
	# path and directory structures
	stellapath="/project/c14/install/${slave}/crclim/stella_kflat8_klevel40/${compiler}"
	dycorepath="/project/c14/install/${slave}/crclim/dycore_cordex/${target}/${compiler}"
	cosmopath="/project/c14/install/${slave}/crclim/cosmo_cordex/${target}/${compiler}"

	# clean previous install path
	\rm -rf ${stellapath}/*
	\rm -rf ${dycorepath}/*
	\rm -rf ${cosmopath}/*
}

# compile and install the stella
doStella()
{
	cd stella
	test/jenkins/build.sh -c ${compiler} -i ${installpath} -f ${kflat} -k ${klevel} -z
	cd ..
}

# compile and install the dycore
doDycore()
{
	cd cosmo-pompa/dycore	
	test/jenkins/build.sh -c ${compiler} -t ${target} -s ${stellapath} -i ${dycorepath} -z
	cd ../..
}

# compile and install cosmo-pompa
doCosmo()
{
	cd cosmo-pompa/cosmo
	test/jenkins/build.sh -c ${compiler} -t ${target} -i ${cosmopath} -x ${dycorepath} -z
	cd ../..
}

