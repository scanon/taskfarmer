#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export THREADS=4
  $TF_HOME/bin/tfrun --tfdebuglevel=3 --tfbatchbytes=800 -i $TFILE $ME arg1 > test.out 2> test.err

# Everything has ran.  Now let us see how it did
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l|awk '{print $1}')
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || error "Didn't process all lines $PLINES vs $ELINES"
  okay
# Cleanup
else

  OUT=$(wc)
  echo $OUT
  
fi
