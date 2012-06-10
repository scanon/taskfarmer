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

# Simulate a bad input

$ENV{THREADS} = 1;
$ENV{FLUSHTIME} = 1;
$ENV{SOCKET_TIMEOUT} = 2;
$ENV{ERRORINPUT}=">HWI-E4:2:1:5:407#0/1";
qx "$TR --tftimeout=10 --tfbatchsize=32 --tfdebuglevel=5 --tfpidfile=$pidfile -i $IFILE $TESTER arg1 > test.out 2> test.err";
delete $ENV{ERRORINPUT};

ok( ! -e $DONE, 'Check that did not finish on first try.');
ok( countlines($FR)>1, "Fast recovery" );

print "Now lets try to finish up\n";
utime 0, 0, $FR;
qx "$TR --tfbatchsize=32 --tfdebuglevel=5 --tfpidfile $pidfile -i $IFILE $TESTER arg1 >> test.out 2>> test.err";
ok( -e $DONE, "Finished recovery.");
ok( checklines($IFILE,$PFILE),'Compare output');

# Everything has ran.  Now let us see how it did
#  diff --brief -u test.out $IFILE > /dev/null
# compare files
#cleanup_tests();

