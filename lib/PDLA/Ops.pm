package PDLA::Ops;

use strict;
use warnings;
use PDLA::Core;
use PDLA::Ops::Inline Pdlapp => Config => clean_after_build => 0;
use PDLA::Ops::Inline Pdlapp => 'DATA', internal => 1;
use parent 'PDLA::Exporter';

our @EXPORT_OK  = qw( log10 assgn ipow );
our %EXPORT_TAGS = (Func=>[@EXPORT_OK]);

*log10 = \&PDLA::log10;
*assgn = \&PDLA::assgn;
*ipow = \&PDLA::ipow;

sub PDLA::log10 {
    my $x = shift;
    if ( ! UNIVERSAL::isa($x,"PDLA") ) { return log($x) / log(10); }
    my $y;
    if ( $x->is_inplace ) { $x->set_inplace(0); $y = $x; }
    elsif( ref($x) eq "PDLA"){
	#PDLA Objects, use nullcreate:
	$y = PDLA->nullcreate($x);
    }else{
	#PDLA-Derived Object, use copy: (Consistent with
	#  Auto-creation docs in Objects.pod)
	$y = $x->copy;
    }
    &PDLA::_log10_int( $x, $y );
    return $y;
}

=head1 NAME

PDLA::Ops - Fundamental mathematical operators

=head1 DESCRIPTION

This module provides the functions used by PDLA to
overload the basic mathematical operators (C<+ - / *>
etc.) and functions (C<sin sqrt> etc.)

=head1 FUNCTIONS

=head2 log10

It also includes the function C<log10>, which should
be a perl function so that we can overload it!

Matrix multiplication (the operator C<x>) is handled
by the module L<PDLA::Primitive|PDLA::Primitive>.

=head2 assgn

Also provides C<assgn>. This is used to implement the C<.=> operator.

If C<a> is a child piddle (e.g., the result of a slice) and bad values are generated in C<b>,
the bad value flag is set in C<b>, but it is B<NOT> automatically propagated back to the parent of C<a>.
The following idiom ensures that the badflag is propagated back to the parent of C<a>:

 $pdl->slice(":,(1)") .= PDLA::Bad_aware_func();
 $pdl->badflag(1);
 $pdl->check_badflag();

This is unnecessary if $pdl->badflag is known to be 1 before the slice is performed.

See L<http://pdl.perl.org/PDLAdocs/BadValues.html#dataflow_of_the_badflag> for details.

=head2 ipow

=for ref

raise piddle C<$a> to integer power C<$b>

=for example

   $z = $x->ipow($y,0);     # explicit function call
   $z = ipow $x, $y;
   $x->inplace->ipow($y,0);  # modify $x inplace

It can be made to work inplace with the C<$x-E<gt>inplace> syntax.
Note that when calling this function explicitly you need to supply
a third argument that should generally be zero (see first example).
This restriction is expected to go away in future releases.

Algorithm from L<Wikipedia|http://en.wikipedia.org/wiki/Exponentiation_by_squaring>

=cut


=head1 SYNOPSIS

none

=head1 OPERATOR TYPES

All can be made to work inplace with the C<$a-E<gt>inplace> syntax.

=head2 Binary operators

=for ref

They are used to overload the relevant Perl binary operator. Note that
when calling this function explicitly you need to supply a third argument
that should generally be zero (see first example).

This restriction is expected to go away in future releases.

=for example

   $z = plus $x, $y, 0;     # explicit call with trailing 0
   $z = $x + $y;            # overloaded call
   $x->inplace->plus($y,0); # modify $x inplace

=head3 Arithmetic ops

=over 2

=item plus OVERLOADS +

add two piddles

=item mult OVERLOADS *

multiply two piddles

=item minus OVERLOADS -

subtract two piddles

=item divide OVERLOADS /

divide two piddles', Exception => '$b() == 0' );

=back

=head3 Comparison ops

=over 2

=item gt OVERLOADS E<gt>

the binary E<gt> (greater than) operation

=item lt OVERLOADS E<lt>

the binary E<lt> (less than) operation

=item le OVERLOADS E<lt>=

