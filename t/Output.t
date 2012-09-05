# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

use threads;
use threads::shared;
use Test::More tests => 1;
use NERSC::TaskFarmer::Config;

BEGIN { use_ok('NERSC::TaskFarmer::Output') }

#########################

my $config = initialize_conf();
#$config->{FLUSHTIME}=0;
$config->{MAXBUFF}=32;
my $sb;
my @list=();

init_output($config);

$sb->{'t1'}="0123456789\n";
buffer_output(\@list,$sb);
buffer_output(\@list,$sb);
buffer_output(\@list,$sb);
$sb->{'t2'}="0123456789\n";
buffer_output(\@list,$sb);
#finalize_output();
