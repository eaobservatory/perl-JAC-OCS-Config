#!perl

# Test script for Az/El coordinate parsing.
#
# The purpose of this script is to check how the classes parse coordinates
# as written by the OT into its XML files.  This is necessary because the
# OMP code (e.g. translator) uses the JAC::OCS::Config::TCS class to parse
# coordinates in the OT XML files.

use Test::More tests => 1 + 4 * 11 * 6;
use Test::Number::Delta within => 0.00001;
use Astro::PAL;

use strict;

require_ok("JAC::OCS::Config::TCS");

my @az = qw/0.0 1.5 4.0876 10.65484 20 45.3 100 150.135 290 350.0 51:25:42.857/;
my @el = qw/0 1.2342 6.453456 32.8 85.0 12:51:25.714/;

for my $az_str (@az) {
    for my $el_str (@el) {
        my $xml = '        <SpTelescopeObsComp type="oc" subtype="targetList">
            <meta_gui_collapsed>false</meta_gui_collapsed>
            <meta_gui_selectedTelescopePos>Base</meta_gui_selectedTelescopePos>
            <meta_unique>true</meta_unique>
            <BASE TYPE="Base">
                <target>
                    <targetName></targetName>
                    <spherSystem SYSTEM="AZEL">
                        <c1>' . $az_str . '</c1>
                        <c2>' . $el_str . '</c2>
                        <rv defn="radio" frame="LSRK">0.0</rv>
                    </spherSystem>
                </target>
            </BASE>
        </SpTelescopeObsComp>';

        # Parse the XML and check we get the right coordinates:

        my $cfg = new JAC::OCS::Config::TCS(
            telescope => 'JCMT',
            XML => $xml,
            validation => 0,
        );

        # Prepare comparison value: convert to numeric form.
        my $az = ($az_str =~ /:/) ? ([palDafin($az_str =~ s/:/ /gr, 1)]->[1] * DR2D) : (1.0 * $az_str);
        my $el = ($el_str =~ /:/) ? ([palDafin($el_str =~ s/:/ /gr, 1)]->[1] * DR2D) : (1.0 * $el_str);

        my $coords = $cfg->getTarget();
        my ($coords_az, $coords_el) = $coords->azel();
        delta_ok($coords_az->degrees(), $az, "Azimuth for $az_str, $el_str");
        delta_ok($coords_el->degrees(), $el, "Elevation for $az_str, $el_str");

        # Re-generate the XML, and parse it again to check the coordinates are still understood:

        my $xmlout = "$cfg";

        my $cfgout = new JAC::OCS::Config::TCS(
            telescope => 'JCMT',
            XML => $xmlout,
            validation => 0,
        );

        my $coordsout = $cfgout->getTarget();
        my ($coordsout_az, $coordsout_el) = $coordsout->azel();

        delta_ok($coordsout_az->degrees(), $coords_az->degrees(), "Azimuth for $az_str, $el_str");
        delta_ok($coordsout_el->degrees(), $coords_el->degrees(), "Elevation for $az_str, $el_str");
    }
}
