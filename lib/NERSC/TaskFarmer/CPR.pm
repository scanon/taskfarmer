package NERSC::TaskFarmer::CPR;

use 5.010000;
use strict;
use warnings;
require threads;
require threads::shared;
use NERSC::TaskFarmer::Reader;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use NERSC::TaskFarmer::CPR ':all';
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
	read_fastrecovery
	write_fastrecovery
	check_recovery_age
);

our $VERSION = '0.01';
our $lock : shared;

#
# Check that the fast recovery file isn't too new
# This would indicate that another server may still
# be running .
#
sub check_recovery_age {
	my $config = shift;
	my @stat   = stat( $config->{FR_FILE} );
	return 1 if !defined $stat[9];

	my $age = time() - $stat[9];
	if ( $age < $config->{FLUSHTIME} ) {
		return 0;
	}
	return 1;
}

#
# Read fast recovery file
# Figure out where we were in the input stream.
# Requeue any outstanding work.
#
sub read_fastrecovery {
	my $filename = shift;
	my $offset   = 0;
	my @q        = ();
	my $index;
	return unless ( -e $filename );

	#        print STDERR "Recoverying using $filename\n";
	my $fr = new IO::File($filename) or die "Unable to open $filename\n";

	# Read the max index and offset
	#
	$_ = <$fr>;
	die "Bad fast recovery file" if !defined $_;
	$_ =~ s/.*max: //;
	( $index, $offset ) = split;
	my @offsets = <$fr>;
	foreach my $o (@offsets) {

		die "Invalid offset: $o is larger than $offset\n" if ( $o > $offset );
		push @q, NERSC::TaskFarmer::Reader::read_input( 1, $o );
	}
	setpos( $index, $offset );

#        printf LOG "Recovered %d inputs from $filename\n", scalar @{$state->{ondeck}};
	return @q;
}

# Write the fastrecovery file.
# The first line is the index number and the offset into the
#   query file.
# This is followed by a list of inputs that were in process
# This list must include retries, pending jobs, and ondeck.
# The last is needed because the file pointer has already moved past
#   the ondeck list of inputs.
#
sub write_fastrecovery {
	my $filename = shift;
	lock($lock);
	return 0 unless defined $filename;
	open( FR, "> $filename.new" );

	my ( $index, $offset ) = getpos();
	printf FR "# max: %ld %ld\n", $index, $offset;
	my $ct = 0;
	foreach my $offset ( pending_inputs() ) {
		printf FR "%d\n", $offset;
		$ct++;
	}
	close FR;

	# Try to safely move the file in place.
	#
	unlink $filename;
	link $filename . ".new", $filename or die "Unable to move $filename.new\n";
	unlink $filename . ".new";
	return $ct;
}

1;
__END__

=head1 NAME

NERSC::TaskFarmer::CPR - Perl extension for NERSC TaskFarmer

=head1 SYNOPSIS

  use NERSC::TaskFarmer::CPR;


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
