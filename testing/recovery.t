#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export SERVER_TIMEOUT=1
  export SOCKET_TIMEOUT=1
  export PIDFILE=`pwd`/tf.pid

  echo "Starting server.  This will get killed as part of test."
  export LOOP=1
  $TF_HOME/bin/tfrun --tfdebuglevel=3 --tfpidfile $PIDFILE -i $TFILE $ME arg1 > test.out 2> test.err
  [ -s progress.$TFILE ] || echo "Progress file is empty on kill. Not much of a test."
  LOOP=2
  echo "Restarting server"
  $TF_HOME/bin/tfrun --tfdebuglevel=3 --tfpidfile $PIDFILE -i $TFILE $ME arg1 >> test.out 2>> test.err

# Everything has ran.  Now let us see how it did
  echo "Checking Results"
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || echo "Didn't process all lines $PLINES vs $ELINES"

# Cleanup
else

  OUT=$(wc)

  if [ $STEP -eq 5 ] && [ $LOOP -eq 1 ] ; then 
    echo "Kill $PIDFILE"
    echo "$PIDFILE" > /tmp/debug
    cat $PIDFILE
    kill -INT $(cat $PIDFILE)
    sleep 1
    exit 1;
  fi
  echo $OUT
  
fi
