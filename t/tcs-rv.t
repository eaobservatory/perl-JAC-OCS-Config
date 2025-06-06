use strict;
use Test::More tests => 1 + 3 * 7;
use Test::Number::Delta within => 0.000001;

use_ok('JAC::OCS::Config::TCS::BASE');

foreach my $info (
            [11.22, 'radio', 'LSR', 'RADIO', 'LSRK', 0],
            [22.33, 'optical', 'HELIOCENTRIC', 'OPTICAL', 'HEL', 0],
            [0.001, 'redshift', 'HELIOCENTRIC', 'REDSHIFT', 'HEL', 1],
        ) {
    my ($rv, $defn, $frame, $defn_expect, $frame_expect, $expect_redshift) = @$info;

    my ($base, $line1) = make_base($rv, $defn, $frame);
    isa_ok($base, 'JAC::OCS::Config::TCS::BASE');

    my $coords = $base->coords;
    isa_ok($coords, 'Astro::Coords');

    # Check that the Astro::Coords object contains the correct data.
    unless ($expect_redshift) {
        delta_ok($coords->rv, $rv, "$defn: rv");
    }
    else {
        delta_ok($coords->redshift, $rv, "$defn: redshift");
    }

    is($coords->vdefn, $defn_expect, "$defn: defn");
    is($coords->vframe, $frame_expect, "$defn: frame");

    # Convert back to XML and check the "rv" line.
    $base = JAC::OCS::Config::TCS::BASE->from_coord($coords, 'SCIENCE');
    isa_ok($base, 'JAC::OCS::Config::TCS::BASE');

    my $line2 = xml_rv_line("$base");

    is($line2, $line1, "$defn XML");
}

# Make JAC::OCS::Config::TCS::BASE for the given rv,
# also returning the relevant XML line.
sub make_base {
    my ($rv, $defn, $frame) = @_;

    my $xml = sprintf '<?xml version="1.0" encoding="US-ASCII"?>
        <BASE TYPE="SCIENCE">
         <target>
            <targetName>Name</targetName>
            <spherSystem SYSTEM="J2000">
               <c1>12:34:56.000</c1>
               <c2>07:08:09.00</c2>
               <rv defn="%s" frame="%s">%s</rv>
            </spherSystem>
         </target>
         <TRACKING_SYSTEM SYSTEM="ICRS" />
        </BASE>',
        $defn, $frame, $rv;

    return (
        JAC::OCS::Config::TCS::BASE->new(XML => $xml, validation => 0),
        xml_rv_line($xml));
}

# Find the <rv>...</rv> line in the XML and return it.
sub xml_rv_line {
    my $xml = shift;

    foreach (split /\n/, $xml) {
        next unless /<rv /;

        s/^ *//;
        s/ *$//;

        return $_;
    }

    return undef;
}
