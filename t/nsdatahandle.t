use strict;
use Test;


# check if PDLA::NiceSlice clobbers the DATA filehandle
use PDLA::LiteF;

plan tests => 1;

$| = 1;

use PDLA::NiceSlice;

my $data = join '', <DATA>;
ok $data =~ "we've got data";

__DATA__

we've got data
