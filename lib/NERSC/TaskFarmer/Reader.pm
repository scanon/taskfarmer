package NERSC::TaskFarmer::Reader;

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
our %EXPORT_TAGS = ( 'all' => [ qw(
	read_input
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	read_input
	check_inputs
);

our $VERSION = '0.01';


# Preloaded methods go here.
#
#
# Read in $read number of inputs from $in.
# If $read is 0 then read until the eof.
# Store input and return list.
#
sub read_input {
        my $in   = shift;
        my $read = shift;
        my $input = shift;
        my $index = shift;
        my $ct   = 0;
        my $l    = 0;
        my $id;
        my @list;

        return @list if eof($in);
        while (<$in>) {
                die "Bad start: $_" if ( $l eq 0 && !/^>/ );
                if (/^>/) {
                        $ct++;
                        last if ( $read && $ct > $read );
                        $id = ( tell($in) - length($_) );
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
        my $length = length $_;
        seek $in, -$length, 1 or die "Unable to step back: $length";

        return @list;
}

sub check_inputs {
        my $input = shift;

        foreach my $inputid (@_) {
                print STDERR "Bad inputid: $inputid\n"
                        if ( !defined $inputid || $inputid eq '^$' );
                die "Bad input in retry $inputid\n\n$input->{$inputid}->{input}\n"
                        unless $input->{$inputid}->{input} =~ /^>/;
        }
}

sub cleanup_oldinputs {
	my $i = shift;
	
	foreach my $id ( sort keys %{$i} ) {
		delete $i->{$id} if $i->{$id} && $i->{$id}->{status} eq 'completed';
	}
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
