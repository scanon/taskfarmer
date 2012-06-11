#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

use Test::More tests => 5;

BEGIN { use_ok('NERSC::TaskFarmer::Tester') }

#########################
setup_test();


my $pwd=qx 'pwd';
chomp($pwd);
my $TFILE  = "test.faa";
my $IFILE  = "./t/$TFILE";
my $PFILE  = "$pwd/progress.$TFILE";
my $FR     = "$pwd/fastrecovery.$TFILE";
my $DONE   = "$pwd/done.$TFILE";
my $TR     = "$pwd/blib/script/tfrun";
my $TESTER = "$pwd/t/tester.sh";
# Consistency (kill the server)
my $pidfile = "$pwd/tf.pid";
$ENV{PIDFILE} = $pidfile;

$ENV{FR}   = $FR;

cleanup_tests();

$ENV{THREADS} = 1;
$ENV{SLEEPTIME} = 5;
$ENV{TIMEOUTSTEP} = 0;
$ENV{KILLSTEP} = 1;
$ENV{SOCKET_TIMEOUT} = 1;

qx "$TR --tftimeout=2 --tfbatchsize=32 --tfdebuglevel=5 --tfpidfile=$pidfile -i $IFILE $TESTER arg1 > test.out 2> test.err";
delete $ENV{TIMEOUTSTEP};
delete $ENV{KILLSTEP};

# [ -s fastrecovery.$TFILE ] || error "Fastrecovery file is empty on kill. Not much of a test."
ok( ! -e $DONE, 'Check that did not finish on first try.');
ok( countlines($FR)>1, "Fast recovery" );

print "Now lets try to finish up\n";
utime 0,0, $FR;
qx "$TR --tfbatchsize=32 --tfdebuglevel=5 --tfpidfile $pidfile -i $IFILE $TESTER arg1 >> test.out 2>> test.err";
ok( -e $DONE, "Finished recovery.");
ok( difffiles($IFILE,'test.out'), 'Output is correct after a recovery');

cleanup_tests();

