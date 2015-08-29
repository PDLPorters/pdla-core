use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config;

our ($hdf_include_path, $hdf_lib_path, $hdf_libs, $szip);

my $package = [ qw(VS.pd VS PDLA::IO::HDF::VS) ];

undef &MY::postamble; # suppress warning
*MY::postamble = sub { pdlpp_postamble_int($package); };

WriteMakefile(
    NAME => 'PDLA::IO::HDF::VS',
    TYPEMAPS => [ &PDLA_TYPEMAP() ],
    OBJECT => 'VS.o',
    PM => {
        'VS.pm' => '$(INST_LIBDIR)/VS.pm',
    },
    INC => &PDLA_INCLUDE() . " -I$hdf_include_path",
    LIBS => [ "-L$hdf_lib_path $hdf_libs -ljpeg -lz $szip" ],
    clean => {
        FILES => 'VS.pm VS.xs VS.o VS.c',
    },
    dist => { 
        COMPRESS => 'gzip', 
        SUFFIX => 'gz', 
    },
    (eval ($ExtUtils::MakeMaker::VERSION) >= 6.57_02 ? ('NO_MYMETA' => 1) : ()),
);
