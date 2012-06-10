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
my $IFILE  = "./testing/$TFILE";
my $DONE   = "$pwd/done.$TFILE";
my $TR     = "$pwd/blib/script/tfrun";
my $TESTER = "$pwd/t/tester.sh";

$ENV{FR} = $FR;

cleanup_tests();

$ENV{THREADS}    = 1;
$ENV{TF_SERVERS} = "$pwd/servers.$$";

print "Starting server1\n";
if ( fork() eq 0 ) {
	$ENV{SERVER_ONLY} = 1;
	qx "$TR --tfheartbeat=4 --tfdebuglevel=5 -i $IFILE $TESTER arg1 > test.out 2> test.err";
	exit;
}
sleep 1;
$IFILE2="test2.faa";
$DONE2="done.test2.faa";
symlink $IFILE,$IFILE2;
print "Starting server2\n";
if ( fork() eq 0 ) {
	$ENV{SERVER_ONLY} = 1;
	qx "$TR --tfheartbeat=4 --tfdebuglevel=5 -i $IFILE2 $TESTER arg1 > test.out 2> test.err";
	exit;
}

sleep 2;
qx "$TR > client.out 2> client.err";
wait;

ok( -e $DONE, 'Server1 - Finished' );
ok( -e $DONE2, 'Server2 - Finished' );

unlink $ENV{TF_SERVERS};
unlink $IFILE2;
unlink $DONE2;
#cleanup_tests();



## Everything has ran.  Now let us see how it did
#  PLINES=$( cat progress.$TFILE |sed 's/,/\n/g'|wc -l)
#  ELINES=$( grep -c '^>' $TFILE)
#  [ $PLINES -eq $ELINES ] || error "1: Didn't process all lines $PLINES vs $ELINES"
##  PLINES=$( cat progress.$TFILE.2 |sed 's/,/\n/g'|wc -l)
#  [ $PLINES -eq $ELINES ] || error "2: Didn't process all lines $PLINES vs $ELINES"
#  okay
