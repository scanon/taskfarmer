package NERSC::TaskFarmer::Config;

use 5.010000;
use strict;
use warnings;

require Exporter;
use Getopt::Long;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
	'all' => [
		qw(

			)
	]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	initialize_conf
);

our $VERSION = '0.01';

#
# Initialize parameters
#
sub initialize_conf {
	my $config = {
		BATCHSIZE       => 32,
		BATCHBYTES      => 0,
		TIMEOUT         => 1800,
		SOCKET_TIMEOUT  => 10,
		heartbeatto     => 600,
		MAXRETRY        => 8,
		MAXBUFF         => 100 * 1024 * 1024,    # 100M buffer
		FLUSHTIME       => 20,                   # write
		WINDOWTIME      => 60 * 10,              # 10 minutes
		POLLTIME        => 600,
		closetime       => 600,
		REQUEST_TIMEOUT => 10,
		debuglevel      => -1,
	};
	my $result;

	# Override defaults
	for my $param qw(BATCHSIZE BATCHBYTES SOCKET_TIMEOUT PORT SOCKFILE) {
		$config->{$param} = $ENV{$param} if defined $ENV{$param};
	}

	$config->{TIMEOUT} = $ENV{SERVER_TIMEOUT} if defined $ENV{SERVER_TIMEOUT};
	Getopt::Long::Configure("pass_through");
	$result = GetOptions( "i=s"             => \$config->{INPUT} );
	$result = GetOptions( "tfbatchsize=i"   => \$config->{BATCHSIZE} );
	$result = GetOptions( "tfbatchbytes=i"  => \$config->{BATCHBYTES} );
	$result = GetOptions( "tftimeout=i"     => \$config->{TIMEOUT} );
	$result = GetOptions( "tfsocktimeout=i" => \$config->{SOCKET_TIMEOUT} );
	$result = GetOptions( "tfsockfile=s"    => \$config->{SOCKFILE} );
	$result = GetOptions( "tfstatusfile=s"  => \$config->{STATUSFILE} );
	$result = GetOptions( "tfpidfile=s"     => \$config->{PIDFILE} );
	$result = GetOptions( "tfdebuglevel=i"  => \$config->{debuglevel} );
	$result = GetOptions( "tfheartbeat=i"   => \$config->{heartbeatto} );

	# Calculated values
	$config->{POLLTIME} = $config->{TIMEOUT};
	$config->{POLLTIME} = $config->{heartbeatto}
		if ( $config->{TIMEOUT} > $config->{heartbeatto} );
	if ( defined $config->{INPUT} ) {
		my $inputfile = $config->{INPUT};
		$inputfile =~ s/.*\///;
		$config->{FR_FILE}      = "fastrecovery." . $inputfile;
		$config->{DONEFILE}     = "done." . $inputfile;
		$config->{PROGRESSFILE} = "./progress." . $inputfile;
		$config->{LOGFILE}      = "./log." . $inputfile;
	}

	return $config;
}

1;
__END__

=head1 NAME

NERSC::TaskFarmer::Config - Perl extension for NERSC TaskFarmer

=head1 SYNOPSIS

  use NERSC::TaskFarmer::Config;


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
