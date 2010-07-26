#!/bin/sh

DIR=$(basename $PIPELINE_PATH)
EX=$PIPELINE_PATH/NERSC/excludes
SF=stage.tgz

cd $PIPELINE_PATH/;tar czf ../$SF -X $EX .
