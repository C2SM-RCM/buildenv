#!/bin/bash -e

# First, test cosmo-pompa
git clone git@github.com:MeteoSwiss-APN/cosmo-pompa
git clone git@github.com:C2SM-RCM/testsuite
cd testsuite
git checkout ${BRANCH}
cd ..
rm -rf cosmo-pompa/cosmo/testsuite/src/*
cp -rf testsuite/* cosmo-pompa/cosmo/test/testsuite/src
cd cosmo-pompa/cosmo/test
test -f ./jenkins/jenkins.sh || exit 1
./jenkins/jenkins.sh test

# Next, test int2lm
cd ../../..
git clone git@github.com:MeteoSwiss-APN/int2lm
cp -rf testsuite/* int2lm/test/testsuite/src
cd int2lm/test
test -f ./jenkins/jenkins.sh || exit 1
export target="release"
export compiler="gnu"
./jenkins/jenkins.sh test

