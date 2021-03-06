
=head1 NAME

PDLA::AutoLoader - MatLab style AutoLoader for PDLA

=head1 SYNOPSIS

 use PDLA::AutoLoader;
 $x = func1(...);   # Load file func1.pdl
 $y = func2(...);   # Load file func2.pdl

 $PDLA::AutoLoader::Rescan = 1; # Enable re-scanning

=head1 DESCRIPTION

This module implements a MatLab style AutoLoader for PDLA. If an unknown
function C<func()> is called, PDLA looks for a file called C<func.pdl>.
If it finds one, it compiles the file and calls the function C<func>.

The list of directories to search in is given by the shell environment
variable C<PDLALIB>. This is a colon-separated list of directories. On
MSWindows systems, is it a I<semicolon> -separated list of directories.

For example, in csh:

  setenv PDLALIB "/home/joe/pdllib:/local/pdllib"

B<Note>: This variable is unrelated to Perl's C<PERL5LIB>.

If you add a leading '+' on a directory name, PDLA will search the
entire directory tree below that point. Internally, PDLA stores the
directory list in the variable C<@PDLALIB>, which can be modified at
run time.

For example, in csh:

  setenv PDLALIB "+/home/joe/PDLA"

will search /home/joe/PDLA and all its subdirectories for .pdl files.

=head2 AUTO-SCANNING

The variable C<$PDLA::AutoLoader::Rescan> controls whether files
are automatically re-scanned for changes at the C<perldla> or
C<pdla2> command line.

If C<$PDLA::AutoLoader::Rescan == 1> and the file is changed
then the new definition is reloaded auto-matically before
executing the C<perldla> or C<pdla2> command line. Which means
in practice you can edit files, save changes and have C<perldla>
or C<pdla2> see the changes automatically.

The default is '0' - i.e. to have this feature disabled.

As this feature is only pertinent to the PDLA shell it imposes
no overhead on PDLA scripts. Yes Bob you can have your cake and
eat it too!

Note: files are only re-evaled if they are determined to have
been changed according to their date/time stamp.

No doubt this interface could be improved upon some more. :-)

=head2 Sample file:

 sub foo { # file 'foo.pdl' - define the 'foo' function
   my $x=shift;
   return sqrt($x**2 + $x**3 + 2);
 }
 1; # File returns true (i.e. loaded successfully)

=head1 AUTHOR

Copyright(C) 1997 Karl Glazebrook (kgb@aaoepp.aao.gov.au);
several extensions by Craig DeForest (deforest@boulder.swri.edu)
All rights reserved. There is no warranty. You are allowed
to redistribute this software / documentation under certain
conditions. For details, see the file COPYING in the PDLA
distribution. If this file is separated from the PDLA distribution,
the copyright notice should be included in the file.

=head1 BUGS

No doubt this interface could be improved upon some more. :-)

Will probably be quite slow if C<$PDLA::AutoLoader::Rescan == 1>
and thousands of functions have been autoloaded.

There could be a race condition in which the file changes
while the internal autoloader code is being executed but it
should be harmless.

Probably has not been tested enough!

=head1 SEE ALSO

For an alternative approach to managing a personal collaction of 
modules and functions, see L<local::lib>.

=cut

BEGIN{
   if (defined $ENV{"PDLALIB"}) {
      if ( $^O eq 'MSWin32' ) { # win32 flavors
         @PDLALIB = (".",split(';',$ENV{"PDLALIB"}));
         s/"//g for @PDLALIB;
      } else {                  # unixen systems
         @PDLALIB = (".",split(':',$ENV{"PDLALIB"}));
      }
      @PDLALIB = grep length, @PDLALIB;
   }
  $PDLA::AutoLoader::Rescan=0;
  %PDLA::AutoLoader::FileInfo = ();
}

# Code to reload stuff if changed

sub PDLA::AutoLoader::reloader {
   return unless $PDLA::AutoLoader::Rescan;

   # Now check functions and reload if changed

   my ($file, $old_t);
   for my $func (keys %PDLA::AutoLoader::FileInfo) {
       ($file, $old_t) = @{ $PDLA::AutoLoader::FileInfo{$func} };
       if ( (stat($file))[9]>$old_t ) { # Reload
          print "Reloading $file as file changed...\n" if $PDLA::verbose;
	  &PDLA::AutoLoader::autoloader_do($file);
	  $PDLA::AutoLoader::FileInfo{$func} = [ $file, (stat($file))[9] ];
       }
   }
}

# Used for Beta, and should probably be used generall in this mod
#use File::Spec;

