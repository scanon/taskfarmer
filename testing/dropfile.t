#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export TF_TESTING=1

  echo "Starting server"
  $TF_HOME/bin/tfrun --tfdebuglevel=3 -i $TFILE $ME arg1 > test.out 2> test.err

# Everything has ran.  Now let us see how it did
  echo "Checking Results"
  [ $(grep -c Missing log.$TFILE) -eq 1 ] && echo "Missing files as expected"
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || echo "Didn't process all lines $PLINES vs $ELINES"
else
  OUT=$(wc)

  [ -e drop ] && rm drop
  if [ $STEP -eq 1 ] ; then
    touch drop 
  fi
  echo $OUT
  
fi
