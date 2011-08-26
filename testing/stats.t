#!/bin/sh


# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . ./functions.t
  setup
  export SERVER_TIMEOUT=1
  export SOCKET_TIMEOUT=1

  $TF_HOME/bin/tfrun --tfstatusfile status -i $TFILE $ME arg1  > test.out 2> test.err

# Everything has ran.  Now let us see how it did
  PLINES=$( cat progress.$TFILE|sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || error "Didn't process all lines $PLINES vs $ELINES"
  okay
else

  OUT=$(wc)
  let E=STEP%2
#  [ $E -eq 0 ] && sleep 1
  echo $OUT
  
fi
