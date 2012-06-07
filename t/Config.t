# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

use Test::More tests => 2;

BEGIN { use_ok('NERSC::TaskFarmer::Config') };

#########################

my $config=initialize_conf();

ok(scalar(keys %$config) > 1, 'Non-empty config');

