#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export TF_SERVERS=`pwd`/servers

  echo -n .
  touch fastrecovery.$TFILE
  SERVER_ONLY=1 $TF_HOME/bin/tfrun -i $TFILE $ME a > test.out 2> test.err 
  RET=$?
  [ $RET ] || error "Server exited with no errors but should have"
  rm fastrecovery.$TFILE
  echo -n .
  $TF_HOME/bin/tfrun -i $TFILE $ME a > test.out 2> test.err 
  RET=$?
  [ $RET -eq 0 ] || error "Server exited with errors"

  okay
else
  OUT=$(wc)

  echo $OUT
  
fi
