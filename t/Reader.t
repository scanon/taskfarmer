# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 3;
use IO::File;

BEGIN { use_ok('NERSC::TaskFarmer::Reader') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
my $inputfile="t/test.faa";
my $config->{INPUT}=$inputfile;
$config->{MAXRETRY}=2;

init_read($config);
my $ct=32;
read_input($ct);
my $input=get_inputs();

ok(scalar(keys %{$input}) eq $ct, 'read_input');

# Change State
my @list=keys %{$input};
update_status('buffered',@list);

my $id=shift @list;
ok(get_status($id) eq 'buffered','Change state test');

retry_inputs(($id));
