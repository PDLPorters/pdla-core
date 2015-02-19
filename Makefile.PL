use strict;
use warnings;

# using absolute path to make it valid also for Makefile.PL files in subdirectories
use Cwd;
use lib 'inc', Cwd::abs_path('lib'), Cwd::abs_path('inc');

use Devel::CheckLib;
use 5.010_000;
use ExtUtils::MakeMaker 7.05_11;  # for XSMULTI
use Config;
use File::Spec;
use Inline::Module;

$::PP_VERBOSE = $::PP_VERBOSE = 0; # =1 makes PP waffle a lot

# file globals(!)
my ($pdl_f77conf, $forcebuild);
my ($seen_pdlconf, $seen_f77conf);
my $pdl_conf_file = ''; # apparently for users to change

# build-system globals
our ($usenan, $bvalflag, $bvalPerPdl);

sub checkbuggysetup {
    # detect buggy Perl setups
    if (!$forcebuild &&
	$Config{osname} eq 'solaris' &&
	($Config{cc} =~ /gcc/ || $Config{gccversion} ne '') &&
	$Config{usemymalloc} eq 'y'
	) {
	die <<'EOM';

FATAL BUG IN YOUR PERL SETUP DETECTED. BUILD TERMINATED.

On this platform the combination of gcc and the Perl malloc
are buggy. The optimizations lead to random coredumps
and make PDL essentially unusable.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
WORKAROUND: YOU MUST RECOMPILE PERL WITH 'usemymalloc=n' !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

You may override and force the build by including the
'FORCE' switch:

  perl Makefile.PL FORCE

However, you will most likely end up with an unusable
PDL build unless *all* optimizations are disabled!
YOU HAVE BEEN WARNED!!

EOM
  }

    my($dot);
    for(@INC) {$dot += $_ eq '.'}
    $dot-- if($INC[-1] eq '.');
    if($dot) {
	$INC = join(":",@INC);
	warn << "EOM"

**********************************************************************
Your Perl \@INC path is:

$INC

That seems to include the directory '.' before the last entry in the
path.  Configurations like that might be broken, because they may
prevent strict division of hierarchy in the module name space.
In particular, adding a module Foo::Bar::Baz can cause trouble
if Baz exists in the top level elsewhere, and if you run from the
Foo/Bar directory.

This happens with the PDL::Config and some other modules.  You may
not be able to build PDL with this \@INC setup.

If you strike trouble, you may need to fix your \@INC.
**********************************************************************


EOM
unless $ENV{PDL_INC_OK};
}

}

# The user specifies configuration options using the PDL_CONFIG
# array in perldl.conf - or ~/.perldl.conf or via the PDLCONF command-line
# argument.
#
# We need to use this information during the 'perl Makefile.PL' process,
# and historically this has been done by directly accessing %PDL_CONFIG
# (or %::PDL_CONFIG) variable. However, there are times that this information
# is also needed during the actual build (ie 'make' cycle), at which point
# the variable is not available. However lib/PDL/Config.pm is available,
# but this uses the %PDL::Config variable to access the data.
#
# So, we try to avoid this dichotomy by creating a %PDL::Config during
# the 'perl Makefile.PL' stage and then making sure that PDL_CONFIG
# is destroyed (so it can't be used by accident).
#
# Do we need to worry about Makefile.PL's hacking PDL_CONFIG?
# Probably...
#
%PDL::Config = ();

