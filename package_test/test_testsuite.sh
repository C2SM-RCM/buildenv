#!/bin/bash -e
# Script to test a branch "BRANCH" of the testsuite

if [ -z "${BRANCH}" ] ; then
     echo "Error : BRANCH env variable not defined"
     exit 1
fi

if [ -z "${ORGANIZATION}" ] ; then
     export ORGANIZATION="C2SM-RCM"
fi

wd=`pwd`
echo Working dir $wd

module load PE/17.06
module load python

# Get testsuite
git clone git@github.com:${ORGANIZATION}/testsuite
cd testsuite
git checkout ${BRANCH}
echo "Last commit in testsuite repo:"
git --no-pager log -1
cd $wd

# First, test cosmo-pompa
git clone git@github.com:MeteoSwiss-APN/cosmo-pompa
rm -rf cosmo-pompa/cosmo/testsuite/src/*
cp -rf testsuite/* cosmo-pompa/cosmo/test/testsuite/src
cd cosmo-pompa/cosmo/test
export compiler="cray"
test -f ./jenkins/jenkins.sh || exit 1
./jenkins/jenkins.sh test

# Next, test int2lm
cd $wd
git clone git@github.com:MeteoSwiss-APN/int2lm
cp -rf testsuite/* int2lm/test/testsuite/src
cd int2lm/test
test -f ./jenkins/jenkins.sh || exit 1
export target="release"
export compiler="gnu"
./jenkins/jenkins.sh test

