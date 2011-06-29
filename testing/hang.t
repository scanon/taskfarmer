#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export TF_TESTING=1
  export TF_SERVERS=`pwd`/servers

  echo -n "."
  SERVER_ONLY=1 $TF_HOME/bin/tfrun --tfheartbeat=4 --tfdebuglevel=5 -i $TFILE $ME arg1 > test.out 2> test.err &
  sleep 2
  echo -n "."
  $TF_HOME/bin/tfrun > client.out 2> client.err
  echo -n "."
  $TF_HOME/bin/tfrun > client2.out 2> client2.err
  echo -n "."

# Everything has ran.  Now let us see how it did
  [ $(grep -c Missing log.$TFILE) -eq 1 ] && error "Missing files as expected"
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || error "Didn't process all lines $PLINES vs $ELINES"
  okay
else
  OUT=$(wc)

  [ -e testhang ] && rm testhang
  if [ $STEP -eq 1 ] ; then
    touch testhang 
  fi
  echo $OUT
  
fi