sub getpdl_config {
  my ($pdl_conf_file) = @_;

  # First read in distribution config file
  #
  our %PDL_CONFIG;
  require './perldl.conf';

  # Add BAD_VAL tests if CPAN testers
  #
  if ($ENV{AUTOMATED_TESTING}) {
     # warn "Makefile.PL: Automated testing environment: enabling USE_POGL config option\n";
     # $PDL_CONFIG{USE_POGL} = 1;
  }

  # Save standard values
  #
  my %PDL_CONFIG_DIST = %PDL_CONFIG;

  # Now read in the users config file if specified
  # and convert y/n to 1/0
  #
  if (-f $pdl_conf_file) {
    warn "\nINFORMATION: using file $pdl_conf_file to set configuration defaults\n\n";
    require $pdl_conf_file;
  }

  # Sanity checking of user supplied keys (look for ones not defined in dist)

  for(keys %PDL_CONFIG) {
    if(!exists($PDL_CONFIG_DIST{$_})) {
      die << "EOD";
Invalid key $_ found in user supplied $pdl_conf_file
  - this key appears to be no longer in use.
  Please review configuration options and check the comments in
  the file perldl.conf that came with this distribution
EOD
    }
  }

  # Merge in default options where not supplied in users file
  #
  for(keys %PDL_CONFIG_DIST) {
    $PDL_CONFIG{$_} = $PDL_CONFIG_DIST{$_} unless exists $PDL_CONFIG{$_};
  }

  # Set up the default TEMPDIR if it has not been set by the user
  #
  # set up the default directory we use for temporary files throughout
  # PDL. These are mainly for files created during the build of PDL itself,
  # but it can also invovle files created whilst building an external
  # module that uses PDL (e.g. the trylink() function of PDL::Dev needs
  # a temporary file) or when a module is actually being used (e.g.
  # PDL::IO::Dumper may need a temporary file).
  #
  # We have no policy about what directory to use - the following is
  # an amalgam of the different choices that have been used within PDL
  # up to (and including) v2.4.1
  #

  $PDL_CONFIG{PDL_BUILD_DIR} = File::Spec->rel2abs(File::Spec->curdir());

  $PDL_CONFIG{TEMPDIR} = $^O =~ /MSWin32/i ? 'File::Spec->tmpdir()' : File::Spec->tmpdir()
    unless exists $PDL_CONFIG{TEMPDIR} and defined $PDL_CONFIG{TEMPDIR};

  # set up the default MALLOCDBG information (if not specified by the user)
  #
  if ( exists $PDL_CONFIG{MALLOCDBG} and defined $PDL_CONFIG{MALLOCDBG} ) {
      my $val = $PDL_CONFIG{MALLOCDBG};
      my $rval = ref($val);
      die "ERROR: MALLOCDBG must be set to an associative array, not to a " .
	( $rval ? $rval : "SCALAR" ) unless $rval eq "HASH";
  } else {
      $PDL_CONFIG{MALLOCDBG} = undef; # exists but undef
  }
  foreach my $item ( qw( libs include ) ) {
      $PDL_CONFIG{MALLOCDBG}->{$item} = ""
	unless exists $PDL_CONFIG{MALLOCDBG}->{$item};
  }

  # filter out incompatible options for the 'bad' code.
  # At present we can not have the experimental per-piddle
  # code turned on (the BADVAL_PER_PDL option) and use
  # NaN's for floating-point bad values (the BADVAL_USENAN
  # option).
  #
  my $flag_bad     = $PDL_CONFIG{WITH_BADVAL} || 0;
  my $flag_per_pdl = $PDL_CONFIG{BADVAL_PER_PDL} || 0;
  my $flag_use_nan = $PDL_CONFIG{BADVAL_USENAN} || 0;
  if ( $flag_bad and $flag_per_pdl and $flag_use_nan ) {
      print "WARNING: Setting BADVAL_USENAN=0 as BADVAL_PER_PDL option is set!\n\n";
      $PDL_CONFIG{BADVAL_USENAN} = 0;
  }

  # create a PDL::Config variable matching the PDL_CONFIG structure
  # and convert yes/no answers to 1/0
  #
  for my $key ( keys %PDL_CONFIG ) {
      my $val = $PDL_CONFIG{$key};
      $val =~ s/^y.*/1/i if defined $val;
      $val =~ s/^n.*/0/i if defined $val;
      $PDL::Config{$key} = $val;
  }

  # destroy PDL_CONFIG/PDL_CONFIG_DIST so that we can catch any accesses
  # to them in other Makefile.PL's
  #
  %PDL_CONFIG = ();
}

sub check_f77conf {
  my ($seenyet) = @_;
  return 0 unless $seenyet;

  my $pdl_f77conf = File::Spec->rel2abs($pdl_f77conf)
    unless File::Spec->file_name_is_absolute($pdl_f77conf);
  $PDL::Config{F77CONF} = $pdl_f77conf;
  return 1;
}

sub make_Version_pm {
  # Get VERSION from lib/PDL.pm and generate lib/PDL/Version.pm from it
  require 'lib/PDL.pm';
  # keep version info in $PDL::Config
  $PDL::Config{PDL_BUILD_VERSION} = "$PDL::VERSION";

  my $versionFile = 'lib/PDL/Version.pm';
  open my $fh, ">", $versionFile or
    die("Can't Open '$versionFile' for Writing!\n");
  print $fh <<"EOVF";
package PDL::Version;
#  This File was autogenerated by MakeFile.PL from the version
#  number in PDL.pm. It is used by PDL::Lite and others as
#  a single, consistent place to get the current PDL version.
our \$VERSION='$PDL::VERSION';
\$VERSION = eval \$VERSION;
1;
EOVF
  $fh->close();
}

