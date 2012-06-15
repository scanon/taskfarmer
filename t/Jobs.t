# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

use threads;
use threads::shared;
use Test::More tests => 14;
use NERSC::TaskFarmer::Config;
use NERSC::TaskFarmer::Stats;
use NERSC::TaskFarmer::Reader;
use NERSC::TaskFarmer::Output;

BEGIN { use_ok('NERSC::TaskFarmer::Jobs') }

#########################

push @ARGV, '--tfbatchsize=1';
push @ARGV, ( '-i', 't/test.faa' );
my $config = initialize_conf();
my $sb;
my %out;
my $ct = 128;
my $pf = "$$.pf";

init_read($config);
init_output($config);

my $input = get_inputs();

$config->{PROGRESSFILE} = $pf;

# Force it so we can get into timeout loops
$config->{FLUSHTIME}=0;
$config->{POLLTIME}=0;
initialize_jobs(  $config);
initialize_counters( $config);

# Build fake inputs
#for $id ( 1 .. $ct ) {
#	$input{$id}->{header} = "test-$id";
#	$input{$id}->{input}  = "> test-$id\nATGCATGCATGC\n";
#	$input{$id}->{retry}  = 0;
#	$input{$id}->{offset} = $id;
#	$input{$id}->{index}  = $id;
#	$input{$id}->{status} = 'ondeck';
#	push @od, $id;
#}

ok( isajob('x') eq 0, 'Non job' );

my $job=queue_job('tester');
my $jid=$job->{jid};
ok(defined $job, 'queue_job test');

ok(isajob($jid) eq 1, 'isajob true');

my $b=get_job_inputs($jid);
print $b;
ok(length $b > 0, "get_inputs test");
#ok(remaining_inputs() eq 1,'remaining_inputs test');

printf "Remaining jobs %d\n", remaining_jobs();
ok(remaining_jobs() eq 1, 'remaining_jobs test');

# Simulate an heartbeat update
my $t=update_job_stats($jid);
ok($t>0,'Update heartbeat test');

# Simulate a job completing
my $ret=process_job($job->{jid},'tester',1,$sb);
ok($ret > 0, 'Process Job');

# Simulate Failed job
$job=queue_job('tester');
# Not sure if this is the best way to test
my $id=@{$job->{list}}[0];
requeue_job($job->{jid});
ok(get_status($id) eq 'retry', 'Requeue test');

# Simulate Failed Input (Max Retries)
for (1..$config->{MAXRETRY}){
	$job=queue_job('tester');
	requeue_job($job->{jid});
}
#ok( failed_jobs() > 0, 'Failed Job Test - Max Retry');


my $d=delete_olddata();
print "Deleted $d jobs\n";
ok($d>0,'delete_olddata test');

# This should not timeout
$job=queue_job('tester');
$id=@{$job->{list}}[0];
sleep 1;
check_timeouts();
ok(get_status($id) eq 'in progress', 'Timeout test success');

# Cause a timeout
$config->{TIMEOUT}=0;
sleep 1;
check_timeouts();
printf "Status %s\n",get_status($id);
ok(get_status($id) eq 'retry', 'Timeout test');
$job=queue_job('tester');

# Now heartbeats
$config->{TIMEOUT}=10;
$job=queue_job('tester');
$id=@{$job->{list}}[0];
sleep 1;
check_timeouts();
ok(get_status($id) eq 'in progress', 'Heartbeat Timeout test success');
$config->{heartbeatto}=0;
sleep 1;
check_timeouts();
#printf "Status %s\n",$input{$id}->{status};
ok(get_status($id) eq 'retry', 'Timeout test');


finalize_jobs();


