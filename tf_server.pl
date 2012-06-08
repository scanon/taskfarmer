#!/usr/bin/env perl

# TODO Close files that aren't accessed for a while
# TODO Move output handler to separate module
# TODO Move scratchbuffer into Jobs.pm

use threads;
use threads::shared;
use Socket;
use IO::Handle;
use IO::File;
use IO::Socket::INET;
use strict;
use Getopt::Long;
use NERSC::TaskFarmer::Reader;
use NERSC::TaskFarmer::Config;
use NERSC::TaskFarmer::Jobs;
use NERSC::TaskFarmer::CPR;
use NERSC::TaskFarmer::Stats;
use NERSC::TaskFarmer::Log;
use Carp qw(cluck);

my $config = initialize_conf();

die "No input file specified\n" unless defined $config->{INPUT};

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

initialize_jobs( \%input, $config, \@buffered, \@ondeck, \%scratchbuffer, \%output );

# Not sure...
my $next_flush = time + $config->{FLUSHTIME};

my $processed   = 0;
my $shutdown    = 0;

init_read($config, \%input);

# Check the age of the recovery file
#
if ( !check_recovery_age($config) ) {
	print stderr "Fast Recovery is too new.\n";
	print stderr
"Check that another server isn't running and retry in $config->{FLUSHTIME} seconds\n";
	exit 1;
}
push @ondeck, read_fastrecovery( $config->{FR_FILE}, \%input );

# make the socket
my %sockargs = (
	Proto   => 'tcp',
	Timeout => $config->{SOCKET_TIMEOUT},
	Listen  => 1000,
	Reuse   => 1
);

$sockargs{LocalPort} = $config->{port} if defined $config->{port};

my $sock = new IO::Socket::INET->new(%sockargs)
	or die "Unable to create socket\n";

writeline( $config->{SOCKFILE}, $sock->sockport() . "\n" );
writeline( $config->{PIDFILE}, $$ . "\n" );

my $ident;
my $command;

initialize_counters( $config, \%input, \@ondeck );

setlog( $config->{LOGFILE}, $config->{debuglevel} );

# Catch sigint and do a drain.
#
$SIG{INT} = \&catch_int;

# This is so we can get a backtrace in cases where things get wedged.
#
$SIG{'USR2'} = sub {
	ERROR("Caught SIGUSR2.  Dumping backtrace and exiting.");
	Carp::confess("Dumping backtrace.");
};

# This is the main work loop.

my $rj=1;
my $ri=1;
while ( $rj || $ri ) {
	my $new_sock = $sock->accept();
	if ( defined $new_sock ) {
		my $clientaddr = $new_sock->peerhost();
		eval {
			local $SIG{ALRM} =
				sub { snapshottimeout($clientaddr); die "alarm\n" };   # NB: \n required
			   # Let's give the request handler a fixed amount of time.  Just in case something
			   # gets dropped in the middle.
			alarm $config->{REQUEST_TIMEOUT};
			my $status = do_request($new_sock);
			alarm 0;
		};
		close $new_sock;
	}
	check_timeouts();
	flush_output() if ( time > $next_flush );
	
	$rj=remaining_jobs();
	$ri=remaining_inputs();
#	printf STDERR "DEBUG: $rj $ri\n";

	if ( endoffile() || $shutdown ) {
		$shutdown       = 1;                   # In case eof got us here.
		INFO("Draining: $rj remaining connections.");
		INFO("Draining: $ri remaining inputs");
	}
}
finalize_jobs();

INFO("Doing final flush");
flush_output();
close_all();
INFO("All done");
writeline( $config->{DONEFILE}, "done" ) if (failed_jobs() eq 0);
closelog();

# Interrupt handler
#
sub catch_int {
	my $signame = shift;
#	print stderr "Caught signal $signame (shutdown=$shutdown)\n";
	sleep 10 if $shutdown eq 2;
	if ($shutdown) {
		flush_output();
		close_all();
		ERROR("Exiting on signal $signame");
		closelog();
		exit;
	}
	else {
		my $rem=remaining_jobs();
		$shutdown = 2;
		flush_output();
		ERROR("Shutting down on signal $signame");
		ERROR("Draining: $rem remaining connections");
		$shutdown = 1;
	}
}

