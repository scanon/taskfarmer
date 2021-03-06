#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export TF_HEARTBEAT=0
  export TF_SERVERS=`pwd`/servers

  SERVER_ONLY=1 $TF_HOME/bin/tfrun --tfheartbeat=4 --tfdebuglevel=5 -i $TFILE $ME arg1 > test.out 2> test.err &
  sleep 2
  export SLEEP=2
  $TF_HOME/bin/tfrun > client.out 2> client.err &
  CPID=$!
  sleep 2
  kill -9 $(ps auxwww|grep tf_worker_thread|awk '{print $2}')
  sleep 10
  
  export SLEEP=0
  $TF_HOME/bin/tfrun > client2.out 2> client2.err
  wait

# Everything has ran.  Now let us see how it did
  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
  ELINES=$( grep -c '^>' $TFILE)
  [ $PLINES -eq $ELINES ] || error "Didn't process all lines $PLINES vs $ELINES"
  ELINES=$( wc -c $TFILE|awk '{print $1}')
  WCLINES=$( cat test.out|awk '{sum+=$3}END{print sum}')
  [ $WCLINES -eq $ELINES ] || error "Results are wrong $WCLINES vs $ELINES"
  [ -e done.$TFILE ] || error "Missing done file"
  okay
else
  OUT=$(wc)
  sleep $SLEEP
  echo $OUT
  
fi
