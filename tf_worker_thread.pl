#!/usr/bin/perl
#
# This is the standard run script that is executed on the compute node for each thread.
# It fetches sequences from a server, runs the app, and pushes back results
#
# Author: Shane Canon
#
# TODO Improve error handling when writing to the socket
#
use IO::Handle;
use IO::File;
use IO::Socket::INET;
use POSIX qw(:sys_wait_h);
use strict;
my $DEBUG=0;

die "Missing arguments\n" if ( @ARGV <3 );

# Get the SERVER PORT and THREAD
#
my $SERVER=$ARGV[0];
my $PORT=$ARGV[1];
my $THREAD=$ARGV[2];

#
# This is to spread things out a bit.
sleep $THREAD;

# Default TIMEOUT, RETRIES, SLEEP
my $TIMEOUT=45;
my $MAX_RETRIES=10;
my $SLEEP=20;
my $heartbeattime=300;
my $polltime=0.5;
my $TESTING=1 if (defined $ENV{TF_TESTING});

# This is our work area
#
die "TF_TMPDIR not defined\n" if (! defined $ENV{TF_TMPDIR});
die "TF_TMPDIR doesn't exist\n" if (! -e $ENV{TF_TMPDIR});

my $TMPDIR="$ENV{TF_TMPDIR}/$THREAD";
my $IGNORE_RETURN=1 if defined $ENV{IGNORE_RETURN};

$polltime=$ENV{TF_POLLTIME} if defined $ENV{TF_POLLTIME};
$heartbeattime=$ENV{TF_HEARTBEAT} if defined $ENV{TF_HEARTBEAT};

# Get our ID
my $ID="unknown";
$ID=$ENV{ID} if defined $ENV{ID};
my $input;

mkdir $TMPDIR;
chdir $TMPDIR or die "Unable to change to $TMPDIR";
$ENV{TMPDIR}=$TMPDIR;


my @args=read_args($SERVER,$PORT);
if (scalar @args eq 0 ){
  print STDERR "$ID: Connection error to $SERVER($PORT)\nFailed to get args\n";
  exit -1;
}
# The app is the first argument
#
my $app=shift @args;

my $step=-1;
my $status=0;
while ( ($step=send_and_get($SERVER,$PORT,$step,$status)) >= 0 ){
# Run the users code
  $ENV{STEP}=$step;
  $status=run_application($SERVER,$PORT,$step,$app,$input,@args);
}
if ($step eq -1){
  print STDERR "$ID: Connection Error to $SERVER($PORT)\n";
}
elsif ($step eq -2){
  print STDERR "$ID: All done: shutting down on thread $THREAD\n";
}
else{
  print STDERR "$ID: Unknown error: ($step)\n";
}

# Cat all of the files in the work directory
# Prepend the filename in the message stream
#
sub catfiles {
  my $sock=shift;
  opendir(DIR, ".") or die "cann't opendir: $!";
  my @files = readdir(DIR);
  closedir DIR;
  my $nfiles=scalar @files-2;
  print $sock "FILES $nfiles\n";
  foreach my $file (@files){
    next if ($file eq "." || $file eq "..");
    next if (defined $ENV{GETFILES} && ! $file=~/$ENV{GETFILES}/ );
    next unless (-f $file);
    my @s=stat $file;
    my $size=$s[7];
    $size++ if induce_errors("size");
    next if induce_errors("skip");
    return if induce_errors("drop");
    print $sock "FILE $file $size\n";
    open(F,"$file");
    while(<F>){
      print $sock $_;
    }
    close F;
    print $sock "DONE\n";
    unlink "$TMPDIR/$file";
  }
# Cleanup any files in the work directory
#
  foreach (@files){
    unlink $_ if ($_ ne "." && $_ ne "..");
  }
}

sub induce_errors{
	my $type=shift;
	
	return 0 unless (defined $TESTING);
	return 1 if ($type eq 'skip' && -e "skipfile");
	return 1 if ($type eq 'drop' && -e "drop");
	return 1 if ($type eq 'size' && -e "testreaderror");
    return 0;
}
# Read the args from the server
#
sub read_args {
  my $server=shift;
  my $port=shift;
  my @args;

  my $sock=connect_server($server,$port);
  return if ! $sock; 
  if ($sock){
    print $sock "ARGS\n";
    while(<$sock>){
      chomp;
      last if /DONE/;
      push @args, $_;
    }
    close $sock;
    return @args;
  }
   
}

