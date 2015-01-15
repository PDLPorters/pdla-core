use strict;
use warnings;
eval { require Devel::CheckLib; Devel::CheckLib->import; };
use Config;
use ExtUtils::MakeMaker;

## $DB::single = 1;  # uncomment to have debugger stop here

my $badval_define = " -DBADVAL=$PDLA::Config{WITH_BADVAL} -DBADVAL_USENAN=$PDLA::Config{BADVAL_USENAN} -DBADVAL_PER_PDLA=$PDLA::Config{BADVAL_PER_PDLA}";

my $malloclib = $PDLA::Config{MALLOCDBG}->{libs};
my $mallocinc = $PDLA::Config{MALLOCDBG}->{include};

my (undef, $pthread_include, $pthread_library, $pthread_define) = figure_pthreads();

print "Trying to figure out endian-ness of machine...";
print " It is " . (PDLA::Core::Dev::isbigendian() ? "big" : "little") . " endian\n";

undef &MY::postamble; # suppress warning
*MY::postamble = sub {
    # nmake doesn't seem to do inference rules right so spell it out
    my $pdlsections_g = sprintf <<'EOF', PDLA::Core::Dev::genpp_cmdline(qw(pdlsections.g pdlsections.c));

pdlsections.c :: pdlsections.g ../../lib/PDLA/Types.pm
	%s
EOF
    my $text = PDLA::Core::Dev::postamble() . "

pdlbadvalinit.c:: pdlbadvalinit.c.PL ../../lib/PDLA/Types.pm\n"
. make_from_PL( 'pdlbadvalinit.c' )
."

pdldataswitch.c:: pdldataswitch.c.PL ../../lib/PDLA/Types.pm\n"
. make_from_PL( 'pdldataswitch.c' );
if($Config{make} =~ /\bdmake/i) {
  if($ExtUtils::MakeMaker::VERSION < 7) {
    return $text . $pdlsections_g;
  } else {
#EU-MM >= 7
    return $text;
  }
} else { return
$text.
"
# Bits of C code we generate from special perl scripts
#
# there must be a more elegant way of saying that
# certain files have additional dependencies!

pdlthread.c :: ../../lib/PDLA/Core/pdl.h ../../lib/PDLA/Core/pdlcore.h\n"
."

pdlhash.c :: ../../lib/PDLA/Core/pdl.h ../../lib/PDLA/Core/pdlcore.h\n"
."

pdlapi.c :: ../../lib/PDLA/Core/pdl.h ../../lib/PDLA/Core/pdlcore.h\n"
."

pdlmagic.c :: ../../lib/PDLA/Core/pdlcore.h\n"
."

pdlsections.c :: ../../lib/PDLA/Core/pdl.h ../../lib/PDLA/Core/pdlcore.h\n"
."

pdlconv.c:: pdlconv.c.PL ../../lib/PDLA/Types.pm\n"
. make_from_PL( 'pdlconv.c' )
."

pdlcore.c:: pdlcore.c.PL ../../lib/PDLA/Types.pm\n"
. make_from_PL( 'pdlcore.c' )
.
($^O =~ /MSWin/ ? $pdlsections_g : '');
}
};

my @cfiles = qw(pdlcore pdlapi pdlhash pdlthread pdlconv pdlmagic pdlsections);
my $cobj = join ' ', map qq{$_\$(OBJ_EXT)}, @cfiles;
WriteMakefile(
 'NAME'	        => 'PDLA::Core',
 'VERSION_FROM' => '../../lib/PDLA/Version.pm',
 'OBJECT'       => 'Core$(OBJ_EXT) ' . $cobj,
 'DEFINE' 	=> $pthread_define.$badval_define,
 'LIBS'         => ["$pthread_library $malloclib"],
 'clean'        => {'FILES'  => $cobj .
                   ' pdlconv.c pdlsections.c pdlcore.c '.
                   'pdldataswitch.c pdlbadvalinit.c '.
		   'Core.c '
		   },
 'INC'          => join(' ',
   PDLA_INCLUDE(), map {length($_) ? qq{"$_"} : ()} $pthread_include, $mallocinc
 ),
  depend => {
    'Core$(OBJ_EXT)' => '$(INST_ARCHLIB)$(DFSEP).exists pm_to_blib pdldataswitch.c pdlbadvalinit.c ../../lib/PDLA/Core/pdl.h ../../lib/PDLA/Core/pdlcore.h',
        # Core.xs needs blib/arch for -Mblib to work, as well as pm_to_blib
  },
 'NO_MYMETA' => 1,
);
