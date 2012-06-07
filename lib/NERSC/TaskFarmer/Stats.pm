package NERSC::TaskFarmer::Stats;

use 5.010000;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use NERSC::TaskFarmer::Stats ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	initialize_counters
	update_counters
	write_stats
	increment_errors
	increment_timeouts
);

our $VERSION = '0.01';
our $counters;
our $statusfile;
our $inputs;
our $ondeck;
our $config;

sub initialize_counters {
	$config = shift;
	$inputs  = shift;
	$ondeck = shift;
	
	my $size = shift;
	my $statusfile=$config->{STATUSFILE};
	
	for my $field qw( bytes_in bytes_out timeouts errors ) {
		$counters->{$field} = 0;
	}
	$counters->{quantum} = $config->{WINDOWTIME};
	$counters->{size}   = NERSC::TaskFarmer::Reader::getsize();
  $counters->{start_time} = time;
  $counters->{last_update} = 0;
}

sub increment_errors{
	$counters->{errors}++;
}

sub increment_timeouts{
	$counters->{timeout}++;	
}

sub update_counters {
	my $jobs = shift;
	my $bytesin = shift;
	my $output;
	my $tss = time - $counters->{start_time};

	$counters->{bytesin} = $bytesin;
	$counters->{ondeck}  = scalar @{$ondeck};

	# Initialize epochs
	my $epoch = int( $tss / ( $counters->{quantum} ) );
	if ( !defined $counters->{h_bytesin}->{$epoch} ) {
		$counters->{h_bytesin}->{$epoch}  = 0;
		$counters->{h_bytesout}->{$epoch} = 0;
		$counters->{h_count}->{$epoch}    = 0;
	}

	foreach my $jid ( keys %{$jobs} ) {
		my $job = $jobs->{$jid};
		if ( $job->{finish} > $counters->{last_update} ) {

			# time series counters
			my $epoch =
				int( ( $job->{finish} - $counters->{start_time} ) / ( $counters->{quantum} ) );
			$counters->{h_bytesin}->{$epoch}  += $job->{bytesin};
			$counters->{h_bytesout}->{$epoch} += $job->{bytesout};
			$counters->{h_count}->{$epoch}    += $job->{count};

			# total counters
			$counters->{bytesout} += $job->{bytesout};
			$counters->{count}    += $job->{count};
		}
	}
	$counters->{last_update} = time;

	my $inflight = 0;
	foreach my $id ( sort keys %{$inputs} ) {
		my $in = $inputs->{$id};
		$inflight++ if $in->{status} eq 'in progress';
	}
	$counters->{inflight} = $inflight;

		write_stats( $jobs )
			if defined $statusfile;
}

sub write_stats {
	my $jobs=shift;
	my $output;

	$output = open( CF, "> $statusfile.new" );
	return unless $output;
	print CF "{\"jobs\":[\n" if $output;
	my $ct = 0;
	foreach my $jid ( sort { $a <=> $b } keys %{$jobs} ) {
		print CF ",\n" if $ct;
		$ct++;
		my $job = $jobs->{$jid};
		printf CF
"{\"id\":%d,\"start\":%d,\"finish\":%d,\"bytesin\":%d,\"bytesout\":%d,\"ident\":\"%s\"}",
			$jid, $job->{start}, $job->{finish}, $job->{bytesin}, $job->{bytesout},
			$job->{ident};
	}
	print CF "],\n";

	print CF "\"inflight\":[\n";
	$ct = 0;
	foreach my $id ( sort { $a <=> $b } keys %{$inputs} ) {
		my $in = $inputs->{$id};
		next unless $inputs->{status} eq 'in progress';
		print CF ",\n" if $ct;
		$ct++;
		printf CF "{\"id\":\"%s\",\"header\":\"%s\",\"status\":\"%s\"}", $id,
			$in->{header}, $in->{status}
			if $output;
	}
	print CF "],\n";
	print CF "\"counters\":{";
	$ct = 0;
	foreach ( sort keys %{$counters} ) {
		print CF ",\n" if $ct;
		$ct++;
		if ( !ref( $counters->{$_} ) ) {
			printf CF "\"%s\":%d", $_, $counters->{$_};
		}
		elsif ( UNIVERSAL::isa( $counters->{$_}, 'HASH' ) ) {
			printf CF "\"$_\":[";
			my $ct = 0;
			for my $key ( sort { $a <=> $b } keys %{ $counters->{$_} } ) {
				print CF "," if $ct;
				$ct++;
				printf CF "[%d,%d]", $key, $counters->{$_}->{$key};
			}
			print CF "]";
		}
	}
	print CF "}\n}\n";
	close CF;

	# Move the file into place
	unlink $statusfile;
	link $statusfile . ".new", $statusfile or die "Unable to move $statusfile.new\n";
	unlink $statusfile . ".new";
	chmod 0664, $statusfile;

}



1;
__END__

=head1 NAME

NERSC::TaskFarmer::Stats - Perl extension for NERSC TaskFarmer

=head1 SYNOPSIS

  use NERSC::TaskFarmer::Stats;


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
