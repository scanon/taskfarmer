#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export TF_SERVERS=`pwd`/servers

  echo "Starting server 1"
  rm $TF_SERVERS *$TFILE.2 test2.* > /dev/null 2>&1
  SERVER_ONLY=1 $TF_HOME/bin/tfrun -i $TFILE $ME a > test.out 2> test.err &
  cp $TFILE $TFILE.2
  sleep 2
  echo "Starting server 2"
  SERVER_ONLY=1 $TF_HOME/bin/tfrun -i $TFILE.2 $ME b > test2.out 2> test2.err &
  sleep 2
  echo "Starting client"
  $TF_HOME/bin/tfrun > client.out 2> client.err
  wait

# Everything has ran.  Now let us see how it did
  echo "Checking Results"
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || echo "1: Didn't process all lines $PLINES vs $ELINES"
  PLINES=$( cat progress.$TFILE.2 |sed 's/,/\n/g'|wc -l)
  [ $PLINES -eq $ELINES ] || echo "2: Didn't process all lines $PLINES vs $ELINES"
  rm *$TFILE.2 test2.* client.err client.out servers
  cleanup
else
  OUT=$(wc)

  echo $OUT
  
fi
