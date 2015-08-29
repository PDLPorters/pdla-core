use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config;

my $package = [ qw(SD.pd SD PDLA::IO::HDF::SD) ];
our ($hdf_include_path, $hdf_lib_path, $hdf_libs, $szip);

undef &MY::postamble; # suppress warning
*MY::postamble = sub { pdlpp_postamble_int($package); };

WriteMakefile(
    NAME => 'PDLA::IO::HDF::SD',
    TYPEMAPS => [ &PDLA_TYPEMAP() ], 
    OBJECT => 'SD.o ',
    PM => { 
        'SD.pm' => '$(INST_LIBDIR)/SD.pm',
    },
    INC => &PDLA_INCLUDE() . " -I$hdf_include_path", 
    LIBS => [ "-L$hdf_lib_path $hdf_libs -ljpeg -lz $szip" ],
    clean => {
        FILES => 'SD.pm SD.xs SD.o SD.c',
    },
    dist => { 
        COMPRESS => 'gzip', 
        SUFFIX => 'gz'
    }, 
    (eval ($ExtUtils::MakeMaker::VERSION) >= 6.57_02 ? ('NO_MYMETA' => 1) : ()),
);
