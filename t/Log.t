# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

use Test::More tests => 2;
use IO::File;

BEGIN { use_ok('NERSC::TaskFarmer::Log') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
my $lfile="test.log";

unlink $lfile if ( -e $lfile);
ERROR('Send error to standard error');
DEBUG('Send debug to standard error');
NERSC::TaskFarmer::Log::setlog('test.log',1);

DEBUG('test');
ERROR('error');
open(L,$lfile);
$l=<L>;
chomp $l;
close L;
ok($l eq 'ERROR: error', 'Test Error Log');
#ok($input{$t1}->{offset} eq $input2{$t1}->{offset}, 'test recovery inputs');

unlink ($lfile) if ( -e $lfile);
