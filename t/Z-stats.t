#!/usr/bin/perl

# TODO Finish stats test

use Test::More tests => 2;

BEGIN { use_ok('NERSC::TaskFarmer::Tester') }

#########################
setup_test();
my $pwd = qx 'pwd';
chomp($pwd);
my $TFILE  = "test.faa";
my $IFILE  = "./t/$TFILE";
my $DONE   = "$pwd/done.$TFILE";
my $TR     = "$pwd/blib/script/tfrun";
my $TESTER = "$pwd/t/tester.sh";

cleanup_tests();

qx "$TR --tfdebuglevel=5 --tfstatusfile status -i $IFILE $TESTER arg1 > test.out 2> test.err";

#  export SERVER_TIMEOUT=1
#  export SOCKET_TIMEOUT=1
#
#  $TF_HOME/bin/tfrun --tfstatusfile status -i $TFILE $ME arg1  > test.out 2> test.err
#
## Everything has ran.  Now let us see how it did
#  PLINES=$( cat progress.$TFILE|sed 's/,/\n/g'|wc -l)
#  ELINES=$( grep -c '^>' $TFILE)
#  [ $PLINES -eq $ELINES ] || error "Didn't process all lines $PLINES vs $ELINES"
#  okay
