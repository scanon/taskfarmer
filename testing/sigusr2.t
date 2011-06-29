#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export TF_TESTING=1
  export TF_SERVERS=`pwd`/servers
  export PIDFILE=`pwd`/tf.pid

  SERVER_ONLY=1 $TF_HOME/bin/tfrun --tfpidfile $PIDFILE --tfheartbeat=4 --tfdebuglevel=5 -i $TFILE $ME arg1 > test.out 2> test.err &
  sleep 2
  kill -USR2 $(cat $PIDFILE)
  [ $(grep -c Dump test.err) -gt 0 ] || error "No Dump detected"
  okay

fi
