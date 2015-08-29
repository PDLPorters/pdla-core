# -*-perl-*-

use strict;
use Test::More;

BEGIN {
    plan tests => 8;
}

use PDLA::LiteF;
use PDLA::Types;
use PDLA::Graphics::LUT;

sub tapprox {
    my($a,$b) = @_;
    my $d = max( abs($a-$b) );
    $d < 0.0001;	
}

my @names = lut_names();
is( $#names > -1, 1 );  # 1

my @cols = lut_data( $names[0] );
is( $#cols, 3 );                         # 2
is( $cols[0]->nelem, $cols[1]->nelem );  # 3
is( $cols[2]->get_datatype, $PDLA_F );    # 4

# check we can reverse things
my @cols2 = lut_data( $names[0], 1 );
is( tapprox($cols[3]->slice('-1:0'),$cols2[3]), 1 );  # 5

# check we know about the intensity ramps
my @ramps = lut_ramps();
is( $#ramps > -1, 1 ); # 6

# load in a different intensity ramp
my @cols3 = lut_data( $names[0], 0, $ramps[0] ); 
is( $cols3[0]->nelem, $cols3[1]->nelem ); # 7

TODO: {
local $TODO = 'Fragile test';
is( tapprox($cols[1],$cols3[1]), 1 );      # 8
}
