#!perl

# Test script for RA/Dec coordinate parsing.

use Test::More tests => 1 + 4 * 5 * 5;
use Test::Number::Delta within => 0.00001;
use Astro::PAL;

use strict;

require_ok("JAC::OCS::Config::TCS");

my @ra = qw/0.01 1.5 4.0876 10.65484 12:34:56.78/;
my @dec = qw/0 1.2342 6.453456 32.8 43:21:12.34/;

for my $ra_str (@ra) {
    for my $dec_str (@dec) {
        my $xml = '        <SpTelescopeObsComp type="oc" subtype="targetList">
            <meta_gui_collapsed>false</meta_gui_collapsed>
            <meta_gui_selectedTelescopePos>Base</meta_gui_selectedTelescopePos>
            <meta_unique>true</meta_unique>
            <BASE TYPE="Base">
                <target>
                    <targetName></targetName>
                    <spherSystem SYSTEM="J2000">
                        <c1>' . $ra_str . '</c1>
                        <c2>' . $dec_str . '</c2>
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
        my $ra = ($ra_str =~ /:/) ? ([palDafin($ra_str =~ s/:/ /gr, 1)]->[1] * DR2D) : (1.0 * $ra_str);
        my $dec = ($dec_str =~ /:/) ? ([palDafin($dec_str =~ s/:/ /gr, 1)]->[1] * DR2D) : (1.0 * $dec_str);

        my $coords = $cfg->getTarget();
        my ($coords_ra, $coords_dec) = $coords->radec2000();
        delta_ok($coords_ra->hours(), $ra, "RA for $ra_str, $dec_str");
        delta_ok($coords_dec->degrees(), $dec, "Declination for $ra_str, $dec_str");

        # Re-generate the XML, and parse it again to check the coordinates are still understood:

        my $xmlout = "$cfg";

        my $cfgout = new JAC::OCS::Config::TCS(
            telescope => 'JCMT',
            XML => $xmlout,
            validation => 0,
        );

        my $coordsout = $cfgout->getTarget();
        my ($coordsout_ra, $coordsout_dec) = $coordsout->radec2000();

        delta_ok($coordsout_ra->hours(), $coords_ra->hours(), "RA for $ra_str, $dec_str");
        delta_ok($coordsout_dec->degrees(), $coords_dec->degrees(), "Declination for $ra_str, $dec_str");
    }
}
