# A template for Makefile.PL used by Arena Networks.
# - Set the $PACKAGE variable to the name of your module.
# - Set $LAST_API_CHANGE to reflect the last version you changed the API 
#   of your module.
# - Fill in your dependencies in PREREQ_PM
# Alternatively, you can say the hell with this and use h2xs.

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

$PACKAGE = 'Tie::Cache::LRU';
($PACKAGE_FILE) = $PACKAGE =~ /(?:\::)([^:]+)$/;
$LAST_API_CHANGE = '0.05';
$LAST_MAJOR_BUG  = '0.05';

eval {
    eval "require $PACKAGE";
};

unless ($@) { # Make sure we did find the module.
    print <<"CHANGE_WARN" if ${$PACKAGE.'::VERSION'} < $LAST_API_CHANGE;

NOTE: There have been API changes between this version and any older
than version $LAST_API_CHANGE!  Please read the Changes file if you
are upgrading from a version older than $LAST_API_CHANGE.

CHANGE_WARN

    print <<"BUG_WARN" if ${$PACKAGE.'::VERSION'} < $LAST_MAJOR_BUG;
Version $LAST_MAJOR_BUG contained a MAJOR BUG which has now been fixed.  
See the Changes file for details.
BUG_WARN
}

WriteMakefile(
    NAME                => $PACKAGE,
    VERSION_FROM        => "$PACKAGE_FILE.pm", # finds $VERSION
    PREREQ_PM           => { 
                            Carp::Assert    =>  0,
                            enum            =>  0,
                           },
    'dist'              => { COMPRESS   => 'gzip -9',
                             SUFFIX     => '.gz',
                             DIST_DEFAULT   => 'all tardist',
                           },
);
