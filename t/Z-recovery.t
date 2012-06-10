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
my $TFILE  = "test.faa";
my $IFILE  = "./t/$TFILE";
my $LFILE  = "$pwd/log.$TFILE";
my $PFILE  = "$pwd/progress.$TFILE";
my $FR     = "$pwd/fastrecovery.$TFILE";
my $DONE   = "$pwd/done.$TFILE";
my $TR     = "$pwd/blib/script/tfrun";
my $TESTER = "$pwd/t/tester.sh";

$ENV{FR} = $FR;

# Test that server stops with a new recovery file
#
cleanup_tests();
open(FR,"> $FR");
print FR "bogus\n";
close FR;
qx "$TR --tfheartbeat=4 --tfdebuglevel=5 -i $IFILE $TESTER arg1 > test.out 2> test.err";

ok(countstring('test.err','too new'), 'Server does not start with new fastrecovery');

cleanup_tests();

