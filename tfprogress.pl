#!/usr/bin/env perl

$fr=$ARGV[0];
$file=$fr;
$file=~s/fastrecovery.//;

if ( ! defined $fr ){
  print stderr "Usage: $0 <taskfarmer input file>\n";
  exit;
}

@s=stat $file;
$size=@s[7];

open(R,"$fr");
$_=<R>;
s/.*://;
chomp;
($index,$off)=split;

while(<R>){
  $ct++;
}
printf "%d%% done reading.  %d items remaining\n",100*$off/$size,$ct;

if ( ($ct==0) && $size==$off){
  print "Done!\n";
  exit;
}
else{
  print "Not Done.\n";
  exit -1;
}