the binary E<lt>= (less equal) operation

=item ge OVERLOADS E<gt>=

the binary E<gt>= (greater equal) operation

=item eq OVERLOADS ==

binary I<equal to> operation (C<==>)

=item ne OVERLOADS !=

binary I<not equal to> operation (C<!=>)

=back

=head3 Bit ops

These are limited to the right types: bytes, unsigned, shorts and longs.

=over 2

=item shiftleft OVERLOADS <<

leftshift C<$x> by C<$y>

=item shiftright OVERLOADS >>

rightshift C<$x> by C<$y>

=item or2 OVERLOADS |

binary I<or> of two piddles

=item and2 OVERLOADS &

binary I<and> of two piddles

=item xor OVERLOADS ^

binary I<exclusive or> of two piddles

=back

=head2 Simple binary functions

=for ref

They are used to overload the relevant binary function.
Note that when calling these explicitly you need to supply
a third argument that should generally be zero (see first example).
This restriction is expected to go away in future releases.

=for example

   $z = $x->pow($y,0);     # explicit function call
   $z = $x ** $y;          # INFIX - overloaded use
   $z = atan2 $x, $y;      # OTHERWISE - overloaded use
   $x->inplace->pow($y,0); # modify $x inplace

=over 2

=item power OVERLOADS C<**>.

(infix) raise piddle C<$x> to the power C<$y> (doubles only)

=item atan2

atan2

elementwise C<atan2> of two piddles (doubles only)

=item modulo OVERLOADS C<%>.

(infix) elementwise C<modulo> operation (unsigned only)

=item spaceship OVERLOADS C<E<lt>=E<gt>>.

(infix) elementwise "E<lt>=E<gt>" operation

=back

=head2 Unary functions

=for ref

These are used to overload unary operators/functions.

=for example

   $y = ~ $x;
   $x->inplace->bitnot;  # modify $x inplace

=over 2

=item bitnot

OVERLOAD ~. unary bit negation.

=item sqrt

elementwise square root.

=item abs

elementwise absolute value. Double, float, signed, long.

=item sin

the sin function

=item cos

the cos function

=item not

OVERLOAD !. The elementwise I<not> operation.

=item exp

the exponential function, doubles only.

=item log

the natural logarithm, doubles only.

=item log10

The base 10 logarithm. Doubles only. Works on scalars (returning scalars)
as well as piddles.

=back

=head1 AUTHOR

Tuomas J. Lukka (lukka@fas.harvard.edu),
Karl Glazebrook (kgb@aaoepp.aao.gov.au),
Doug Hunt (dhunt@ucar.edu),
Christian Soeller (c.soeller@auckland.ac.nz),
Doug Burke (burke@ifa.hawaii.edu),
and Craig DeForest (deforest@boulder.swri.edu).

=cut

1;

__DATA__

__Pdlapp__

pp_addhdr(<<'EOF');
#include <math.h>

/* MOD requires hackage to map properly into the positive-definite numbers. */
/* Note that this code causes some warning messages in the compile, because */
/* the unsigned data types always fail the ((foo)<0) tests.  I believe that */
/* gcc optimizes those tests away for those data types.  --CED 7-Aug-2002   */
/* Resurrect the old MOD operator as the unsigned BU_MOD to get around this. --DAL 27-Jun-2008 */
/* Q_MOD is the same as MOD except the internal casts are to longlong.  -DAL 18-Feb-2015 */
/* Also changed the typecast in MOD to (long), and added a N==0 conditional to BU_MOD. -DAL 06-Mar-2015 */

#define MOD(X,N) (  ((N) == 0)   ?    0   :   (   (X) - (ABS(N))  *  ((long     )((X)/(ABS(N))) + (   ( ((N) * ((long     )((X)/(N)))) != (X) )   ?   ( ( ((N)<0) ? 1 : 0 )  +  ( (((X)<0) ? -1 : 0)))  :  0 ))))

