#!perl

use strict;
use Test::More tests => 5;

use_ok('JAC::OCS::Config::TCS::BASE');

my $base = JAC::OCS::Config::TCS::BASE->new(
    XML => '<?xml version="1.0" encoding="US-ASCII"?>
        <BASE TYPE="SCIENCE">
         <target>
            <targetName>Target with &lt;&gt; &amp; &#x6c49;&#x5b57; in it</targetName>
            <spherSystem SYSTEM="J2000">
               <c1>12:34:56.000</c1>
               <c2>07:08:09.00</c2>
               <rv defn="radio" frame="LSR">12.34</rv>
            </spherSystem>
         </target>
         <TRACKING_SYSTEM SYSTEM="ICRS" />
        </BASE>',
    validation => 0);

isa_ok($base, 'JAC::OCS::Config::TCS::BASE');

my $coords = $base->coords;

isa_ok($coords, 'Astro::Coords');

is($coords->name, "Target with <> & \x{6c49}\x{5b57} in it");

my $xml = "$base";

like($xml, qr/<targetName>Target with &lt;&gt; &amp; &#x6c49;&#x5b57; in it<\/targetName>/);
