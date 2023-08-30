#!perl

use strict;
use XML::LibXML;
use Test::More tests => 2 + 3 + 4;

use_ok('JAC::OCS::Config::XMLHelper', qw/
    get_pcdata indent_xml_string escape_xml/);

# Test indentation:

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

# Test escaping:

is(escape_xml(
    'nothing to see here'),
    'nothing to see here');

is(escape_xml(
    'named & < > \' "'),
    'named &amp; &lt; &gt; &apos; &quot;');

is(escape_xml(
    "text with \x{6c49}\x{5b57} in it"),
    'text with &#x6c49;&#x5b57; in it');

# Test get_pcdata:

my $parser = new XML::LibXML;
$parser->validation(0);

my $doc = $parser->parse_string('<XYZ_CONFIG>
    <elem_a></elem_a>
    <elem_b>simple text</elem_b>
    <elem_c>text <!-- with a comment --> in the middle of it</elem_c>
    <elem_d>text &amp; XML entity</elem_d>
</XYZ_CONFIG>');

my $root = $doc->documentElement();

is(get_pcdata($root, 'elem_a'), undef);
is(get_pcdata($root, 'elem_b'), 'simple text');
is(get_pcdata($root, 'elem_c'), 'text  in the middle of it');
is(get_pcdata($root, 'elem_d'), 'text & XML entity');
