#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export TF_SERVERS=`pwd`/servers

  echo -n .
  rm $TF_SERVERS *$TFILE.2 test2.* > /dev/null 2>&1
  SERVER_ONLY=1 $TF_HOME/bin/tfrun -i $TFILE $ME a > test.out 2> test.err &
  cp $TFILE $TFILE.2
  sleep 2
  echo -n .
  SERVER_ONLY=1 $TF_HOME/bin/tfrun -i $TFILE.2 $ME b > test2.out 2> test2.err &
  sleep 2
  echo -n .
  $TF_HOME/bin/tfrun > client.out 2> client.err
  echo -n .
  wait
  echo -n .

# Everything has ran.  Now let us see how it did
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || error "1: Didn't process all lines $PLINES vs $ELINES"
  PLINES=$( cat progress.$TFILE.2 |sed 's/,/\n/g'|wc -l)
  [ $PLINES -eq $ELINES ] || error "2: Didn't process all lines $PLINES vs $ELINES"
  okay
else
  OUT=$(wc)

  echo $OUT
  
fi
