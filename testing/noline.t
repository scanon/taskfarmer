#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export TF_POLLTIME=.01

  $TF_HOME/bin/tfrun --tfdebuglevel=4 -i $TFILE $ME arg1 > test.out 2> test.err

  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || error "Didn't process all lines $PLINES vs $ELINES"
  ELINES=$( wc -c $TFILE|awk '{print $1}')
#  WCLINES=$( cat test.out|awk '{sum+=$3}END{print sum}')
#  [ $WCLINES -eq $ELINES ] || error "Results are wrong $WCLINES vs $ELINES"
  [ -e done.$TFILE ] || error "No done file"
  okay
else
#  OUT=$(wc)
  echo -n "HOWDY"
  
fi
