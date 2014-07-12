#!/bin/bash

# SLURM tools

##################################################
# functions
##################################################

exitError()
{
    \rm -f /tmp/tmp.$$ 1>/dev/null 2>/dev/null
    echo "ERROR $1: LINE=$2" 1>&2
    PARENT_COMMAND=$(ps $PPID | tail -n 1 | awk "{print \$6}")
    echo "ERROR       LOCATION=$0"
    exit $1
}

showWarning()
{
    echo "WARNING $1: LINE=$2" 1>&2
    echo "WARNING       LOCATION=$0"
}

# function to launch and wait for job (until job finishes or a
# specified timeout in seconds is reached)
#
# usage: launch_job script timeout

function launch_job {
  local script=$1
  local timeout=$2

  # check sanity of arguments
  test -f "${script}" || exitError 7201 "${LINENO}: cannot find script ${script}"
  if [ -n "${timeout}" ] ; then
      echo "${timeout}" | grep '^[0-9][0-9]*$' 2>&1 > /dev/null
      if [ $? -ne 0 ] ; then
          exitError 7203 "${LINENO}: timeout is not a number"
      fi
  fi

  # submit SLURM job
  local res=`sbatch ${script}`
  if [ $? -ne 0 ] ; then
      exitError 7205 "${LINENO}: problem submitting SLURM batch job"
  fi
  echo "${res}" | grep "^Submitted batch job [0-9][0-9]*$" || exitError 7206 "${LINENO}: problem determining job ID of SLURM job"
  local jobid=`echo "${res}" | sed  's/^Submitted batch job //g'`
  test -n "${jobid}" || exitError 7207 "${LINENO}: problem determining job ID of SLURM job"

  # wait until job has finished (or maximum sleep time has been reached)
  if [ -n "${timeout}" ] ; then
      local secs=0
      local inc=2
      while [ $secs -lt $timeout ] ; do
          echo "...waiting ${inc}s for SLURM job ${jobid} to finish"
          sleep ${inc}
          secs=$[$secs+${inc}]
          inc=60
          squeue -o "%.20i %.20u" -h -j "${jobid}" | grep "^ *${jobid} " > /dev/null
          if [ $? -eq 1 ] ; then
              break
          fi
      done
  fi

  # make sure that job has finished
  squeue -o "%.20i %.20u" -h -j "${jobid}" | grep "^ *${jobid} "
  if [ $? -eq 0 ] ; then
      exitError 7207 "${LINENO}: batch job ${script} with ID ${jobid} on host ${slave} did not finish"
  fi

  # check for normal completion of batch job
  sacct --jobs ${jobid} --user jenkins -p -n -b -D | grep -v '|COMPLETED|0:0|' > /dev/null
  if [ $? -eq 0 ] ; then
      exitError 7209 "${LINENO}: batch job ${script} with ID ${jobid} on host ${slave} did not complete successfully"
  fi

}


