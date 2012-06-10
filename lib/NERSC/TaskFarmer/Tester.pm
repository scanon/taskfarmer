package NERSC::TaskFarmer::Tester;

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
our %EXPORT_TAGS = (
	'all' => [
		qw(

			)
	]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	setup_test
	cleanup_tests
	checklines
	countlines
	difffiles
	countstring
	sendmess
);

sub setup_test {
	my $pwd = `pwd`;
	chomp $pwd;

	$ENV{TF_HOME}     = "$pwd/blib";
	$ENV{NERSC_HOST}  = "test";
	$ENV{TF_POLLTIME} = 0.00001;

}

sub countlines {
	my $pfile = shift;
	my $plines;
	open( P, $pfile ) or return 0;
	while (<P>) {
		$plines++;
	}
	close P;
	return $plines;
}

sub checklines {
	my $tfile  = shift;
	my $pfile  = shift;
	my $plines = 0;
	my $elines = 0;
	open( P, $pfile ) or return 0;
	while (<P>) {
		my @e = split /,/, $_;
		$plines += scalar @e;
	}
	open( I, $tfile );
	while (<I>) {
		$elines++ if /^>/;
	}
	close I;
	print "p: $plines $elines\n";
	return ( $plines eq $elines );
}

sub cleanup_tests {
	foreach $_ (
		"done.test.faa",          "progress.test.faa",
		"fastrecovery.test.faa",  "log.test.faa",
		"progress.test.faa","progress.test2.faa",
		"test.args",              "tf.pid",
		"test.out",               "test.err",
		"test2.err",              "test2.out",
		"fastrecovery.test2.faa", "log.test2.faa",
		"client.out",             "client.err",
		"client2.out",            "client2.err",
		)
	{
		unlink $_ if ( -e $_ );
	}
}

sub difffiles {
	my $f1 = shift;
	my $f2 = shift;
	open( F1, $f1 );
	open( F2, $f2 );
	while ( my $l1 = <F1> ) {
		my $l2 = <F2>;
		return 0 if $l1 ne $l2;
	}
	my $rem = <F2>;
	return 0 if defined $rem;
	return 1;

}

sub countstring {
	my $file   = shift;
	my $string = shift;
	my $ct;

	open( F, $file ) or die "Unable to open $file";
	while (<F>) {
		$ct++ if /$string/;
	}
	return $ct;
}

sub sendmess {
	my $server  = shift;
	my $port    = shift;
	my $message = shift;

	my $sock = IO::Socket::INET->new(
		PeerAddr => $server,
		PeerPort => $port,
		Proto    => 'tcp'
		)
		or die "Unable to open Socket";
	print $sock $message;
	close $sock;

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
