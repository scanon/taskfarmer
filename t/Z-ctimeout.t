#!/usr/bin/perl
#
# Simulates a client timing out
#
#########################

use Test::More tests => 3;

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
$ENV{TF_SERVERS} = "$pwd/servers.$$";
$ENV{TESTFILE} = "testhang";

if ( fork() eq 0 ) {
	$ENV{SERVER_ONLY} = 1;
	qx "$TR --tfheartbeat=4 --tfdebuglevel=5 -i $IFILE $TESTER arg1 > test.out 2> test.err";
	exit;
}
sleep 2;
print "Starting clients\n";
print "Starting Client 1\n";
qx "$TR > client.out 2> client.err";

sleep 1;
print "Starting Client 2\n";
qx "$TR > client2.out 2> client2.err";

wait;

unlink $ENV{TF_SERVERS};

ok( countstring($LFILE,'heartbeat'), 'Missed heartbeat as expect' );
ok( -e $DONE, 'Client Timeout - Finished' );
cleanup_tests();

