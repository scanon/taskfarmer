#!/bin/sh

if [ $# -ne 1 ] ; then
  echo "Usage: ./fix_perl_paths.pl </path/to/global/perl>"
  exit
fi
PERL=$1
echo "Perl interpreter will be replaced with $PERL for all perl scripts in the current tree."
echo "Cancel now if this is not what you want."
echo "Waiting 5 seconds"
sleep 5

for f in $(find . -type f|grep -v .svn|xargs file|grep -i perl|awk -F: '{print $1}')
do
	if [ $(head -1 $f|grep -v project/projectdirs|egrep -c '^#!/.*perl' $f) -gt 0 ] ; then
		echo "Will fix $f"
		perl -pi -e "s|#!.*perl|#!$PERL|;" $f
  	fi
done
