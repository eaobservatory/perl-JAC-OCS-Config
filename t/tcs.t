#!perl

use Test::More tests => 8;

require_ok("JAC::OCS::Config::TCS");

my @xml = <DATA>;
my $cfg = new JAC::OCS::Config::TCS(
    XML => join("\n", @xml),
    validation => 0,
);

isa_ok($cfg, "JAC::OCS::Config::TCS");

is($cfg->telescope, "JCMT", "Check telescope");

my $sci = $cfg->getTarget("SCIENCE");
my $ref = $cfg->getTarget("REFERENCE");

my $distance = $sci->distance($ref);
is($distance->radians, 0, "Distance between science and reference position");

require_ok("JAC::OCS::Config::TCS::BASE");
ok(! JAC::OCS::Config::TCS::BASE::_looks_like_sexagesimal(" 12.34567 "));
ok(JAC::OCS::Config::TCS::BASE::_looks_like_sexagesimal(" 12:34:56.7 "));
ok(JAC::OCS::Config::TCS::BASE::_looks_like_sexagesimal(" 12 34 56.7 "));

# Simple test snippet
__DATA__
<?xml version="1.0" encoding="US-ASCII"?>
<TCS_CONFIG TELESCOPE="JCMT">

    <!-- This base element contains a target, an offset, and a
         tracking system. -->

    <BASE TYPE="SCIENCE">
      <!-- First, define a target. -->

      <target>
        <targetName>Foo</targetName>
        <spherSystem SYSTEM="J2000">
           <c1>18:30:20.45</c1>
           <c2>17:25:43.8</c2>
           <epoch>1997.3</epoch>
           <pm1>1.5</pm1>
           <pm2>-1.5</pm2>
           <rv>-1000</rv>
           <parallax>0.2</parallax>
        </spherSystem>
      </target>

      <!-- Now, define an offset from the target position -->

      <OFFSET>
        <DC1>10</DC1>
        <DC2>20</DC2>
      </OFFSET>

      <!-- Finally, select a tracking coordinate system -->

      <TRACKING_SYSTEM SYSTEM="J2000" />

    </BASE>

    <BASE TYPE="REFERENCE">
      <!-- Now, define a reference. -->

      <target>
        <targetName>Foo</targetName>
        <spherSystem SYSTEM="J2000">
           <c1>18:30:20.45</c1>
           <c2>17:25:43.8</c2>
        </spherSystem>
      </target>

      <!-- Now, define an offset from the target position -->

      <OFFSET>
        <DC1>10</DC1>
        <DC2>20</DC2>
      </OFFSET>

      <!-- Finally, select a tracking coordinate system -->

      <TRACKING_SYSTEM SYSTEM="J2000" />

    </BASE>

    <!-- Define the SLEW method -->
    <SLEW OPTION="TRACK_TIME" TRACK_TIME="3600" />

    <!-- Now, define an obsArea as a set of offsets. -->

    <obsArea>
        <PA>20</PA>

        <OFFSET SYSTEM="TRACKING" TYPE="TAN">
          <DC1>0</DC1>
          <DC2>0</DC2>
        </OFFSET>

        <OFFSET SYSTEM="TRACKING" TYPE="TAN">
          <DC1>10</DC1>
          <DC2>20</DC2>
        </OFFSET>

        <OFFSET SYSTEM="TRACKING" TYPE="TAN">
          <DC1>-10</DC1>
          <DC2>20</DC2>
        </OFFSET>

        <OFFSET SYSTEM="TRACKING" TYPE="TAN">
          <DC1>-10</DC1>
          <DC2>-20</DC2>
        </OFFSET>

        <OFFSET SYSTEM="TRACKING" TYPE="TAN">
          <DC1>10</DC1>
          <DC2>-20</DC2>
        </OFFSET>
    </obsArea>

    <!-- Set up a jiggle map here -->
    <SECONDARY MOTION="CONTINUOUS">
    <JIGGLE_CHOP>
       <JIGGLE NAME="64POINT" SYSTEM="FPLANE" SCALE="1.0" >
         <PA>45</PA>
       </JIGGLE>

       <!-- Define a chop here -->

       <CHOP SYSTEM="SCAN" >
         <THROW>3.4</THROW>
         <PA>45.3</PA>
       </CHOP>

       <TIMING>
         <JIGS_PER_CHOP N_CYC_OFF="4" N_JIGS_ON="10"/>
       </TIMING>
    </JIGGLE_CHOP>
    </SECONDARY>

    <!-- Configure the instrument rotator here -->

    <ROTATOR SYSTEM="TRACKING">
      <PA>15.3</PA>
    </ROTATOR>
</TCS_CONFIG>
