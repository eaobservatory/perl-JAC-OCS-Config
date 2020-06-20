#!perl

use Test::More tests => 2;

use_ok('JAC::OCS::Config::XMLHelper', qw/indent_xml_string/);

my $indented = indent_xml_string('<a>
<!--
   comment
-->
<b x="1"
   y="2">
<c>text</c>
</b>
<d/>
</a>');

is($indented, '<a>
   <!--
      comment
   -->
   <b x="1"
      y="2">
      <c>text</c>
   </b>
   <d/>
</a>
');
