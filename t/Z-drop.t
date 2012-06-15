#!/usr/bin/perl
#
# Simulates a dropped file
#
#########################

use Test::More tests => 10;

BEGIN { use_ok('NERSC::TaskFarmer::Tester') }

#########################
setup_test();

my $pwd = qx 'pwd';
chomp($pwd);
my $TFILE  = "test.faa";
my $IFILE  = "./t/$TFILE";
my $LFILE  = "$pwd/log.$TFILE";
my $PFILE  = "$pwd/progress.$TFILE";
my $FR     = "$pwd/fastrecovery.$TFILE";
my $DONE   = "$pwd/done.$TFILE";
my $TR     = "$pwd/blib/script/tfrun";
my $TESTER = "$pwd/t/tester.sh";

$ENV{FR} = $FR;

cleanup_tests();

$ENV{THREADS}    = 1;
$ENV{TF_TESTING} = 1;
$ENV{TF_TIMEOUT} = 1;

$ENV{TESTFILE} = "drop";
qx "$TR --tfheartbeat=4 --tfdebuglevel=5 -i $IFILE $TESTER arg1 > test.out 2> test.err";

ok( countstring($LFILE,'Read error'), 'Read error as expect' );
ok( -e $DONE, 'Client Timeout - Finished' );
ok( compsize( $IFILE,'test.out' ), "Check output - drop" );
cleanup_tests();

$ENV{THREADS}    = 1;
$ENV{TF_TESTING} = 1;
$ENV{TF_TIMEOUT} = 1;

$ENV{TESTFILE} = "skipfile";
qx "$TR --tfheartbeat=4 --tfdebuglevel=5 -i $IFILE $TESTER arg1 > test.out 2> test.err";

ok( countstring($LFILE,'Missing files')>0, 'Missed files as expect' );
ok( -e $DONE, 'Skipped file - Finished' );
ok( compsize( $IFILE,'test.out' ), "Check output - skip file" );
cleanup_tests();

$ENV{THREADS}    = 1;
$ENV{TF_TESTING} = 1;
$ENV{TF_TIMEOUT} = 1;

$ENV{TESTFILE} = "testreaderror";
qx "$TR --tfheartbeat=4 --tfdebuglevel=5 -i $IFILE $TESTER arg1 > test.out 2> test.err";

ok( countstring($LFILE,' Truncated read'), 'Truncated read as expect' );
ok( -e $DONE, 'Truncated read - Finished' );
ok( compsize( $IFILE,'test.out' ), "Check output - read error" );
#cleanup_tests();

