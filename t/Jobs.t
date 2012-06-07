# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

use Test::More tests => 9;
use IO::File;
use NERSC::TaskFarmer::Config;

BEGIN { use_ok('NERSC::TaskFarmer::Jobs') }

#########################

push @ARGV, '--tfbatchsize=1';
push @ARGV, ( '-i', 'testing/test.faa' );
my $config = initialize_conf();
my @buf;
my @od;
my %input;
my %sb;
my %out;
my $ct = 128;
my $pf = "$$.pf";

$config->{PROGRESSFILE} = $pf;
initialize_jobs( \%input, $config, \@buf, \@od, \%sb, \%out);

# Build fake inputs
for $id ( 1 .. $ct ) {
	$input{$id}->{header} = "test-$id";
	$input{$id}->{input}  = "> test-$id\nATGCATGCATGC\n";
	$input{$id}->{retry}  = 0;
	$input{$id}->{offset} = $id;
	$input{$id}->{index}  = $id;
	$input{$id}->{status} = 'ondeck';
	push @od, $id;
}

ok( isajob('x') eq 0, 'Non job' );

my $job=queue_job('tester');
ok(defined $job, 'send_work test');

ok(isajob($job->{jid}) eq 1, 'isajob true');

ok(remaining_inputs() eq 1,'remaining_inputs test');

# Simulate a job completing
my $ret=process_job($job->{jid},'tester',1);
ok($ret > 0, 'Process Job');

# Simulate Failed job
$job=queue_job('tester');
# Not sure if this is the best way to test
my $id=@{$job->{list}}[0];
requeue_job($job->{jid});
ok($input{$id}->{status} eq 'retry', 'Requeue test');

# Simulate Failed Input (Max Retries)
for (1..$config->{MAXRETRY}){
	$job=queue_job('tester');
	requeue_job($job->{jid});
}
ok( failed_jobs() > 0, 'Failed Job Test - Max Retry');

# Progress File
flushprogress();
my @st=stat $pf;
ok($st[7] > 0, 'Progress File Test');
unlink $pf;

# Things to test
# failed a job
# requeue a job
# cleanup

#sub initialize_jobs {
#sub process_results {
#                substr( $inputs, 0, 25 ),
#sub send_work {
#sub isajob {
#sub remaining_inputs{
#sub remaining_jobs {
#sub check_timeouts {
#sub requeue_job {
#sub failed_jobs {
#sub update_job_stats {
#sub delete_olddata {
#sub finalize_jobs {

