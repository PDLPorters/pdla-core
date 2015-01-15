use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'PDLA',
    'VERSION_FROM' => '../lib/PDLA/Version.pm',
    NO_MYMETA => 1,
);

# modify clean method not to delete files named 'core'
# (required for MacOSX, where "Core" and "core" are
# indistinguishable)
package MY; # so that "SUPER" works right
sub clean {
  my $inherited = shift->SUPER::clean(@_);
  $inherited =~ s/\s+core\s/ /;
  # print STDERR "processed list :\n$inherited\n";
  $inherited;
}
