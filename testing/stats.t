#!/bin/sh


# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . ./functions.t
  setup
  cleanup
  export SERVER_TIMEOUT=1
  export SOCKET_TIMEOUT=1
  export STATUSFILE=status

  export ARG_OUT=`pwd`/test.args

  echo "Starting server"
  $TF_HOME/bin/tfrun -i $TFILE `pwd`/$0 arg1 arg2 'a b' > test.out 2> test.err

# Everything has ran.  Now let us see how it did
  echo "Checking Results"
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  SUCCESS=1
  [ $PLINES -ne $ELINES ] && SUCCESS=0 && echo "Didn't process all lines $PLINES vs $ELINES"
  mv status.new stats.js
  [ $SUCCESS -eq 1 ] && cleanup
else

  OUT=$(wc)
  let E=STEP%2
#  [ $E -eq 0 ] && sleep 1
  echo $OUT
  
fi
