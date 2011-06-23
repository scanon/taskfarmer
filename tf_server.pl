#!/usr/bin/env perl

# TODO

use Socket;
use IO::Handle;
use IO::File;
use IO::Socket::INET;
use strict;
use Getopt::Long;

my $input;

# Parameters
#
my $BATCHSIZE      = 32;
my $batchbytes     = 0;
my $TIMEOUT        = 1800;
my $TIMEOUT_SOCKET = 10;
my $MAXRETRY       = 8;
my $MAXBUFF        = 100 * 1024 * 1024;    # 100M buffer
my $FLUSHTIME      = 20;                   # write
my $WINDOWTIME     = 60 * 10;              # 10 minutes
my $FR_FILE;
my $port;
my $sockfile;
my $pidfile;
my $debuglevel=1;

# Override defaults
$BATCHSIZE      = $ENV{BATCHSIZE}      if defined $ENV{BATCHSIZE};
$batchbytes     = $ENV{BATCHSIZE}      if defined $ENV{BATCHSIZE};
$TIMEOUT        = $ENV{SERVER_TIMEOUT} if defined $ENV{SERVER_TIMEOUT};
$TIMEOUT_SOCKET = $ENV{SOCKET_TIMEOUT} if defined $ENV{SOCKET_TIMEOUT};
$port           = $ENV{PORT}           if defined $ENV{PORT};
$sockfile       = $ENV{SOCKFILE}       if defined $ENV{SOCKFILE};
my $statusfile = $ENV{STATUSFILE};

Getopt::Long::Configure("pass_through");
my $result = GetOptions( "i=s"             => \$input );
my $result = GetOptions( "tfbatchsize=i"   => \$BATCHSIZE );
my $result = GetOptions( "tfbatchbytes=i"  => \$batchbytes );
my $result = GetOptions( "tftimeout=i"     => \$TIMEOUT );
my $result = GetOptions( "tfsocktimeout=i" => \$TIMEOUT_SOCKET );
my $result = GetOptions( "tfstatusfile=s"  => \$statusfile );
my $result = GetOptions( "tfpidfile=s"     => \$pidfile );
my $result = GetOptions( "tfdebuglevel=i"  => \$debuglevel );

die "No input file specified\n" unless defined $input;

my $inputfile = $input;
$inputfile =~ s/.*\///;
$FR_FILE = "fastrecovery." . $inputfile;
my $done_file = "done." . $inputfile;

#  Global vars
#
my $progress_buffer = '';
my %input;
my %output;
my %scratchbuffer;
my %job;
my @ondeck;
my @failed;
my $item;
my $offset;
my $index;
my $next_flush  = time + $FLUSHTIME;
my $next_status = time + $FLUSHTIME;
my $next_check  = time + $TIMEOUT;
my $processed   = 0;
my $buffer_size = 0;
my $chunksize   = 2 * $BATCHSIZE;
my $shutdown    = 0;

my $inputf = new IO::File $input or die "Unable to open input file ($input)\n";

fast_recovery($FR_FILE);

# make the socket
my %sockargs = (
	Proto   => 'tcp',
	Timeout => $TIMEOUT_SOCKET,
	Listen  => 1000,
	Reuse   => 1
);

$sockargs{LocalPort} = $port if defined $port;

my $sock = new IO::Socket::INET->new(%sockargs)
  or die "Unable to create socket\n";

if ( defined $sockfile ) {
	open( SF, "> $sockfile" ) or die "Unable to open socket file\n";
	print SF $sock->sockport() . "\n";
	close SF;
}

if ( defined $pidfile ) {
	open( PF, "> $pidfile" ) or die "Unable to open pid file\n";
	print PF $$ . "\n";
	close PF;
}

my $item             = 0;
my $remaining_jobs   = 1;
my $remaining_inputs = 1;
my $ident;
my $command;
my $counters;

initialize_counters( $counters, $WINDOWTIME );
my @stati = stat $inputf;
$counters->{size}       = $stati[7];
$counters->{quantum}    = $WINDOWTIME;
$counters->{start_time} = time;

open( PROGRESS, ">> ./progress.$inputfile" );
open( LOG,      ">> ./log.$inputfile" );
select LOG;
$| = 1;
select STDOUT;
$SIG{INT} = \&catch_int;    # best strategy

