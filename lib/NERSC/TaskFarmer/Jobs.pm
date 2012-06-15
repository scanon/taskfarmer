package NERSC::TaskFarmer::Jobs;

use 5.010000;
use strict;
use warnings;
use threads;
use threads::shared;

require Exporter;

use NERSC::TaskFarmer::Log;
use NERSC::TaskFarmer::Reader;
use NERSC::TaskFarmer::Stats;
use NERSC::TaskFarmer::Output;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use NERSC::TaskFarmer::Jobs ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = (
	'all' => [
		qw(

			)
	]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	initialize_jobs
	process_job
	isajob
	queue_job
	get_job_inputs
	remaining_jobs
	check_timeouts
	ondeck
	requeue_job
	update_job_stats
	delete_olddata
	finalize_jobs
);

our $VERSION = '0.01';
our %job;
our $ondeck;
our $processed = 0;
our $item      = 0;
our $config;
our $next_check;
our $next_status;
our $last_status = 0;
our $pf;
our $chunksize;
our $progfile;

sub initialize_jobs {
	$config        = shift;
	$ondeck        = [];

	$next_check  = time + $config->{POLLTIME};
	$next_status = time + $config->{FLUSHTIME};
	if ( defined $config->{PROGRESSFILE} ) {
		$progfile = $config->{PROGRESSFILE};
	}
	$chunksize = 2 * $config->{BATCHSIZE};

}

# Process results from client.
# Add line to progress buffer.
# Cleanup data structures.
# (This doesn't actually spool the output)
#
sub process_job {
	my $jstep = shift;
	my $ident = shift;
	my $bytes = shift;
	my $scratchbuffer = shift;

	return 0 unless defined( $job{$jstep} );
	$job{$jstep}->{bytesout} = $bytes;

	# Copy data from scratch buffer
	#
	my $inputs = join ",", @{ $job{$jstep}->{list} };
	my $rtime = time - $job{$jstep}->{start};
	$job{$jstep}->{time}   = $rtime;
	$job{$jstep}->{finish} = time;
	$scratchbuffer->{$progfile} = sprintf "%s %s %d %d %d %d\n", $inputs,
		$job{$jstep}->{ident}, $rtime, 0, time, $job{$jstep}->{bytesin};
	buffer_output($job{$jstep}->{list},$scratchbuffer);
	INFO(
		sprintf "Recv: %d input:%25s hostid:%-10s  time:%-4ds lines: %-6d proc: %d",
		$jstep,
		substr( $inputs, 0, 25 ),
		$job{$jstep}->{ident},
		$rtime,
		0,
		$processed
	);

	#	foreach my $inputid (  ) {
	#		$input->{$inputid}->{status} = 'buffered';
	#		push @{$buffered}, $inputid;
	#	}
	$processed += $job{$jstep}->{count};

	#    delete $job{$jstep};
	return 1;
}

#
# This builds up a work list of args inputs.
# It will read in more input if there isn't enough ondeck.
# Then it will create a job for the list.
#
sub queue_job {
	my $ident = shift;
	my @list;
	my $length = 0;
	my $ct     = 0;
	my $bytes =0;
	

	if ( scalar @{$ondeck} < ( $config->{BATCHSIZE} ) ) {
		push @{$ondeck}, read_input($chunksize);
	}
	while ( $ct < $config->{BATCHSIZE} && scalar @{$ondeck} > 0 ) {
		my $id = shift @{$ondeck};
		push @list, $id;
		die "Bad Input ID $id\n" unless isainput($id);
		$bytes += inputlength( $id);
		$ct++;
		last if ( $config->{BATCHBYTES} > 0 && $bytes > $config->{BATCHBYTES} );
	}
	
	# Send the list if there is one.
	#
	if ( scalar @list > 0 ) {
		my $jid = $item;
		update_status('in progress',@list);

		# Save info about the job step.
		#
		$job{$jid}->{jid}           = $item;
		$job{$jid}->{start}         = time;
		$job{$jid}->{finish}        = 0;
		$job{$jid}->{time}          = 0;
		$job{$jid}->{bytesin}       = $bytes;
		$job{$jid}->{list}          = \@list;
		$job{$jid}->{count}         = $ct;
		$job{$jid}->{ident}         = $ident;
		$job{$jid}->{lastheartbeat} = time;
		$job{$jid}->{length}				= 0;
		$item++;

		return $job{$jid};
	}
	else {
		return undef;
	}
}

sub ondeck {
	push @{$ondeck}, @_
}
sub get_job_inputs {
	my $jstep = shift;
	return get_input_data( @{ $job{$jstep}->{list} } );
}

sub isajob {
	my $jstep = shift;

	if ( defined $job{$jstep} ) {
		return 1;
	}
	else {
		return 0;
	}
}

sub remaining_jobs {
	my $c = 0;
	foreach my $jid ( keys %job ) {
		next if $job{$jid}->{finish} > 0;
		$c++;
	}

	#	print stderr "Remaining jobs: $c\n";
	return $c;
}

# Look for old inflight messages.
# Move to retry queue
#
sub check_timeouts {
	DEBUG("Entered check_timeouts");
	if ( time > $next_status ) {
		update_counters( \%job, 0 );
		$last_status = time;
		$next_status = time + $config->{FLUSHTIME};
	}
	delete_olddata();
	return unless ( time > $next_check );
	DEBUG("Checking for timed out jobs");
	foreach my $jstep ( keys %job ) {
		next if $job{$jstep}->{finish};
		my $retry = 0;

		$retry = 1
			if ( time > ( $job{$jstep}->{lastheartbeat} + $config->{heartbeatto} ) );
		$retry = 1 if ( time > ( $job{$jstep}->{start} + $config->{TIMEOUT} ) );
		if ($retry) {
			WARN("RETRY: $jstep timed out or missed heartbeat.  Adding to retry.");
			requeue_job($jstep);
			increment_timeouts();
		}
	}
	$next_check = time + $config->{POLLTIME} / 2;
}

# Take inputs for job step
# and put back on the queue.
#
sub requeue_job {
	my $jstep = shift;
	DEBUG("Requeue $jstep");
	unshift @{$ondeck}, retry_inputs( @{ $job{$jstep}->{list} } );
	delete $job{$jstep};
}

sub update_job_stats {
	my $jstep = shift;
	my @stats;
	#TODO Use stats as key value pair to record interesting stuff

	if ( defined $job{$jstep} ) {
		$job{$jstep}->{lastheartbeat} = time;
		return $job{$jstep}->{lastheartbeat};
	}
	return 0;
}

sub delete_olddata {
	my $ct;
	foreach my $jid ( keys %job ) {
		die "Bad id $jid" if (! defined $job{$jid}->{finish});
		next unless $job{$jid}->{finish} > 0;
		delete $job{$jid} if $job{$jid}->{finish} < $last_status;
		$ct++;
	}
	return $ct;
}

sub finalize_jobs {
	flush_output();

	#Let's do this somewhere else.  May in CPR.
	#NERSC::TaskFarmer::Reader::check_inputs( @{$ondeck} );

	update_counters( \%job, 0 );
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
