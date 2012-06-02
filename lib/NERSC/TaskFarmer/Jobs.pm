package NERSC::TaskFarmer::Jobs;

use 5.010000;
use strict;
use warnings;

require Exporter;

use NERSC::TaskFarmer::Log;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use NERSC::TaskFarmer::Jobs ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	initialize_jobs
	process_jobs
	isajob
	send_work
	remaining_inputs
	remaining_jobs
	check_timeouts
	requeue_job
	failed_jobs
	update_job_stats
	delete_olddata
	finalize_jobs
);

our $VERSION = '0.01';
our %job;
our %input;
our %output;
our @failed;
our @ondeck;
our @buffered;
our %scratchbuffer;
our $processed;
our $progress_buffer;
our $item;
our $config;
our $next_check;
our $next_status;

sub initialize_jobs {
	
	my $input=shift;
	my $config=shift;
	my $buffered=shift;
	my $ondeck=shift;
	
	%input=%{$input};
	@buffered=@$buffered;
	@ondeck=@$ondeck;
  $next_check  = time + $config->{POLLTIME};
  $next_status = time + $config->{FLUSHTIME};
}

# Process results from client.
# Add line to progress buffer.
# Cleanup data structures.
# (This doesn't actually spool the output)
#
sub process_results {
	my $jstep = shift;
	my $ident = shift;
	my $bytes = shift;

	return 0 unless defined( $job{$jstep} );
	$job{$jstep}->{bytesout} = $bytes;
	

	# Copy data from scratch buffer
	#
	foreach my $file ( keys %scratchbuffer ) {
		DEBUG("Copying $file to buffer");
		$output{$file}->{buffer} .= $scratchbuffer{$file};
	}
	my $inputs = join ",", @{ $job{$jstep}->{list} };
	my $rtime = time - $job{$jstep}->{start};
	$job{$jstep}->{time}   = $rtime;
	$job{$jstep}->{finish} = time;
	$job{$jstep}->{ident}  = $ident;
	$progress_buffer .= sprintf "%s %s %d %d %d %d\n", $inputs, $ident, $rtime,
		$job{$jstep}->{lines}, time, $job{$jstep}->{bytesin};
	INFO(
		sprintf "Recv: %d input:%25s hostid:%-10s  time:%-4ds lines: %-6d proc: %d",
		$jstep,
		substr( $inputs, 0, 25 ),
		$ident,
		$rtime,
		$job{$jstep}->{lines},
		$processed
	);

	foreach my $inputid ( @{ $job{$jstep}->{list} } ) {
		$input{$inputid}->{status} = 'buffered';
		push @buffered, $inputid;
#TODO fix this		push @buffered, $inputid;
	}
	$processed += $job{$jstep}->{count};

	#    delete $job{$jstep};
	return 1;
}

sub send_work {
	my $ident;


	my $sent = [];
	my $length;
	my $ct   = 0;
	my @list = build_list( $config->{BATCHSIZE}, $config->{BATCHBYTES} );
	my $buffer;

	# Send the list if there is one.
	#
	if ( scalar @list > 0 ) {
		$buffer="STEP: $item\n";
		foreach my $inputid (@list) {
			$buffer.=$input{$inputid}->{input};
			$input{$inputid}->{status} = 'in progress';
			push @{$sent}, $inputid;
			$length += length $input{$inputid}->{input};
			$ct++;
		}

		# Save info about the job step.
		#
		$job{$item}->{start}         = time;
		$job{$item}->{finish}        = 0;
		$job{$item}->{time}          = 0;
		$job{$item}->{bytesin}       = $length;
		$job{$item}->{list}          = $sent;
		$job{$item}->{count}         = $ct;
		$job{$item}->{ident}         = $ident;
		$job{$item}->{lastheartbeat} = time;
		INFO("Sent: $item hostid:$ident length:$length");
		$item++;
	}
	else {

		# If no work then send a shutdown
		$buffer="SHUTDOWN";
	}
	return $buffer;
}

sub isajob {
	my $jstep = shift;
	
	if (defined $job{$jstep}){
		return 1;
	}
	else {
		return 0;
	}
}

sub remaining_inputs{
	return ( scalar @ondeck );
}

sub remaining_jobs {
	my $j = shift;
	my $c = 0;
	foreach my $jid ( keys %{$j} ) {
		next if $j->{$jid}->{finish};
		$c++;
	}
#	print stderr "Remaining jobs: $c\n";
	return $c;
}

# Look for old inflight messages.
# Move to retry queue
#
sub check_timeouts {
	DEBUG("Checking timeouts");
	if ( time > $next_status ) {
				update_counters( \%job, \%input, \@ondeck );

		$next_status = time + $config->{FLUSHTIME};
	}
		
		delete_olddata( );
	return unless ( time > $next_check );
	foreach my $jstep ( keys %job ) {
		next if $job{$jstep}->{finish};
		my $retry = 0;

		$retry = 1 if ( time > ( $job{$jstep}->{lastheartbeat} + $config->{heartbeatto} ) );
		$retry = 1 if ( time > ( $job{$jstep}->{start} + $config->{TIMEOUT} ) );
		if ($retry) {
			WARN("RETRY: $jstep timed out or missed heartbeat.  Adding to retry.");
			requeue_job($jstep);
			increment_timeout();
		}
	}
	$next_check = time + $config->{polltime} / 2;
}

# Take inputs for job step
# and put back on the queue.
#
sub requeue_job {
	my $jstep = shift;

	foreach my $inputid ( @{ $job{$jstep}->{list} } ) {
		$input{$inputid}->{retry}++;
		DEBUG( sprintf "Retrying %s for %d time",
			$inputid, $input{$inputid}->{retry} );
		if ( $input{$inputid}->{retry} < $config->{MAXRETRY} ) {
			unshift @ondeck, $inputid;
			$input{$inputid}->{status} = 'retry';
		}
		else {
			ERROR("$inputid hit max retries");
			push @failed, $inputid;
		}
	}
	delete $job{$jstep};
}

sub failed_jobs {
	return scalar(@failed);
}

sub update_job_stats {
	my $jstep = shift;

	if ( defined $job{$jstep} ) {
		$job{$jstep}->{lastheartbeat} = time;
	}
}

sub delete_olddata {
	foreach my $jid ( keys %job ) {
		next unless $job{$jid}->{finish} > 0;
		delete $job{$jid} if $job{$jid}->{finish} < time - 120;
	}

}

sub finalize_jobs {
	NERSC::TaskFarmer::Reader::check_inputs(@ondeck);
	NERSC::TaskFarmer::Stats::update_counters(\%job,\%input,\@ondeck,0);
}

1;
__END__

=head1 NAME

NERSC::TaskFarmer::Jobs - Perl extension for NERSC TaskFarmer

=head1 SYNOPSIS

  use NERSC::TaskFarmer::Jobs;


=head1 DESCRIPTION

This is a set of helper function to do checkpoint restart for the NERSC TaskFarmer.

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