sub close_all {
	foreach my $file ( keys %output ) {
		$output{$file}->{handle}->close()
			if defined $output{$file}->{handle};
	}
}

sub snapshottimeout {
	my $clientaddr = shift;
	cluck("timeout");
	ERROR("timeout: $clientaddr");
}

sub writeline {
	my $filename = shift;
	my $line     = shift;
	return if (! defined $filename);
	open(F,"> $filename") or die "Unable to open $filename";
	print F $line;
	close F;
}

sub do_request {
	my $sock       = shift;
	my $clientaddr = $sock->peerhost();

	DEBUG("Connect from $clientaddr");

	my $got_response = 0;
	my $status       = 0;
	$ident = "noid";

	# Read from client.  Process requests and reponse.
	#
	while (<$sock>) {

#		DEBUG("COMMAND: $_");
		if (/^RESULTS /) {
			my ( $command, $jstep ) = split;
			chomp $jstep;
			my $bytes   = 0;
			my $success = 1;
			my $nfiles;
			map             { delete $scratchbuffer{$_} } keys %scratchbuffer;
			while (<$sock>) {
				if (/^FILES /) {
					( $command, $nfiles ) = split;
					DEBUG("Number of files: $nfiles for $jstep");
				}
				last if /^DONE$/;
				my $readbytes = read_file( $sock, $_ ) if /^FILE /;
				if ( $readbytes < 0 ) {
					ERROR("Truncated read in Job step $jstep");
					$success = 0;
				}
				else {
					$bytes += $readbytes;
				}
			}
			if ( $nfiles != scalar( keys %scratchbuffer ) ) {
				my $nfilesr = scalar keys %scratchbuffer;
				ERROR("Missing files ($nfiles vs $nfilesr) for $jstep");
				$success = 0;
			}
			if ($success) {

				# Queue process job && defined $job{$jstep}
				print $sock "RECEIVED $jstep\n";
				my $status = process_job( $jstep, $ident, $bytes );
			}
			elsif ( !$success && isajob($jstep) ) {
				ERROR("Processing job step $jstep");
				print $sock "RECEIVED $jstep\n";
				increment_errors();
				requeue_job($jstep);
			}
			else {
				ERROR("Unexpected report from $clientaddr:$ident for $jstep");
				print $sock "RECEIVED $jstep\n";
				$status = 0;
			}
		}    #
		elsif (/^IDENT /) {
			( $command, $ident ) = split;
		}
		elsif (/^NEXT$/) {
			if ( $shutdown && !remaining_inputs() ) {
				DEBUG("Sending shutdown to $ident\n");
				print $sock "SHUTDOWN\n";
			}
			my $job=queue_job($ident);
			print $sock send_work( $job );
			last;
		}
		elsif (/^ARGS$/) {
			foreach my $a (@ARGV) {
				print $sock "$a\n";
			}
			print $sock "DONE\n";
		}
		elsif (/^MESSAGE /) {
			chomp;
			s/^MESSAGE //;
			print stderr "MESSAGE: $_\n";
		}
		elsif (/^HEARTBEAT /) {
			chomp;
			s/^HEARTBEAT //;
			my @items = split;
			my $jstep = shift @items;
			update_job_stats( $jstep, @items );
			DEBUG("Got Heartbeat for $jstep");
		}
		elsif (/^STATUS/) {
			if ($shutdown) {
				print $sock "SHUTDOWN";
			}
			else {
				print $sock "READY";
			}
		}
		elsif (/^ERROR /) {
			my ( $command, $jstep ) = split;
			ERROR("Job step $jstep exited with an error");
			print $sock "RECEIVED $jstep\n";
			increment_errors();
			requeue_job($jstep);
		}
		else {
			print stderr "Recieved unusual response from $clientaddr: $_";
		}
	}
	return $status;
}

