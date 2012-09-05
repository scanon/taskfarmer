package NERSC::TaskFarmer::Output;

# TODO Close files that aren't accessed for a while

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
	buffer_output
	finalize_output
);

our $VERSION = '0.01';

our %output : shared;
our $next_flush : shared;
our $config;
our @buffered : shared;       # list of inputs in buffered state
our $buffer_size : shared;    # number of bytes buffered
our %handles;
our $doorbell;
our $writerthread;

sub init_output {
	$config      = shift;
	@buffered    = ();
	$buffer_size = 0;

	$next_flush   = time + $config->{FLUSHTIME};
	$doorbell     = new Thread::Queue;
	$writerthread = threads->create( \&writer, $doorbell );
	return $writerthread;
}

sub finalize_output {
	if ( defined $writerthread ) {
		print "Sending shutdown\n";
		$doorbell->enqueue(undef);
		$writerthread->join();
		$writerthread = undef;
	}
}

sub writer {
	my $q = shift;
	while ( my $message = $q->dequeue ) {
		print "Message: $message\n";
		*STDOUT->flush();
		if ( !defined $message ) {
			print STDERR "Emptry message: shutting down\n";
			flush_output();
			close_all();
			return;
		}
		elsif ( time >= $next_flush || $buffer_size > $config->{MAXBUFF} ) {
			print "writer writing\n";
			flush_output();
			$next_flush = time + $config->{FLUSHTIME};
		}
	}
}

sub close_all {
	foreach my $file ( keys %output ) {
		$handles{$file}->close()
			if defined $handles{$file};
	}
}

sub buffer_output {
	my $list          = shift;
	my $scratchbuffer = shift;

	lock($buffer_size);
	DEBUG("Buffer output called");
	push @buffered, @{$list};
	update_status( 'buffered', @{$list} );
	foreach my $file ( keys %{$scratchbuffer} ) {
		DEBUG("Copying $file to buffer");
		$output{$file} .= $scratchbuffer->{$file};
		$buffer_size += length( $scratchbuffer->{$file} );
	}
	$doorbell->enqueue(1);
}

sub flush_output {
	DEBUG("Flush called");
	lock($buffer_size);
	foreach my $file ( keys %output ) {
		my $bf = $output{$file};
		if ( !defined $handles{$file} ) {
			DEBUG("Opening new file $file");
			if ( $file eq "stdout" ) {
				$handles{$file} = *STDOUT;
			}
			elsif ( $file eq "stderr" ) {
				$handles{$file} = *STDERR;
			}
			else {
				$handles{$file} = new IO::File ">> $file";
			}
		}
		my $handle = $handles{$file};
		if ( !defined $handle ) {
			ERROR("Unable to open file $file.  Exiting");
			exit -1;
		}
		my $blength = length $output{$file};
		if ( $blength > 0 ) {
#			$output{$file}->{lastwrite} = time;
			DEBUG("Flushed $blength bytes to $file");
			print {$handle} $output{$file};
			$handle->flush();
		}
		$output{$file} = '';
	}

	update_status( 'completed', @buffered );
	@buffered    = ();
	$buffer_size = 0;

	my $ct = write_fastrecovery( $config->{FR_FILE} );
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
