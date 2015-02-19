package PDL::Ufunc;

use strict;
use warnings;
use PDL::Ufunc::Inline Pdlpp => 'DATA';
use parent 'PDL::Exporter';
use PDL::Core;
use PDL::Slices;
use Carp;

our @EXPORT_OK = qw(any all);
our %EXPORT_TAGS = (Func=>\@EXPORT_OK);

sub import_export {
    my ($func) = @_;
    push @EXPORT_OK, $func;
    no strict 'refs';
    *$func = \&{"PDL::$func"};
}

for my $func (qw(
    sumover dsumover cumusumover dcumusumover prodover dprodover
    cumuprodover dcumuprodover borover andover orover bandover zcover
    intover average daverage medover oddmedover modeover pctover
    oddpctover pct oddpct avg sum prod davg dsum dprod zcheck and band
    or bor min max median mode oddmedian
    minmax qsort qsorti
    qsortvec qsortveci minimum minimum_ind minimum_n_ind maximum
    maximum_ind maximum_n_ind minmaximum
)) {
    import_export($func);
}

*any = \&or;
*PDL::any = \&PDL::or;
*all = \&and;
*PDL::all = \&PDL::and;

sub PDL::pct {
	my($x, $p) = @_; 
    my $tmp;
	$x->clump(-1)->pctover($p, $tmp=PDL->nullcreate($x));
	return $tmp->at();
}

sub PDL::oddpct {
	my($x, $p) = @_; 
    my $tmp;
	$x->clump(-1)->oddpctover($p, $tmp=PDL->nullcreate($x));
	return $tmp->at();
}

