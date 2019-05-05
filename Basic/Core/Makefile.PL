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

# isbigendian() is in PDLA::Dev
print "Trying to figure out endian-ness of machine...";
print " It is " . (PDLA::Core::Dev::isbigendian() ? "big" : "little") . " endian\n";

sub nopl { my $txt = shift; $txt =~ s/[.]PL$//; return $txt}

# Extra targets to build

sub make_from_PL ($) {
    my $head = shift;
    return "\t" .
	'$(PERLRUNINST) ' .
	    "${head}.PL $head\n";
}

sub MY::xs_o {
    if($Config{make} =~ /\bnmake/i) {
      return'
.xs$(OBJ_EXT):
	$(PERLRUN) $(XSUBPP) $(XSPROTOARG) $(XSUBPPARGS) $*.xs > $*.c
	$(CCCMD) $(CCCDLFLAGS) "-I$(PERL_INC)" $(DEFINE) $*.c
'
      }
    else {
      package MY;
      my $self = shift;
      return $self->SUPER::xs_o;
      }
}

undef &MY::processPL; *MY::processPL = sub {
    package MY;
    my ($self) = @_;
    return $self->SUPER::processPL
        unless $^O =~ /MSWin32/i && $Config::Config{make} =~ /\b[dn]make/i;
    return '' if $Config::Config{make} =~ /\bnmake/i;
    return "" unless $self->{PL_FILES};
    my @m;
    my $alltarget = 'all';
    my $colon = $Config::Config{make} =~ /\bdmake/i ? ':' : '::';
    foreach my $plfile (sort keys %{$self->{PL_FILES}}) {
        my $list = ref($self->{PL_FILES}->{$plfile})
                ? $self->{PL_FILES}->{$plfile}
                : [$self->{PL_FILES}->{$plfile}];
        foreach my $target (@$list) {
            push @m,
                "\n$alltarget :: $target\n\t\$(NOECHO) \$(NOOP)\n",
                "\n$target $colon\n\t\$(PERLRUNINST) $plfile $target\n";
        }
    }
    join "", @m;
};

undef &MY::postamble; # suppress warning
*MY::postamble = sub {

    # nmake doesn't seem to do inference rules right so spell it out
    my $pdlsections_g = sprintf <<'EOF', PDLA::Core::Dev::genpp_cmdline(qw(pdlsections.g pdlsections.c));

pdlsections.c :: pdlsections.g Types.pm
	%s
EOF
    my $text = PDLA::Core::Dev::postamble() . "

pdlbadvalinit.c:: pdlbadvalinit.c.PL Types.pm\n"
. make_from_PL( 'pdlbadvalinit.c' )
."

pdldataswitch.c:: pdldataswitch.c.PL Types.pm\n"
. make_from_PL( 'pdldataswitch.c' )
."

pdl.h:: pdl.h.PL Types.pm\n"
    . make_from_PL( 'pdl.h' ) . "

pdlsimple.h:: pdlsimple.h.PL Types.pm\n"
    . make_from_PL( 'pdlsimple.h' ) . "

pdlcore.h:: pdlcore.h.PL Types.pm\n"
    . make_from_PL( 'pdlcore.h' );
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

pdlthread.c :: pdl.h pdlcore.h\n"
."

pdlhash.c :: pdl.h pdlcore.h\n"
."

pdlapi.c :: pdl.h pdlcore.h\n"
."

pdlmagic.c :: pdlcore.h\n"
."

pdlsections.c :: pdl.h pdlcore.h\n"
."

pdlconv.c:: pdlconv.c.PL Types.pm\n"
. make_from_PL( 'pdlconv.c' )
."

pdlcore.c:: pdlcore.c.PL Types.pm\n"
. make_from_PL( 'pdlcore.c' )
.
($^O =~ /MSWin/ ? $pdlsections_g : '');
}
};

my @cfiles = qw(pdlcore pdlapi pdlhash pdlthread pdlconv pdlmagic pdlsections);
my $cobj = join ' ', map qq{$_\$(OBJ_EXT)}, @cfiles;
WriteMakefile(
 'NAME'	        => 'PDLA::Core',
 'VERSION_FROM' => 'Version.pm',
  'PM'          => {
		(map {($_,'$(INST_LIBDIR)/'.$_)} (
			qw/Core.pm Basic.pm Version.pm Types.pm
						  Dbg.pm Exporter.pm Config.pm Char.pm/
		)),
		(map {($_,'$(INST_LIBDIR)/Core/'.$_)} (
			qw/Dev.pm typemap.pdl pdl.h pdlcore.h pdlmagic.h pdlsimple.h
				pdlthread.h ppport.h/
		)),
		qq/IFiles.pm/,'$(INST_LIBDIR)/Install/Files.pm',
		},
 'PL_FILES'     => {map {($_ => nopl $_)} grep {!/^Makefile.PL$/} <*.PL>},
 'OBJECT'       => 'Core$(OBJ_EXT) ' . $cobj,
 'DEFINE' 	=> $pthread_define.$badval_define,
 'LIBS'         => ["$pthread_library $malloclib"],
 'clean'        => {'FILES'  => $cobj .
                   ' pdlconv.c pdlsections.c pdlcore.c '.
		   'pdl.h pdlsimple.h pdlcore.h '.
                   'pdldataswitch.c pdlbadvalinit.c '.
		   'Types.pm Version.pm Core.c '
		   },
 'INC'          => join(' ',
   PDLA_INCLUDE(), map {length($_) ? qq{"$_"} : ()} $pthread_include, $mallocinc
 ),
  depend => {
    'Core$(OBJ_EXT)' => '$(INST_ARCHLIB)$(DFSEP).exists pm_to_blib pdldataswitch.c pdlbadvalinit.c pdl.h pdlcore.h',
        # Core.xs needs blib/arch for -Mblib to work, as well as pm_to_blib
  },
 (eval ($ExtUtils::MakeMaker::VERSION) >= 6.57_02 ? ('NO_MYMETA' => 1) : ()),
);
