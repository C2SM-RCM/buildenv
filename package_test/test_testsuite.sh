#!/bin/bash -e
module load git/2.8.4
git clone git@github.com:MeteoSwiss-APN/cosmo-pompa
cd cosmo-pompa
git remote add -f testsuite git@github.com:C2SM-RCM/testsuite
git subtree pull --prefix cosmo/test/testsuite/src/ testsuite ${BRANCH} --squash -m "Update testsuite"
cd cosmo/test
test -f ./jenkins/jenkins.sh || exit 1
./jenkins/jenkins.sh test
