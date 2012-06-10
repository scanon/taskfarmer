#!/bin/sh

cat > in

if [ -z $STEP ] ; then
  echo "No STEP"
  exit 1;
elif [ ! -z "$ERRORSTEP" ] && [ "$STEP" = "$ERRORSTEP" ] ; then
  exit 1
elif [ ! -z "$TIMEOUTSTEP" ] && [ "$STEP" = "$TIMEOUTSTEP" ] ; then
  sleep $SLEEPTIME
elif [ ! -z "$ERRORINPUT" ] && [ $(grep -c "$ERRORINPUT" in) -gt 0 ] ; then
  echo "Simulate bad input"
  exit 1
elif [ ! -z "$KILLSTEP" ] && [ "$STEP" = "$KILLSTEP" ] ; then
    echo "Let's wait for a flush"
    sleep 2
    while [ ! -e $FR ] ; do
      sleep 2
    done
    PID=$(cat $PIDFILE)
    echo "Kill parent $PID"
    kill -9 $(ps -p $PID -o ppid|tail -1) 2>&/dev/null
    kill -9 $PID
    exit 1
elif [ ! -z $NOLINE ] ; then
  echo -n "blah"
  exit
fi

if [ ! -z $TESTFILE ] ; then
  [ -e $TESTFILE ] && rm $TESTFILE
  if [ "$STEP" = "1" ] ; then
    touch $TESTFILE 
    if [ "$TESTFILE" = "skipfile" ] ; then
      touch blah;
    fi
  fi
fi

if [ ! -z "$ARG_OUT" ] ; then
 if [ $STEP -eq 0 ] ; then
    for i in "$@" ; do
      echo $i  >> $ARG_OUT
    done
 fi
fi


cat in
rm in
