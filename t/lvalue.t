use strict;
use English;

use Test;

use PDLA::LiteF;
use PDLA::Lvalue;

BEGIN { 
    if ( PDLA::Lvalue->subs and !$PERLDB) {
	plan tests => 3;
    } else {
	plan tests => 1;
	print "ok 1 # Skipped: no lvalue sub support\n";
	exit;
    }
} 

$| = 1;

ok (PDLA::Lvalue->subs('slice'));

$a = sequence 10;
eval '$a->slice("") .= 0';

ok (!$@);

ok ($a->max, 0);