# This is the main work loop.
while ( $remaining_jobs || $remaining_inputs ) {
	my $new_sock = $sock->accept();
	if ( defined $new_sock ) {
		my $clientaddr = $new_sock->peerhost();
		my $status     = do_request($new_sock);

		close $new_sock;
	}
	check_timeouts() if ( time > $next_check );
	flush_output() if ( time > $next_flush || $buffer_size > $MAXBUFF );
	if ( time > $next_status ) {
		update_counters( $counters, \%job, \%input, \@ondeck );
		write_stats( $counters, \%job, \%input, \@ondeck, $statusfile )
		  if defined $statusfile;
		delete_olddata( \%job, \%input );
		$next_status = time + $FLUSHTIME;
	}

	$remaining_inputs = ( scalar @ondeck );
	if ( eof($inputf) || $shutdown ) {
		$shutdown       = 1;    # In case eof got us here.
		$remaining_jobs =
		  remaining_jobs( \%job );    # How much pending stuff is there?
		INFO("Draining: $remaining_jobs remaining connections.");
		INFO("Draining: $remaining_inputs remaining inputs");
	}
}
update_counters( $counters, \%job, \%input, \@ondeck );
write_stats( $counters, \%job, \%input, \@ondeck, $statusfile )
  if defined $statusfile;

check_inputs(@ondeck);

INFO("Doing final flush");
flush_output();
close_all();
LOG("DONE","All done");
if (defined $done_file && scalar(@failed)==0){
	open(DONE,">$done_file");
	print DONE "done";
	close DONE;
}
close PRROGRESS;
close LOG;

# Interrupt handler
#
sub catch_int {
	my $signame = shift;
	print stderr "Caught signal $signame ($shutdown)\n";
	sleep 10 if $shutdown eq 2;
	if ($shutdown) {
		flush_output();
		close_all();
		ERROR("Exiting");
		close PRROGRESS;
		close PROGRESS;
		close LOG;
		exit;
	}
	else {
		$shutdown = 2;
		flush_output();
		$remaining_jobs = remaining_jobs( \%job );
		ERROR("Shutting down on signal $signame");
		ERROR("Draining: $remaining_jobs remaining connections");
		$shutdown = 1;
	}
}

sub close_all{
	foreach my $file ( keys %output ) {
		$output{$file}->{handle}->close()
			 if defined $output{$file}->{handle};
	}
}

sub do_request {
	my $sock       = shift;
	my $clientaddr = $sock->peerhost();

	#  print "Connect from $clientaddr\n";

	my $got_response = 0;
	my $status       = 0;
	$ident = "noid";

	# Read from client.  Process requests and reponse.
	#
	while (<$sock>) {
		DEBUG("COMMAND: $_");
		# print $_;
		if (/^RESULTS /) {
			my ( $command, $jstep ) = split;
			chomp $jstep;
			my $expected = defined $job{$jstep};
			my $bytes    = 0;
			my $success  = 1;
			my $nfiles;
			map {delete $scratchbuffer{$_}} keys %scratchbuffer;
			while (<$sock>) {
				if (/^FILES /) {
					( $command, $nfiles ) = split;
					DEBUG("Number of files: $nfiles for $jstep");
				}
				last if /^DONE$/;
				my $readbytes = read_file( $sock, $_, $expected ) if /^FILE /;
				if ( $readbytes < 0 ) {
					ERROR("Truncated read in Job step $jstep");
					$success = 0;
				}
				else {
					$bytes += $readbytes;
				}
			}
			if ($nfiles!=scalar(keys %scratchbuffer)){
				my $nfilesr=scalar keys %scratchbuffer;
				ERROR("Missing files ($nfiles vs $nfilesr) for $jstep");
				$success=0;
			}
			if ( $success && defined $job{$jstep} ) {
				$job{$jstep}->{bytesout} = $bytes;
				print $sock "RECEIVED $jstep\n";
				my $status = process_results($jstep);
			}
			elsif ( !$success && defined $job{$jstep} ) {
				ERROR("Job step $jstep");
				print $sock "RECEIVED $jstep\n";
				$counters->{errors}++;
				requeue_job($jstep);
			}
			else {
				ERROR(
				  "Unexpected report from $clientaddr:$ident for $jstep");
				print $sock "RECEIVED $jstep\n";
				$status = 0;
			}
		}    #
		elsif (/^IDENT /) {
			( $command, $ident ) = split;
		}
		elsif (/^NEXT$/) {
			if ( $shutdown && !$remaining_inputs ) {
				print $sock "SHUTDOWN\n";
			}
			send_work($sock);
			last;
		}
		elsif (/^ARGS$/) {
			foreach my $a (@ARGV) {
				print $sock "$a\n";
			}
			print $sock "DONE\n";
		}
		elsif (/^MESSAGE /) {
			chomp;
			s/MESSAGE //;
			print stderr "MESSAGE: $_\n";
		}
		elsif (/^STATUS/) {
			if ($shutdown) {
				print $sock "SHUTDOWN";
			}
			else {
				print $sock "READY";
			}
		}
		elsif (/^ERROR /) {
			my ( $command, $jstep ) = split;
			ERROR("Job step $jstep");
			print $sock "RECEIVED $jstep\n";
			$counters->{errors}++;
			requeue_job($jstep);
		}
		else {
			print stderr "Recieved unusual response from $clientaddr: $_";
		}
	}

	return $status;
}

