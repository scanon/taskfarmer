package NERSC::TaskFarmer::Log;

use 5.010000;
use strict;
use warnings;

use IO::File;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use NERSC::TaskFarmer::Log ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	setlog
	setloglevel
	closelog
	DEBUG
	INFO
	WARN
	ERROR
);

our $VERSION = '0.01';

our $log=\*STDERR;
our $debuglevel=0;
our $start = time;

sub setlog {
        my $fname = shift;
        $log = new IO::File ">> $fname" or die "Unable to open log file ($fname)\n";
        $log->autoflush(1);
        $debuglevel=shift;
}

sub closelog {
	close($log) if defined $log;
}

sub setloglevel {
        $debuglevel=shift;
}

sub debuglevel {
        return $debuglevel;
}

sub DEBUG {
        LOG( "DEBUG", shift ) if $debuglevel > 3;
}

sub INFO {
        LOG( "INFO", shift ) if $debuglevel > 2;
}

sub WARN {
        LOG( "WARN", shift ) if $debuglevel > 1;

}

sub ERROR {
        LOG( "ERROR", shift ) if $debuglevel > 0;
}

sub LOG {
        my $level   = shift;
        my $message = shift;
        printf {$log} "%5d %s: %s\n",time-$start,$level, $message;
}

1;
__END__

=head1 NAME

NERSC::TaskFarmer::Log - Perl extension for NERSC TaskFarmer

=head1 SYNOPSIS

  use NERSC::TaskFarmer::Log;


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
