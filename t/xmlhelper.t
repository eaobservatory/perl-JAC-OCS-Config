#!perl

use Test::More tests => 5;

use_ok('JAC::OCS::Config::XMLHelper', qw/
    indent_xml_string escape_xml/);

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

is(escape_xml(
    'nothing to see here'),
    'nothing to see here');

is(escape_xml(
    'named & < > \' "'),
    'named &amp; &lt; &gt; &apos; &quot;');

is(escape_xml(
    "text with \x{6c49}\x{5b57} in it"),
    'text with &#x6c49;&#x5b57; in it');
