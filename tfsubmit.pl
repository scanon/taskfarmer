#!/usr/bin/env perl
#
# This is helper script that can automate using backfill slots.
# Currently this is pretty specialized for NERSC.
#
use Getopt::Long;
my $account;
my $queue="regular";
my $ppn=8;
my $mpp=0;
my $minnodes=100;
my $maxnodes="600";
my $yes;

$result = GetOptions (
	"queue=s"   => \$queue,
	"threads=i"   => \$threads,
	"minnodes=i"   => \$minnodes,
	"maxnodes=i"   => \$maxnodes,
	"yes"   => \$yes,
	"Account=s"   => \$account);     # string

# Defaults
#
$mintime="1:00:00";
$maxtime="6:10:00";
#$script="$ENV{TF_HOME}/share/taskfarmer/submit_es.q";
$reducenodes=5;
$reduceminutes=10;

# Check that server file exist;
$ENV{TF_SERVERS}="servers" unless defined $ENV{TF_SERVERS};
die "No servers file found\n" if ( ! -e $ENV{TF_SERVERS} );

# Change defaults
#
if (defined $ENV{NERSC_HOST} && $ENV{NERSC_HOST} eq "hopper"){
  $ppn=24;
  $mpp=1;
}

# Check that taskfarmer is loaded.
#
die "Please load taskfarmer." unless defined $ENV{TF_HOME};


$command="showbf ";
$command.="-a $account " if defined $account;
$command.="-c $queue ";
$command.="-n $minnodes -d $mintime";
$command.="|tail +3|";

print "Checking for backfill\n";
open(SBF,"$command");

$_=<SBF>;
if (! defined $_){
  print stderr "No backfill available at $minnodes nodes for $mintime\n";
  print stderr "Try request less nodes with the -n option\n";
  exit;
}
print $_;
($part,$task,$nodes,$wtime,$rest)=split;

$nodes-=$reducenodes;

$wtime=$maxtime if ($wtime=~/INFINITY/);

($hours,$min,$sec)=split /:/,$wtime;

$min-=$reduceminutes;
if ($min<0){
  $min+=60;
  $hours--;
}

$nodes=$maxnodes if ($nodes>$maxnodes);
$cores=$nodes*$ppn;
$wtime=sprintf "%d:%02d:%02d",$hours,$min;$sec;

print "Should I submit a $cores core for $wtime to the $queue queue? (y/n)  ";

if ( ! defined $yes){
  $ANS=<STDIN>;
  exit unless ($ANS=~/^y/);
}
print "Submitting\n";
$ENV{THREADS}=$threads if defined $threads;
$command="qsub -V -N taskfarmer -q $queue ";
$command.="-A $account " if defined $account;
if ($mpp eq 1){
  $command.=" -l mppwidth=$cores,walltime=$wtime";
}
else{
  $command.=" -l nodes=$nodes:ppn=$ppn,walltime=$wtime";
}

#
# Submit script
#
my $TMP="/tmp/tf.$$";
open(TF,"> $TMP") or die "Unable to open temporary submit script file for output\n";
print TF "#!/bin/sh\n";
print TF 'cd $PBS_O_WORKDIR'."\n";
print TF 'export PATH=$PATH:$(pwd)'."\n";
print TF 'for l in $(cat $TF_SERVERS) ; do'."\n";
print TF '  export TF_ADDR=$(echo $l|awk -F: \'{print $1}\')'."\n";
print TF '  export TF_PORT=$(echo $l|awk -F: \'{print $2}\')'."\n";
print TF "  tfrun\n";
print TF "done\n";
close TF;

$JID=`$command $TMP`;
unlink $TMP;
$RET=$?;
chomp $JID;
print "Submitted $JID\n";
print "Waiting";
sleep 10;
while(1){
  $q=`qstat $JID|tail +3`;
  last if $q=~/R/;
  print ".";
  sleep 10;
}
print "\n$q\n";
