#!/bin/sh

# Temporary directory for run info
#
export SOCKFILE=./.sockfile.$$

cleanup () {
  echo "Shutting down" 1>&2
  if [ -e $PID ] ; then
    kill $PID > /dev/null 2>&1
  fi
  [ -e $SOCKFILE ] && rm $SOCKFILE
  [ ! -z $USE_RELAY ] && [ $USE_RELAY -eq 2 ] && echo "Stoping relay" && stop_relay
  exit $STATUS
}
trap cleanup 2 15

# Create the TF directory
#
[ -e $SOCKFILE ] && rm $SOCKFILE

# Source the configuration file
[ -z $TF_HOME ] && export TF_HOME=$(dirname $0|sed 's/bin$//')
[ -z $TF_CONFDIR ] && TF_CONFDIR=$TF_HOME/share/taskfarmer

if [ -e $TF_CONFDIR/$NERSC_HOST.conf ] ; then
  . $TF_CONFDIR/$NERSC_HOST.conf
else
  echo "The Task Farmer is not currently supported on this system."
  exit
fi

# Get the address for the server
#
if [ -z $TF_ADDR ] && [ -z $TF_PORT ] && [ $# -gt 0 ] ; then
  export TF_ADDR=$(/sbin/ifconfig $INT|grep 'inet addr'|awk -F: '{print $2}'|sed 's/ .*//')

# Start the server and record the PID
#
  if [ $(basename $0) = "tfrun" ] ; then
    $TF_HOME/libexec/taskfarmer/tf_server "$@" &
  else
    base=$(basename $0|sed 's/tf$//')
    APP=$(which $base 2>/dev/null) || (echo "Unable to find $base")
    [ -z $APP ] && exit
    echo "Will run $APP"
    $TF_HOME/libexec/taskfarmer/tf_server $APP "$@" &
  fi
  PID=$!
#
# Wait for the socket file to exist.
#
  while [ -d "/proc/$PID" ] && [ ! -e $SOCKFILE ] ; do
    sleep 1
  done
  TF_PORT=$(cat $SOCKFILE)
  if [ -z $TF_PORT ] ; then
    echo "No port defined.  Report this."
    exit
  fi
  if [ ! -z $TF_SERVERS ] ; then
    echo "$TF_ADDR:$TF_PORT:$PID:$(pwd):$@" >> $TF_SERVERS
  fi
else
  echo "Server defined.  Will contact $TF_ADDR:$TF_PORT"
  export EXTERNAL_SERVER=1
  [ ! -z $USE_RELAY ] && USE_RELAY=2 && echo "Starting relay" && start_relay
fi

if [ -z $SERVER_ONLY ] || [ ! -z $EXTERNAL_SERVER ] ; then
# Launch the clients
#
  run_one
# Get exit status for aprun
#
  STATUS=$?
  [ ! -z $USE_RELAY ] && [ $USE_RELAY -eq 2 ] && echo "Stoping relay" && stop_relay

else
  echo "Starting in server only mode." 1>&2
  echo "Cut and paste..." 1>&2
  echo "TF_ADDR=$TF_ADDR TF_PORT=$TF_PORT tfrun" 1>&2
  wait $PID
  STATUS=$?
fi

# Kill the server (just in case)
if [ -z $EXTERNAL_SERVER ] ; then
  sleep 1
  if [ ! -z $PID ] ; then
    [ -d /proc/$PID ]  && kill -INT $PID > /dev/null 2>&1
    [ -d /proc/$PID ]  && kill -INT $PID > /dev/null 2>&1
    [ -d /proc/$PID ]  && kill $PID > /dev/null 2>&1
  fi
  [ -e $SOCKFILE ] && rm $SOCKFILE
fi
exit $STATUS
