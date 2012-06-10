#!/usr/bin/perl
#
# Simulates a dropped file
#
#########################

use Test::More tests => 2;

BEGIN { use_ok('NERSC::TaskFarmer::Tester') }
use Config;

#########################
setup_test();

my $pwd = qx 'pwd';
chomp($pwd);
my $TFILE  = "test.faa";
my $IFILE  = "./testing/$TFILE";
my $LFILE  = "$pwd/log.$TFILE";
my $PFILE  = "$pwd/progress.$TFILE";
my $FR     = "$pwd/fastrecovery.$TFILE";
my $DONE   = "$pwd/done.$TFILE";
my $TR     = "$pwd/blib/script/tfrun";
my $TESTER = "$pwd/t/tester.sh";
my $pidfile="$pwd/tf.pid";

cleanup_tests();

$ENV{THREADS}    = 1;
$ENV{SERVER_ONLY} = 1;
$pid=fork();
if ($pid eq 0){
	qx "$TR --tfpidfile=$pidfile --tfheartbeat=4 --tfdebuglevel=5 -i $IFILE $TESTER arg1 > test.out 2> test.err";
	exit;
}
sleep 2;

kill USR2, qx "cat $pidfile";

sleep 1;
ok(countstring('test.err','Dump'),'USR2 generated dump');
unlink $pidfile;
cleanup_tests();

