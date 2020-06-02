#!/bin/bash -x
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


# Get testsuite
git clone git@github.com:${ORGANIZATION}/testsuite
cd testsuite
git checkout ${BRANCH}
echo "Last commit in testsuite repo:"
git --no-pager log -1
cd $wd

# First, test cosmo-pompa
git clone git@github.com:COSMO-ORG/cosmo
rm -rf cosmo/cosmo/testsuite/src/*
cp -rf testsuite/* cosmo/cosmo/test/testsuite/src
cd cosmo/cosmo/ACC
compiler_orig=$compiler
if [ $CLAW == "ON" ]; then
    export compiler=claw-$compiler
fi
test -f ./test/jenkins/jenkins.sh || exit 1
./test/jenkins/jenkins.sh test || exit 1
#reset compiler
export compiler=$compiler_orig

if [ $test_int2lm == "ON" ]; then
    # Next, test int2lm
    cd $wd
    git clone git@github.com:MeteoSwiss-APN/int2lm
    cp -rf testsuite/* int2lm/test/testsuite/src
    cd int2lm/test
    test -f ./jenkins/jenkins.sh || exit 1
    export target="release"
    ./jenkins/jenkins.sh test
else
    echo "Info: int2lm test not active, set test_int2lm=ON to activate"
fi

