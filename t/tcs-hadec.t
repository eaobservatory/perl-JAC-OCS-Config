#!perl

# Test script for HA/Dec coordinate parsing.

use Test::More tests => 1 + 4 * 5 * 5;
use Test::Number::Delta within => 0.00001;
use Astro::PAL;

use strict;

require_ok( "JAC::OCS::Config::TCS" );

my @ha = qw/0.0 1.5 4.0876 10.65484 1:23:45.6789/;
my @dec = qw/0 1.2342 6.453456 32.8 87:65:43.210/;

for my $ha_str (@ha) {
  for my $dec_str (@dec) {
    my $xml = '      <SpTelescopeObsComp type="oc" subtype="targetList">
        <meta_gui_collapsed>false</meta_gui_collapsed>
        <meta_gui_selectedTelescopePos>Base</meta_gui_selectedTelescopePos>
        <meta_unique>true</meta_unique>
        <BASE TYPE="Base">
          <target>
            <targetName></targetName>
            <spherSystem SYSTEM="HADEC">
              <c1>' . $ha_str . '</c1>
              <c2>' . $dec_str . '</c2>
              <rv defn="radio" frame="LSRK">0.0</rv>
            </spherSystem>
          </target>
        </BASE>
      </SpTelescopeObsComp>';

    # Parse the XML and check we get the right coordinates:

    my $cfg = new JAC::OCS::Config::TCS(telescope => 'UKIRT',
                                     XML => $xml,
                                     validation => 0);

    # Prepare comparison value: convert to numeric form.
    my $ha = ($ha_str =~ /:/) ? ([palDafin($ha_str =~ s/:/ /gr, 1)]->[1] * DR2D) : (1.0 * $ha_str);
    my $dec = ($dec_str =~ /:/) ? ([palDafin($dec_str =~ s/:/ /gr, 1)]->[1] * DR2D) : (1.0 * $dec_str);

    my $coords = $cfg->getTarget();
    my ($coords_ha, $coords_dec) = $coords->hadec();
    delta_ok($coords_ha->hours(), $ha, "Hours for $ha_str, $dec_str");
    delta_ok($coords_dec->degrees(), $dec, "Declination for $ha_str, $dec_str");

    # Re-generate the XML, and parse it again to check the coordinates are still understood:

    my $xmlout = "$cfg";

    my $cfgout = new JAC::OCS::Config::TCS(telescope => 'UKIRT',
                                     XML => $xmlout,
                                     validation => 0);

    my $coordsout = $cfgout->getTarget();
    my ($coordsout_ha, $coordsout_dec) = $coordsout->hadec();

    delta_ok($coordsout_ha->hours(), $coords_ha->hours(), "Hours for $ha_str, $dec_str");
    delta_ok($coordsout_dec->degrees(), $coords_dec->degrees(), "Declination for $ha_str, $dec_str");
  }
}
