#!/bin/sh

ME=$(which $0)

if [ -z $STEP ] ; then
  FILE=$1 
  IN=$FILE.tfin
  cat $FILE|egrep -v '^#'|awk '{print "> "$0}' > $IN
  tfrun --tfbatchsize=1 --tftimeout=9999999 -i $IN $ME
  if [ -e "done.$IN" ] ; then
    rm {log,fastrecovery}.$IN
  fi
else
  COM=$(cat |sed 's/^> //')
  echo "Running: $COM"
  eval "$COM"
fi
