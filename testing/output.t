#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup

  echo "Starting server"
  $TF_HOME/bin/tfrun -i $TFILE $ME arg1 > test.out 2> test.err

# Everything has ran.  Now let us see how it did
  echo "Checking Results"
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || echo "Didn't process all lines $PLINES vs $ELINES"
<<<<<<< HEAD
  ls -l done.$TFILE
=======
>>>>>>> 917b14cbb14d34e16579fcdfc160487f6441a722
else
  OUT=$(wc)
  echo $OUT
  
fi
