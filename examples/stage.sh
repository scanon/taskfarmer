#!/bin/ksh
TMPD=/tmp/$USER

# Cleanup
if [ $CLEANUP ] ; then
  rm $MYLOCK
  sleep 5
  if [ $(ls $TMPD/|grep -c lock) -eq 0 ] ; then
    echo "Cleaning up"
    rm -rf $TMPD/ > /dev/null 2>&1
  fi

else
  export GETFILES="*.tbl *.geneC* *.gb"
  START_FILE=$TMPD/start
  READY_FILE=$TMPD/ready
  export MYLOCK=$TMPD/lock.$$
  export LD_LIBRARY_PATH=$TMPD/apps/lib:/project/projectdirs/genomes/apps/lib/
  APPS=/project/projectdirs/genomes/apps
  export PATH=$PATH:$APPS/bin
  export HOST=`cat /proc/cray_xt/nid`

# Set Java home, the path, PERL stuff, etc
  export JAVA_HOME=$APPS/lib/jdk1.6.0_13/jre
  export PATH=$PATH:$BASE/bin:$APPS/bin:$JAVA_HOME/bin
  PERL=/tmp/$USER/apps/lib/perl5
  export PERLLIB=$PERL/site_perl/5.8.8/:$PERL/5.8.8/:$PERL/5.8.8/x86_64-linux-thread-multi:$PERL/5.8.8/vendor_perl/5.8.8/x86_64-linux-thread-multi/:
  export PERLLIB=$PERLLIB:$PIPELINE_PATH/Perl_lib:$PIPELINE_PATH/GenePRIMP_suite/
  export LOCAL_BIN=$APPS/bin/
  export BIN=$APPS/bin
  export _JAVA_OPTIONS="-Xms128m -Xmx512m"
  TARBALL=$PIPELINE_PATH/../stage.tgz
  APP_TARBALL=$APPS/staging/apps-$NERSC_HOST.tgz
#
# Override PIPELINE_PATH
#
  export PIPELINE_PATH=$TMPD/img_gp_pipeline/

# Let's clean up first just in case we didn't earlier.
# Pipe it to null since it will likely be clean
#
  rm -rf /tmp/$USER > /dev/null 2>&1
# Let's make everyone is in the same place.
#
  sleep 10

  if [ ! -e $TMPD ] ; then
    mkdir $TMPD > /dev/null 2>&1
  fi
  cd $TMPD

  touch $MYLOCK

# Wait for everyone
  sleep 5
  MASTER=$(ls $TMPD|grep lock|sort|head -1)
  if [ "$TMPD/$MASTER" = "$MYLOCK" ] ; then
    touch $START_FILE
    echo "Unpacking $TARBALL into $PIPELINE_PATH"
    mkdir -p $PIPELINE_PATH
    (cd $PIPELINE_PATH && tar xzf $TARBALL)
    tar xzf $APP_TARBALL
    touch $READY_FILE
  else
    sleep 5
    while [ ! -e $READY_FILE ] 
    do
      echo "Waiting"
      sleep 5 
    done
  fi
fi
