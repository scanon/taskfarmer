#!/usr/bin/env perl

use threads;
use threads::shared;
use strict;
use NERSC::TaskFarmer::Config;
use NERSC::TaskFarmer::Server;

my $config = initialize_conf();

die "No input file specified\n" unless defined $config->{INPUT};
NERSC::TaskFarmer::Server::Start( $config );


=pod

=head1 NAME

taskfarmer

=head1 SYNOPSIS

Usage:

 tfrun -i <input> <serial app> {arguements for app}

=head1 DESCRIPTION

The Task Farmer provides a framework that simplifies running serial
applications in a parallel environment.  It was originally
designed to run the BLAST bioinformatic program, howevever it can
easily be adapted to other applications too.  Using the task farmer
a user can easily launch a serial application in parallel.  The
framework will take care of disributing the tasks, collecting output,
and managing any failures.

=head2 FILE OUTPUT

The taskfarmer will automatically harvest any output generated by
the serial application in the local working directory.  Each tasks
thread runs in a temporary working directory.  After the serial
application exits, the taskfarmer client will scan the working directory
for any files and transmit those back to the server.  The transmitted
output will automatically be appended to a file of the same name in the
working directory of the running server.  All of the output is buffered
from the client in a serial fashion.  So output from each task will be
contingous and complete.  In other words, output cannot got interleaved
from multipole clients.  

If the client application changes working directories
or writes to a path outside the working directory, the output will not 
be captured by the taskfarmer.  In some circumstances this may be 
advantageous since the taskfarmer server can typically only sustain a few 100 MB/s
of bandwidth.  However, if the output harvesting is bypassed, the user
will need to insure that the output filenames are unique for each task.
The STEP environment variable can be used to insure that the filenames are
unique.  However, this can lead to a large number of files which may
create issues with file management and metadata performance.

=head2 LAUNCH MODES

=head3 Simple Mode

The simplest method to start the taskfarmer is to call tfrun
from inside a parallel job allocation (i.e. from the batch script).  The server
and clients will automatically be started.  If the job runs out of walltime 
before completion, the recovery files can be used to pick up where it left off.
The only caveats to this approach is that you must insure that multiple job
instances are not started for the same input since multiple servers would be
reading the file.

=head3 Server Mode

The server can be started in a stand-alone mode.  This can be useful if you wish
to submit multiple parallel jobs that work for a common server.  This may be desirable
to exploit backfill opportunites or run on multiple systems.  Set the environment
variable B<SERVER_ONLY> to 1 prior to running tfrun.  The server will startup and
print a contact string that can be used to launch the clients.  Optionally, you
can set B<TF_SERVERS> to have the server create or append the contact information
to a string.  If this variable is set prior to launching the clients, the clients
will automatically iterate through the servers listed in the file.

=head3 Client Mode

The clients can be also be launched separately.  This is useful if you are starting
clients in a serial queue, on remote resources, or running multiple parallel jobs.
Several environment variables can trigger this mode.  If B<TF_ADDR> and B<TF_PORT>
are defined then the server will not be started and the client will contact the
server listening at TF_ADDR on TF_PORT.  Alternatively, if B<TF_SERVERS> is defined
then the client will iterate through each server listed in the file.  TF_SERVERS
trumps TF_ADDR and TF_PORT.


=head1 OPTIONS

=over 8

=item B<--tfdebuglevel=i>

Adjust the debug level.  Higher means more output.  Level 1 is errors.  Level 2 is warnings.
Level 3 is information.  Level 4 is debug.  Default: 1

=item B<--tfbatchsize=i>

Adjust the number of input items that are sent to a client during each request.  The default is
B<16>.  In general, you should adjust the batchsize to maintain a processing rate of approximately
5 minutes per cycle.  Too little will lead to a high number of connections on the server.  Too few
will result in more loss if the application hits a walltime limit and in-flight tasks are lost.  Default 16.

=item B<--tfbatchbytes=i>

Similar to batchsize, but instead of processing a fixed number of items, a target size (in bytes) is
used.  The server will read in input items until the number of bytes exceeds batchsize.  This splitting
approach can be more consistent for some types of applications.  Default: disabled

=item B<--tftimeout=i>

Adjust the timeout to process one batch of inputs in seconds.  If the time is exceeeded, the task will be
requeued and sent out on susequent requests.  If the client responds with the results after the
timeout, the results will be discarded.  Default: 1800.

=item B<--tfsocktimeout=i>

Adjust the timeout for a socket connection in seconds.  Default: 45.

=item B<--tfsockfile=s>

Filename to write the port for the listening socket.  This can be used by the client to automatically
read the port.  Default: none
my $result = GetOptions( "tfstatusfile=s"  => \$config->{STATUSFILE} );
my $result = GetOptions( "tfpidfile=s"     => \$pidfile );
my $result = GetOptions( "tfheartbeat=i"   => \$heartbeatto );

=back

=head1 BUGS 

Missing BUGS documentation.

=head1 EXAMPLES

tfrun -i input blastall -d $DB -o blast.out

=head1 LIMITATIONS AND CONSIDERATIONS

Avoid changing directories in your executuables or wrappers that are
executed by the task farmer client.  The file harvesting method used
in the taskfarmer assumes all of the files in the working directory
should be sent to the server.  Furthermore, they are removed after
sending.

When running on some HPC systems, the /tmp space may have limited
capacity (< 1 GB).  If the output harvesting is being used, insure
that the output does not exceed this limit.


=cut

