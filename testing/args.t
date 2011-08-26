#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  export ARG_OUT=`pwd`/test.args

  $TF_HOME/bin/tfrun -i $TFILE $ME arg1 arg2 'a b' > test.out 2> test.err

# Everything has ran.  Now let us see how it did
  [ $(cat $ARG_OUT|wc -l) -eq 3 ] || error "Error: incorrect number of args"
  [ $(grep -c 'a b' $ARG_OUT) -eq 1 ] || error "Error: didn't read arg with space"
  okay
else
  OUT=$(wc)

# Get ARGS
  if [ $STEP -eq 0 ] ; then
    for i in "$@" ; do
      echo $i  >> $ARG_OUT
    done
  fi
  echo $OUT
  
fi
