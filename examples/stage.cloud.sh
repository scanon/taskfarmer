#!/bin/ksh
TMPD=/tmp/$USER

# Cleanup
if [ $CLEANUP ] ; then
  echo "Done"
else
  export GETFILES="*.tbl *.geneC* *.gb"
  export HOST=$HOSTNAME
  if [ ! -d $TMPD ] ; then
    mkdir $TMPD
  fi
fi
