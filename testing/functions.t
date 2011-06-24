#!/bin/sh

setup(){
  [ -z $TF_HOME ] && export TF_HOME=/tmp/tf.$$
  [ -d $TF_HOME ] || mkdir $TF_HOME
  if [ ! -e $TF_HOME/bin/tfrun ] ; then
    (cd ../;make install prefix=$TF_HOME)
  fi
  export TFILE=test.faa
  ME=`pwd`/$0
  cp $TFILE $TF_HOME
  cd $TF_HOME
}

cleanup(){
  for f in data.dump  error.test.faa  fastrecovery.test.faa  log.test.faa  progress.test.faa done.test.faa status.new  test.err  test.out tf.fastrecovery progress.$TFILE test.args tf.err tf.log tf.pid test2.out test2.err
  do
    [ -e $f ] && rm $f
  done
}

stage(){
  ME=`pwd`/$0
  export SCRATCH=/tmp/$$
  mkdir $SCRATCH
  cp $TFILE $SCRATCH/
  cd $SCRATCH
}