# Read file output from client
#
sub read_file {
	my $sock = shift;
	$_ = shift;	my $write = shift;

	my $clientaddr = $sock->peerhost();
	my $bytes      = 0;
	my ( $command, $file, $size ) = split;
	$scratchbuffer{$file}="";
	DEBUG("Reading $file size $size");
	while (<$sock>) {
		last if /^DONE$/;
#		next unless $write;    # should we write out stderr?

		#		if ( $file eq "stdout" ) {
		#			$
		#			print stdout $_;
		#		}
		#		elsif ( $file eq "stderr" ) {
		#			print stderr $_;
		#		}
		#		else {
		$scratchbuffer{$file} .= $_;

		#		}
		$bytes += length $_;
	}
	if ( $bytes == $size ) {
		return $bytes;
	}
	else {
		return -1;
	}
}

# Process results from client.
# Add line to progress buffer.
# Cleanup data structures.
# (This doesn't actually spool the output)
#
sub process_results {
	my $jstep = shift;

	return 0 unless defined( $job{$jstep} );

# Copy data from scratch buffer
#
	foreach my $file (keys %scratchbuffer){
		DEBUG("Copying $file to buffer");
		if ( $file eq "stdout" ) {
			print stdout $scratchbuffer{$file};
		}
		elsif ( $file eq "stderr" ) {
			print stderr $scratchbuffer{$file};
		}
		else {
			$output{$file}->{buffer}=$scratchbuffer{$file};
		}
	}
	my $inputs = join ",", @{ $job{$jstep}->{list} };
	my $rtime = time - $job{$jstep}->{start};
	$job{$jstep}->{time}   = $rtime;
	$job{$jstep}->{finish} = time;
	$job{$jstep}->{ident}  = $ident;
	$progress_buffer .= sprintf "%s %s %d %d %d %d\n", $inputs, $ident, $rtime,
	  $job{$jstep}->{lines}, time, $job{$jstep}->{bytesin};
	INFO(
	  sprintf "Recv: %d input:%25s hostid:%-10s  time:%-4ds lines: %-6d proc: %d",
	  $jstep, substr( $inputs, 0, 25 ), $ident, $rtime, $job{$jstep}->{lines},
	  $processed);

	foreach my $inputid ( @{ $job{$jstep}->{list} } ) {
		$input{$inputid}->{status} = 'completed';
	}
	$processed += $job{$jstep}->{count};

	#    delete $job{$jstep};
	return 1;
}

sub send_work {
	my $new_sock = shift;

	my $sent = [];
	my $length;
	my $ct   = 0;
	my @list = build_list( $BATCHSIZE, $batchbytes );

	# Send the list if there is one.
	#
	if ( scalar @list > 0 ) {
		print $new_sock "STEP: $item\n";
		foreach my $inputid (@list) {
			print $new_sock $input{$inputid}->{input};
			$input{$inputid}->{status} = 'in progress';
			push @{$sent}, $inputid;
			$length += length $input{$inputid}->{input};
			$ct++;
		}

		# Save info about the job step.
		#
		$job{$item}->{start}   = time;
		$job{$item}->{finish}  = 0;
		$job{$item}->{time}    = 0;
		$job{$item}->{bytesin} = $length;
		$job{$item}->{list}    = $sent;
		$job{$item}->{count}   = $ct;
		$job{$item}->{ident}   = $ident;
		INFO("Sent: $item hostid:$ident length:$length");
		$item++;
	}
	else {

		# If no work then send a shutdown
		print $new_sock "SHUTDOWN";
	}
}

