=head1 NAME

PDLA::Lite - minimum PDLA module OO loader

=head1 DESCRIPTION

Loads the smallest possible set of modules for
PDLA to work, importing only those functions always defined by
L<PDLA::Core|PDLA::Core>) into the current namespace
(C<pdl>, C<piddle>, C<barf> and C<null>).
This is the absolute minimum set for PDLA.

Access to other functions is by method syntax, viz:

  $x = PDLA->pdl(1, 2, 3, 4, 5);
  $x->wibble(42);

=head1 SYNOPSIS

 use PDLA::Lite; # Is equivalent to the following:

   use PDLA::Core '';
   use PDLA::Ops '';
   use PDLA::Primitive '';
   use PDLA::Ufunc '';
   use PDLA::Basic '';
   use PDLA::Slices '';
   use PDLA::Bad '';
   use PDLA::Version;
   use PDLA::Lvalue;

=cut

# Load the fundamental PDLA packages, no imports
# Because there are no imports, we do not need
# the usual 'eval in the user's namespace' routine.

use PDLA::Core '';
use PDLA::Ops '';
use PDLA::Primitive '';
use PDLA::Ufunc '';
use PDLA::Basic '';
use PDLA::Slices '';
use PDLA::Bad '';
use PDLA::Version ;  # Doesn't export anything - no need for ''
use PDLA::Lvalue;

package PDLA::Lite;
$VERSION = $PDLA::Version::VERSION;

@ISA = qw( PDLA::Exporter );

@EXPORT = qw( piddle pdl null barf ); # Only stuff always exported!
our %EXPORT_TAGS = (
   Func     => [@EXPORT],
);


;# Exit with OK status

1;