sub PDLA::AutoLoader::import {

	# Beta folder support
#	foreach (@INC) {
#		$Beta_dir = File::Spec->catfile($_, 'PDLA', 'Beta');
#		push @PDLALIB, "+$Beta_dir" if -d $Beta_dir;
#	}

my $pkg = (caller())[0];
my $toeval = "package $pkg;\n";

# Make sure that the eval gets NiceSlice if we have it in this level
# (it's a drag that preprocessors aren't transitive...)
$toeval .= "use PDLA::NiceSlice;\n" if(defined $PDLA::NiceSlice::VERSION);

$toeval .= <<'EOD';
$PDLALIB_CT = 0;

push @PERLDL::AUTO, \&PDLA::AutoLoader::reloader;


sub AUTOLOAD {
    local @INC = @INC;
    my @args = @_;
    $AUTOLOAD =~ /::([^:]*)$/;
    my $func = $1;

    # Trap spurious calls from 'use UnknownModule'

    goto &$AUTOLOAD if ord($func)==0;

   # Check if the PDLALIB needs to be expanded and, if so, expand it.
   # This only updates when PDLALIB changes size, which should be OK
   # for most things but doesn't catch new directories in expanded
   # directory trees.  It seems like an OK compromise between never 
   # catching anything and always thrashing through the directories.
    if($PDLALIB_CT != scalar(@PDLALIB)) {
	@PDLALIB_EXPANDED = PDLA::AutoLoader::expand_path(@PDLALIB);
	$PDLALIB_CT = scalar(@PDLALIB);
    }

    print "Loading $func.pdl ..." if $PDLA::verbose;
    my $file;

    my $s = "PDLA AutoLoader:  Undefined subroutine $func() cannot be autoloaded.\n";

    for my $dir (@PDLALIB_EXPANDED) {
        $file = $dir . "/" . "$func.pdl";
	if (-e $file) {
	  
	  print "found $file\n" if $PDLA::verbose;

	  &PDLA::AutoLoader::autoloader_do($file);
	  
	  
	  # Remember autoloaded functions and do some reasonably
	  # smart cacheing of file/directory change times
	  
	  if ($PDLA::AutoLoader::Rescan) {
	    $PDLA::AutoLoader::FileInfo{$func} = [ $file, (stat($file))[9] ];
	  }
	  
	  # Now go to the autoload function
	  ##goto &$AUTOLOAD(@args) unless ($@ || !defined(&{$AUTOLOAD}));
	  return &$AUTOLOAD(@args) unless ($@ || !defined(&{$AUTOLOAD}));

	  die $s."\tWhile parsing file `$file':\n$@\n" if($@);
	  die $s."\tFile `$file' doesn't \n\tdefine ${AUTOLOAD}().\n"
	  
	}
      }

    die $s."\tNo file `$func.pdl' was found in your \@PDLALIB path.\n";
}

EOD

eval $toeval;

}


# Simple 'do' doesn't work with preprocessing -- this replaces
# "do file" and sticks NiceSlice in manually if it's needed (yuck).

sub PDLA::AutoLoader::autoloader_do {
  my ($file) = shift;
  
  if(defined($PDLA::NiceSlice::VERSION)) {
    
    print "AutoLoader: NiceSlice enabled...\n" if($PDLA::debug);
    
    if(open(AUTOLOAD_FILE,"<$file")) {
      my($script) = &PDLA::NiceSlice::perldlpp("PDLA::NiceSlice", join("",<AUTOLOAD_FILE>));
      eval $script;
    }
  } else {
    print "AutoLoader: no NiceSlice...\n" if($PDLA::debug);
    do $file;
  }
}


# Expand directories recursively...
sub PDLA::AutoLoader::expand_dir {
  local $d;  
  local @list;  
  local @subdirs;  

  local $dir = shift;
    
  if(! -d $dir) { return undef; }
  push(@list,$dir);

  opendir(FOO,$dir);

  @subdirs = grep((!m/^\./ && ($_="$dir/$_") && (-d $_)), readdir(FOO));
  closedir FOO;

  while(defined ($d = shift @subdirs)) {
    push(@list,&PDLA::AutoLoader::expand_dir($d));
  }
  return @list;
}


=head2 PDLA::AutoLoader::expand_path

=for ref 

Expand a compactified path into a dir list

You supply a pathlist and leading '+' and '~' characters get expanded into
full directories.  Normally you don't want to use this -- it's internal to the
autoloader -- but some utilities, like the online documentation searcher, need
to be able to use it.

=cut

sub PDLA::AutoLoader::expand_path {
    my @PDLALIB = @_;
    my @PDLALIB_EXPANDED;
    
    print "AutoLoader: Expanding directories from ".join(':',@PDLALIB)."...\n"
	if($PDLA::debug);
    local $_;
    foreach $_(@PDLALIB) {
	# Expand ~{name} and ~ conventions.
	if(s/^(\+?)\~(\+||[a-zA-Z0-9]*)//) {
	    if($2 eq '+') {
		# Expand shell '+' to CWD.
		$_= $1 . ($ENV{'PWD'} || '.');
	    } elsif(!$2) {
		# No name mentioned -- use current user.
                #   Ideally would use File::HomeDir->my_home() here
		$_ = $1 . ( $ENV{'HOME'} || (( getpwnam( getlogin || getpwuid($<) ))[7]) )  . $_;
	    } else {
		# Name mentioned - try to get that user's home directory.
		$_ = $1 . ( (getpwnam($2))[7] ) . $_;
	    }
	}
	
	# If there's a leading '+', include all subdirs too.
	push(@PDLALIB_EXPANDED,
	     s/^\+// ? &PDLA::AutoLoader::expand_dir($_) : $_
	     );
    }

    print "AutoLoader: returning ",join(",",@PDLALIB_EXPANDED),"\n" if($PDLA::debug);
    @PDLALIB_EXPANDED;
}


;# Exit with OK status

1;
