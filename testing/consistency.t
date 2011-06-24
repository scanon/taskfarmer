#!/bin/sh

# This is what starts things...
export NERSC_HOST=test

if [ $# -eq 0 ] ; then
  . functions.t
  setup
  cleanup
  export PIDFILE=`pwd`/tf.pid

  echo "Starting server.  This will get killed as part of test."
  export LOOP=1
  $TF_HOME/bin/tfrun --tfbatchsize=32 --tfdebuglevel=5 --tfpidfile $PIDFILE -i $TFILE $ME arg1 > test.out 2> test.err
  [ -s fastrecovery.$TFILE ] || echo "Fastrecovery file is empty on kill. Not much of a test."
  export LOOP=2
  echo "Restarting server"
  cat fastrecovery.$TFILE
  $TF_HOME/bin/tfrun --tfbatchsize=32 --tfdebuglevel=5 --tfpidfile $PIDFILE -i $TFILE $ME arg1 >> test.out 2>> test.err

# Everything has ran.  Now let us see how it did
  echo "Checking Results"
  diff --brief -u test.out $TFILE
  ls -l test.out $TFILE

# Cleanup
else

  cat > in

  if [ $STEP -eq 0 ] ; then
    sleep 20
  fi
  if [ $STEP -eq 1 ] && [ $LOOP -eq 1 ] ; then 
    echo "Let's wait for a flush"
    while [ ! -e $TF_HOME/fastrecovery.$TFILE ] ; do
      sleep 1
    done
    PID=$(cat $PIDFILE)
    echo "Kill parent $PID"
    kill -9 $(ps -p $PID -o ppid|tail -1)
    kill -9 $PID
    
    exit 1;
  fi
  cat in
  rm in
  
fi
