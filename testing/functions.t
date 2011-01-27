#!/bin/sh

setup(){
  export TF_HOME=/tmp/tf.$$
  (cd ../;make install prefix=$TF_HOME)
  export TFILE=test.faa
}

cleanup(){
  for f in data.dump  error.test.faa  fastrecovery.test.faa  log.test.faa  progress.test.faa  status.new  test.err  test.out
  do
    [ -e $f ] && rm $f
  done
  
}
