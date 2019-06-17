#!perl

# Test script for galactic coordinate parsing.

use Test::More tests => 1 + 4 * 5 * 5;
use Test::Number::Delta within => 0.00001;
use Astro::PAL;

use strict;

require_ok( "JAC::OCS::Config::TCS" );

my @lon = qw/0.01 1.5 4.0876 10.65484 12:34:56.78/;
my @lat = qw/0 1.2342 6.453456 32.8 43:21:12.34/;

for my $lon_str (@lon) {
  for my $lat_str (@lat) {
    my $xml = '      <SpTelescopeObsComp type="oc" subtype="targetList">
        <meta_gui_collapsed>false</meta_gui_collapsed>
        <meta_gui_selectedTelescopePos>Base</meta_gui_selectedTelescopePos>
        <meta_unique>true</meta_unique>
        <BASE TYPE="Base">
          <target>
            <targetName></targetName>
            <spherSystem SYSTEM="Galactic">
              <c1>' . $lon_str . '</c1>
              <c2>' . $lat_str . '</c2>
              <rv defn="radio" frame="LSRK">0.0</rv>
            </spherSystem>
          </target>
        </BASE>
      </SpTelescopeObsComp>';

    # Parse the XML and check we get the right coordinates:

    my $cfg = new JAC::OCS::Config::TCS(telescope => 'JCMT',
                                     XML => $xml,
                                     validation => 0);

    # Prepare comparison value: convert to numeric form.
    my $lon = ($lon_str =~ /:/) ? ([palDafin($lon_str =~ s/:/ /gr, 1)]->[1] * DR2D) : (1.0 * $lon_str);
    my $lat = ($lat_str =~ /:/) ? ([palDafin($lat_str =~ s/:/ /gr, 1)]->[1] * DR2D) : (1.0 * $lat_str);

    my $coords = $cfg->getTarget();
    my ($coords_lon, $coords_lat) = $coords->glonglat();
    delta_ok($coords_lon->degrees(), $lon, "Long for $lon_str, $lat_str");
    delta_ok($coords_lat->degrees(), $lat, "Lat for $lon_str, $lat_str");

    # Re-generate the XML, and parse it again to check the coordinates are still understood:

    my $xmlout = "$cfg";

    my $cfgout = new JAC::OCS::Config::TCS(telescope => 'JCMT',
                                     XML => $xmlout,
                                     validation => 0);

    my $coordsout = $cfgout->getTarget();
    my ($coordsout_lon, $coordsout_lat) = $coordsout->glonglat();

    delta_ok($coordsout_lon->degrees(), $coords_lon->degrees(), "Long for $lon_str, $lat_str");
    delta_ok($coordsout_lat->degrees(), $coords_lat->degrees(), "Lat for $lon_str, $lat_str");
  }
}
