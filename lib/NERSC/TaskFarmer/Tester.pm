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
	cleanup_tests
	checklines
);

sub wc {
	if (-e "/usr/bin/wc"){
		return "/usr/bin/wc";
	}
	else{
		return "/bin/wc";
	}
}

sub checklines {
  my $tfile=shift;
  my $pfile=shift;
  my $plines;
  my $elines;
  open(P,$pfile) or return 0;
  while(<P>){
    my @e=split /,/,$_;
    $plines+=scalar @e;
  }
  open(I,$tfile);
  while(<I>){
  	$elines++ if /^>/;
  }
  print "p: $plines $elines\n";
  return ($plines eq $elines);
}

sub cleanup_tests {
	foreach $_ (
		"done.test.faa",         "progress.test.faa",
		"fastrecovery.test.faa", "log.test.faa",
		"test.args",             "test.out",
		"test.err"
		)
	{
		unlink $_;
	}
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
