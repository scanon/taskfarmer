# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

use Test::More tests => 1;
use IO::File;

BEGIN { use_ok('NERSC::TaskFarmer::Stats') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
my $sfile="stats.log";

unlink $sfile if ( -e $sfile);

unlink ($sfile) if ( -e $sfile);