sub PDL::avg {
	my($x) = @_; my $tmp;
	$x->clump(-1)->average( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::sum {
	my($x) = @_; my $tmp;
	$x->clump(-1)->sumover( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::prod {
	my($x) = @_; my $tmp;
	$x->clump(-1)->prodover( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::davg {
	my($x) = @_; my $tmp;
	$x->clump(-1)->daverage( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::dsum {
	my($x) = @_; my $tmp;
	$x->clump(-1)->dsumover( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::dprod {
	my($x) = @_; my $tmp;
	$x->clump(-1)->dprodover( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::zcheck {
	my($x) = @_; my $tmp;
	$x->clump(-1)->zcover( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::and {
	my($x) = @_; my $tmp;
	$x->clump(-1)->andover( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::band {
	my($x) = @_; my $tmp;
	$x->clump(-1)->bandover( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::or {
	my($x) = @_; my $tmp;
	$x->clump(-1)->orover( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::bor {
	my($x) = @_; my $tmp;
	$x->clump(-1)->borover( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::min {
	my($x) = @_; my $tmp;
	$x->clump(-1)->minimum( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::max {
	my($x) = @_; my $tmp;
	$x->clump(-1)->maximum( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::median {
	my($x) = @_; my $tmp;
	$x->clump(-1)->medover( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::mode {
	my($x) = @_; my $tmp;
	$x->clump(-1)->modeover( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::oddmedian {
	my($x) = @_; my $tmp;
	$x->clump(-1)->oddmedover( $tmp=PDL->nullcreate($x) );
	return $tmp->at();
}

sub PDL::minmax {
  my ($x)=@_; my $tmp;
  my @arr = $x->clump(-1)->minmaximum;
  return map {$_->sclr} @arr[0,1]; # return as scalars !
}

1;

__DATA__

__Pdlpp__

use strict; # be careful

# check for bad value support
use PDL::Config;
my $bvalflag = $PDL::Config{WITH_BADVAL} || 0;

# should we use the finite() routine in libm ?
# (is the Windows version _finite() ?)
#
pp_addhdr(<<'EOD');
#define IsNaN(x) (x*0 != 0)
EOD

# it's a bit unclear what to do with the comparison operators,
# since the return value could be bad because all elements are bad,
# which needs checking for since the bad value could evaluate to 
# true or false (eg if the user has set it to 0)
#
# by setting CopyBadStatusCode to '', we stop the output piddle
# from automatically being set bad if any of the input piddles are bad.
# - we can set the flag within BadCode if necessary
#
# This may NOT be sensible. Only time, and comments, will tell...
#

my %over = 
    (
     sumover  => { name => 'sum',     op => '+=', init => 0, },
     prodover => { name => 'product', op => '*=', init => 1, },
     );

foreach my $func ( keys %over ) {

    # creates $func and cumu$func functions
    # and d$func and dcumu$func functions, which
    # perform the calculations in double precision
    
    my $name = $over{$func}{name};
    my $op   = $over{$func}{op};
    my $init = $over{$func}{init};

    pp_def(
	   $func,
	   HandleBad => 1,
	   Pars => 'a(n); int+ [o]b();',
	   Code => 
	   '$GENERIC(b) tmp = ' . $init . ';
	    loop(n) %{ tmp ' . $op . ' $a(); %}
	    $b() = tmp;',
	   BadCode => 
	   '$GENERIC(b) tmp = ' . $init . ';
            int flag = 0;
	    loop(n) %{ 
               if ( $ISGOOD(a()) ) { tmp ' . $op . ' $a(); flag = 1; }
            %}
            if ( flag ) { $b() = tmp; }
            else        { $SETBAD(b()); }',
	   );

    # as above, but in double precision
    pp_def(
	   "d$func",
	   HandleBad => 1,
	   Pars => 'a(n); double [o]b();',
	   Code => 
	   'double tmp = ' . $init . ';
	    loop(n) %{ tmp ' . $op . ' $a(); %}
	    $b() = tmp;',
	   BadCode => 
	   'double tmp = ' . $init . ';
            int flag = 0;
	    loop(n) %{ 
               if ( $ISGOOD(a()) ) { tmp ' . $op . ' $a(); flag = 1; }
            %}
            if ( flag ) { $b() = tmp; }
            else        { $SETBAD(b()); }',
	   );

    my $cfunc = "cumu${func}";
    pp_def(
	   $cfunc,
	   HandleBad => 1,
	   Pars => 'a(n); int+ [o]b(n);',
	   Code => 
           '$GENERIC(b) tmp = ' . $init . ';
	    loop(n) %{ 
               tmp ' . $op . ' $a();
	       $b() = tmp;
	    %}',
	   BadCode => 
	   '$GENERIC(b) tmp = ' . $init . ';
	    loop(n) %{ 
               if ( $ISBAD(a()) ) { $SETBAD(b()); }
               else {
                  tmp ' . $op . ' $a();
	          $b() = tmp;
               }
	    %}',
	   );

    # as above but in double precision
    pp_def(
	   "d$cfunc",
	   HandleBad => 1,
	   Pars => 'a(n); double [o]b(n);',
	   Code => 
           'double tmp = ' . $init . ';
	    loop(n) %{ 
               tmp ' . $op . ' $a();
	       $b() = tmp;
	    %}',
	   BadCode => 
	   'double tmp = ' . $init . ';
	    loop(n) %{ 
               if ( $ISBAD(a()) ) { $SETBAD(b()); }
               else {
                  tmp ' . $op . ' $a();
	          $b() = tmp;
               }
	    %}',
	   );

} # foreach: my $func


%over = 
    (
     zcover   => { def=>'char tmp', txt => '== 0', init => 1, alltypes => 1,
		   op => 'tmp &= ($a() == 0);', check => '!tmp' },
     andover  => { def=>'char tmp', txt => 'and', init => 1, alltypes => 1, 
		   op => 'tmp &=  ($a() != 0);', check => '!tmp' },
     bandover => { def=>'$GENERIC(b) tmp', txt => 'bitwise and', init => '~0', 
		   op => 'tmp &= $a();', check => '!tmp' },
     orover   => { def=>'char tmp', txt => 'or', init => 0, alltypes => 1, 
		   op => 'tmp |= ($a() != 0);', check => 'tmp' },
     borover  => { def=>'$GENERIC(b) tmp', txt => 'bitwise or', init => 0, 
		   op => 'tmp |= $a() ;', check => '!~tmp' },

     );

foreach my $func ( keys %over ) {

    my $def   = $over{$func}{def};
    my $txt   = $over{$func}{txt};
    my $init  = $over{$func}{init};
    my $op    = $over{$func}{op};
    my $check = $over{$func}{check};

    my %extra = {};
    unless ( defined $over{$func}{alltypes} and $over{$func}{alltypes} ) {
	$extra{GenericTypes} = ['B','S','U','L'];
    }

    pp_def(
	   $func,
	   HandleBad => 1,
	   %extra,
	   Pars => 'a(n); int+ [o]b();',
	   Code =>
	   $def . '=' . $init . ';
            loop(n) %{ ' . $op . ' if (' . $check . ') break; %}
            $b() = tmp;',
	   BadCode => 
	   'char tmp = ' . $init . ';
	    $GENERIC(b) gtmp = '. $init . ';
            int flag = 0;
            loop(n) %{
               if ( $ISGOOD(a()) ) { ' . $op . ' flag = 1; if (' . $check . ') break; }
            %}
            if ( flag ) { $b() = tmp; }
            else        { $SETBAD(b()); $PDLSTATESETBAD(b); }',
	   CopyBadStatusCode => '',
	   );

} # foreach: $func

# this would need a lot of work to support bad values
# plus it gives me a chance to check out HandleBad => 0 ;)
#
pp_def(
       'intover',
       HandleBad => 0,
       Pars => 'a(n); int+ [o]b();',
       Code =>
       '$GENERIC(b) tmp = 0;
       PDL_Indx ns = $SIZE(n), nn;
       /* Integration formulae from Press et al 2nd Ed S 4.1 */
       switch (ns) {
      case 1:
          threadloop %{
          $b() = 0.; /* not a(n=>0); as interval has zero width */
          %}
          break;
        case 2:
          threadloop %{
          $b() = 0.5*($a(n=>0)+$a(n=>1));
          %}
          break;
        case 3:
          threadloop %{
          $b() = ($a(n=>0)+4*$a(n=>1)+$a(n=>2))/3.;
          %}
          break;
      case 4:
          threadloop %{
          $b() = ($a(n=>0)+$a(n=>3)+3.*($a(n=>1)+$a(n=>2)))*0.375;
          %}
          break;
      case 5:
          threadloop %{
          $b() = (14.*($a(n=>0)+$a(n=>4))
                   +64.*($a(n=>1)+$a(n=>3))
                   +24.*$a(n=>2))/45.;
          %}
          break;
      default:
          threadloop %{
        for (nn=3,tmp=0;nn<ns-3;nn++) { tmp += $a(n=>nn); }
        tmp += (23./24.)*($a(n=>2)+$a(n=>nn));nn++;
        tmp += (7./6.)  *($a(n=>1)+$a(n=>nn));nn++;
        tmp += 0.375    *($a(n=>0)+$a(n=>nn));
        $b() = tmp;
          %}
      }
      ',
); # intover

pp_def( 
	'average',
	HandleBad => 1,
	Pars => 'a(n); int+ [o]b();',
	Code => 
	'$GENERIC(b) tmp = 0;
	if($SIZE(n)) {
	   loop(n) %{ tmp += $a(); %} ; 
   	   $b() = tmp / ($GENERIC(b)) $SIZE(n);
        }
          else { $GENERIC(b) foo = 0.25; 
	         if(foo == 0) {  /* Cheesy check for floating-pointiness */
	             $b() = 0;   /* Integer - set to 0 */
	          } else {
	             $b() = sqrt(-1);  /* Cheesy NaN -- CED */
		 }
	        }',

	BadCode => 
	'$GENERIC(b) tmp = 0;
         PDL_Indx cnt = 0;
	 loop(n) %{ 
            if ( $ISGOOD(a()) ) { tmp += $a(); cnt++; }
         %}
         if ( cnt ) { $b() = tmp / ($GENERIC(b)) cnt; }
         else       { $SETBAD(b()); }',
	);

# do the above calculation, but in double precision
pp_def( 
	'daverage',
	HandleBad => 1,
	Pars => 'a(n); double [o]b();',
	Code => 
	'double tmp = 0;
	if($SIZE(n)) {
	 loop(n) %{ tmp += $a(); %}
	 $b() = tmp / $SIZE(n); 
	}
	  else { $b() = 0; }',
	BadCode => 
	'double tmp = 0;
         PDL_Indx cnt = 0;
	 loop(n) %{ 
            if ( $ISGOOD(a()) ) { tmp += $a(); cnt++; }
         %}
         if ( cnt ) { $b() = tmp / cnt; }
         else       { $SETBAD(b()); }',
	);

# Internal utility sorting routine for median/qsort/qsortvec routines.
#
# note: we export them to the PDL Core structure for use in
#       other modules (eg Image2D)

for (keys %PDL::Types::typehash) {
    my $ctype = $PDL::Types::typehash{$_}{ctype};
    my $ppsym = $PDL::Types::typehash{$_}{ppsym};

    pp_add_boot( " PDL->qsort_${ppsym} = pdl_qsort_${ppsym};" .
		 " PDL->qsort_ind_${ppsym} = pdl_qsort_ind_${ppsym};\n" );

    pp_addhdr(<<"FOO"

      void pdl_qsort_$ppsym($ctype* xx, PDL_Indx a, PDL_Indx b) {

         PDL_Indx i,j;

         $ctype t, median;

         i = a; j = b;
         median = xx[(i+j) / 2];
         do {
            while (xx[i] < median)
               i++;
            while (median < xx[j])
               j--;
            if (i <= j) {
               t = xx[i]; xx[i] = xx[j]; xx[j] = t;
               i++; j--;
            }
         } while (i <= j);

         if (a < j)
            pdl_qsort_$ppsym(xx,a,j);
         if (i < b)
            pdl_qsort_$ppsym(xx,i,b);

      }

      void pdl_qsort_ind_$ppsym($ctype* xx,  PDL_Indx* ix, PDL_Indx a, PDL_Indx b) {

         PDL_Indx i,j;

         PDL_Indx t;
        $ctype median;

         i = a; j = b;
         median = xx[ix[(i+j) / 2]];

         do {
          while (xx[ix[i]] < median)
               i++;
            while (median < xx[ix[j]])
               j--;
            if (i <= j) {
               t = ix[i]; ix[i] = ix[j]; ix[j] = t;
               i++; j--;
            }
         } while (i <= j);

         if (a < j)
            pdl_qsort_ind_$ppsym(xx,ix,a,j);
         if (i < b)
            pdl_qsort_ind_$ppsym(xx,ix,i,b);

      }


	/*******
         * qsortvec helper routines
	 *   --CED 21-Aug-2003
	 */

	/* Compare a vector in lexicographic order, returning the
	 *  equivalent of "<=>". 
 	 */
      signed char pdl_cmpvec_$ppsym($ctype *a, $ctype *b, PDL_Indx n) {
	PDL_Indx i;
	for(i=0; i<n; a++,b++,i++) {
	 if( *a < *b ) return -1;
	 if( *a > *b ) return 1;
	}
	return 0;
     }	
	
      void pdl_qsortvec_$ppsym($ctype *xx, PDL_Indx n, PDL_Indx a, PDL_Indx b) {
		
	PDL_Indx i,j, median_ind;

	$ctype t;
	i = a; 
	j = b;

	median_ind = (i+j)/2;

	do {
	  while( pdl_cmpvec_$ppsym( &(xx[n*i]), &(xx[n*median_ind]), n )  <  0 ) 
		i++;
	  while( pdl_cmpvec_$ppsym( &(xx[n*j]), &(xx[n*median_ind]), n )  >  0 ) 
		j--;
	  if(i<=j) {
		PDL_Indx k;
		$ctype *aa = &xx[n*i];
	        $ctype *bb = &xx[n*j];
		for( k=0; k<n; aa++,bb++,k++ ) {
		  $ctype z;
		  z = *aa;
		  *aa = *bb;
		  *bb = z;	
		}

                if (median_ind==i)
                  median_ind=j;
                else if (median_ind==j)
                  median_ind=i;

	        i++; 
		j--;
	  }
	} while (i <= j);
	
	if (a < j)
	  pdl_qsortvec_$ppsym( xx, n, a, j );
	if (i < b)
	  pdl_qsortvec_$ppsym( xx, n, i, b );
	
      }

      void pdl_qsortvec_ind_$ppsym($ctype *xx, PDL_Indx *ix, PDL_Indx n, PDL_Indx a, PDL_Indx b) {
		
	PDL_Indx i,j, median_ind;

	$ctype t;
	i = a; 
	j = b;

	median_ind = (i+j)/2;

	do {
	  while( pdl_cmpvec_$ppsym( &(xx[n*ix[i]]), &(xx[n*ix[median_ind]]), n )  <  0 ) 
		i++;
	  while( pdl_cmpvec_$ppsym( &(xx[n*ix[j]]), &(xx[n*ix[median_ind]]), n )  >  0 ) 
		j--;
	  if(i<=j) {
		PDL_Indx k;
	        k = ix[i];
	        ix[i] = ix[j];
		ix[j] = k;	        

                if (median_ind==i)
                  median_ind=j;
                else if (median_ind==j)
                  median_ind=i;

	        i++; 
		j--;
	  }
	} while (i <= j);
	
	if (a < j)
	  pdl_qsortvec_ind_$ppsym( xx, ix, n, a, j );
	if (i < b)
	  pdl_qsortvec_ind_$ppsym( xx, ix, n, i, b );
	
      }

FOO
   );
}

# when copying the data over to the temporary array,
# ignore the bad values and then only send the number
# of good elements to the sort routines
#

sub generic_qsort {
    my $pdl = shift;
    return '$TBSULNQFDA(pdl_qsort_B,pdl_qsort_S,pdl_qsort_U,
             pdl_qsort_L,pdl_qsort_N,pdl_qsort_Q,pdl_qsort_F,pdl_qsort_D,pdl_qsort_D) ($P(' . $pdl . '), 0, nn);';
}

sub generic_qsortvec {
    my $pdl = shift;
    my $ndim = shift;
    return '$TBSULNQFDA(pdl_qsortvec_B,pdl_qsortvec_S,pdl_qsortvec_U,
             pdl_qsortvec_L,pdl_qsortvec_N,pdl_qsortvec_Q,pdl_qsortvec_F,pdl_qsortvec_D,pdl_qsortvec_D) ($P(' . $pdl . '), '. $ndim.', 0, nn);';
}


# should use threadloop ?
#
my $copy_to_temp_good = '
           PDL_Indx nn, nn1;
	   loop(n) %{ $tmp() = $a(); %}
           nn = $COMP(__n_size)-1; ' .
       generic_qsort('tmp');

my $copy_to_temp_bad = '
        register PDL_Indx nn = 0;
	loop(n) %{ 
           if ( $ISGOOD(a()) ) { $tmp(n=>nn) = $a(); nn++; }
        %}
        if ( nn == 0 ) {
           $SETBAD(b());
        } else {
';

my $find_median_average = '
           nn1 = nn/2; nn2 = nn1+1;
           if (nn%2==0) {
	      $b() = $tmp(n => nn1);
           }
           else {
	      $b() = 0.5*( $tmp(n => nn1) + $tmp(n => nn2)  );
           }';

my $find_median_lower = '
        nn1 = nn/2;
	$b() = $tmp(n => nn1);';

pp_def(
       'medover',
       HandleBad => 1,
       Pars => 'a(n); [o]b(); [t]tmp(n);',
       Code => 
       "PDL_Indx nn2;\n" . $copy_to_temp_good . $find_median_average,
       BadCode =>
       $copy_to_temp_bad . 
       '   PDL_Indx nn1, nn2;
           nn -= 1; ' .
       generic_qsort('tmp') .
       $find_median_average . '}',

       ); # pp_def: medover

pp_def(
       'oddmedover',
       HandleBad => 1,
       Pars => 'a(n); [o]b(); [t]tmp(n);',
       Code => 
       $copy_to_temp_good . $find_median_lower,
       BadCode =>
       $copy_to_temp_bad . 
       '   PDL_Indx nn1;
           nn -= 1; '.
       $find_median_lower . '}',

); # pp_def: oddmedover


pp_def('modeover',
       HandleBad=>undef,
       Pars => 'data(n); [o]out(); [t]sorted(n);',
       GenericTypes=>['B','S','U','L','Q','N'],
	 Code => <<'EOCODE',
	       PDL_Indx i = 0;
	       PDL_Indx most = 0;
	       $GENERIC() curmode;
               $GENERIC() curval;

               /* Copy input to buffer for sorting, and sort it */
               loop(n) %{ $sorted() = $data(); %}
               PDL->$TBSULNQ(qsort_B,qsort_S,qsort_U,qsort_L,qsort_N,qsort_Q)($P(sorted),0,$SIZE(n)-1);
      
               /* Walk through the sorted data and find the most common elemen */
               loop(n) %{
                   if( n==0 || curval != $sorted() ) {
	             curval = $sorted();
	             i=0;
	           } else {
	             i++;
	             if(i>most){
	                most=i;
                        curmode = curval;
	             }
	          }
               %}
               $out() = curmode;
EOCODE
    );

my $find_pct_interpolate = '
           np = nn * $p();
           nn1 = np;
           nn2 = nn1+1;
           
           nn1 = (nn1 < 0) ? 0 : nn1;
           nn2 = (nn2 < 0) ? 0 : nn2;
           
           nn1 = (nn1 > nn) ? nn : nn1;
           nn2 = (nn2 > nn) ? nn : nn2;
           
	   if (nn == 0) {
	      pp1 = 0;
	      pp2 = 0;
	   } else {
	      pp1 = (double)nn1/(double)(nn);
	      pp2 = (double)nn2/(double)(nn);
	   }
           
           if ( np <= 0.0 ) {
              $b() = $tmp(n => 0);
           } else if ( np >= nn ) {
              $b() = $tmp(n => nn);
           } else if ($tmp(n => nn2) == $tmp(n => nn1)) {
              $b() = $tmp(n => nn1);
           } else if ($p() == pp1) {
              $b() = $tmp(n => nn1);
           } else if ($p() == pp2) {
              $b() = $tmp(n => nn2);
           } else {
              $b() = (np - nn1)*($tmp(n => nn2) - $tmp(n => nn1)) + $tmp(n => nn1);
           }
';

pp_def('pctover',
        HandleBad => 1,
        Pars => 'a(n); p(); [o]b(); [t]tmp(n);',
        Code => '
           double np, pp1, pp2;
           PDL_Indx nn2;
	   ' . $copy_to_temp_good .
           $find_pct_interpolate,
       BadCode =>
       $copy_to_temp_bad .  '
           PDL_Indx nn1, nn2;
           double np, pp1, pp2;
           nn -= 1; ' .  generic_qsort('tmp') .
           $find_pct_interpolate . '}',

); 

pp_def('oddpctover',
        HandleBad => 1,
        Pars => 'a(n); p(); [o]b(); [t]tmp(n);',
        Code => '
           PDL_Indx np;
	   ' . $copy_to_temp_good . '
           np = (nn+1)*$p();
           if (np > nn) np = nn;
           if (np < 0) np = 0;
	   $b() = $tmp(n => np);
',
       BadCode => 'PDL_Indx np;
       ' . $copy_to_temp_bad . '
           nn -= 1;
           ' .  generic_qsort('tmp') . '
           np = (nn+1)*$p();
           if (np > nn) np = nn;
           if (np < 0) np = 0;
	   $b() = $tmp(n => np);
        }',
);

pp_add_exported('', 'pct');

pp_add_exported('', 'oddpct');

# Generate small ops functions to do entire array
#
# How to handle a return value of BAD - ie what
# datatype to use?
#
for my $op ( ['avg','average','average'],
	     ['sum','sumover','sum'],
	     ['prod','prodover','product'],

	     ['davg','daverage','average (in double precision)'],
	     ['dsum','dsumover','sum (in double precision)'],
	     ['dprod','dprodover','product (in double precision)'],

	     ['zcheck','zcover','check for zero'],
	     ['and','andover','logical and'],
	     ['band','bandover','bitwise and'],
	     ['or','orover','logical or'],
	     ['bor','borover','bitwise or'],
	     ['min','minimum','minimum'],
	     ['max','maximum','maximum'],
	     ['median', 'medover', 'median'],
	     ['mode', 'modeover', 'mode'],
	     ['oddmedian','oddmedover','oddmedian']) {
    my $name = $op->[0];
    my $func = $op->[1];
    my $text = $op->[2];
   pp_add_exported('', $name);

} # for $op

pp_add_exported('','any all');

pp_add_exported('', 'minmax');
#pp_add_exported('', 'minmax_ind');

# move all bad values to the end of the array
#
pp_def(
    'qsort',
    HandleBad => 1,
    Inplace => 1,
    Pars => 'a(n); [o]b(n);',
    Code => 
    'PDL_Indx nn;
     loop(n) %{ $b() = $a(); %}
     nn = $COMP(__n_size)-1;
    ' . generic_qsort('b'),
    BadCode =>
    'register PDL_Indx nn = 0, nb = $SIZE(n) - 1;
     loop(n) %{ 
        if ( $ISGOOD(a()) ) { $b(n=>nn) = $a(); nn++; }
        else                { $SETBAD(b(n=>nb)); nb--; }
     %}
     if ( nn != 0 ) {
        nn -= 1;
     ' . generic_qsort('b') . ' }',
    ); # pp_def qsort

sub generic_qsort_ind {
    return '$TBSULNQFDA(pdl_qsort_ind_B,pdl_qsort_ind_S,pdl_qsort_ind_U,
            pdl_qsort_ind_L,pdl_qsort_ind_N,pdl_qsort_ind_Q,pdl_qsort_ind_F,pdl_qsort_ind_D,pdl_qsort_ind_D) ($P(a), $P(indx),
            0, nn);';
}

pp_def(
       'qsorti',
       HandleBad => 1,
       Pars => 'a(n); indx [o]indx(n);',
       Code => 
       'PDL_Indx nn = $COMP(__n_size)-1;
        if ($SIZE(n) == 0) return;
        loop(n) %{ 
           $indx() = n; 
        %}
       ' . generic_qsort_ind(),
       BadCode =>
       'register PDL_Indx nn = 0, nb = $SIZE(n) - 1;
        if ($SIZE(n) == 0) return;
        loop(n) %{ 
           if ( $ISGOOD(a()) ) { $indx(n=>nn) = n; nn++; } /* play safe since nn used more than once */ 
           else                { $indx(n=>nb) = n; nb--; }
        %}
        if ( nn != 0 ) {
           nn -= 1;
        ' . generic_qsort_ind() . ' }',
       ); # pp_def: qsorti

# move all bad values to the end of the array
#
pp_def(
    'qsortvec',
    HandleBad => 1,
    Inplace => 1,
    Pars => 'a(n,m); [o]b(n,m);',
    Code => 
    'PDL_Indx nn;
     PDL_Indx nd;
     loop(n,m) %{ $b() = $a(); %}
     nn = ($COMP(__m_size))-1;
     nd = $COMP(__n_size);
    ' . generic_qsortvec('b','nd'),
    ); # pp_def qsort

sub generic_qsortvec_ind {
    my $pdl = shift;
    my $ndim = shift;
    return '$TBSULNQFDA(pdl_qsortvec_ind_B,pdl_qsortvec_ind_S,pdl_qsortvec_ind_U,
             pdl_qsortvec_ind_L,pdl_qsortvec_ind_N,pdl_qsortvec_ind_Q,pdl_qsortvec_ind_F,pdl_qsortvec_ind_D,pdl_qsortvec_ind_D) ($P(' . $pdl . '), $P(indx), '. $ndim.', 0, nn);';
}

pp_def(
    'qsortveci',
    HandleBad => 1,
    Pars => 'a(n,m); indx [o]indx(m);',
    Code => 
    'PDL_Indx nd;
     PDL_Indx nn=$COMP(__m_size)-1;
     loop(m) %{
        $indx()=m;
     %}
     nd = $COMP(__n_size);
    ' . generic_qsortvec_ind('a','nd'),
    ); 

for my $which (
	       ['minimum','<'],
	       ['maximum','>'] 
	       ) {
    my $name = $which->[0];
    my $op   = $which->[1];

    pp_def( 
	    $name,
	    HandleBad => 1,
	    Pars => 'a(n); [o]c();', 
	    Code => 
	    '$GENERIC() cur;
	     int flag = 0;
	     loop(n) %{
	 	if( !flag || ($a() '.$op.' cur ) || IsNaN(cur) ) { cur = $a(); flag = 1;}
	     %}
	     if(flag && !IsNaN(cur)) {
	     	     $c() = cur;
             } else {
	     ' . ($bvalflag ? '
	             $SETBAD(c());
		     $PDLSTATESETBAD(c);
	     ' : '
                     $c() = 0.25;
                     if($c()>0)
                       $c() = sqrt(-1);
             ' ) . '
             }     
		     ',
	    BadCode => 
	    '$GENERIC() cur;
             int flag = 0;
	     loop(n) %{
	 	if( $ISGOOD(a()) && ($a()*0 == 0) && (!flag || $a() '.$op.' cur)) {cur = $a(); flag = 1;}
	     %}
             if ( flag ) { $c() = cur; }
             else        { $SETBAD(c()); $PDLSTATESETBAD(c); }',
	    CopyBadStatusCode => '',
	    );

    pp_def( 
	    "${name}_ind",
	    HandleBad => 1,
	    Pars => 'a(n); indx [o] c();', 
	    Code => 
	    '$GENERIC() cur;
             PDL_Indx curind;
	     int flag = 0;
	     loop(n) %{
	 	if(!flag || $a() '.$op.' cur || IsNaN(cur))
		   {cur = $a(); curind = n;flag=1;}
	     %}
	     if(flag && !IsNaN(cur)) {
	       $c() = curind;
  	     } else { '
	     . ($bvalflag ? '
	          $SETBAD(c());
                  $PDLSTATESETBAD(c);
	     ' : '
	       $c() = 0.25;      /* check for floatiness */
	       if($c() == 0) {
	          $c() = -1;     /* put a nonsensical value in */
	       } else {
	          $c() = sqrt(-1);  /* NaN if possible */
	       }
             ') . '
	     }
	       ',
	    BadCode => 
	    '$GENERIC() cur;
             PDL_Indx curind; int flag = 0; /* should set curind to -1 and check for that, then do not need flag */
	     loop(n) %{
	 	if( $ISGOOD(a()) && (!flag || $a() '.$op.' cur)) 
                   {cur = $a(); curind = n; flag = 1;}
	     %}
             if ( flag && !IsNaN(cur) ) { $c() = curind; }
             else        { $SETBAD(c()); $PDLSTATESETBAD(c); }',
	    CopyBadStatusCode => '',
	    );

    pp_def( 
	    "${name}_n_ind",
	    HandleBad => 0,   # just a marker 
	    Pars => 'a(n); indx [o]c(m);',
	    Code =>
	    '$GENERIC() cur; PDL_Indx curind; register PDL_Indx ns = $SIZE(n);
	     if($SIZE(m) > $SIZE(n)) $CROAK("n_ind: m_size > n_size");
	     loop(m) %{
		 curind = ns;
		 loop(n) %{
		 	PDL_Indx nm; int flag=0;
		 	for(nm=0; nm<m; nm++) {
				if($c(m=>nm) == n) {flag=1; break;}
			}
			if(!flag &&
			   ((curind == ns) || $a() '.$op.' cur || IsNaN(cur)))
				{cur = $a(); curind = n;}
		 %}
		 $c() = curind;
	     %}',
	    );

} # foreach: $which

# removed IsNaN handling, even from Code section
# I think it was wrong, since it was
#
#   if (!n || ($a() < curmin) || IsNaN(curmin)) {curmin = $a(); curmin_ind = n;};
#   if (!n || ($a() > curmax) || IsNaN(curmax)) {curmax = $a(); curmax_ind = n;};
#
# surely this succeeds if cur... is a NaN??
#
pp_def( 
	'minmaximum',
	HandleBad => 1,
	Pars => 'a(n); [o]cmin(); [o] cmax(); indx [o]cmin_ind(); indx [o]cmax_ind();',
	Code => 
	'$GENERIC() curmin, curmax;
         PDL_Indx curmin_ind, curmax_ind;

 	 curmin = curmax = 0; /* Handle null piddle --CED */

	 loop(n) %{
            if ( !n ) {
               curmin = curmax = $a();
               curmin_ind = curmax_ind = n;
            } else {
               if ( $a() < curmin ) { curmin = $a(); curmin_ind = n; }
	       if ( $a() > curmax ) { curmax = $a(); curmax_ind = n; }
            }
	 %}
	 $cmin() = curmin; $cmin_ind() = curmin_ind;
         $cmax() = curmax; $cmax_ind() = curmax_ind;',
	CopyBadStatusCode => '',
	BadCode => 
	'$GENERIC() curmin, curmax;
         PDL_Indx curmin_ind, curmax_ind; int flag = 0;
	
	 loop(n) %{
            if ( $ISGOOD(a()) ) {
               if ( !flag ) {
                  curmin = curmax = $a();
                  curmin_ind = curmax_ind = n;
                  flag = 1;
               } else {
                  if ( $a() < curmin ) { curmin = $a(); curmin_ind = n; }
                  if ( $a() > curmax ) { curmax = $a(); curmax_ind = n; }
               }
            } /* ISGOOD */
	 %}
         if ( flag ) { /* Handle null piddle */
            $cmin() = curmin; $cmin_ind() = curmin_ind;
            $cmax() = curmax; $cmax_ind() = curmax_ind;
         } else {
            $SETBAD(cmin()); $SETBAD(cmin_ind());
            $SETBAD(cmax()); $SETBAD(cmax_ind());
            $PDLSTATESETBAD(cmin); $PDLSTATESETBAD(cmin_ind);
            $PDLSTATESETBAD(cmax); $PDLSTATESETBAD(cmax_ind);
         }',
	); # pp_def minmaximum

__END__

=head1 NAME

PDL::Ufunc - primitive ufunc operations for pdl

=head1 DESCRIPTION

This module provides some primitive and useful functions defined
using PDL::PP based on functionality of what are sometimes called
I<ufuncs> (for example NumPY and Mathematica talk about these).
It collects all the functions generally used to C<reduce> or
C<accumulate> along a dimension. These all do their job across the
first dimension but by using the slicing functions you can do it
on any dimension.

The L<PDL::Reduce|PDL::Reduce> module provides an alternative interface
to many of the functions in this module.

=head1 SYNOPSIS

 use PDL::Ufunc;

=head1 FUNCTIONS

=head2 sumover

=for sig

  Signature: (a(n); int+ [o]b())

=for ref

Project via sum to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the sum along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = sumover($a);

=for example

 $spectrum = sumover $image->xchg(0,1)

=for bad

sumover processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 dsumover

=for sig

  Signature: (a(n); double [o]b())

=for ref

Project via sum to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the sum along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = dsumover($a);

=for example

 $spectrum = dsumover $image->xchg(0,1)

Unlike L<sumover|/sumover>, the calculations are performed in double
precision.

=for bad

dsumover processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 cumusumover

=for sig

  Signature: (a(n); int+ [o]b(n))

=for ref

Cumulative sum

This function calculates the cumulative sum
along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

The sum is started so that the first element in the cumulative sum
is the first element of the parameter.

=for usage

 $b = cumusumover($a);

=for example

 $spectrum = cumusumover $image->xchg(0,1)

=for bad

cumusumover processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 dcumusumover

=for sig

  Signature: (a(n); double [o]b(n))

=for ref

Cumulative sum

This function calculates the cumulative sum
along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

The sum is started so that the first element in the cumulative sum
is the first element of the parameter.

=for usage

 $b = cumusumover($a);

=for example

 $spectrum = cumusumover $image->xchg(0,1)

Unlike L<cumusumover|/cumusumover>, the calculations are performed in double
precision.

=for bad

dcumusumover processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 prodover

=for sig

  Signature: (a(n); int+ [o]b())

=for ref

Project via product to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the product along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = prodover($a);

=for example

 $spectrum = prodover $image->xchg(0,1)

=for bad

prodover processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 dprodover

=for sig

  Signature: (a(n); double [o]b())

=for ref

Project via product to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the product along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = dprodover($a);

=for example

 $spectrum = dprodover $image->xchg(0,1)

Unlike L<prodover|/prodover>, the calculations are performed in double
precision.

=for bad

dprodover processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 cumuprodover

=for sig

  Signature: (a(n); int+ [o]b(n))

=for ref

Cumulative product

This function calculates the cumulative product
along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

The sum is started so that the first element in the cumulative product
is the first element of the parameter.

=for usage

 $b = cumuprodover($a);

=for example

 $spectrum = cumuprodover $image->xchg(0,1)

=for bad

cumuprodover processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 dcumuprodover

=for sig

  Signature: (a(n); double [o]b(n))

=for ref

Cumulative product

This function calculates the cumulative product
along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

The sum is started so that the first element in the cumulative product
is the first element of the parameter.

=for usage

 $b = cumuprodover($a);

=for example

 $spectrum = cumuprodover $image->xchg(0,1)

Unlike L<cumuprodover|/cumuprodover>, the calculations are performed in double
precision.

=for bad

dcumuprodover processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 borover

=for sig

  Signature: (a(n); int+ [o]b())

=for ref

Project via bitwise or to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the bitwise or along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = borover($a);

=for example

 $spectrum = borover $image->xchg(0,1)

=for bad

If C<a()> contains only bad data (and its bad flag is set), 
C<b()> is set bad. Otherwise C<b()> will have its bad flag cleared,
as it will not contain any bad values.

=head2 andover

=for sig

  Signature: (a(n); int+ [o]b())

=for ref

Project via and to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the and along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = andover($a);

=for example

 $spectrum = andover $image->xchg(0,1)

=for bad

If C<a()> contains only bad data (and its bad flag is set), 
C<b()> is set bad. Otherwise C<b()> will have its bad flag cleared,
as it will not contain any bad values.

=head2 orover

=for sig

  Signature: (a(n); int+ [o]b())

=for ref

Project via or to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the or along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = orover($a);

=for example

 $spectrum = orover $image->xchg(0,1)

=for bad

If C<a()> contains only bad data (and its bad flag is set), 
C<b()> is set bad. Otherwise C<b()> will have its bad flag cleared,
as it will not contain any bad values.

=head2 bandover

=for sig

  Signature: (a(n); int+ [o]b())

=for ref

Project via bitwise and to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the bitwise and along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = bandover($a);

=for example

 $spectrum = bandover $image->xchg(0,1)

=for bad

If C<a()> contains only bad data (and its bad flag is set), 
C<b()> is set bad. Otherwise C<b()> will have its bad flag cleared,
as it will not contain any bad values.

=head2 zcover

=for sig

  Signature: (a(n); int+ [o]b())

=for ref

Project via == 0 to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the == 0 along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = zcover($a);

=for example

 $spectrum = zcover $image->xchg(0,1)

=for bad

If C<a()> contains only bad data (and its bad flag is set), 
C<b()> is set bad. Otherwise C<b()> will have its bad flag cleared,
as it will not contain any bad values.

=head2 intover

=for sig

  Signature: (a(n); int+ [o]b())

=for ref

Project via integral to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the integral along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = intover($a);

=for example

 $spectrum = intover $image->xchg(0,1)

Notes:

C<intover> uses a point spacing of one (i.e., delta-h==1).  You will
need to scale the result to correct for the true point delta).

For C<n E<gt> 3>, these are all C<O(h^4)> (like Simpson's rule), but are
integrals between the end points assuming the pdl gives values just at
these centres: for such `functions', sumover is correct to C<O(h)>, but
is the natural (and correct) choice for binned data, of course.

=for bad

intover ignores the bad-value flag of the input piddles.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 average

=for sig

  Signature: (a(n); int+ [o]b())

=for ref

Project via average to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the average along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = average($a);

=for example

 $spectrum = average $image->xchg(0,1)

=for bad

average processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 daverage

=for sig

  Signature: (a(n); double [o]b())

=for ref

Project via average to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the average along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = daverage($a);

=for example

 $spectrum = daverage $image->xchg(0,1)

Unlike L<average|/average>, the calculation is performed in double
precision.

=for bad

daverage processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 medover

=for sig

  Signature: (a(n); [o]b(); [t]tmp(n))

=for ref

Project via median to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the median along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = medover($a);

=for example

 $spectrum = medover $image->xchg(0,1)

=for bad

medover processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 oddmedover

=for sig

  Signature: (a(n); [o]b(); [t]tmp(n))

=for ref

Project via oddmedian to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the oddmedian along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = oddmedover($a);

=for example

 $spectrum = oddmedover $image->xchg(0,1)

The median is sometimes not a good choice as if the array has
an even number of elements it lies half-way between the two
middle values - thus it does not always correspond to a data
value. The lower-odd median is just the lower of these two values
and so it ALWAYS sits on an actual data value which is useful in
some circumstances.
	

=for bad

oddmedover processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 modeover

=for sig

  Signature: (data(n); [o]out(); [t]sorted(n))

=for ref

Project via mode to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the mode along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = modeover($a);

=for example

 $spectrum = modeover $image->xchg(0,1)

The mode is the single element most frequently found in a 
discrete data set.

It I<only> makes sense for integer data types, since
floating-point types are demoted to integer before the
mode is calculated.

C<modeover> treats BAD the same as any other value:  if
BAD is the most common element, the returned value is also BAD.

=for bad

modeover does not process bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 pctover

=for sig

  Signature: (a(n); p(); [o]b(); [t]tmp(n))

=for ref

Project via percentile to N-1 dimensions

This function reduces the dimensionality of a piddle by one by finding
the specified percentile (p) along the 1st dimension.  The specified
percentile must be between 0.0 and 1.0.  When the specified percentile
falls between data points, the result is interpolated.  Values outside
the allowed range are clipped to 0.0 or 1.0 respectively.  The algorithm
implemented here is based on the interpolation variant described at
L<http://en.wikipedia.org/wiki/Percentile> as used by Microsoft Excel
and recommended by NIST.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = pctover($a, $p);

=for example

 $spectrum = pctover $image->xchg(0,1), $p

=for bad

pctover processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 oddpctover

=for sig

  Signature: (a(n); p(); [o]b(); [t]tmp(n))

Project via percentile to N-1 dimensions

This function reduces the dimensionality of a piddle by one by finding
the specified percentile along the 1st dimension.  The specified
percentile must be between 0.0 and 1.0.  When the specified percentile
falls between two values, the nearest data value is the result.
The algorithm implemented is from the textbook version described
first at L< http://en.wikipedia.org/wiki/Percentile>.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = oddpctover($a, $p);

=for example

 $spectrum = oddpctover $image->xchg(0,1), $p

=for bad

oddpctover processes bad values.
It will set the bad-value flag of all output piddles if the flag is set for any of the input piddles.

=head2 pct

=for ref

Return the specified percentile of all elements in a piddle. The
specified percentile (p) must be between 0.0 and 1.0.  When the
specified percentile falls between data points, the result is
interpolated.

=for usage

 $x = pct($data, $pct);

=cut

=head2 oddpct

=for ref

Return the specified percentile of all elements in a piddle. The
specified percentile must be between 0.0 and 1.0.  When the specified
percentile falls between two values, the nearest data value is the
result.

=for usage

 $x = oddpct($data, $pct);

=cut

=head2 avg

=for ref

Return the average of all elements in a piddle.

See the documentation for L<average|/average> for more information.

=for usage

 $x = avg($data);

=for bad

This routine handles bad values.

=cut

=head2 sum

=for ref

Return the sum of all elements in a piddle.

See the documentation for L<sumover|/sumover> for more information.

=for usage

 $x = sum($data);

=for bad

This routine handles bad values.

=cut

=head2 prod

=for ref

Return the product of all elements in a piddle.

See the documentation for L<prodover|/prodover> for more information.

=for usage

 $x = prod($data);

=for bad

This routine handles bad values.

=cut

=head2 davg

=for ref

Return the average (in double precision) of all elements in a piddle.

See the documentation for L<daverage|/daverage> for more information.

=for usage

 $x = davg($data);

=for bad

This routine handles bad values.

=cut

=head2 dsum

=for ref

Return the sum (in double precision) of all elements in a piddle.

See the documentation for L<dsumover|/dsumover> for more information.

=for usage

 $x = dsum($data);

=for bad

This routine handles bad values.

=cut

=head2 dprod

=for ref

Return the product (in double precision) of all elements in a piddle.

See the documentation for L<dprodover|/dprodover> for more information.

=for usage

 $x = dprod($data);

=for bad

This routine handles bad values.

=cut

=head2 zcheck

=for ref

Return the check for zero of all elements in a piddle.

See the documentation for L<zcover|/zcover> for more information.

=for usage

 $x = zcheck($data);

=for bad

This routine handles bad values.

=cut

=head2 and

=for ref

Return the logical and of all elements in a piddle.

See the documentation for L<andover|/andover> for more information.

=for usage

 $x = and($data);

=for bad

This routine handles bad values.

=cut

=head2 band

=for ref

Return the bitwise and of all elements in a piddle.

See the documentation for L<bandover|/bandover> for more information.

=for usage

 $x = band($data);

=for bad

This routine handles bad values.

=cut

=head2 or

=for ref

Return the logical or of all elements in a piddle.

See the documentation for L<orover|/orover> for more information.

=for usage

 $x = or($data);

=for bad

This routine handles bad values.

=cut

=head2 bor

=for ref

Return the bitwise or of all elements in a piddle.

See the documentation for L<borover|/borover> for more information.

=for usage

 $x = bor($data);

=for bad

This routine handles bad values.

=cut

=head2 min

=for ref

Return the minimum of all elements in a piddle.

See the documentation for L<minimum|/minimum> for more information.

=for usage

 $x = min($data);

=for bad

This routine handles bad values.

=cut

=head2 max

=for ref

Return the maximum of all elements in a piddle.

See the documentation for L<maximum|/maximum> for more information.

=for usage

 $x = max($data);

=for bad

This routine handles bad values.

=cut

=head2 median

=for ref

Return the median of all elements in a piddle.

See the documentation for L<medover|/medover> for more information.

=for usage

 $x = median($data);

=for bad

This routine handles bad values.

=cut

=head2 mode

=for ref

Return the mode of all elements in a piddle.

See the documentation for L<modeover|/modeover> for more information.

=for usage

 $x = mode($data);

=for bad

This routine handles bad values.

=cut

=head2 oddmedian

=for ref

Return the oddmedian of all elements in a piddle.

See the documentation for L<oddmedover|/oddmedover> for more information.

=for usage

 $x = oddmedian($data);

=for bad

This routine handles bad values.

=cut

=head2 any

=for ref

Return true if any element in piddle set

Useful in conditional expressions:

=for example

 if (any $a>15) { print "some values are greater than 15\n" }

=for bad

See L<or|/or> for comments on what happens when all elements
in the check are bad.

=head2 all

=for ref

Return true if all elements in piddle set

Useful in conditional expressions:

=for example

 if (all $a>15) { print "all values are greater than 15\n" }

=for bad

See L<and|/and> for comments on what happens when all elements
in the check are bad.

=head2 minmax

=for ref

Returns an array with minimum and maximum values of a piddle.

=for usage

 ($mn, $mx) = minmax($pdl);

This routine does I<not> thread over the dimensions of C<$pdl>; 
it returns the minimum and maximum values of the whole array.
See L<minmaximum|/minmaximum> if this is not what is required.
The two values are returned as Perl scalars similar to min/max.

=for example

 pdl> $x = pdl [1,-2,3,5,0]
 pdl> ($min, $max) = minmax($x);
 pdl> p "$min $max\n";
 -2 5

=cut

=head2 qsort

=for sig

  Signature: (a(n); [o]b(n))

=for ref

Quicksort a vector into ascending order.

=for example

 print qsort random(10);

=for bad

Bad values are moved to the end of the array:

 pdl> p $b
 [42 47 98 BAD 22 96 74 41 79 76 96 BAD 32 76 25 59 BAD 96 32 BAD]
 pdl> p qsort($b)
 [22 25 32 32 41 42 47 59 74 76 76 79 96 96 96 98 BAD BAD BAD BAD]

=head2 qsorti

=for sig

  Signature: (a(n); indx [o]indx(n))

=for ref

Quicksort a vector and return index of elements in ascending order.

=for example

 $ix = qsorti $a;
 print $a->index($ix); # Sorted list

=for bad

Bad elements are moved to the end of the array:

 pdl> p $b
 [42 47 98 BAD 22 96 74 41 79 76 96 BAD 32 76 25 59 BAD 96 32 BAD]
 pdl> p $b->index( qsorti($b) )
 [22 25 32 32 41 42 47 59 74 76 76 79 96 96 96 98 BAD BAD BAD BAD]

=head2 qsortvec

=for sig

  Signature: (a(n,m); [o]b(n,m))

=for ref

Sort a list of vectors lexicographically.

The 0th dimension of the source piddle is dimension in the vector;
the 1st dimension is list order.  Higher dimensions are threaded over.

=for example

 print qsortvec pdl([[1,2],[0,500],[2,3],[4,2],[3,4],[3,5]]);
 [
  [  0 500]
  [  1   2]
  [  2   3]
  [  3   4]
  [  3   5]
  [  4   2]
 ]
 

=for bad

Vectors with bad components should be moved to the end of the array:

=head2 qsortveci

=for sig

  Signature: (a(n,m); indx [o]indx(m))

=for ref

Sort a list of vectors lexicographically, returning the indices of the
sorted vectors rather than the sorted list itself.

As with C<qsortvec>, the input PDL should be an NxM array containing M
separate N-dimensional vectors.  The return value is an integer M-PDL 
containing the M-indices of original array rows, in sorted order.

As with C<qsortvec>, the zeroth element of the vectors runs slowest in the
sorted list.  

Additional dimensions are threaded over: each plane is sorted separately,
so qsortveci may be thought of as a collapse operator of sorts (groan).

=for bad

Vectors with bad components should be moved to the end of the array:

=head2 minimum

=for sig

  Signature: (a(n); [o]c())

=for ref

Project via minimum to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the minimum along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = minimum($a);

=for example

 $spectrum = minimum $image->xchg(0,1)

=for bad

Output is set bad if all elements of the input are bad,
otherwise the bad flag is cleared for the output piddle.

Note that C<NaNs> are considered to be valid values;
see L<isfinite|PDL::Math/isfinite> and L<badmask|PDL::Math/badmask>
for ways of masking NaNs.

=head2 minimum_ind

=for sig

  Signature: (a(n); indx [o] c())

=for ref

Like minimum but returns the index rather than the value

=for bad

Output is set bad if all elements of the input are bad,
otherwise the bad flag is cleared for the output piddle.

=head2 minimum_n_ind

=for sig

  Signature: (a(n); indx [o]c(m))

=for ref

Returns the index of C<m> minimum elements

=for bad

Not yet been converted to ignore bad values

=head2 maximum

=for sig

  Signature: (a(n); [o]c())

=for ref

Project via maximum to N-1 dimensions

This function reduces the dimensionality of a piddle
by one by taking the maximum along the 1st dimension.

By using L<xchg|PDL::Slices/xchg> etc. it is possible to use
I<any> dimension.

=for usage

 $b = maximum($a);

=for example

 $spectrum = maximum $image->xchg(0,1)

=for bad

Output is set bad if all elements of the input are bad,
otherwise the bad flag is cleared for the output piddle.

Note that C<NaNs> are considered to be valid values;
see L<isfinite|PDL::Math/isfinite> and L<badmask|PDL::Math/badmask>
for ways of masking NaNs.

=head2 maximum_ind

=for sig

  Signature: (a(n); indx [o] c())

=for ref

Like maximum but returns the index rather than the value

=for bad

Output is set bad if all elements of the input are bad,
otherwise the bad flag is cleared for the output piddle.

=head2 maximum_n_ind

=for sig

  Signature: (a(n); indx [o]c(m))

=for ref

Returns the index of C<m> maximum elements

=for bad

Not yet been converted to ignore bad values

=head2 minmaximum

=for sig

  Signature: (a(n); [o]cmin(); [o] cmax(); indx [o]cmin_ind(); indx [o]cmax_ind())

=for ref

Find minimum and maximum and their indices for a given piddle;

=for usage

 pdl> $a=pdl [[-2,3,4],[1,0,3]]
 pdl> ($min, $max, $min_ind, $max_ind)=minmaximum($a)
 pdl> p $min, $max, $min_ind, $max_ind
 [-2 0] [4 3] [0 1] [2 2]

See also L<minmax|/minmax>, which clumps the piddle together.

=for bad

If C<a()> contains only bad data, then the output piddles will
be set bad, along with their bad flag.
Otherwise they will have their bad flags cleared,
since they will not contain any bad values.

=head1 AUTHOR

Copyright (C) Tuomas J. Lukka 1997 (lukka@husc.harvard.edu).
Contributions by Christian Soeller (c.soeller@auckland.ac.nz)
and Karl Glazebrook (kgb@aaoepp.aao.gov.au).  All rights
reserved. There is no warranty. You are allowed to redistribute this
software / documentation under certain conditions. For details, see
the file COPYING in the PDL distribution. If this file is separated
from the PDL distribution, the copyright notice should be included in
the file.
