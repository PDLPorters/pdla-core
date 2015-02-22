use strict;
use warnings;
use ExtUtils::MakeMaker;

system("copy default.perldlrc default.pdl") if $^O =~ /win32/i;

WriteMakefile(
    'NAME'	=> 'PDL',
    'VERSION_FROM' => '../lib/PDL/Version.pm',
    NO_MYMETA => 1,
);
