# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 5;
use IO::File;

BEGIN { use_ok('NERSC::TaskFarmer::Reader') };
BEGIN { use_ok('NERSC::TaskFarmer::CPR') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# Create some fake state
my $inputfile="t/test.faa";
my $fr="fr.test.faa";
my $ct=32;
my @q;
my $config->{INPUT}=$inputfile;

init_read($config);
push @q,read_input($ct);
my $in1=get_inputs();

ok(write_fastrecovery($fr) eq $ct, 'write recovery test');
init_read($config);
my $in2=get_inputs();
my @q2=read_fastrecovery($fr);

ok(scalar @q eq scalar @q2, 'recovery test');
my $t1=$q[0];

ok($in1->{$t1}->{offset} eq $in2->{$t1}->{offset}, 'test recovery inputs');

unlink($fr) if (-e $fr);;
