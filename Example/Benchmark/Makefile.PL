use strict;
use warnings;

use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'	=> 'PDLA::Bench',
    'VERSION_FROM' => '../../lib/PDLA/Version.pm', # finds $VERSION
    'LIBS'	=> [''],   # e.g., '-lm'
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING'
    'INC'	=> '',     # e.g., '-I/usr/include/other'
);
