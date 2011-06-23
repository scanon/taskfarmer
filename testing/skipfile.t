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
  grep TEST test.out
  ls -l blah
  [ $(grep -c Missing log.$TFILE) -eq 1 ] && echo "Missing files as expected"
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || echo "Didn't process all lines $PLINES vs $ELINES"
  cleanup
else
  OUT=$(wc)

  if [ $STEP -eq 1 ] ; then
    echo "TEST: You shouldn't see this"
    touch blah
    touch skipfile 
  fi
  echo $OUT
  
fi
