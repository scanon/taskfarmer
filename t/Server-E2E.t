#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NERSC-TaskFarmer.t'

#########################

# Client Piece
if (scalar (@ARGV) > 0 ){
	my $line;
  while(<STDIN>){
     $line++;
  }
  print "$line\n";
  open AO, "> $ENV{ARG_OUT}";
  foreach (@ARGV){
  	print AO "$_\n";
  }
  exit;
}


use Test::More tests => 2;

BEGIN { use_ok('NERSC::TaskFarmer::Tester') }

#########################

$ENV{NERSC_HOST}="test";

my $pwd=`pwd`;
chomp $pwd;

$ENV{ARG_OUT}="$pwd/test.args";

my $TFILE = "./testing/test.faa";

my $ME="$pwd/$0";

# Run server
print STDERR qx "./blib/script/tfrun --tfdebuglevel=3 --tfbatchsize=512 -i $TFILE $pwd/t/args.sh arg1 arg2 'a b' > test.out 2> test.err";

ok(-e "./test.args", "Args test");

#cleanup_tests();


