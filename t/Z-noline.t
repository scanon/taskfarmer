#!/usr/bin/perl
#
# Simulates a dropped file
#
#########################

use Test::More tests => 2;

BEGIN { use_ok('NERSC::TaskFarmer::Tester') }

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

$ENV{FR} = $FR;

cleanup_tests();

$ENV{THREADS}    = 1;
$ENV{NOLINE} = "1";
qx "$TR --tfheartbeat=4 --tfdebuglevel=5 -i $IFILE $TESTER arg1 > test.out 2> test.err";

ok( -e $DONE, 'Client Timeout - Finished' );
cleanup_tests();

