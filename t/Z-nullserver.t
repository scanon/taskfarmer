#!/usr/bin/perl
#
# Test a recovery stuff
#
#########################

use Test::More tests => 2;

BEGIN { use_ok('NERSC::TaskFarmer::Tester') }

#########################
setup_test();

my $pwd = qx 'pwd';
chomp($pwd);
my $TR     = "$pwd/blib/script/tfrun";
my $TESTER = "$pwd/t/tester.sh";

cleanup_tests();
$ENV{TF_SERVERS}="$pwd/servers.$$";
open(S,"> $ENV{TF_SERVERS}");
print S "localhost:1234:bogus:bogus\n";
close S;
my $start=time();
qx "$TR > test.out 2> test.err";
print "Exited $?\n";

ok($start+3>time,'Bad server line should exit immediately');

unlink($ENV{TF_SERVERS});
cleanup_tests();


