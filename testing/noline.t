#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup

  echo "Starting server"
  $TF_HOME/bin/tfrun --tfdebuglevel=4 -i $TFILE $ME arg1 > test.out 2> test.err

# Everything has ran.  Now let us see how it did
  echo "Checking Results"
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || echo "Didn't process all lines $PLINES vs $ELINES"
  ELINES=$( wc -c $TFILE|awk '{print $1}')
  WCLINES=$( cat test.out|awk '{sum+=$3}END{print sum}')
  [ $WCLINES -eq $ELINES ] || echo "Results are wrong $WCLINES vs $ELINES"
  ls -l done.$TFILE
else
  OUT=$(wc)
  echo -n $OUT
  
fi
