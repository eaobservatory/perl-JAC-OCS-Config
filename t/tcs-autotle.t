#!perl

# Test script for TCS XML handling of Auto TLE configurations

use Test::More tests => 16 + 2 * 11;
use Test::Number::Delta;

use strict;

my @xml = <DATA>;

require_ok('JAC::OCS::Config::TCS');

my $cfg = new JAC::OCS::Config::TCS(
    telescope => 'UKIRT',
    XML => join('', @xml),
    validation => 0,
);

isa_ok($cfg, 'JAC::OCS::Config::TCS');

# Check that the coordinates were recognised as Auto TLE.
my $coord = $cfg->getTarget();
isa_ok($coord, 'JAC::OCS::Config::Coords::AutoTLE');

my @array = $coord->array(); my $n = 0;
is((shift @array), 'AUTO-TLE', 'array element ' . $n);
ok((not defined $_), 'array element ' . ++ $n) foreach @array;

# Generate XML and reparse it to make sure we can serialize successfully.
my $xml = "$cfg";

my $cfgr = new JAC::OCS::Config::TCS(
    telescope => 'UKIRT',
    XML => $xml,
    validation => 0,
);

isa_ok($cfgr, 'JAC::OCS::Config::TCS');
my $coordr = $cfgr->getTarget();
isa_ok($coordr, 'JAC::OCS::Config::Coords::AutoTLE');

# Now compare the two sets of coordinates with the expected values.
foreach (
        ['original', $coord],
        ['reparsed', $coordr],
) {
    my ($t, $c) = @$_;

    is($c->type(),                          'AUTO-TLE',  "$t coordinate type");
    is($c->name(),                          'my target', "$t target name");
    is($c->epoch_year(),                     0,          "$t epoch year");
    is($c->epoch_day(),                      0.0,        "$t epoch day");
    is($c->inclination()->degrees(),         0.0,        "$t inclination");
    is($c->raanode()->degrees(),             0.0,        "$t ra a node");
    is($c->perigee()->degrees(),             0.0,        "$t perigee");
    is($c->e(),                              0.0,        "$t e");
    is($c->mean_anomaly()->degrees(),        0.0,        "$t mean anomaly");
    is($c->mean_motion(),                    0.0,        "$t mean motion");
    is($c->bstar(),                          0.0,        "$t bstar");
}


__DATA__
  <SpTelescopeObsComp type="oc" subtype="targetList">
    <meta_gui_selectedTelescopePos>Base</meta_gui_selectedTelescopePos>
    <meta_unique>true</meta_unique>
    <BASE TYPE="Base">
      <target>
        <targetName>my target</targetName>
        <tleSystem>
          <epochYr>0</epochYr>
          <epochDay>0.0</epochDay>
          <inclination>0.0</inclination>
          <raanode>0.0</raanode>
          <perigee>0.0</perigee>
          <e>0.0</e>
          <LorM>0.0</LorM>
          <mm>0.0</mm>
          <bstar>0.0</bstar>
        </tleSystem>
      </target>
    </BASE>
  </SpTelescopeObsComp>
