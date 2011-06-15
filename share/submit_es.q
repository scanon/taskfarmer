#!/bin/sh

#PBS -V

cd $PBS_O_WORKDIR 

#
# Setup task farmer
export PATH=$PATH:`pwd`

# Game time.  tfrun will handle launching the compute processes.
for l in $(cat $TF_SERVERS) ; do
  export TF_ADDR=$(echo $l|awk -F: '{print $1}')
  export TF_PORT=$(echo $l|awk -F: '{print $2}')
  tfrun
done