# Read file output from client
#
sub read_file {
	my $sock = shift;
	$_ = shift;

	my $clientaddr = $sock->peerhost();
	my $bytes      = 0;
	my $alert      = 0;
	my ( $command, $file, $size ) = split;
	$scratchbuffer{$file} = "";
	DEBUG("Reading $file size $size");
	while (<$sock>) {
		$bytes += length $_;
		if ( /DONE$/ && $bytes > $size ) {
			s/DONE\n//;
			$scratchbuffer{$file} .= $_;
			$bytes -= 5;    # Subtract off the DONE marker
			last;
		}
		elsif ( $bytes > $size && !$alert ) {
			INFO("Overrun: for $file: $_");
			INFO("Continue to read.");
			$alert = 1;
		}
		$scratchbuffer{$file} .= $_;
	}
	if ( $bytes == $size ) {
		DEBUG("Read $file correctly.  Read $bytes versus $size");
		return $bytes;
	}
	else {
		ERROR("Read error on $file.  Read $bytes versus $size");
		return -1;
	}
}

#
# Send work
sub send_work {
	my $job    = shift;
	my $buffer = "";

	# Send the list if there is one.
	if ( defined $job ) {
		my $jid    = $job->{jid};
		my $length = $job->{length};
		$buffer = "STEP: $jid\n";
		$buffer.=get_inputs(@{$job->{list}});
		
		INFO("Sent: $jid hostid:$ident length:$length");
	}
	# If no work then send a shutdown
	else {
		DEBUG("send_work says SHUTDOWN");
		$buffer = "SHUTDOWN";
	}
	return $buffer;
}

# Flush output, progress, and create fast_recovery file
# This tries to keep everything in a consistent state.
#
sub flush_output {
	
	#|| $buffer_size > $config->{MAXBUFF} );
	
	DEBUG("Flush called");
	foreach my $file ( keys %output ) {
		my $bf = $output{$file}->{buffer};
		if ( !defined $output{$file}->{handle} ) {
			DEBUG("Opening new file $file");
			if ( $file eq "stdout" ) {
				$output{$file}->{handle} = *stdout;
			}
			elsif ( $file eq "stderr" ) {
				$output{$file}->{handle} = *stderr;
			}
			else {
				$output{$file}->{handle} = new IO::File ">> $file";
			}
		}
		my $handle = $output{$file}->{handle};
		if ( !defined $handle ) {
			ERROR("Unable to open file $file.  Exiting");
			exit -1;
		}
		my $blength = length $output{$file}->{buffer};
		if ( $blength > 0 ) {
			$output{$file}->{lastwrite} = time;
			DEBUG("Flushed $blength bytes to $file");
			print {$handle} $output{$file}->{buffer};
			$handle->flush();
		}
		$output{$file}->{buffer} = '';
	}

  update_status('completed',@buffered);
	@buffered = ();
	flushprogress();

	my $ct = write_fastrecovery( $config->{FR_FILE}, \%input, 1 );
	DEBUG("Wrote fast recovery ($ct items)");
	DEBUG("Next flush in $config->{FLUSHTIME} seconds");
	$next_flush = time + $config->{FLUSHTIME};
}

=pod

=head1 NAME

taskfarmer

=head1 SYNOPSIS

Usage:

 tfrun -i <input> <serial app> {arguements for app}

=head1 DESCRIPTION

The Task Farmer provides a framework that simplifies running serial
applications in a parallel environment.  It was originally
designed to run the BLAST bioinformatic program, howevever it can
easily be adapted to other applications too.  Using the task farmer
a user can easily launch a serial application in parallel.  The
framework will take care of disributing the tasks, collecting output,
and managing any failures.

=head2 FILE OUTPUT

The taskfarmer will automatically harvest any output generated by
the serial application in the local working directory.  Each tasks
thread runs in a temporary working directory.  After the serial
application exits, the taskfarmer client will scan the working directory
for any files and transmit those back to the server.  The transmitted
output will automatically be appended to a file of the same name in the
working directory of the running server.  All of the output is buffered
from the client in a serial fashion.  So output from each task will be
contingous and complete.  In other words, output cannot got interleaved
from multipole clients.  