sub make_Types_pm {
  # make sure we have Types.pm ready for prime time
  die "Types.pm.PL not found in lib/PDL"
    unless -f 'lib/PDL/Types.pm.PL';
  my $usebvals = $PDL::Config{WITH_BADVAL} ? "BADVALS=1" : "";
  system( $Config{perlpath}, 'lib/PDL/Types.pm.PL', $usebvals);
  unless ( -f 'lib/PDL/Types.pm' ) {
     warn "system( $Config{perlpath}, 'lib/PDL/Types.pm.PL', $usebvals) was run...\n";
     die "error creating lib/PDL/Types.pm";
  }
}

# very simple formatter, assumes structures are *not* nested
# used by make_PDL_Config_pm
sub myformat {
  my $entry = shift;
  if (ref $entry eq 'ARRAY') {
    my $list = join ',', (map {('"'.quotemeta($_).'"')} @$entry);
    return "[$list]";
  } elsif (ref $entry eq 'HASH') {
    my $list = join ",\n", (map {('"'.quotemeta($_).'" => "'.
			       quotemeta($entry->{$_}).'"')} keys %$entry);
    $list = "\n$list\n\t\t" unless $list =~ /^\s*$/;
    return "{$list}";
  } else {
     return join '', '"',quotemeta($PDL::Config{$_}),'"';
  }
}

