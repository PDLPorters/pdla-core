#  Can PDLA::Lite be loaded twice?
#  The first import was interfering with the second.  

use Test::More tests => 10;

{
    package mk1;
    use PDLA::Lite;

    sub x {
        return PDLA->pdl (1..10);
    }
}

{
    package mk2;
    use PDLA::Lite;

    sub x {
        return PDLA->pdl (11..20);
    }
}

foreach my $name (qw /x barf pdl piddle null/) {
    ok (mk1->can($name), "Sub loaded: mk1::" . $name);
    ok (mk2->can($name), "Sub loaded: mk2::" . $name);
}