# Flush output, progress, and create fast_recovery file
# This tries to keep everything in a consistent state.
#
sub flush_output {
	foreach my $file ( keys %output ) {
		next if ( $file eq 'stdout' || $file eq 'stderr' );
		if ( !defined $output{$file}->{handle} ) {
			INFO("Opening new file $file");
			$output{$file}->{handle} = new IO::File ">> $file";
			die "Unable to open file $file\n"
			  if !defined $output{$file}->{handle};
		}
		my $handle = $output{$file}->{handle};
		INFO(sprintf "Flushed %ld bytes to %s", length $output{$file}->{buffer},
		  $file) if (length $output{$file}->{buffer}>0);
		print {$handle} $output{$file}->{buffer};
		$handle->flush();
		$output{$file}->{buffer} = '';
	}
	flush LOG;
	print PROGRESS $progress_buffer;
	flush PROGRESS;
	$progress_buffer = '';
	$buffer_size     = 0;

	my $ct = write_fastrecovery($FR_FILE);
	printf LOG "Wrote fast recovery (%d items)\n", $ct;
	$next_flush = time + $FLUSHTIME;
}

#
# This builds up a work list of args inputs.
# It will read in more input if there isn't enough ondeck.
#
sub build_list {
	my $batchsize  = shift;
	my $batchbytes = shift;
	my @list;
	my @tlist;
	my $ct    = 0;
	my $bytes = 0;

	# Build rest from ondeck
	#
	if ( scalar @ondeck < ( $batchsize - $ct ) ) {
		@tlist = read_input( $inputf, $chunksize );
		$index += scalar @tlist;
		push @ondeck, @tlist;
	}
	while ( $ct < $batchsize && scalar @ondeck > 0 ) {
		my $id = shift @ondeck;
		push @list, $id;
		$bytes += length( $input{$id}->{input} );
		$ct++;
		last if ( $batchbytes > 0 && $bytes > $batchbytes );
	}
	return @list;
}

sub remaining_jobs {
	my $j = shift;
	my $c = 0;
	foreach my $jid ( keys %{$j} ) {
		next if $j->{$jid}->{finish};
		$c++;
	}
	print stderr "Remaining jobs: $c\n";
	return $c;
}

# Look for old inflight messages.
# Move to retry queue
#
sub check_timeouts {
	my $time = time - $TIMEOUT;
	foreach my $jstep ( keys %job ) {
		next if $job{$jstep}->{finish};
		if ( $job{$jstep}->{start} < $time ) {
			WARN("RETRY: $jstep timed out.  Adding to retry.");
			requeue_job($jstep);
			$counters->{timeouts}++;
		}
	}
	$next_check = time + $TIMEOUT / 2;
}

# Take inputs for job step
# and put back on the queue.
#
sub requeue_job {
	my $jstep = shift;

	foreach my $inputid ( @{ $job{$jstep}->{list} } ) {
		$input{$inputid}->{retry}++;
		DEBUG(sprintf "Retrying %s for %d time", $inputid,
		  $input{$inputid}->{retry});
		if ( $input{$inputid}->{retry} < $MAXRETRY ) {
			unshift @ondeck, $inputid;
			$input{$inputid}->{status} = 'retry';
		}
		else {
			ERROR("$inputid hit max retries");
			push @failed, $inputid;
		}
	}
	delete $job{$jstep};
}

#
# Read in $read number of inputs from $in.
# If $read is 0 then read until the eof.
# Store input and return list.
#
sub read_input {
	my $in   = shift;
	my $read = shift;
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
			$input{$id}->{header} = $header;
			$input{$id}->{input}  = $_;
			$input{$id}->{retry}  = 0;
			$input{$id}->{offset} = $id;
			$input{$id}->{index}  = $index;
			$input{$id}->{status} = 'ondeck';
			push @list, $id;
		}
		else {
			$input{$id}->{input} .= $_;
		}
		$l++;
	}
	my $length = length $_;
	seek $in, -$length, 1 or die "Unable to step back: $length";

	return @list;
}

