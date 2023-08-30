#!perl

use Test::More tests => 40;
use JAC::OCS::Config::ACSIS;

BEGIN {
    use_ok("JAC::OCS::Config::Units");
}

my %units = (
    MHz => {
        name => "hertz",
        symbol => 'Hz',
        prefix => 'M',
        power => 6,
        fullprefix => 'mega',
    },
    Glm => {
        name => "lumen",
        symbol => 'lm',
        prefix => 'G',
        power => 9,
        fullprefix => 'giga',
    },
    mum => {
        name => "metre",
        symbol => 'm',
        prefix => 'mu',
        power => -6,
        fullprefix => 'micro',
    },
    YJy => {
        name => "jansky",
        symbol => 'Jy',
        prefix => 'Y',
        power => 24,
        fullprefix => 'yotta',
    },
    daPa => {
        name => "pascal",
        symbol => 'Pa',
        prefix => 'da',
        power => 1,
        fullprefix => 'deca',
    },
    g => {
        name => "gram",
        symbol => 'g',
        prefix => '',
        power => 0,
        fullprefix => '',
    },
);


for my $ustr (keys %units) {
    my $u = new JAC::OCS::Config::Units($ustr);

    is($u->unit, $ustr, "Compare recombined symbol '$ustr'");
    for my $m (keys %{$units{$ustr}}) {
        is($u->$m, $units{$ustr}->{$m}, "Compare $m");
    }
}

# mult factors
my $u = new JAC::OCS::Config::Units("MHz");
is($u->mult('M'), 1, "Compare M to M");
is($u->mult(''), 1E6, "Compare M to base");
is($u->mult('G'), 1E-3, "Compare M to G");