sub make_PDL_Config_pm {
  print "Writing lib/PDL/Config.pm\n";

  my $versionFile = "lib/PDL/Config.pm";
  open my $fh, ">", $versionFile
    or die "Couldn't open $versionFile for writing";
  print $fh "
# AUTOMATICALLY GENERATED BY THE PDL TOPLEVEL Makefile.PL.
# DO NOT HAND-EDIT - CHANGES WILL BE LOST UPON YOUR NEXT
#  'perl Makefile.PL'!!!
package PDL;
use File::Spec;
\%PDL::Config = (\n";
  for (sort keys %PDL::Config) {
    $fh->print( "\t$_\t=>\t" );
    if(defined $PDL::Config{$_}) {
      if($PDL::Config{$_} eq 'File::Spec->tmpdir()') {$fh->print( $PDL::Config{$_} )}
      else {$fh->print( myformat($PDL::Config{$_}) )}
    } else {
      $fh->print( "undef" );
    }
    $fh->print(",\n");
  }
  $fh->print( ");\n1;" );
  $fh->close();
}

# test for critical modules
my @hasnt = ();
my @test = (
    ['Filter::Util::Call','Filter'],
    ['Filter::Simple','Filter::Simple'],
    ## ['Module::Compile','Module::Compile'], # don't do this, fails (why?)
    ['Text::Balanced','Text::Balanced'],
);
## $DB::single = 1; # uncomment to have debugger stop here
for my $mod (@test) {
    eval "use $mod->[0]";
    push @hasnt, $mod->[1] if $@;
}

# Scan ARGV for config file argument
@ARGV = map {
	if(/^PDLCONF=(.*)$/) {
		$seen_pdlconf=1;
		$pdl_conf_file = $1; ();
	} elsif (/^F77CONF=(.*)$/) {
		$seen_f77conf=1;
		$pdl_f77conf=$1; ();
	} elsif (/^FORCE$/i) {
		$forcebuild=1;
		();
        } else {
		$_
	}
} @ARGV;

warn "WARNING: forcing build...\n" if $forcebuild;

checkbuggysetup(); # check for buggy Perl setups

unless ( $seen_pdlconf ) {
    my $defname = "$ENV{HOME}/.perldl.conf";
    $pdl_conf_file = $defname if -f $defname;
}

# needs to be called before any of the make_XX routines
getpdl_config($pdl_conf_file);
$seen_f77conf = check_f77conf($seen_f77conf);

# Check environment for SKIP_KNOWN_PROBLEMS
if (!defined($PDL::Config{SKIP_KNOWN_PROBLEMS}) and defined($ENV{SKIP_KNOWN_PROBLEMS})) {
   $PDL::Config{SKIP_KNOWN_PROBLEMS} = $ENV{SKIP_KNOWN_PROBLEMS};
   warn "Makefile.PL: setting SKIP_KNOWN_PROBLEMS Config from environment value: $ENV{SKIP_KNOWN_PROBLEMS}";
}
# Add check for POGL if USE_POGL is enabled
if (!defined($PDL::Config{USE_POGL}) or +$PDL::Config{USE_POGL}) {
   eval "use OpenGL $PDL::Config{POGL_VERSION} qw();";
   if ($@) {
      if (defined($PDL::Config{USE_POGL})) {
         warn "Makefile.PL: DEPENDENCY ERROR: USE_POGL requires at least OpenGL version $PDL::Config{POGL_VERSION}!\n";
         exit 0;
      } else {
         warn "Makefile.PL: OpenGL-$PDL::Config{POGL_VERSION} not found, setting \$PDL::Config{USE_POGL} => 0\n";
         $PDL::Config{USE_POGL} = 0;
      }
   } else {
      # Have OpenGL so set USE_POGL option if needed
      warn "Makefile.PL: Found required OpenGL version, setting USE_POGL => 1\n" unless defined($PDL::Config{USE_POGL});
      $PDL::Config{USE_POGL} ||= 1;
   }
} else {
   warn "Makefile.PL: Have \$PDL::Config{USE_POGL} => 0 so skipping TriD build with POGL\n";
}

make_Version_pm();

make_Types_pm();

# this will make PDL::Core::Dev's functions available
# in Makefile.PL files in all subdirectories
# IMPORTANT: it has to be after make_Types_pm()
require "PDL/Core/Dev.pm"; PDL::Core::Dev->import();

# only perform one test if required modules are missing
# the test will print an informational message and fail
my %notestsifmodulesmissing = @hasnt ? # are any required modules missing ?
  (test => {TESTS => 't/requiredmods.t'}) : ();

my @prereq = (
	   'Astro::FITS::Header' => 0,
           'Carp'                => 0,         # Need to run
           'Convert::UU'         => 0,         # for PDL::IO::Dumper
           'Data::Dumper'        => 2.121,     # for PDL::IO::Dumper
           'ExtUtils::MakeMaker' => 7.05_11,   # XSMULTI
	   'File::Map'           => 0.57,      # test new mmap implementation
	   'File::Spec'          => 0.6,
	   'File::Temp'          => 0,
	   'Filter::Util::Call'  => 0,         # for PDL::NiceSlice
	   'Filter::Simple'      => 0.88,      # for new PDL::NiceSlice
	   'Inline'              => 0.68,
	   'Inline::C'           => 0.62,
	   'Module::Compile'     => 0.23,      # for new PDL::NiceSlice
	   'Pod::Parser'         => 0,         # version TBD for PDL::Doc
	   'Pod::Select'         => 0,         # version TBD for PDL::Doc
           'Storable'            => 1.03,      # for PDL::IO::Storable
	   'Text::Balanced'      => 1.89,      # for PDL::NiceSlice
           'Test::Warn'          => 0,         # for t/pptest.t
	  );

# add OpenGL version dependency for CPAN to follow
push @prereq, ('OpenGL' => $PDL::Config{POGL_VERSION}) if $PDL::Config{USE_POGL};
# push @prereq, ('ExtUtils::F77' => 1.10) unless $seen_f77conf;

my @exe_files = map "bin/$_", qw(perldl pdldoc pptemplate);
my $pdlexe = "bin/pdl$Config{exe_ext}";
push @exe_files, $pdlexe if $^O !~ /MSWin/;
my @cleanup = ($pdlexe, qw(
    bin/pdldoc.db Changes.new
    t/callext$(OBJ_EXT) t/callext.$(DLEXT)
));

##############################
# Hack to include fPIC on x86_64 systems -
# use similar mods to affect CCFLAGS on other systems as needed...

my $ccflags =  $Config{ccflags};
if($Config{archname}=~m/x86_64/) {
    $ccflags .= " -fPIC";
}
my ($pthread_define, $pthread_include, $pthread_library) = check_pthread();

my $preop = '';
$preop .= q[git log --stat --since='29 Apr 2009' > Changes.new && $(MV) Changes.new $(DISTVNAME)/Changes] if $^O ne 'MSWin32';

my $macos_braindamage_define = ($^O eq 'darwin') ? " -DMACOS_MZERO_BRAINDAMAGE " : "";
my $badval_define = " -DBADVAL=$PDL::Config{WITH_BADVAL} -DBADVAL_USENAN=$PDL::Config{BADVAL_USENAN} -DBADVAL_PER_PDL=$PDL::Config{BADVAL_PER_PDL}";
my $core_cobj = join ' ', map qq{lib/PDL/$_\$(OBJ_EXT)}, qw(pdlcore pdlapi pdlhash pdlthread pdlconv pdlmagic pdlsections);
push @cleanup, $core_cobj, map "lib/PDL/$_", qw(
    pdlconv.c pdlsections.c pdlcore.c Core.c
);

my %makefile_hash = (
  'PREREQ_PM' => { @prereq },
  'CONFIGURE_REQUIRES' => {
    'Carp'            => 1.20, # EU::MM seems to need this not to crash
    'Devel::CheckLib' => 1.01,
    'ExtUtils::MakeMaker' => 7.05_11,
  },
  BUILD_REQUIRES => {
    'ExtUtils::MakeMaker' => 0,
    'ExtUtils::ParseXS' => 3.01, # avoids 2.21, known broken
  },
  TEST_REQUIRES => {
    'CPAN::Meta' => '2.120900',
    'Test::Exception' => 0,
  },
  'NAME' => 'PDL',
  'VERSION_FROM' => 'lib/PDL/Version.pm',
  'EXE_FILES' => \@exe_files,
  'MIN_PERL_VERSION' => '5.010',
  'META_MERGE' => {
     resources => {
        homepage => 'http://pdl.perl.org/',
        bugtracker  => 'http://sourceforge.net/p/pdl/bugs/',
        repository  => {
           url => 'git://git.code.sf.net/p/pdl/code',
           type => 'git',
           web => 'http://sourceforge.net/p/pdl/code/ci/master/tree/',
        },
     },
  },
  'OPTIMIZE'  => $PDL::Config{OPTIMIZE} || $Config{optimize},
  'CCFLAGS' => $ccflags,
  'DEFINE' 	=> $pthread_define.$macos_braindamage_define.$badval_define,
  'LIBS'         => ["$pthread_library $PDL::Config{MALLOCDBG}->{libs}"],
  'INC'          => join(' ',
    PDL_INCLUDE(), map {length($_) ? qq{"$_"} : ()} $pthread_include, $PDL::Config{MALLOCDBG}->{include}
  ),
  TYPEMAPS => [ qw(lib/PDL/typemap.core) ],
  XSMULTI => 1,
  XSBUILD => {
    xs => {
        'lib/PDL/Core' => {
            OBJECT => 'lib/PDL/Core$(OBJ_EXT) ' . $core_cobj,
        },
    }
  },
  depend => {
     'lib/PDL/Core$(OBJ_EXT)' => 'config pm_to_blib lib/PDL/pdldataswitch.c lib/PDL/pdlbadvalinit.c lib/PDL/Core/pdl.h lib/PDL/Core/pdlcore.h',
         # Core.xs needs blib/arch for -Mblib to work, as well as pm_to_blib
  },
  'dist'     => {
    COMPRESS => 'gzip',
    SUFFIX   => 'gz',
    ($preop ? (PREOP => $preop) : ()),
  },
  'clean' => {
    'FILES' => join ' ', @cleanup, qw(
      tbyte.tif tmp0 tmp0.hdr tushort.tif
      MANIFEST.bak tmp1* tmpraw* t/tmpraw* t/tmp1*
      _Inline/ .inlinepdlpp/ .inlinewith/ *.xfig
    ),
  },
  'realclean' => {
    'FILES' => join ' ', map "lib/PDL/$_", qw(
      Config.pm Types.pm Version.pm Doc/Config.pm PP/Dump.pm
      Core/pdl.h Core/pdlcore.h Core/pdlsimple.h
    )
  },
  'AUTHOR' => 'PerlDL Developers (perldl@jach.hawaii.edu)',
  'ABSTRACT' => 'Perl Data Language',
  'BINARY_LOCATION' => 'PDL.tar.gz',

  %notestsifmodulesmissing,

  postamble => {
    inline => {
      # ordering matters:
      # bad loads primitive, primitive loads slices
      module => [ qw(
        PDL::Ops PDL::Slices PDL::Primitive PDL::Bad PDL::Ufunc PDL::Complex
      ) ],
      ilsm => 'Inline::Pdlpp',
      bundle => 0,
    },
  },
);

my $inline_postamble = \&MY::postamble; # imported by Inline::Module->import
{ no warnings 'redefine';
*MY::postamble = sub {
  my $self = shift;
  my $pdl_text = pdl_my_postamble($self, @_);
  my $inline_text = $self->$inline_postamble(@_);
  $inline_text =~ s/\bABSPERLRUN\b/${&}INST/g; # PDL stuff relies on blib
  join "\n", $pdl_text, $inline_text;
};
}

WriteMakefile(%makefile_hash);

# do *after* WriteMakefile since some options
# are set by the recursively called Makefile.PLs
make_PDL_Config_pm(); # write out config to PDL::Config

sub make_from_PL {
    my ($head, $extradeps) = @_;
    return unless defined $extradeps;
    sprintf <<'EOF', $head, $extradeps;
%s :: %s
EOF
}

sub pdl_my_postamble {
  my ($self) = @_;
  package MY;
  my @m = PDL::Core::Dev::postamble() . "\n\n";
  push @m, map { ::make_from_PL("lib/PDL/Core/$_", 'lib/PDL/Types.pm') }
    qw( pdl.h pdlsimple.h pdlcore.h pdlconv.c pdlcore.c );
  push @m, <<'EOF';
# Bits of C code we generate from special perl scripts
# there must be a more elegant way of saying that
# certain files have additional dependencies!
lib/PDL/Core/pdlthread.c :: lib/PDL/Core/pdlcore.h
lib/PDL/Core/pdlhash.c :: lib/PDL/Core/pdlcore.h
lib/PDL/Core/pdlapi.c :: lib/PDL/Core/pdlcore.h
lib/PDL/Core/pdlmagic.c :: lib/PDL/Core/pdlcore.h
lib/PDL/Core$(OBJ_EXT) : lib/PDL/Core/pdl.h lib/PDL/Core/pdlcore.h

EOF

  # Extra build target to build the doc database
  my $text = '
doctest ::
	$(NOECHO) $(ECHO) "doctest: Building PDL documentation database in blib ..."
	$(NOECHO) $(PERLRUNINST) Doc$(DFSEP)scantree.pl
%HTML%	$(NOECHO) $(ECHO) "doctest: Building PDL documentation web pages in blib ..."
%HTML%	$(NOECHO) $(PERLRUNINST) Doc$(DFSEP)mkhtmldoc.pl

doc_site_install ::
	$(NOECHO) $(ECHO) "doc_site_install: Building PDL documentation database ..."
	$(NOECHO) $(PERLRUNINST) Doc$(DFSEP)scantree.pl "$(INSTALLSITEARCH)"
%HTML%	$(NOECHO) $(ECHO) "doc_site_install: Building PDL documentation web pages ..."
%HTML%	$(NOECHO) $(PERL) Doc$(DFSEP)mkhtmldoc.pl "$(INSTALLSITEARCH)$(DFSEP)PDL"

doc_vendor_install ::
	$(NOECHO) $(ECHO) "doc_vendor_install: Building PDL documentation database ..."
	$(NOECHO) $(PERLRUNINST) Doc$(DFSEP)scantree.pl "$(INSTALLVENDORARCH)"
%HTML%	$(NOECHO) $(ECHO) "doc_vendor_install: Building PDL documentation web pages ..."
%HTML%	$(NOECHO) $(PERL) Doc$(DFSEP)mkhtmldoc.pl "$(INSTALLVENDORARCH)$(DFSEP)PDL"

doc_perl_install ::
	$(NOECHO) $(ECHO) "doc_perl_install: Building PDL documentation database ..."
	$(NOECHO) $(PERLRUNINST) Doc$(DFSEP)scantree.pl "$(INSTALLARCHLIB)"
%HTML%	$(NOECHO) $(ECHO) "doc_perl_install: Building PDL documentation web pages ..."
%HTML%	$(NOECHO) $(PERL) Doc$(DFSEP)mkhtmldoc.pl "$(INSTALLARCHLIB)$(DFSEP)PDL"
';

  if(defined $PDL::Config{HTML_DOCS} && !$PDL::Config{HTML_DOCS}){
    $text=~ s/\%HTML\%[^\n]*\n//og; # Remove %HTML% lines
  } else {
    $text=~ s/\%HTML\%//og; # Remove just %HTML% markers
  }
  push @m, $text;

$text .= <<EOT if $^O !~ /MSWin/;
bin/pdl$Config::Config{exe_ext} : bin/pdl.c
	\$(CC) \$< -o \$\@
EOT

  push @m, << 'EOT' if $^O =~ /MSWin/;

DISTWIN32NAME=$(DISTVNAME)-win32

ppm : doctest ppd
	$(MV) blib$(DFSEP)lib$(DFSEP)PDL$(DFSEP)HtmlDocs$(DFSEP)PDL blib$(DFSEP)html$(DFSEP)lib$(DFSEP)PDL
	$(COMPRESS) -dc win32$(DFSEP)pbmwin32.tar.gz | $(TAR) xf -
	$(MKPATH) $(DISTWIN32NAME)
	$(CP) win32$(DFSEP)Readme $(DISTWIN32NAME)
	$(CP) win32$(DFSEP)install.ppm .
	$(PERL) -pe "s|<\x{2f}IMPLEMENTATION>|<INSTALL EXEC=\"perl\">install.ppm<\x{2f}INSTALL><\x{2f}IMPLEMENTATION>|" PDL.ppd > PDL.ppd.new
	$(RM) PDL.ppd
	$(MV) PDL.ppd.new PDL.ppd
	$(CP) PDL.ppd $(DISTWIN32NAME)
	$(TAR) cf $(DISTWIN32NAME)$(DFSEP)PDL.tar blib install.ppm
	cd $(DISTWIN32NAME)
	$(COMPRESS) PDL.tar
	$(ZIP) $(DISTWIN32NAME).zip *
	$(MV) $(DISTWIN32NAME).zip ..
	cd ..
	$(RM_RF) $(DISTWIN32NAME)
EOT

  my $coretest = join ' ', map File::Spec->catfile('t', $_), qw(core.t ops.t);
  push @m, <<EOF;

# dynamic only
core : pm_to_blib \$(INST_DYNAMIC) build_inline

coretest : core
	prove -b $coretest
EOF

  join '', @m;
}

# remove pdl.c from making EUMM think this dir has XS in it
sub MY::init_dirscan {
    package MY;
    my ($self) = @_;
    $self->SUPER::init_dirscan;
    $self->{C} = [];
    $self->{O_FILES} = [];
}

# the .PLs in DIR below rely on PDL::{Config,Types} being in blib already
sub MY::top_targets {
  package MY;
  my ($self) = @_;
  my $super = $self->SUPER::top_targets;
  $super =~ s#^subdirs_(?:pure_nolink|static|dynamic)\s*:+.*?$#$& pm_to_blib#gm;
  $super;
}

sub MY::init_PM {
  package MY;
  my ($self) = @_;
  my $core = 'lib/PDL/Core';
  $self->{XS}{"$core.xs"} = "$core.c";
  push @{$self->{C}}, "$core.c";
  push @{$self->{O_FILES}}, "$core$self->{OBJ_EXT}";
  $self->SUPER::init_PM;
  for my $pm (keys %{ $self->{PM} }) {
    next unless (my $nonPL = $pm) =~ s/\.PL$//;
    $self->{PM}{$nonPL} = delete $self->{PM}{$pm};
    $self->{PM}{$nonPL} =~ s/\.PL$//i;
    $self->{realclean}{FILES} .= " $nonPL";
    next if $nonPL =~ /Types\.pm/; # we do that ourselves already
    $self->{PL_FILES}{$pm} = $nonPL;
  }
  for my $pm (keys %{ $self->{PM} }) {
    next unless $pm =~ /(\.[cg]|\Q$Config::Config{obj_ext}\E|\Qtypemap.core\E)$/;
    delete $self->{PM}{$pm};
  }
  $self->{PM}{'lib/PDL/Config.pm'} = 'blib/lib/PDL/Config.pm';
}

# warn if vital modules are missing
END {
    if (@hasnt) {
      print << 'EOP';

********************************************************
* IMPORTANT: Your installation will not work since it  *
* lacks critical modules.                              *
* ALL TESTS WILL FAIL UNLESS YOU IMMEDIATELY           *
* INSTALL THE FOLLOWING MODULES [available from CPAN]: *
*
EOP

    for (@hasnt) { print "*\t$_\n" }


    print << 'EOP';
*                                                      *
* Please install the missing module(s) and start the   *
* PDL build process again (perl Makefile.PL; ....)     *
*                                                      *
********************************************************

EOP

  }

} # end of END block

sub check_pthread {
    my $pthread_include = $Config::Config{usrinc};  # not good for win32
    my $pthread_library = '-lpthread';              # not good for MSVC
    my $pthread_define  = ' -DPDL_PTHREAD ';

    print "Trying to figure out POSIX threads support ...\n";

    # TODO: replace directory and file checks for pthread.h by Devel::CheckLib test
    if ( exists $PDL::Config{POSIX_THREADS_INC} and  defined $PDL::Config{POSIX_THREADS_INC} ) {
        $pthread_include = $PDL::Config{POSIX_THREADS_INC};
        print "\t..setting \$pthread_include to $pthread_include\n";
    } elsif (-d $pthread_include) {
        print "\tSaw pthread.h. Fine.\n";
        $pthread_include = "-I$pthread_include"
    } else {
        print "\tEhh. Didn't see include file 'pthread.h'.\n";
        $pthread_include = '';
    }

    # TODO: need to clean up per-platform logic here
    if ( exists $PDL::Config{POSIX_THREADS_LIBS} and defined $PDL::Config{POSIX_THREADS_LIBS} ) {
        $pthread_library = $PDL::Config{POSIX_THREADS_LIBS};
        print "\tUsing POSIX_THREADS_LIBS from perldl.conf\n";
    } elsif ($Config::Config{libs} =~ /-lpthread/) {   # wrong
        print "\tFine, your perl was linked against pthread library.\n";
    } elsif ($^O eq 'dec_osf') {
        if ($Config::Config{usemymalloc} eq 'n') {
            print "\tFine pthread, works with Digital Unixs malloc\n";
        } else {
            #
            print "\tPerls malloc has problems when perl is not linked with -lpthread\n";
            $pthread_library = '';
        }
    } elsif ($^O eq 'freebsd'){
        if ($Config::Config{libs} =~ /-lc_r/) {
            print "\tGood, found -lc_r on a freebsd system.\n";
        } else {
            print "On FreeBSD try building perl with libc_r instead of libc\n";
            $pthread_library = '';
        }
     } elsif ($^O =~ /bsd$/i){
        if ($Config::Config{ldflags} =~ /-pthread/) {
           if ($Config::Config{usemymalloc} eq 'y') {
              print "\tGood, usemymalloc=y, will build with pthread support\n";
           } else {
              print "\tGot usemymalloc=$Config::Config{usemymalloc} so not building with pthreads\n";
              $pthread_library = '';
           }
        } else {
              print "\tMissing '-pthread' from ldflags=$Config::Config{lddlflags} so not building with pthreads\n";
              $pthread_library = '';
        }
     } else {
        print "\tNope, your perl was not linked against pthread library\n";
        if ($^O =~ /mswin/i or $^O =~ /cygwin/i) {
           if (check_lib(LIB=>'-lpthread',header=>'pthread.h')) {
              print "\tWe found -lpthread and pthread.h so will build anyway\n";
              $pthread_library = '-lpthread';
           } else {
              $pthread_library = '';
           }
        } else {
           print "\tWe'll try the default -lpthread anyway\n";
           # $pthread_library = '';
        }
     }

    $pthread_include = $pthread_library = '' unless $pthread_include and $pthread_library;

    {
        # TODO: use a Devel::CheckLib build/run test to verify working build params
        my $conf = $PDL::Config{WITH_POSIX_THREADS};

        if ((!defined($conf) or $conf)
            and $pthread_include and $pthread_library) {
            print "\t==> Will build PDL with POSIX thread support. Gifts to TJL :-)\n";
            $PDL::Config{WITH_POSIX_THREADS} = 1;
        } elsif($conf) {
            print "\t==> I couldn't find pthread support. However, you have\n";
            print "\t    turned on the forcing option in PDL_CONFIG so I guess I gotta do it\n";
        } else {
            print "\t==> PDL will be built without POSIX thread support.\n";
            print "\t==> *NOTE*: PDL threads are unrelated to perl threads (usethreads=y)!\n";
            print "\t==> Enabling perl threads will not help!\n";
            $pthread_define = '';
            $PDL::Config{WITH_POSIX_THREADS} = 0;
        }
    }
    ($pthread_define, $pthread_include, $pthread_library);
}
