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

  export ARG_OUT=`pwd`/test.args

  echo "Starting server.  This will get killed as part of test."
  export LOOP=1
  $TF_HOME/bin/tfrun --tfpidfile $PIDFILE -i $TFILE `pwd`/$0 arg1 arg2 'a b' > test.out 2> test.err
  [ -s progress.$TFILE ] || echo "Progress file is empty on kill. Not much of a test."
  LOOP=2
  echo "Restarting server"
  $TF_HOME/bin/tfrun --tfpidfile $PIDFILE -i $TFILE `pwd`/$0 arg1 arg2 'a b' >> test.out 2>> test.err

# Everything has ran.  Now let us see how it did
  echo "Checking Results"
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || echo "Didn't process all lines $PLINES vs $ELINES"

# Cleanup
else

  OUT=$(wc)

# Get ARGS
  if [ $STEP -eq 2 ] && [ $LOOP -eq 1 ] ; then
    sleep 3
# Test max retry
#
  elif [ $STEP -gt 4 ] && [ $STEP -lt 13 ] && [ $LOOP -eq 1 ] ; then
    exit 1
# Test recovery
  elif [ $STEP -gt 15 ] && [ $LOOP -eq 1 ] ; then 
    echo "$PIDFILE"
    cat $PIDFILE
    kill -INT $(cat $PIDFILE)
    sleep 1
    exit 1;
# Let us try to test the last step
  elif [ $STEP -eq 46 ] && [ $LOOP -eq 2 ] ; then 
    sleep 3
  fi
  echo $OUT
  
fi