/* We assume that "long long" is ok for all Microsoft Compiler versions >= 1400. */
#if defined(_MSC_VER) && _MSC_VER < 1400
#define Q_MOD(X,N) (((N) == 0)   ?    0   :   (   (X) - (ABS(N))  *  ((__int64  )((X)/(ABS(N))) + (   ( ((N) * ((__int64  )((X)/(N)))) != (X) )   ?   ( ( ((N)<0) ? 1 : 0 )  +  ( (((X)<0) ? -1 : 0)))  :  0 ))))
#else
#define Q_MOD(X,N) (((N) == 0)   ?    0   :   (   (X) - (ABS(N))  *  ((long long)((X)/(ABS(N))) + (   ( ((N) * ((long long)((X)/(N)))) != (X) )   ?   ( ( ((N)<0) ? 1 : 0 )  +  ( (((X)<0) ? -1 : 0)))  :  0 ))))
#endif
#define BU_MOD(X,N)(((N) == 0)   ?    0   :   ( (X)-(N)*((int)((X)/(N))) ))
#define SPACE(A,B)   ( ((A)<(B)) ? -1 : ((A)!=(B)) )
#define ABS(A)       ( (A)>=0 ? (A) : -(A) )
#define NOTHING
EOF

sub protect_chars {
  my ($txt) = @_;
  $txt =~ s/>/E;gt#/g;
  $txt =~ s/</E;lt#/g;
  $txt =~ s/;/</g;
  $txt =~ s/#/>/g;
  return $txt;
}

# simple binary operators

sub biop {
    my ($name,$op,$swap,%extra) = @_;
    my $optxt = protect_chars ref $op eq 'ARRAY' ? $op->[1] : $op;
    $op = $op->[0] if ref $op eq 'ARRAY';

    if ($swap) {
	$extra{HdrCode} = << 'EOH';
  pdl *tmp;
  if (swap) {
    tmp = a;
    a = b;
    b = tmp;

  }
EOH
    }

    # handle exceptions
    my $badcode = '   ( $PDLASTATEISBAD(a) && $ISBAD(a()) )
                   || ( $PDLASTATEISBAD(b) && $ISBAD(b()) )';
    if ( exists $extra{Exception} ) {
	# NOTE This option is unused ($badcode is not set).
	#      See also `ufunc()`.
	delete $extra{Exception};
    }
    if( exists $extra{Comparison} && $PDLA::Config{WITH_BADVAL} ) {
	# *append* to header
	$extra{HdrCode} .= <<'EOH';
           {
             double bad_a, bad_b;
             ANYVAL_TO_CTYPE(bad_a, double, PDLA->get_pdl_badvalue(a));
             ANYVAL_TO_CTYPE(bad_b, double, PDLA->get_pdl_badvalue(b));
             if( bad_a == 0 || bad_a == 1 || bad_b == 0 || bad_b == 1 ) {
               warn("Badvalue is set to 0 or 1. This will cause data loss when using badvalues for comparison operators.");
             }
           }
EOH
    }

    pp_def($name,
	   Pars => 'a(); b(); [o]c();',
	   OtherPars => 'int swap',
	   HandleBad => 1,
	   NoBadifNaN => 1,
	   Inplace => [ 'a' ], # quick and dirty solution to get ->inplace do its job
	   Code =>
	   "\$c() = \$a() $op \$b();",
	   BadCode => qq{
	       if ( $badcode  )
	           \$SETBAD(c());
	       else
	           \$c() = \$a() $op \$b();
	   },
	   CopyBadStatusCode =>
	   'if ( $BADFLAGCACHE() ) {
               if ( a == c && $ISPDLASTATEGOOD(a) ) {
                  PDLA->propagate_badflag( c, 1 ); /* have inplace op AND badflag has changed */
               }
               $SETPDLASTATEBAD(c);
            }',
	   %extra,
    );
} # sub: biop()

