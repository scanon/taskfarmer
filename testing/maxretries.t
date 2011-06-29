#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup

  export LOOP=1
  $TF_HOME/bin/tfrun --tfbatchsize=16 --tfdebuglevel=3 -i $TFILE $ME arg1  > test.out 2> test.err
  [ $(wc -l fastrecovery.$TFILE|awk '{print $1}') -gt 1 ] || error "No failed tasks as expected"
  LOOP=2
  $TF_HOME/bin/tfrun --tfbatchsize=16 --tfdebuglevel=3 -i $TFILE $ME arg1  > test.out 2> test.err

# Everything has ran.  Now let us see how it did
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || error "Didn't process all lines $PLINES vs $ELINES"
  okay
else
  OUT=$(wc)

  if [ $STEP -gt 1 ] && [ $STEP -lt 10 ] && [ $LOOP -eq 1 ] ; then
    exit 1
  fi
  echo $OUT
  
fi
