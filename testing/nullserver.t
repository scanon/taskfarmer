#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export TF_SERVERS=`pwd`/servers
  echo "localhost:1234:bogus"> $TF_SERVERS

  $TF_HOME/bin/tfrun > client.out 2> client.err
  [ $(grep -c refused client.err) -gt 0 ] || error "No client refused error"
  okay

# Everything has ran.  Now let us see how it did
else
  OUT=$(wc)

  echo $OUT
  
fi
