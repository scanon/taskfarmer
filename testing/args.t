#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export ARG_OUT=`pwd`/test.args

  echo "Starting server"
  $TF_HOME/bin/tfrun -i $TFILE `pwd`/$0 arg1 arg2 'a b' > test.out 2> test.err

# Everything has ran.  Now let us see how it did
  echo "Checking Results"
  [ $(cat $ARG_OUT|wc -l) -eq 3 ] || echo "Error: incorrect number of args"
  [ $(grep -c 'a b' $ARG_OUT) -eq 1 ] || echo "Error: didn't read arg with space"
#  cleanup
else
  touch b
  OUT=$(wc)

# Get ARGS
  if [ $STEP -eq 0 ] ; then
    for i in "$@" ; do
      echo $i  >> $ARG_OUT
    done
  fi
  echo $OUT
  
fi
