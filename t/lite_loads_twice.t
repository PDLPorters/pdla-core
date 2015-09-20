use Test::More tests => 1;
use Devel::Symdump;

{
    package mk1;
    #BEGIN {print "Loading mk1\n"};
    use PDLA::Lite;

    sub x {
        return PDLA->pdl (1..10);
    }
}

{
    package mk2;
    #BEGIN {print "Loading mk2\n"};
    use PDLA::Lite;

    sub x {
        return PDLA->pdl (11..20);
    }
}

#my $obj = Devel::Symdump->rnew(__PACKAGE__); 
#my @sub_names = grep {$_ =~ /mk[12]/} $obj->functions();

#print join ' ', @sub_names, "\n";


#my %sub_hash;
#@sub_hash{@sub_names} = undef;

#my %expected;
foreach my $name (qw /x barf pdl piddle null/) {
    ok (mk1->can($name), "Sub loaded: mk1::" . $name);
    ok (mk2->can($name), "Sub loaded: mk2::" . $name);
}

