package NERSC::TaskFarmer::Server;

use 5.010000;
use strict;
use warnings;

require Exporter;

use IO::Socket::INET;
use NERSC::TaskFarmer::Jobs;
use NERSC::TaskFarmer::CPR;
use NERSC::TaskFarmer::Reader;
use NERSC::TaskFarmer::Output;
use NERSC::TaskFarmer::Log;
use NERSC::TaskFarmer::Stats;
use Carp qw(cluck);

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
	'all' => [
		qw(

			)
	]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	Start
);

our $VERSION = '0.01';
our $config;
our $shutdown;

sub Start {
	$config = shift;
	setlog( $config->{LOGFILE}, $config->{debuglevel} );
	writeline( $config->{PIDFILE}, $$ . "\n" );

	#  Global vars
	#

	initialize_jobs($config);
	my $shutdown = 0;

	init_read($config);
	init_output($config);

	# Check the age of the recovery file
	#
	if ( !check_recovery_age($config) ) {
		print STDERR "Fast Recovery is too new.\n";
		print STDERR
"Check that another server isn't running and retry in $config->{FLUSHTIME} seconds\n";
		exit 1;
	}
	ondeck( read_fastrecovery( $config->{FR_FILE} ) );

	initialize_counters($config);

	# Catch sigint and do a drain.
	#
	$SIG{INT} = \&catch_int;

	# This is so we can get a backtrace in cases where things get wedged.
	#
	$SIG{'USR2'} = sub {
		ERROR("Caught SIGUSR2.  Dumping backtrace and exiting.");
		Carp::confess("Dumping backtrace.");
	};

	my $next_flush = time + $config->{FLUSHTIME};

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
	DEBUG("Starting Server on ".$sock->sockport());

	writeline( $config->{SOCKFILE}, $sock->sockport() . "\n" );

	my $ident;
	my $command;

	# This is the main work loop.

	my $rj = 1;
	my $ri = 1;
	while ( $rj || $ri ) {
		my $new_sock = $sock->accept();
		if ( defined $new_sock ) {
			my $clientaddr = $new_sock->peerhost();
			eval {
				local $SIG{ALRM} =
					sub { snapshottimeout($clientaddr); die "alarm\n" }; # NB: \n required
				   # Let's give the request handler a fixed amount of time.  Just in case something
				   # gets dropped in the middle.
				alarm $config->{REQUEST_TIMEOUT};
				my $status = do_request($new_sock);
				alarm 0;
			};
			close $new_sock;
		}
		check_timeouts();
		NERSC::TaskFarmer::Output::flush_check();

		$rj = remaining_jobs();
		$ri = remaining_inputs();

		if ( ( $ri eq 0 ) || $shutdown ) {
			$shutdown = 1;    # In case eof got us here.
			INFO("Draining: $rj remaining connections.");
			INFO("Draining: $ri remaining inputs");
		}
	}
	finalize_jobs();
	INFO("Doing final flush");
	flush_output();
	close_all();
	INFO("All done");
	writeline( $config->{DONEFILE}, "done" ) if ( failed_inputs() eq 0 );
	closelog();

}

# Interrupt handler
#
sub catch_int {
	my $signame = shift;
	flush_output();
	close_all();
	ERROR("Exiting on signal $signame");
	closelog();
	exit;
}

sub snapshottimeout {
	my $clientaddr = shift;
	cluck("timeout");
	ERROR("timeout: $clientaddr");
}

sub writeline {
	my $filename = shift;
	my $line     = shift;
	return if ( !defined $filename );
	open( F, "> $filename" ) or die "Unable to open $filename";
	print F $line;
	close F;
}

sub do_request {
	my $sock       = shift;
	my $clientaddr = $sock->peerhost();

	DEBUG("Connect from $clientaddr");

	my $got_response = 0;
	my $status       = 0;
	my $command;
	my $ident = "noid";
	my $scratchbuffer;

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
			map             { delete $scratchbuffer->{$_} } keys %{$scratchbuffer};
			while (<$sock>) {
				if (/^FILES /) {
					( $command, $nfiles ) = split;
					DEBUG("Number of files: $nfiles for $jstep");
				}
				last if /^DONE$/;
				my $readbytes = 0;
				$readbytes = read_file( $sock, $scratchbuffer, $_ ) if /^FILE /;

				if ( $readbytes < 0 ) {
					ERROR("Truncated read in Job step $jstep");
					$success = 0;
				}
				else {
					$bytes += $readbytes;
				}
			}
			if ( $nfiles != scalar( keys %{$scratchbuffer} ) ) {
				my $nfilesr = scalar keys %{$scratchbuffer};
				ERROR("Missing files ($nfiles vs $nfilesr) for $jstep");
				$success = 0;
			}
			if ($success) {

				# Queue process job && defined $job{$jstep}
				print $sock "RECEIVED $jstep\n";
				my $status = process_job( $jstep, $ident, $bytes, $scratchbuffer );
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
			my $job = queue_job($ident);
			print $sock send_work( $job, $ident );
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
			print STDERR "MESSAGE: $_\n";
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
			print STDERR "Recieved unusual response from $clientaddr: $_";
		}
	}
	return $status;
}

# Read file output from client
#
sub read_file {
	my $sock          = shift;
	my $scratchbuffer = shift;
	$_ = shift;

	my $clientaddr = $sock->peerhost();
	my $bytes      = 0;
	my $alert      = 0;
	my ( $command, $file, $size ) = split;
	$scratchbuffer->{$file} = "";
	DEBUG("Reading $file size $size");
	while (<$sock>) {
		$bytes += length $_;
		if ( /DONE$/ && $bytes > $size ) {
			s/DONE\n//;
			$scratchbuffer->{$file} .= $_;
			$bytes -= 5;    # Subtract off the DONE marker
			last;
		}
		elsif ( $bytes > $size && !$alert ) {
			INFO("Overrun: for $file: $_");
			INFO("Continue to read.");
			$alert = 1;
		}
		$scratchbuffer->{$file} .= $_;
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
	my $ident  = shift;
	my $buffer = "";

	# Send the list if there is one.
	if ( defined $job ) {

		#		print "job keys ".join "\n",keys %{$job};
		my $jid    = $job->{jid};
		my $length = $job->{length};
		$buffer = "STEP: $jid\n";
		$buffer .= get_job_inputs($jid);
		INFO("Sent: $jid hostid:$ident length:$length");
	}

	# If no work then send a shutdown
	else {
		DEBUG("send_work says SHUTDOWN");
		$buffer = "SHUTDOWN";
	}
	return $buffer;
}

1;
__END__

=head1 NAME

NERSC::TaskFarmer::Server - Perl extension for NERSC TaskFarmer

=head1 SYNOPSIS

  use NERSC::TaskFarmer::Server;


=head1 DESCRIPTION


=head2 EXPORT

None by default.



=head1 SEE ALSO

TODO

Visit http://www.nersc.gov/

=head1 AUTHOR

Shane Canon, E<lt>scanon@lbl.govE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Shane Canon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
