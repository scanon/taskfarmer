#!/bin/sh

setup(){
  export TF_HOME=/tmp/tf.$$
  (cd ../;make install prefix=$TF_HOME)
  export TFILE=test.faa
  ME=`pwd`/$0
  cp $TFILE $TF_HOME
  cd $TF_HOME
}

cleanup(){
  for f in data.dump  error.test.faa  fastrecovery.test.faa  log.test.faa  progress.test.faa  status.new  test.err  test.out tf.fastrecovery progress.$TFILE test.args tf.err tf.log tf.pid
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