#
# Read fast recovery file
# Figure out where we were in the input stream.
# Requeue any outstanding work.
#
sub fast_recovery {
	my $filename = shift;
	return unless ( -e $filename );
	print STDERR "Recoverying using $filename\n";
	my $fr = new IO::File($filename) or die "Unable to open $filename\n";

	# Read the max index and offset
	#
	$_ = <$fr>;
	$_ =~ s/.*max: //;
	( $index, $offset ) = split;
	my @offsets = <$fr>;
	foreach (@offsets) {
		seek $inputf, $_, 0 or die "Unable to seek to input file location $_\n";
		die "Invalid offset: $_ is larger than $offset\n" if ( $_ > $offset );
		push @ondeck, read_input( $inputf, 1 );
	}
	seek $inputf, $offset, 0 or die "Unable to seek to input file location\n";
	printf LOG "Recovered %d inputs from $filename\n", scalar @ondeck;
}

sub check_inputs {
	foreach my $inputid (@_) {
		print stderr "Bad inputid: $inputid\n"
		  if ( !defined $inputid || $inputid eq '^$' );
		die "Bad input in retry $inputid\n\n$input{$inputid}->{input}\n"
		  unless $input{$inputid}->{input} =~ /^>/;
	}
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
	my $offset;
	my @recoverylist;

	open( FR, "> $filename.new" );

	#  $offset=tell($inputf)-length($input{$next_header}->{input});
	$offset = tell($inputf);
	$offset = tell($inputf) if ( eof($inputf) );
	printf FR "# max: %ld %ld\n", $index, $offset;
	my $inputid;
	my $ct = 0;

	# Add failed jobs to the recovery list

	push @recoverylist, @failed;

	# What's in progress
	foreach my $jstep ( keys %job ) {
		next if $job{$jstep}->{finish};
		foreach $inputid ( @{ $job{$jstep}->{list} } ) {
			push @recoverylist, $inputid;
		}
	}
	push @recoverylist, @ondeck;

	check_inputs(@recoverylist);
	foreach my $inputid (@recoverylist) {

		#    print FR $input{$inputid}->{input};
		printf FR "%d\n", $input{$inputid}->{offset};
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

sub initialize_counters {
	my $c    = shift;
	my $q    = shift;
	my @list = ( 'bytes_in', 'bytes_out', 'timeouts', 'errors' );
	for my $field (@list) {
		$c->{$field} = 0;
	}
	$c->{quantum} = $q;

}

sub update_counters {
	my $c  = shift;
	my $j  = shift;
	my $i  = shift;
	my $od = shift;
	my $output;
	my $tss = time - $c->{start_time};

	$c->{bytesin} = tell $inputf;
	$c->{ondeck}  = scalar @{$od};

	# Initialize epochs
	my $epoch = int( $tss / ( $c->{quantum} ) );
	if ( !defined $c->{h_bytesin}->{$epoch} ) {
		$c->{h_bytesin}->{$epoch}  = 0;
		$c->{h_bytesout}->{$epoch} = 0;
		$c->{h_count}->{$epoch}    = 0;
	}

	foreach my $jid ( keys %{$j} ) {
		my $job = $j->{$jid};
		if ( $job->{finish} > $c->{last_update} ) {

			# time series counters
			my $epoch =
			  int( ( $job->{finish} - $c->{start_time} ) / ( $c->{quantum} ) );
			$c->{h_bytesin}->{$epoch}  += $job->{bytesin};
			$c->{h_bytesout}->{$epoch} += $job->{bytesout};
			$c->{h_count}->{$epoch}    += $job->{count};

			# total counters
			$c->{bytesout} += $job->{bytesout};
			$c->{count}    += $job->{count};
		}
	}
	$c->{last_update} = time;

	my $inflight = 0;
	foreach my $id ( sort keys %{$i} ) {
		my $in = $i->{$id};
		$inflight++ if $i->{$id}->{status} eq 'in progress';
	}
	$c->{inflight} = $inflight;

}

sub write_stats {
	my $c  = shift;
	my $j  = shift;
	my $i  = shift;
	my $od = shift;
	my $cf = shift;
	my $output;
	my $data;

	$output = open( CF, "> $cf.new" );
	$data->{counters} = $c;
	$data->{jobs}     = $j;
	$data->{input}    = $i;
	$data->{ondeck}   = $od;
	return unless $output;
	print CF "{\"jobs\":[\n" if $output;
	my $ct = 0;
	foreach my $jid ( sort { $a <=> $b } keys %{$j} ) {
		print CF ",\n" if $ct;
		$ct++;
		my $job = $j->{$jid};
		printf CF
"{\"id\":%d,\"start\":%d,\"finish\":%d,\"bytesin\":%d,\"bytesout\":%d,\"ident\":\"%s\"}",
		  $jid, $job->{start}, $job->{finish}, $job->{bytesin},
		  $job->{bytesout}, $job->{ident};
	}
	print CF "],\n";

	print CF "\"inflight\":[\n";
	my $ct = 0;
	foreach my $id ( sort { $a <=> $b } keys %{$i} ) {
		my $in = $i->{$id};
		next unless $i->{status} eq 'in progress';
		print CF ",\n" if $ct;
		$ct++;
		printf CF "{\"id\":\"%s\",\"header\":\"%s\",\"status\":\"%s\"}", $id,
		  $in->{header}, $in->{status}
		  if $output;
	}
	print CF "],\n";
	print CF "\"counters\":{";
	my $ct = 0;
	foreach ( sort keys %{$c} ) {
		print CF ",\n" if $ct;
		$ct++;
		if ( !ref( $c->{$_} ) ) {
			printf CF "\"%s\":%d", $_, $c->{$_};
		}
		elsif ( UNIVERSAL::isa( $c->{$_}, 'HASH' ) ) {
			printf CF "\"$_\":[";
			my $ct = 0;
			for my $key ( sort { $a <=> $b } keys %{ $c->{$_} } ) {
				print CF "," if $ct;
				$ct++;
				printf CF "[%d,%d]", $key, $c->{$_}->{$key};
			}
			print CF "]";
		}
	}
	print CF "}\n}\n";
	close CF;

	# Move the file into place
	unlink $cf;
	link $cf . ".new", $cf or die "Unable to move $cf.new\n";
	unlink $cf . ".new";
	chmod 0664, $cf;

}

sub delete_olddata {
	my $j = shift;
	my $i = shift;
	foreach my $jid ( keys %{$j} ) {
		next unless $j->{$jid}->{finish} > 0;
		delete $j->{$jid} if $j->{$jid}->{finish} < time - 120;
	}
	foreach my $id ( sort keys %{$i} ) {
		delete $i->{$id} if $i->{$id} && $i->{$id}->{status} eq 'completed';
	}
}

sub DEBUG{
	LOG("DEBUG",shift) if $debuglevel>3;
}

sub INFO{
	LOG("INFO",shift) if $debuglevel>2;
}
sub WARN{
	LOG("WARN",shift) if $debuglevel>1;
	
}
sub ERROR{
	LOG("ERROR",shift) if $debuglevel>0;	
}

sub LOG{
	my $level=shift;
	my $message=shift;
	print LOG "$level: $message\n";
}

=pod

=head1 NAME

taskfarmer

=head1 SYNOPSIS

Usage:

 tfrun -i <input> <serial app> {arguements for app}

=head1 DESCRIPTION

 The Task Farmer framework makes it easy to run serial
applications in a parallel environment.  It was originally
designed to run bioinformatics applications, howevever it can
work for other applications too.

The B<tf> program (notice how tf bold) works on these items:

=over 4

=item * Files

Just file names in your directory tree. The file name could be a
regular file, socket, device or a link.

=item * Directories

Yes, it'll work on directories too.

=back

Ship it!

=head1 BUGS

Remember the note about features?

=head1 EXAMPLES

This is a header 1

=head2 LIMITATIONS AND CONSIDERATIONS

Avoid changing directories in your executuables or wrappers that are
executed by the task farmer client.  The file harvesting method used
in the taskfarmer assumes all of the files in the working directory
should be sent to the server.  Furthermore, they are removed after
sending.

This is header 2 in I<Italics>.

=head2  Another Header 2

This is header 2 in B<BOLD>.

Another list with non-bulleted items.

=over 5

=item First

This is the First item.

=item Second

This is the Second item.

=item Third

This is the Third item.

=back

=cut

