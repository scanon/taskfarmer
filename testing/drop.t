#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  export SERVER_TIMEOUT=1
  export SOCKET_TIMEOUT=1

  export LOOP=1
  export SOCKFILE=sockfile
  $TF_HOME/libexec/taskfarmer/tf_server --tfdebuglevel=3 -i $TFILE $ME arg1 > test.out 2> test.err &
# Everything has ran.  Now let us see how it did
  sleep 2
  PORT=`cat $SOCKFILE`
  echo "Checking Results"
    echo "Sending NEXT"
    (echo "IDENT test";echo "NEXT")|nc localhost $PORT > /dev/null
    echo "Sending RESULTS"
    (echo "IDENT test";echo "RESULTS 0";echo "FILE blah 20";echo "line1 - drop";sleep 45)|nc localhost $PORT &
    

  TF_ADDR=localhost TF_PORT=$PORT tfrun
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || echo "Didn't process all lines $PLINES vs $ELINES"

# Cleanup
else
  echo what
fi
