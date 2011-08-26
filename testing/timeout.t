#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export SERVER_TIMEOUT=1
  export SOCKET_TIMEOUT=1
  $TF_HOME/bin/tfrun --tfdebuglevel=3 -i $TFILE $ME arg1 > test.out 2> test.err

# Everything has ran.  Now let us see how it did
  grep bogus test.out
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || error "Didn't process all lines $PLINES vs $ELINES"
  okay
# Cleanup
else

  OUT=$(wc)

  if [ $STEP -eq 2 ] ; then
    echo bogus
    sleep 3
  fi
  if [ $STEP -eq 47 ] ; then
    echo bogus
    sleep 3
  fi
  echo $OUT
  
fi
