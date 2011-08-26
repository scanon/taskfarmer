#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export PIDFILE=`pwd`/tf.pid

  $TF_HOME/bin/tfrun --tfpidfile $PIDFILE -i $TFILE $ME arg1 > test.out 2> test.err

# Everything has ran.  Now let us see how it did
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || error "Didn't process all lines $PLINES vs $ELINES"
  okay
# Cleanup
else

  OUT=$(wc)

  if [ $STEP -eq 2 ] ; then
    echo "bog" > file
    echo "blah" > file2
    echo "This should fail" 1>&2
    exit 1
  fi
  echo $OUT
  
fi