If the client application changes working directories
or writes to a path outside the working directory, the output will not 
be captured by the taskfarmer.  In some circumstances this may be 
advantageous since the taskfarmer server can typically only sustain a few 100 MB/s
of bandwidth.  However, if the output harvesting is bypassed, the user
will need to insure that the output filenames are unique for each task.
The STEP environment variable can be used to insure that the filenames are
unique.  However, this can lead to a large number of files which may
create issues with file management and metadata performance.

=head2 LAUNCH MODES

=head3 Simple Mode

The simplest method to start the taskfarmer is to call tfrun
from inside a parallel job allocation (i.e. from the batch script).  The server
and clients will automatically be started.  If the job runs out of walltime 
before completion, the recovery files can be used to pick up where it left off.
The only caveats to this approach is that you must insure that multiple job
instances are not started for the same input since multiple servers would be
reading the file.

=head3 Server Mode

The server can be started in a stand-alone mode.  This can be useful if you wish
to submit multiple parallel jobs that work for a common server.  This may be desirable
to exploit backfill opportunites or run on multiple systems.  Set the environment
variable B<SERVER_ONLY> to 1 prior to running tfrun.  The server will startup and
print a contact string that can be used to launch the clients.  Optionally, you
can set B<TF_SERVERS> to have the server create or append the contact information
to a string.  If this variable is set prior to launching the clients, the clients
will automatically iterate through the servers listed in the file.

=head3 Client Mode

The clients can be also be launched separately.  This is useful if you are starting
clients in a serial queue, on remote resources, or running multiple parallel jobs.
Several environment variables can trigger this mode.  If B<TF_ADDR> and B<TF_PORT>
are defined then the server will not be started and the client will contact the
server listening at TF_ADDR on TF_PORT.  Alternatively, if B<TF_SERVERS> is defined
then the client will iterate through each server listed in the file.  TF_SERVERS
trumps TF_ADDR and TF_PORT.


=head1 OPTIONS

=over 8

=item B<--tfdebuglevel=i>

Adjust the debug level.  Higher means more output.  Level 1 is errors.  Level 2 is warnings.
Level 3 is information.  Level 4 is debug.  Default: 1

=item B<--tfbatchsize=i>

Adjust the number of input items that are sent to a client during each request.  The default is
B<16>.  In general, you should adjust the batchsize to maintain a processing rate of approximately
5 minutes per cycle.  Too little will lead to a high number of connections on the server.  Too few
will result in more loss if the application hits a walltime limit and in-flight tasks are lost.  Default 16.

=item B<--tfbatchbytes=i>

Similar to batchsize, but instead of processing a fixed number of items, a target size (in bytes) is
used.  The server will read in input items until the number of bytes exceeds batchsize.  This splitting
approach can be more consistent for some types of applications.  Default: disabled

=item B<--tftimeout=i>

Adjust the timeout to process one batch of inputs in seconds.  If the time is exceeeded, the task will be
requeued and sent out on susequent requests.  If the client responds with the results after the
timeout, the results will be discarded.  Default: 1800.

=item B<--tfsocktimeout=i>

Adjust the timeout for a socket connection in seconds.  Default: 45.

=item B<--tfsockfile=s>

Filename to write the port for the listening socket.  This can be used by the client to automatically
read the port.  Default: none
my $result = GetOptions( "tfstatusfile=s"  => \$config->{STATUSFILE} );
my $result = GetOptions( "tfpidfile=s"     => \$pidfile );
my $result = GetOptions( "tfheartbeat=i"   => \$heartbeatto );

=back

=head1 BUGS 

Missing BUGS documentation.

=head1 EXAMPLES

tfrun -i input blastall -d $DB -o blast.out

=head1 LIMITATIONS AND CONSIDERATIONS

Avoid changing directories in your executuables or wrappers that are
executed by the task farmer client.  The file harvesting method used
in the taskfarmer assumes all of the files in the working directory
should be sent to the server.  Furthermore, they are removed after
sending.

When running on some HPC systems, the /tmp space may have limited
capacity (< 1 GB).  If the output harvesting is being used, insure
that the output does not exceed this limit.


=cut

