#!/bin/ksh
#
# This is a staging file that would be _sourced_ by the client script.
# It is sourced just once by the client script which runs on each compute node.
#

# Add setup here that should be done for every
# client.  For example, setting the PATH or 
# LD_LIBRARY_PATH.  The settings below provides
# support for Java and Perl out on compute nodes
# It also illustrates unpacking some application in TF_TMPDIR
# to releave load on the global file system.
#

APPS=/project/projectdirs/genomes/apps
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$APPS/lib
export PATH=$PATH:$APPS/bin

# Set Java home, the path, PERL stuff, etc
export JAVA_HOME=$APPS/lib/jdk1.6.0_13/jre
export _JAVA_OPTIONS="-Xms128m -Xmx512m"
export PATH=$PATH:$JAVA_HOME/bin

PERL=$APPS/lib/perl5
PERL_VER=5.8.8
PERL_ARCH=x86_64-linux-thread-multi/
export PERLLIB=$PERL/site_perl/$PERL_VER/:$PERL/$PERL_VER/:$PERL/$PERL_VER/$PERL_ARCH:$PERL/$PERL_VER/vendor_perl/5.8.8/$PERL_ARCH/

# Cleanup
if [ $CLEANUP ] ; then
  (cd $TF_TMPDIR;rm -rf $TF_TMPDIR/app)
else
  mkdir $TF_TMPDIR/app
  (cd $TF_TMPDIR/app; tar xzf $TARBALL)
  export PATH=$TF_TMPDIR/app/bin:$PATH
fi
