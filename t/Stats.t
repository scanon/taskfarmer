# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

use Test::More tests => 1;
use IO::File;

BEGIN { use_ok('NERSC::TaskFarmer::Stats') };
use NERSC::TaskFarmer::Config;
use NERSC::TaskFarmer::Reader;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
my $sfile="stats.log";

unlink $sfile if ( -e $sfile);

my $config = initialize_conf();

#  Global vars
#

# shared
my %input;
my %output;
my %scratchbuffer;

# These become thread queues
my @ondeck;

#my @failed;
my @buffered;

$config->{INPUT}="./testing/test.faa";
init_read($config, \%input);

initialize_counters( $config, \%input, \@ondeck );

increment_errors();


unlink ($sfile) if ( -e $sfile);
