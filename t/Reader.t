# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;
use IO::File;

BEGIN { use_ok('NERSC::TaskFarmer::Reader') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
my $input="testing/test.faa";
my %input;
my $index=0;
my $inputf = new IO::File $input or die "Unable to open input file ($input)\n";
my $ct=32;
read_input($inputf,$ct,\%input,$index);

ok(scalar(keys %input) eq $ct, 'read_input');

print join "\n",sort keys %input;
