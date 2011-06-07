#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export SERVER_TIMEOUT=1
  export SOCKET_TIMEOUT=1

  export ARG_OUT=`pwd`/test.args

  echo "Starting server.  This will get killed as part of test."
  export LOOP=1
  export PORT=7000
  $TF_HOME/libexec/taskfarmer/tf_server -i $TFILE `pwd`/$0 arg1 arg2 'a b' > test.out 2> test.err &
echo "Sending NEXT"
  echo "IDENT test\nNEXT\n"|nc localhost $PORT
echo "Sending RESULTS"
  echo "IDENT test\nRESULTS 0\nFILE blah\nline1 - drop\n"|nc localhost $PORT
  wait
# Everything has ran.  Now let us see how it did
  echo "Checking Results"
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || echo "Didn't process all lines $PLINES vs $ELINES"

# Cleanup
#  rm progress.$TFILE error.$TFILE fastrecovery.$TFILE $ARG_OUT
#  rm -rf $TF_HOME
else
  echo what
fi
