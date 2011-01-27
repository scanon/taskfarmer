#!/usr/bin/perl

# Temporary directory for run info
#
my $TF_DIR="$HOME/.task-farmer.$(hostname).$PBS_JOBID";
my $SOCKFILE="$TF_DIR/sockfile";
my $PIDFILE="$TF_DIR/tfserver.pid";

$SIG{INT} = \&cleanup;  # best strategy

read_config();

# Create the TF directory
#
if ( ! -e "$TF_DIR" ){
  mkdir $TF_DIR;
}
else{
  if ( -e $PIDFILE ){
#    echo "Server may already be running." 1>&2 && exit
  } 
  else {
    unlink $SOCKFILE if ( -e $SOCKFILED );
    unlink $PIDFILE;
  }
}


# Get the address for the server
#
if ( -z $TF_ADDR  &&  -z $TF_PORT ){
  $TF_ADDR=`/sbin/ifconfig $INT|grep 'inet addr'|awk -F: '{print $2}'|sed 's/ .*//'`;

# Start the server and record the PID
#
  $exe=$0;
  $exe=~s/.*\///;
  if ( $exe == "tfrun" ){
    `$TF_HOME/libexec/taskfarmer/tf_server "$@" &`;
  }
  else{
    $exe=~s/tf$//;
    $APP=`which $exe`;
# 2>/dev/null) || (print "Unable to find $base")
    exit if ( ! -e $APP );
    print "Will run $APP";
    $line="$TF_HOME/libexec/taskfarmer/tf_server $APP";
    $line.=join @ARGV," ";
    $line.=" &";
    `$line`;
  }
  $PID=$!;
  open(P,"> $PIDFILE");
  print P "$PID\n";
  close P;
#
# Wait for the socket file to exist.
#
  while ( ! -e $SOCKFILE ){
    sleep 1;
  }
  open(S,"$SOCKFILE");
  $TF_PORT=<S>;
  chomp $TF_PORT;
  close S;
}
else{
  print "Server defined.  Will contact $TF_ADDR:$TF_PORT";
  $ENV{EXTERNAL_SERVER}=1;
  if ( -z $ENV{USE_RELAY} ){
    $ENV{USE_RELAY}=2;
    print "Starting relay";
    start_relay();
  }
}

if ( -z $SERVER_ONLY ){
# Launch the clients
#
  run_one();
# Get exit status for aprun
#
  $STATUS=$?;
  if ( $ENV{USE_RELAY} eq 2 ){
    print "Stoping relay";
    stop_relay();
  }
}
else{
  print STDERR "Starting in server only mode.";
  print STDERR "Cut and paste...";
  print STDERR "TF_ADDR=$TF_ADDR TF_PORT=$TF_PORT tfrun";

  waitpid $PID,0;
  $ENV{STATUS}=$?;
}

# Kill the server (just in case)
kill_server();
exit $STATUS;

sub kill_server {
#if ( -z $ENV{EXTERNAL_SERVER} ){
#  [ -e $PIDFILE ] && kill $(cat $PIDFILE) > /dev/null 2>&1
#  [ -e $PIDFILE ] && unlink $PIDFILE
#  [ -e $SOCKFILE ] && unlink $SOCKFILE
#}
}

sub cleanup {
  print STDERR "Shutting down";
  if ( -e "$PIDFILE" ){
    $pid=`cat $PIDFILE`;
    kill $pid;
    unlink $PIDFILE
  }
  unlink $SOCKFILE if ( -e $SOCKFILE );
  rmdir $TF_DIR if ( -d $TF_DIR );
  if ( $ENV{USE_RELAY} eq 2 ){
    print "Stoping relay";
    stop_relay();
  }
  exit $STATUS;
}


sub read_config{
  # Source the configuration file
  if (! defined $ENV{TF_HOME}){
    my $base=$0;
    $base=~s/\/[^\/]*$//;
    $base=~s/bin//;
    $TF_HOME=$base;
    $ENV{TF_HOME}=$TF_HOME;
  }
  if ( -z $ENV{TF_CONFDIR} ){
    $TF_CONFDIR="$TF_HOME/share/taskfarmer";
    $ENV{TF_CONFDIR};
  }
  if ( -e "$ENV{TF_CONFDIR}/$ENV{NERSC_HOST}.conf" ){
#    . "$ENV{TF_CONFDIR}/$ENV{NERSC_HOST}.conf";
  }
  else{
    print "The Task Farmer is not currently supported on this system.";
    exit;
  }
}


sub start_relay{
}

sub stop_relay{
}
