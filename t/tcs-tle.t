#!perl

# Test script for TCS XML handling of TLE data.

use Test::More;
use Test::Number::Delta;

use strict;

eval {
    require Astro::Coords::TLE;
};
if ($@) {
    plan skip_all => 'Astro::Coords::TLE not installed';
}
else {
    plan tests => 5 + 2 * 10;
}

my @xml = <DATA>;

require_ok('JAC::OCS::Config::TCS');

my $cfg = new JAC::OCS::Config::TCS(
    telescope => 'UKIRT',
    XML => join('', @xml),
    validation => 0,
);

isa_ok($cfg, 'JAC::OCS::Config::TCS');

# Check that the coordinates were recognised as TLE.
my $coord = $cfg->getTarget();
isa_ok($coord, 'Astro::Coords::TLE');

# Generate XML and reparse it to make sure we can serialize successfully.
my $xml = "$cfg";

my $cfgr = new JAC::OCS::Config::TCS(
    telescope => 'UKIRT',
    XML => $xml,
    validation => 0,
);

isa_ok($cfgr, 'JAC::OCS::Config::TCS');
my $coordr = $cfgr->getTarget();
isa_ok($coordr, 'Astro::Coords::TLE');

# Now compare the two sets of coordinates with the expected values.
foreach (
        ['original', $coord],
        ['reparsed', $coordr],
) {
    my ($t, $c) = @$_;

    is($c->name(),                          'my target', "$t target name");
    is($c->epoch_year(),                    2013,        "$t epoch year");
    delta_ok($c->epoch_day(),               321.0123456, "$t epoch day");
    delta_ok($c->inclination()->degrees(),  2.22,        "$t inclination");
    delta_ok($c->raanode()->degrees(),      3.33,        "$t ra a node");
    delta_ok($c->perigee()->degrees(),      5.55,        "$t perigee");
    delta_ok($c->e(),                       0.444,       "$t e");
    delta_ok($c->mean_anomaly()->degrees(), 6.66,        "$t mean anomaly");
    delta_ok($c->mean_motion(),             7.77,        "$t mean motion");
    delta_ok($c->bstar(),                   1.11,        "$t bstar");
}


__DATA__
  <SpTelescopeObsComp type="oc" subtype="targetList">
    <meta_gui_selectedTelescopePos>Base</meta_gui_selectedTelescopePos>
    <meta_unique>true</meta_unique>
    <BASE TYPE="Base">
      <target>
        <targetName>my target</targetName>
        <tleSystem>
          <epochYr>2013</epochYr>
          <epochDay>321.0123456</epochDay>
          <inclination>2.22</inclination>
          <raanode>3.33</raanode>
          <perigee>5.55</perigee>
          <e>0.444</e>
          <LorM>6.66</LorM>
          <mm>7.77</mm>
          <bstar>1.11</bstar>
        </tleSystem>
      </target>
    </BASE>
  </SpTelescopeObsComp>
