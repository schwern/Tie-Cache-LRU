use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Tie::Cache::InMemory::LastUse',
    'VERSION_FROM' => 'LastUse.pm', # finds $VERSION
);
