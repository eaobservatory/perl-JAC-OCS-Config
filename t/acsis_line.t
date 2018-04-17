#!perl

use Test::More tests => 4;

use strict;

use_ok('JAC::OCS::Config::ACSIS::Line');

my $cfg = new JAC::OCS::Config::ACSIS::Line(
    Molecule => '   C-13-O  ',
    Transition => ' 3  - 2      ',
);

isa_ok($cfg, 'JAC::OCS::Config::ACSIS::Line');

# Check that the supplied strings were cleaned up correctly.
is($cfg->molecule(), 'C-13-O');
is($cfg->transition(), '3 - 2');
