package NERSC::TaskFarmer::Reader;

# TODO Move all input access into Reader

use 5.010000;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use NERSC::TaskFarmer::Reader ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = (
	'all' => [
		qw(
			read_input
			)
	]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	init_read
	read_input
	check_inputs
	get_inputs
	update_status
	getpos
	setpos
	endoffile
);

our $VERSION = '0.01';
our $index   = 0;
our $inputf;
our $size;
our $config;
our $input;

sub init_read {
	$config = shift;
	$input = shift;
	my $file   = $config->{INPUT};
	$inputf = new IO::File $file
		or die "Unable to open input file ($file)\n";
	my @stati = stat $inputf;
	$size = $stati[7];

}

# Preloaded methods go here.
#
#
# Read in $read number of inputs from $in.
# If $read is 0 then read until the eof.
# Store input and return list.
#
sub read_input {
	my $nread  = shift;
	my $offset = shift;
	my $ct     = 0;
	my $l      = 0;
	my $id;
	my @list;

	die "File not initialized yet!" if ( !defined $inputf );
	return @list                    if eof($inputf);

	if ( defined $offset ) {
		seek $inputf, $offset, 0
			or die "Unable to seek to input file location $offset\n";
	}

	while (<$inputf>) {
		die "Bad start: $_" if ( $l eq 0 && !/^>/ );
		if (/^>/) {
			$ct++;
			last if ( $nread && $ct > $nread );
			$id = tell($inputf) - length($_);
			$index++;
			my ( $bl, $header, $rest ) = split /[> \r\n]/;
			$input->{$id}->{header} = $header;
			$input->{$id}->{input}  = $_;
			$input->{$id}->{retry}  = 0;
			$input->{$id}->{offset} = $id;
			$input->{$id}->{index}  = $index;
			$input->{$id}->{status} = 'ondeck';
			push @list, $id;
		}
		else {
			$input->{$id}->{input} .= $_;
		}
		$l++;
	}
	if ( defined $_ ) {
		my $length = length $_;
		seek $inputf, -$length, 1 or die "Unable to step back: $length";
	}
	return @list;
}

sub check_inputs {

	foreach my $inputid (@_) {
		print STDERR "Bad inputid: $inputid\n"
			if ( !defined $inputid || $inputid eq '^$' );
		die "Bad input in retry $inputid\n\n$input->{$inputid}->{input}\n"
			unless $input->{$inputid}->{input} =~ /^>/;
	}
}

sub get_inputs {
	my $buffer;
	foreach my $inputid (@_) {
		$buffer .= $input->{$inputid}->{input};
	}
	return $buffer;
}

sub update_status {
	my $state=shift;
	map { $input->{$_}->{status} = $state } @_;
	return @_;
}

sub cleanup_oldinputs {

	foreach my $id ( sort keys %{$input} ) {
		delete $input->{$id} if $input->{$id} && $input->{$id}->{status} eq 'completed';
	}
}

sub getpos {
	return ( $index, tell($inputf) );
}

sub setpos {
	$index = shift;
	my $offset = shift;

	seek $inputf, $offset, 0 or die "Unable to seek to input file location\n";
}

sub getsize {
	return $size;
}

sub endoffile {
	return 1 if ( !defined $inputf );
	return eof($inputf);
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

NERSC::TaskFarmer::Reader - Perl extension for NERSC TaskFarmer

=head1 SYNOPSIS

  use NERSC::TaskFarmer::Reader;


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