# Connect to the server
# Retry a few times before giving up.
#
sub connect_server {
  my $server=shift;
  my $port=shift;
  my $retry=0;
  my $sock;

  while ($retry<$MAX_RETRIES){  
    $sock = IO::Socket::INET->new(PeerAddr => $server, PeerPort => $port,
	Timeout => 45,
	Proto    => 'tcp');
    return $sock if defined $sock;
    sleep rand($retry*$SLEEP);
    $retry++;
    print STDERR "$ID: Retrying connection to $server on $port ($retry)\n" if ($retry<$MAX_RETRIES);
  }
  return $sock
}

# This is the main function to push new output and
# fetch the next chunk of work.
#
sub send_and_get {
  my $server=shift;
  my $port=shift;
  my $step=shift;
  my $status=shift;
  my $error=0;

  $error=1 if ($status && ! $IGNORE_RETURN);

  my $sock=connect_server($server,$port);
  return -1 unless $sock;
  printf $sock "IDENT %s\n",$ID;
  if ($step>=0){
    if ($error){
      print STDERR "$ID: ERROR: step $step exited with $status\n";
      print STDERR `cat stderr`;
      save_errors("$ENV{DEBUGDIR}/step.$step") if (defined $ENV{DEBUGDIR});
      opendir(DIR, ".") or die "cann't opendir: $!";
      map {unlink "$TMPDIR/$_" if ($_ ne '.' && $_ ne '..');} readdir(DIR);
      closedir DIR;
      print $sock "ERROR $step\n";
    }
    else{
      print $sock "RESULTS $step\n";
      catfiles($sock);
      print $sock "DONE\n";
    }
    $_=<$sock>;
    $error=1 unless /RECEIVED/;
  }
  print $sock "NEXT\n";
  my $step=<$sock>;
  chomp $step;
  if ($step=~/STEP/){
    $step=~s/STEP: //;
    print STDERR "$ID: Got Step: $step\n" if $DEBUG;
    return -2 if ($step eq '');  # All done
    $input="";
    while(<$sock>){
      $input.=$_;
    }
  }
  else{
    print stderr "$ID: Got Shutdown ($step)\n";
    $step=-2;
  }
  close $sock;
  return $step;
}

sub heartbeat{
	my $server=shift;
	my $port=shift;
	my $step=shift;
	
  	my $sock=connect_server($server,$port);
  	return -1 unless $sock;
  	printf $sock "IDENT %s\n",$ID;
  	
  	print $sock "HEARTBEAT $step ".get_stats()."\n";
}

sub get_stats{
	return "status=running";
}

sub save_errors{
  my $ddir=shift;
  
  mkdir $ddir;
  print STDERR "Saving listings\n";
  print STDERR `ls -l > $ddir/listing.workingdir`;
  print STDERR `ls -l ../ $ddir/listing.parent`;
  print STDERR "Saving input\n";
  print STDERR `echo "$input" > $ddir/input`;
  print STDERR "Moving files\n";
  print STDERR `mv * $ddir/`;
  print STDERR "Killing thread.  No more for this guy.\n";
  die "ERROR";
}

# Run the application
# Redirect stdout and stderrr to files so they can
# be pushed back.
# 
sub run_application{
	my $server=shift;
	my $port=shift;
	my $step=shift;
  my $app=shift;
  my $input=shift;
  my $exit;
  my $pid;

  my $pid=fork();
  if ($pid>0){
  	my $lasthb=0;
  	while (waitpid($pid,WNOHANG)==0){
  		if (time>($lasthb+$heartbeattime)){
  			heartbeat($server,$port,$step);
  			$lasthb=time;
  		}
  		select(undef, undef, undef, $polltime);
  	}
  	$exit=$?>>8;
  }
  else{
#  open my $oldout, ">&STDOUT" or die "Can't dup STDOUT: $!";
    open my $olderr, ">&STDERR" or die "Can't dup STDERR: $!";
	open STDOUT, '>', "stdout" or die "Can't redirect STDOUT: $!";
  	open STDERR, '>', "stderr" or die "Can't redirect STDERR: $!";
  	select STDOUT; $| = 1;
  	select STDERR; $| = 1;
	  my $st=open(APP,"|-",$app,@_);
	  if (!$st){
    	print $olderr "Error: not able to execute or find $app ($st)\n";
    	die;
  	  }
# Print the input to the application
  	print APP $input;
  	close APP;
  	exit($? >> 8);
  }
# Restore stdout and stderr
#
#  open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";
#  open STDERR, ">&", $olderr or die "Can't dup \$olderr: $!";
#  close $oldout;
#  close $olderr;
  return $exit;
}
