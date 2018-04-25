#!/bin/bash -e

# First, test cosmo-pompa
git clone git@github.com:MeteoSwiss-APN/cosmo-pompa
cd cosmo-pompa
git config user.email "jenkins@cscs.ch"
git config user.name "Mr. Jenkins"
git remote add -f testsuite git@github.com:C2SM-RCM/testsuite
git subtree pull --prefix cosmo/test/testsuite/src/ testsuite ${BRANCH} --squash -m "Update testsuite"
cd cosmo/test
test -f ./jenkins/jenkins.sh || exit 1
./jenkins/jenkins.sh test

# Next, test int2lm
cd ../../..
git clone git@github.com:MeteoSwiss-APN/int2lm
cd int2lm
git config user.email "jenkins@cscs.ch"
git config user.name "Mr. Jenkins"
git remote add -f testsuite git@github.com:C2SM-RCM/testsuite
git subtree pull --prefix test/testsuite/src/ testsuite ${BRANCH} --squash -m "Update testsuite"
cd test
test -f ./jenkins/jenkins.sh || exit 1
export target="release"
export compiler="gnu"
./jenkins/jenkins.sh test

