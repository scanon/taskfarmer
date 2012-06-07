package NERSC::TaskFarmer::Jobs;

#TODO Flush on buffer size

use 5.010000;
use strict;
use warnings;

require Exporter;

use NERSC::TaskFarmer::Log;
use NERSC::TaskFarmer::Reader;

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
	remaining_inputs
	remaining_jobs
	flushprogress
	check_timeouts
	requeue_job
	failed_jobs
	update_job_stats
	delete_olddata
	finalize_jobs
	);

our $VERSION = '0.01';
our %job;
our $input;
our $output;
our @failed;
our $ondeck;
our $buffered;
our $scratchbuffer;
our $processed = 0;
our $progress_buffer = "";
our $item = 0;
our $config;
our $next_check;
our $next_status;
our $pf;
our $chunksize;

sub initialize_jobs {
	$input    = shift;
	$config   = shift;
	$buffered = shift;
	$ondeck   = shift;
	$scratchbuffer = shift;
	$output = shift;

	$next_check  = time + $config->{POLLTIME};
	$next_status = time + $config->{FLUSHTIME};
	if ( defined $config->{PROGRESSFILE} ) {
		$pf = new IO::File ">> $config->{PROGRESSFILE}"
			or die "Unable to open progress file\n";
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

	return 0 unless defined( $job{$jstep} );
	$job{$jstep}->{bytesout} = $bytes;

	# Copy data from scratch buffer
	#
	foreach my $file ( keys %{$scratchbuffer} ) {
		DEBUG("Copying $file to buffer");
		$output->{$file}->{buffer} .= $scratchbuffer->{$file};
	}
	my $inputs = join ",", @{ $job{$jstep}->{list} };
	my $rtime = time - $job{$jstep}->{start};
	$job{$jstep}->{time}   = $rtime;
	$job{$jstep}->{finish} = time;
	$progress_buffer .= sprintf "%s %s %d %d %d %d\n", $inputs,
		$job{$jstep}->{ident}, $rtime, 0, time, $job{$jstep}->{bytesin};
	INFO(
		sprintf "Recv: %d input:%25s hostid:%-10s  time:%-4ds lines: %-6d proc: %d",
		$jstep,
		substr( $inputs, 0, 25 ),
		$job{$jstep}->{ident},
		$rtime,
		0,
		$processed
	);

  push @{$buffered},update_status('buffered',@{ $job{$jstep}->{list} });
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
#
sub build_list {
	my @list;
	my @tlist;
	my $ct    = 0;
	my $bytes = 0;

	# Build rest from ondeck
	#
	if ( scalar @{$ondeck} < ( $config->{BATCHSIZE} ) ) {
		@tlist = NERSC::TaskFarmer::Reader::read_input($chunksize);
		push @{$ondeck}, @tlist;
	}
	while ( $ct < $config->{BATCHSIZE} && scalar @{$ondeck} > 0 ) {
		my $id = shift @{$ondeck};
		push @list, $id;
		die "Bad Input ID $id\n" unless defined $input->{$id};
		$bytes += length( $input->{$id}->{input} );
		$ct++;
		last if ( $config->{BATCHBYTES} > 0 && $bytes > $config->{BATCHBYTES} );
	}
	return @list;
}

sub queue_job {
	my $ident = shift;

	my @list = build_list();
	my $sent = [];
	my $length = 0;
	my $ct = 0;

	# Send the list if there is one.
	#
	if ( scalar @list > 0 ) {
		my $jid = $item;
		foreach my $inputid (@list) {
			$input->{$inputid}->{status} = 'in progress';
			push @{$sent}, $inputid;
			die "Bad input $inputid" unless defined $input->{$inputid}->{input};
			$length += length $input->{$inputid}->{input};
			$ct++;
		}

		# Save info about the job step.
		#
		$job{$jid}->{jid}           = $item;
		$job{$jid}->{start}         = time;
		$job{$jid}->{finish}        = 0;
		$job{$jid}->{time}          = 0;
		$job{$jid}->{bytesin}       = $length;
		$job{$jid}->{list}          = $sent;
		$job{$jid}->{count}         = $ct;
		$job{$jid}->{ident}         = $ident;
		$job{$jid}->{lastheartbeat} = time;
		$item++;
		
		return $job{$jid};
	}
	else {
		return undef;
	}
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

sub remaining_inputs {
	return 1 if (! endoffile())	;
	foreach (keys %{$input}){
		my $s=$input->{$_}->{status};
		print "DEBUG: $_ $input->{$_}->{status}\n";
		return 1 if ($s ne 'completed' && $s ne 'failed' && $s ne 'buffered');
	}
	return 0;
}

sub remaining_jobs {
	my $j = shift;
	my $c = 0;
	foreach my $jid ( keys %{$j} ) {
		next if $j->{$jid}->{finish}>0;
		$c++;
	}

	#	print stderr "Remaining jobs: $c\n";
	return $c;
}

sub flushprogress {
	print $pf $progress_buffer;
	flush $pf;
	$progress_buffer = '';
}

# Look for old inflight messages.
# Move to retry queue
#
sub check_timeouts {
	DEBUG("Checking timeouts");
	if ( time > $next_status ) {
		#update_counters( \%job, $input, $ondeck );

		$next_status = time + $config->{FLUSHTIME};
	}

	delete_olddata();
	return unless ( time > $next_check );
	foreach my $jstep ( keys %job ) {
		next if $job{$jstep}->{finish};
		my $retry = 0;

		$retry = 1
			if ( time > ( $job{$jstep}->{lastheartbeat} + $config->{heartbeatto} ) );
		$retry = 1 if ( time > ( $job{$jstep}->{start} + $config->{TIMEOUT} ) );
		if ($retry) {
			WARN("RETRY: $jstep timed out or missed heartbeat.  Adding to retry.");
			requeue_job($jstep);
			increment_timeout();
		}
	}
	$next_check = time + $config->{POLLTIME} / 2;
}

# Take inputs for job step
# and put back on the queue.
#
sub requeue_job {
	my $jstep = shift;

	foreach my $inputid ( @{ $job{$jstep}->{list} } ) {		
		$input->{$inputid}->{retry}++;
		DEBUG( sprintf "Retrying %s for %d time",
			$inputid, $input->{$inputid}->{retry} );
		if ( $input->{$inputid}->{retry} < $config->{MAXRETRY} ) {
			unshift @{$ondeck}, $inputid;
			$input->{$inputid}->{status} = 'retry';
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
	#TODO Fix stats
	flushprogress();
	NERSC::TaskFarmer::Reader::check_inputs( @{$ondeck} );
	#NERSC::TaskFarmer::Stats::update_counters( \%job, $input, $ondeck, 0 );
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
