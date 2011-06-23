#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup

  $TF_HOME/bin/tfrun -tfbatchbytes=1 -i $TFILE $ME arg1 > test.out 2> test.err

# Everything has ran.  Now let us see how it did
  echo "Checking Results"
  PLINES=$( cat progress.$TFILE |wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  echo "$PLINES versus $ELINES"
  [ $PLINES -eq $ELINES ] || echo "Didn't process all lines $PLINES vs $ELINES"

# Cleanup
else

  OUT=$(wc)

  echo $OUT
  
fi
