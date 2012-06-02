use 5.010000;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    NAME              => 'NERSC::TaskFarmer',
    VERSION_FROM      => 'lib/NERSC/TaskFarmer.pm', # finds $VERSION
#    DIR		      => [ 'share' ],
    EXE_FILES	      => [ 'tfrun.sh', 'tf_server.pl', 'tf_worker', 'tf_worker_thread.pl' ],
#    NOECHO		=> '',
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/NERSC/TaskFarmer.pm', # retrieve abstract from module
       AUTHOR         => 'Shane Canon <scanon@lbl.gov>') : ()),
);


package MY; # so that "SUPER" works right

sub  post_constants {
  return << 'POST';
SHAREFILES=    share/*.conf share/submit_es.q share/stage.cacher
POST
}

# Need to override install to pick up the examples stuff.
#
sub install {
    my $inherited = shift->SUPER::install(@_);
    my $new = "";

    foreach (split /\n/,$inherited){
#        if (/doc_site_install ::/){
#          $_.=" examples_site_install";
#        }
       if (/write.*SITE/){
         $_.="\n";
         $_.="\t\tblib/share/taskfarmer/ \$(DISTDIR)/\$(SITEPREFIX)/share/taskfarmer/ \\";
       }
      $new.="$_\n";
    }
    return "$new";
}

sub  subdirs {
  return << 'SUB';
subdirs ::
	mkdir -p blib/share/taskfarmer
	$(CP) share/*.conf blib/share/taskfarmer
	$(CP) share/stage.cacher blib/share/taskfarmer
	$(CP) share/submit_es.q blib/share/taskfarmer
SUB
}
