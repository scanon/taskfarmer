package NERSC::TaskFarmer::Reader;

use strict;
use warnings;

require threads;
require threads::shared;
use NERSC::TaskFarmer::Log;

require Exporter;

our @ISA = qw(Exporter);

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
	remaining_inputs
	pending_inputs
	retry_inputs
	failed_inputs
	isainput
	inputlength
	get_inputs
	get_input_data
	update_status
	get_status
	getpos
	setpos
);

our $VERSION = '0.01';
our $index : shared;
our $inputf;
our $size;
our $config;
our %input : shared;
our $maxretry = 8;
our %counters : shared;
our $pos : shared = 0;

sub init_read {
	$config = shift;
	my $file = $config->{INPUT};
	$inputf = new IO::File $file
		or die "Unable to open input file ($file)\n";
	my @stati = stat $inputf;
	$size     = $stati[7];
	$maxretry = $config->{MAXRETRY};
	$index    = 0;
	foreach $_ ( 'ondeck', 'in progress', 'failed', 'buffered', 'completed',
		'retry' )
	{
		$counters{$_} = 0;
	}
}

#
#
# Read in $read number of inputs from $in.
# If $read is 0 then read until the eof.
# Store input and return list.
#
sub read_input {
	my $nread  = shift;
	my $offset = shift;
	my $thread = shift;
	my $ct     = 0;
	my $l      = 0;
	my $id;
	my @list;
	lock($pos);

#	print "Start: $pos\n";
	die "File not initialized yet!" if ( !defined $inputf );
	return @list if ( eof($inputf) || !defined $pos );

	if ( defined $offset ) {
		seek $inputf, $offset, 0
			or die "Unable to seek to input file location $offset\n";
	}
	else {
		seek $inputf, $pos, 0;
	}

	while (<$inputf>) {

		#		print $thread.": ".tell($inputf)."\n" if defined $thread;
		die "Bad start: $_" if ( $l eq 0 && !/^>/ );
		if (/^>/) {
			$ct++;
			last if ( $nread && $ct > $nread );
			$id = tell($inputf) - length($_);
			$index++;
			my ( $bl, $header, $rest ) = split /[> \r\n]/;
			my %in : shared;
			$in{header} = $header;
			$in{input}  = $_;
			$in{retry}  = 0;
			$in{offset} = $id;
			$in{index}  = $index;
			$in{status} = 'ondeck';
			$in{length} = length($_);
			$input{$id} = \%in;
			$counters{'ondeck'}++;

			push @list, $id;
		}
		else {
			$input{$id}->{input} .= $_;
			$input{$id}->{length} += length($_);
		}
		$l++;
	}
	if ( defined $_ ) {
		my $length = length $_;
		seek $inputf, -$length, 1 or die "Unable to step back: $length";
	}
	$pos = tell $inputf;

	#	print "Stop: $index\n";
	return @list;
}

sub check_inputs {

	foreach my $inputid (@_) {
		print STDERR "Bad inputid: $inputid\n"
			if ( !defined $inputid || $inputid eq '^$' );
		die "Bad input in retry $inputid\n\n$input{$inputid}->{input}\n"
			unless $input{$inputid}->{input} =~ /^>/;
	}
}

sub failed_inputs {
	return $counters{failed};
}

sub retry_inputs {
	my @list;

	foreach my $inputid (@_) {
		$input{$inputid}->{retry}++;
		DEBUG( sprintf "Retrying %s for %d time",
			$inputid, $input{$inputid}->{retry} );
		if ( $input{$inputid}->{retry} < $maxretry ) {
			push @list, $inputid;
			update_status( 'retry', $inputid );

			#			$input{$inputid}->{status} = 'retry';
		}
		else {
			ERROR("$inputid hit max retries");
			update_status( 'failed', $inputid );

			#			push @failed, $inputid;
		}
	}
	return @list;
}

sub pending_inputs {
	my @list;

	for my $inputid ( sort { $a <=> $b } keys %input ) {
		if ( $input{$inputid}->{status} ne 'completed' ) {
			push @list, $input{$inputid}->{offset};
		}
	}
	return @list;
}

sub remaining_inputs {

	return 1 if ( !eof($inputf) );

	#foreach (keys %{$input}){
	#	my $s=$input{$_}->{status};
	#		return 1 if ($s ne 'completed' && $s ne 'failed' && $s ne 'buffered');
	#}
	return 1 if ( $counters{ondeck} > 0 || $counters{retry} > 0 );
	return 0;
}

sub get_inputs {
	return \%input;
}

sub get_input_data {
	my $buffer;
	foreach my $inputid (@_) {
		$buffer .= $input{$inputid}->{input};
	}
	return $buffer;
}

sub isainput {
	my $id = shift;
	return defined $input{$id};
}

sub inputlength {
	my $id = shift;
	return undef if ( !defined $input{$id} );
	return $input{$id}->{length};
}

sub update_status {
	my $state = shift;
	foreach (@_) {
		my $oldstate = $input{$_}->{status};
		$counters{$oldstate}--;
		$counters{$state}--;
		$input{$_}->{status} = $state;
	}
	return @_;
}

sub get_status {
	my $id = shift;
	return undef if ( !defined $input{$id} );
	return $input{$id}->{status};
}

sub cleanup_oldinputs {

	foreach my $id ( sort keys %input ) {
		delete $input{$id}
			if $input{$id} && $input{$id}->{status} eq 'completed';
	}
}

sub getpos {
	return ( $index, $pos );
}

sub setpos {
	$index = shift;
	my $offset = shift;

	seek $inputf, $offset, 0 or die "Unable to seek to input file location\n";
}

sub getsize {
	return $size;
}

#sub endoffile {
#	return 1 if ( !defined $inputf );
#	return eof($inputf);
#}

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