#simple binary functions
sub bifunc {
    my ($name,$func,$swap,%extra) = @_;
    my $funcov = ref $func eq 'ARRAY' ? $func->[1] : $func;
    my $isop=0; if ($funcov =~ s/^op//) { $isop = 1; }
    my $funcovp = protect_chars $funcov;
    $func = $func->[0] if ref $func eq 'ARRAY';
    if ($swap) {
	$extra{HdrCode} .= << 'EOH';
  pdl *tmp;
  if (swap) {
    tmp = a;
    a = b;
    b = tmp;
  }
EOH
    }
    my $ovcall;
    # is this one to be used as a function or operator ?
    if ($isop) { $ovcall = "\$c = \$a $funcov \$b;    # overloaded use"; }
    else       { $ovcall = "\$c = $funcov \$a, \$b;    # overloaded use"; }


#a little dance to avoid the MOD macro warnings for byte & ushort datatypes
    my $codestr;
    my $badcodestr;
    if ($extra{unsigned}){
    $codestr = << "ENDCODE";
  types(BU) %{
  \$c() = BU_$func(\$a(),\$b());
  %}
  types(SLNFD) %{
  \$c() = $func(\$a(),\$b());
  %}
  types(Q) %{
  \$c() = Q_$func(\$a(),\$b());
  %}
ENDCODE
} else {
   $codestr = "\$c() = $func(\$a(),\$b());";
   }
 delete $extra{unsigned}; #remove the key so it doesn't get added in pp_def.

 $badcodestr = 'if ( $ISBAD(a()) || $ISBAD(b()) )
	       $SETBAD(c());
	       else {' . $codestr . " } \n";
#end dance

    pp_def($name,
	   HandleBad => 1,
	   NoBadifNaN => 1,
	   Pars => 'a(); b(); [o]c();',
	   OtherPars => 'int swap',
	   Inplace => [ 'a' ], # quick and dirty solution to get ->inplace do its job
	   Code => $codestr,
	   BadCode => $badcodestr,
	   CopyBadStatusCode =>
	   'if ( $BADFLAGCACHE() ) {
               if ( a == c && $ISPDLASTATEGOOD(a) ) {
                  PDLA->propagate_badflag( c, 1 ); /* have inplace op AND badflag has changed */
               }
               $SETPDLASTATEBAD(c);
            }',
	   %extra,
    );
} # sub: bifunc()

# simple unary functions and operators
sub ufunc {
    my ($name,$func,%extra) = @_;
    my $funcov = ref $func eq 'ARRAY' ? $func->[1] : $func;
    my $funcovp = protect_chars $funcov;
    $func = $func->[0] if ref $func eq 'ARRAY';

    # handle exceptions
    my $badcode = '$ISBAD(a())';
    if ( exists $extra{Exception} ) {
#	$badcode .= " || $extra{Exception}";
#	print "Warning: ignored exception for $name\n";
	# NOTE This option is unused ($badcode is commented out above).
	#      See also `biop()`.
	delete $extra{Exception};
    }

    # do not have to worry about propagation of the badflag when
    # inplace since only input piddle is a, hence its badflag
    # won't change
    # UNLESS an exception occurs...
    pp_def($name,
	   Pars => 'a(); [o]b()',
	   HandleBad => 1,
	   NoBadifNaN => 1,
	   Inplace => 1,
	   Code =>
	   "\$b() = $func(\$a());",
	   BadCode =>
	   'if ( ' . $badcode . ' )
	      $SETBAD(b());
	   else' . "\n  \$b() = $func(\$a());\n",
	   %extra,
    );
} # sub: ufunc()

######################################################################

# we trap some illegal operations here -- see the Exception option
# note, for the ufunc()'s, the checks do not work too well
#    for unsigned integer types (ie < 0)
#
# XXX needs thinking about
#    - have to integrate into Code section as well (so
#      12/pdl(2,4,0,3) is trapped and flagged bad)
#      --> complicated
#    - perhaps could use type %{ %} ?
#
# ==> currently have commented out the exception code, since
#     want to see if can use NaN/Inf for bad values
#     (would solve many problems for F,D types)
#
# there is an issue over how we handle comparison operators
# - see Primitive/primitive.pd/zcover() for more discussion
#

## arithmetic ops
# no swap needed but set anyway fixing sf bug #391
biop('plus','+',1);
biop('mult','*',1);

# all those need swapping
biop('minus','-',1);
biop('divide','/',1, Exception => '$b() == 0' );

## note: divide should perhaps trap division by zero as well

## comparison ops
# need swapping
biop('gt','>',1, Comparison => 1 );
biop('lt','<',1, Comparison => 1 );
biop('le','<=',1, Comparison => 1 );
biop('ge','>=',1, Comparison => 1 );
# no swap required but set anyway fixing sf bug #391
biop('eq','==',1, Comparison => 1 );
biop('ne','!=',1, Comparison => 1 );

## bit ops
# those need to be limited to the right types
my $T = [B,U,S,L,N,Q]; # the sensible types here
biop('shiftleft','<<',1,GenericTypes => $T);
biop('shiftright','>>',1,GenericTypes => $T);
biop('or2','|',1,GenericTypes => $T, Bitwise => 1);
biop('and2','&',1,GenericTypes => $T, Bitwise => 1);
biop('xor','^',1,GenericTypes => $T, Bitwise => 1);

# by itself to preserve order for diffing with ops.pd
ufunc('bitnot','~',GenericTypes => $T);

# some standard binary functions
bifunc('power',['pow','**'],1,GenericTypes => [D]);
bifunc('atan2','atan2',1,GenericTypes => [D]);
bifunc('modulo',['MOD','%'],1,unsigned=>1);
bifunc('spaceship',['SPACE','<=>'],1);

# some standard unary functions
ufunc('sqrt','sqrt', Exception => '$a() < 0' );
ufunc('abs',['ABS','abs'],GenericTypes => [D,F,S,L]);
ufunc('sin','sin');
ufunc('cos','cos');
ufunc('not','!');
ufunc('exp','exp',GenericTypes => [D]);
ufunc('log','log',GenericTypes => [D], Exception => '$a() <= 0' );

pp_export_nothing();

# make log10() work on scalars (returning scalars)
# as well as piddles
ufunc('log10','log10', GenericTypes => [D],
      Exception => '$a() <= 0',
      PMCode => # include PMCode anyway as this makes PP generate _log10_int
'
sub PDLA::log10 {
    my $x = shift;
    if ( ! UNIVERSAL::isa($x,"PDLA") ) { return log($x) / log(10); }
    my $y;
    if ( $x->is_inplace ) { $x->set_inplace(0); $y = $x; }
    elsif( ref($x) eq "PDLA"){
       #PDLA Objects, use nullcreate:
       $y = PDLA->nullcreate($x);
    }else{
       #PDLA-Derived Object, use copy: (Consistent with
       #  Auto-creation docs in Objects.pod)
       $y = $x->copy;
    }
    &PDLA::_log10_int( $x, $y );
    return $y;
};
'
);

# note: the extra code that adding 'HandleBad => 1' creates is
# unneeded here. Things could be made clever enough to work this out,
# but it's very low priority.
# It does add doc information though, and lets people know it's been
# looked at for bad value support
# DJB adds: not completely sure about this now that I have added code
# to avoid a valgrind-reported error (see the CacheBadFlagInit rule
# in PP.pm)
#
# Can't this be handled in Core.pm when '.=' is overloaded ?
#
pp_def(
       'assgn',
       HandleBad => 1,
       Pars => 'a(); [o]b();',
       Code =>
       '$b() = $a();',
       BadCode =>
       'if ( $ISBAD(a()) ) { $SETBAD(b()); } else { $b() = $a(); }',
); # pp_def assgn

pp_def('ipow',
   Pars => 'a(); b(); [o] ans()',
   Code => pp_line_numbers(__LINE__, q{
      PDLA_Indx n = $b();
      $GENERIC() y = 1;
      $GENERIC() x = $a();
      if (n < 0) {
         x = 1 / x;
         n = -n;
      }
      if (n == 0) {
         $ans() = 1;
      } else {
          while (n > 1) {
             if (n % 2 == 0) {
                x = x * x;
                n = n / 2;
             } else {
                y = x * y;
                x = x * x;
                n = (n - 1) / 2;
             }
         }
         $ans() = x * y;
      }
   })
);


#pp_export_nothing();

pp_done();