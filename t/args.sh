#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

OUT=$(wc)

# Get ARGS
if [ $STEP -eq 0 ] ; then
    for i in "$@" ; do
      echo $i  >> $ARG_OUT
    done
 fi
echo $OUT
