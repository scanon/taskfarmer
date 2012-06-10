#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

# Client Piece
if ( scalar(@ARGV) > 0 ) {
	my $line;
	while (<STDIN>) {
		$line++;
	}
	print "$line\n";
	open AO, "> $ENV{ARG_OUT}";
	foreach (@ARGV) {
		print AO "$_\n";
	}
	exit;
}

use Test::More tests => 7;

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

$ENV{FR}   = $FR;

cleanup_tests();

# Run server
$ENV{ARG_OUT}     = "$pwd/test.args";
$ENV{THREADS} = 4;
qx "$TR -i $IFILE $TESTER arg1 arg2 'a b' > test.out 2> test.err";

ok( -e "./test.args", "Args test" );
ok( checklines( $IFILE, $PFILE ) eq 1, "Check Output" );
delete $ENV{ARG_OUT};

cleanup_tests();

print "Batchbytes Test\n";
qx "$TR --tfdebuglevel=3 --tfbatchbytes=800 -i $IFILE $TESTER arg1 > test.out 2> test.err";
printf "PL: %d\n", countlines($PFILE);
ok( $? eq 0, "Batchtypes ran clean" );
ok( countlines($PFILE) > 100, 'Batchbytes yields smaller chunks' );
ok( checklines( $IFILE, $PFILE ) eq 1, "Check output batchbytes" );

cleanup_tests();

print "Error Test\n";
$ENV{ERRORSTEP} = 2;
qx "$TR --tfdebuglevel=5 -i $IFILE $TESTER arg1 > test.out 2> test.err";
ok( checklines( $IFILE, $PFILE ) eq 1, "Error Test: Check Output" );

#cleanup_tests();

