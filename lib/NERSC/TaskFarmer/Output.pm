package NERSC::TaskFarmer::Output;

use 5.010000;
use strict;
use warnings;

require Exporter;
use Getopt::Long;
use NERSC::TaskFarmer::Log;
use NERSC::TaskFarmer::Reader;
use NERSC::TaskFarmer::CPR;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
	'all' => [
		qw(

			)
	]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	init_output
	flush_check
	flush_output
	buffer_output
	close_all
	);

our $VERSION = '0.01';

our %output;
our $next_flush;
our $config;
our @buffered;

sub init_output {
	$config   = shift;
	@buffered = ();

	$next_flush = time + $config->{FLUSHTIME};
}

sub close_all {
	foreach my $file ( keys %output ) {
		$output{$file}->{handle}->close()
			if defined $output{$file}->{handle};
	}
}

# Flush output, progress, and create fast_recovery file
# This tries to keep everything in a consistent state.
#
sub flush_check {
	flush_output();
	$next_flush = time + $config->{FLUSHTIME};
}

sub buffer_output {
	my $list = shift;
	my $scratchbuffer = shift;

	DEBUG("Buffer output called");
	push @buffered,@{$list};
	update_status( 'buffered', @{$list } );
	foreach my $file ( keys %{$scratchbuffer} ) {
		DEBUG("Copying $file to buffer");
		$output{$file}->{buffer} .= $scratchbuffer->{$file};
	}

}

sub flush_output {

	#|| $buffer_size > $config->{MAXBUFF} );

	DEBUG("Flush called");
	foreach my $file ( keys %output ) {
		my $bf = $output{$file}->{buffer};
		if ( !defined $output{$file}->{handle} ) {
			DEBUG("Opening new file $file");
			if ( $file eq "stdout" ) {
				$output{$file}->{handle} = *STDOUT;
			}
			elsif ( $file eq "stderr" ) {
				$output{$file}->{handle} = *STDERR;
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

	update_status( 'completed', @buffered );
	@buffered = ();

	my $ct = write_fastrecovery( $config->{FR_FILE});
	DEBUG("Wrote fast recovery ($ct items)");
	DEBUG("Next flush in $config->{FLUSHTIME} seconds");
}

1;
__END__

=head1 NAME

NERSC::TaskFarmer::Output - Perl extension for NERSC TaskFarmer

=head1 SYNOPSIS

  use NERSC::TaskFarmer::Output;


=head1 DESCRIPTION

This is a set of helper function to do configuration for the NERSC TaskFarmer.

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
