#!/usr/bin/perl

use utf8;
use Modern::Perl;
use Test::More;
use C4::Search::Engine::Solr;

my $tests;
plan tests => $tests;

my $q;
my $indexes;
my $operands;
my $operators;
my $expected;
my $got;

BEGIN { $tests += 2 }
use_ok('C4::Search::Query');
is(C4::Context->preference("SearchEngine"), 'Solr', "Test search engine = Solr");

my $titleindex = C4::Search::Query::getIndexName("title");
my $authorindex = C4::Search::Query::getIndexName("author");
my $eanindex = C4::Search::Query::getIndexName("ean");
my $pubdateindex = C4::Search::Query::getIndexName("pubdate");

BEGIN { $tests += 22 } # 'Normal' search
@$operands[0] = "title:maudits"; # Solr indexes
@$indexes = ();
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:maudits";
is($got, $expected, "Test Solr indexes in 'normal' search");

@$operands[0] = "title:maudits"; # code indexes
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:maudits";
is($got, $expected, "Test Code indexes in 'normal' search");

@$operands[0] = "ti:maudits"; # zebra indexes
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:maudits";
is($got, $expected, "Test Zebra indexes in 'normal' search");

@$operands[0] = "*:*"; # all fields search
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "*:*";
is($got, $expected, "Test *:* in 'normal' search");

@$operands[0] = "title:maudits OR author:andre NOT title:crépuscule"; # long normal search
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:maudits OR $authorindex:andre NOT $titleindex:crépuscule";
is($got, $expected, "Test long 'normal' search");

@$operands[0] = "title:maudits and a or author:andre not title:crépuscule"; # test operators
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:maudits AND a OR $authorindex:andre NOT $titleindex:crépuscule";
is($got, $expected, "Test operators in 'normal' search");

$q = "title:maudits and a or author:andre not ean:blabla"; # test normal search
$got = C4::Search::Query->normalSearch($q);
$expected = "$titleindex:maudits AND a OR $authorindex:andre NOT $eanindex:blabla";
is($got, $expected, "Test 'normal' search");

$q = qq{Mathématiques Analyse L3 : Cours complet}; # escape colon
$got = C4::Search::Query->normalSearch($q);
$expected = "Mathématiques Analyse L3 \\: Cours complet";
is($got, $expected, "Test escape colon");

$q = qq{Mathématiques Analyse L3 \\: Cours complet}; # escape colon
$got = C4::Search::Query->normalSearch($q);
$expected = "Mathématiques Analyse L3 \\: Cours complet";
is($got, $expected, "Test no escape colon if already escaped");

$q = qq{title:'Mathématiques: Analyse L3:Cours complet'}; # escape colon
$got = C4::Search::Query->normalSearch($q);
$expected = "$titleindex:'Mathématiques\\: Analyse L3\\:Cours complet'";
is($got, $expected, "Test escape colon without space");

$q = qq{title:'Mathématiques\\: Analyse L3\\:Cours complet'}; # escape colon
$got = C4::Search::Query->normalSearch($q);
$expected = "$titleindex:'Mathématiques\\: Analyse L3\\:Cours complet'";
is($got, $expected, "Test no escape colon if already escaped without space");

$q = "Mathéma*"; # lc if wildcard
$got = C4::Search::Query->normalSearch($q);
$expected = "mathéma*";
is($got, $expected, "Test lc if wildcard *");

$q = "title:Mathéma*"; # lc if wildcard
$got = C4::Search::Query->normalSearch($q);
$expected = "$titleindex:mathéma*";
is($got, $expected, "Test lc if wildcard *");

$q = "Mathéma?"; # lc if wildcard
$got = C4::Search::Query->normalSearch($q);
$expected = "mathéma?";
is($got, $expected, "Test lc if wildcard ?");

$q = "title:Mathéma?"; # lc if wildcard
$got = C4::Search::Query->normalSearch($q);
$expected = "$titleindex:mathéma?";
is($got, $expected, "Test lc if wildcard ?");

$q = "Math?matiques"; # lc if wildcard
$got = C4::Search::Query->normalSearch($q);
$expected = "math?matiques";
is($got, $expected, "Test lc if wildcard ?");

$q = "?AthéMatiques"; # lc if wildcard
$got = C4::Search::Query->normalSearch($q);
$expected = "?athématiques";
is($got, $expected, "Test lc if wildcard ?");

$q = "Math?matiques AND Foo"; # lc if wildcard
$got = C4::Search::Query->normalSearch($q);
$expected = "math?matiques AND Foo";
is($got, $expected, "Test lc if wildcard ?");

$q = "Math?ma* AND Foo"; # lc if wildcards * and ?
$got = C4::Search::Query->normalSearch($q);
$expected = "math?ma* AND Foo";
is($got, $expected, "Test lc if wildcards ? and *");

$q = "Math?ma* AND title:Fo* AND BAR"; # lc if wildcards * and ?
$got = C4::Search::Query->normalSearch($q);
$expected = "math?ma* AND $titleindex:fo* AND BAR";
is($got, $expected, "Test lc if wildcards ? and *");

$q = "title:M?th?maTique AND Fo* AND ?A?"; # lc if wildcards * and ?
$got = C4::Search::Query->normalSearch($q);
$expected = "$titleindex:m?th?matique AND fo* AND ?a?";
is($got, $expected, "Test lc if wildcards ? and *");

$q = "M?th?maTiqu? AND Fo* AND ?A?"; # lc if wildcards * and ?
$got = C4::Search::Query->normalSearch($q);
$expected = "m?th?matiqu? AND fo* AND ?a?";
is($got, $expected, "Test lc if wildcards ? and *");

BEGIN { $tests += 8 } # Advanced search
@$operands = ("maudits"); # Solr indexes
@$indexes = ("title", "all_fields", "all_fields");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:maudits";
is($got, $expected, "Test Solr indexes in advanced search");

@$operands = ("maudits"); # Zebra indexes
@$indexes = ("ti", "kw", "kw");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:maudits";
is($got, $expected, "Test Solr indexes in advanced search");

@$operands = ("maudits"); # Code indexes
@$indexes = ("title", "all_fields", "kw");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:maudits";
is($got, $expected, "Test Code indexes in advanced search");

@$operands = ("maudits", "a", "andre"); # More elements
@$indexes = ("title", "all_fields", "author");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:maudits AND a AND $authorindex:andre";
is($got, $expected, "Test Zebra indexes in advanced search");

@$operands = ("maudits", "a", "andre", "Besson"); # With 'More options'
@$indexes = ("title", "all_fields", "author", "author");
@$operators = ("AND", "NOT", "OR");
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:maudits AND a NOT $authorindex:andre OR $authorindex:Besson";
is($got, $expected, "Test 'More options' in advanced search");

@$operands = ("crépuscule", "André"); # Accents
@$indexes = ("title", "author");
@$operators = ("AND");
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:crépuscule AND $authorindex:André";
is($got, $expected, "Test Accents in advanced search");

@$operands = ("maudits", "a", "andre"); # Bad indexes types
@$indexes = ("", undef, ());
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "maudits AND a AND andre";
is($got, $expected, "Test call with bad indexes types");

@$operands = ("Mathématiques Analyse L3 : Cours complet"); # escape colon
@$indexes = ();
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "Mathématiques Analyse L3 \\: Cours complet";
is($got, $expected, "Test escape colon");

BEGIN { $tests += 1 } # normal search with rpn query
@$indexes = ();
@$operators = ();
# NB: not supported by Z3950 server (rflag=x is replaced by rflag='x')
@$operands[0] = q{allrecords,alwaysMatches="" not harvestdate,alwaysMatches="" and (rflag=1 or rflag=2)};
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "[* TO *] NOT date_harvestdate:[* TO *] AND (int_rflag:1 OR int_rflag:2)";
is($got, $expected, "Test alwaysMatches modifier and allrecords index in 'normal' search");


BEGIN { $tests += 7 } # Test BuildIndexString (of many words in one operand string)
@$operands = (qq{le crépuscule des maudits});
@$indexes = ("title");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "($titleindex:le AND $titleindex:crépuscule AND $titleindex:des AND $titleindex:maudits)";
is($got, $expected, qq{Test BuildIndexString with (le crépuscule des maudits)});

@$operands = (qq{maudits crépuscule});
@$indexes = ("title");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "($titleindex:maudits AND $titleindex:crépuscule)";
is($got, $expected, qq{Test BuildIndexString with (maudits crépuscule)});

@$operands = (qq{"le crépuscule des maudits"});
@$indexes = ("title");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{(em$titleindex:"le crépuscule des maudits")};
is($got, $expected, qq{Test BuildIndexString with ("le crépuscule des maudits")});

@$operands = (qq{"le crépuscule" "des maudits"});
@$indexes = ("title");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{(em$titleindex:"le crépuscule" AND em$titleindex:"des maudits")};
is($got, $expected, qq{Test BuildIndexString with ("le crépuscule" "des maudits")});

@$operands = (qq{"le crépuscule" "des maudits"});
@$indexes = ("title");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{(em$titleindex:"le crépuscule" AND em$titleindex:"des maudits")};
is($got, $expected, qq{Test BuildIndexString with ("le crépuscule" "des maudits")});

@$operands = (qq{"le crépuscule" mot "des maudits"});
@$indexes = ("title");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{(em$titleindex:"le crépuscule" AND em$titleindex:"des maudits" AND $titleindex:mot)};
is($got, $expected, qq{Test BuildIndexString with ("le crépuscule" mot "des maudits")});

@$operands = (qq{les maudits}, qq{a}, qq{andre besson}); # With 'More options'
@$indexes = ("title", "all_fields", "author");
@$operators = ("AND", "NOT");
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "($titleindex:les AND $titleindex:maudits) AND a NOT ($authorindex:andre AND $authorindex:besson)";
is($got, $expected, qq{Test BuildIndexString complex});

BEGIN { $tests += 3 } # Test BuildIndexString with expression
@$operands = ("monde","histoire","(VIDEO OR LIVRE OR POUET)" );
@$indexes = ("all_fields", "all_fields", "itype");
@$operators = ("AND", "AND");
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "monde AND histoire AND str_itype:(VIDEO OR LIVRE OR POUET)";
is($got, $expected, qq{Test BuildIndexString with expression in operand});

@$operands = ("monde","histoire","(VIDEO)" );
@$indexes = ("all_fields", "all_fields", "itype");
@$operators = ("AND", "AND");
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "monde AND histoire AND str_itype:(VIDEO)";
is($got, $expected, qq{Test BuildIndexString with expression in operand});

@$operands = ("crise","(OUVRAGE OR VIDEO)" );
@$indexes = ("title", "itype");
@$operators = ("AND", "AND");
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:crise AND str_itype:(OUVRAGE OR VIDEO)";
is($got, $expected, qq{Test BuildIndexString with expression in operand});

BEGIN { $tests += 11 } # Test wildcard * and ?
@$operands = ("Mathéma*");
@$indexes = ();
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "mathéma*";
is($got, $expected, qq{Test simple wildCard *});

@$operands = ("Mathéma*");
@$indexes = ("title");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:mathéma*";
is($got, $expected, qq{Test simple wildCard * (with index)});

@$operands = ("Mathéma?");
@$indexes = ();
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "mathéma?";
is($got, $expected, qq{Test simple wildCard ?});

@$operands = ("Mathéma?");
@$indexes = ("title");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:mathéma?";
is($got, $expected, qq{Test simple wildCard ? (with index)});

@$operands = ("Math?matiques");
@$indexes = ();
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "math?matiques";
is($got, $expected, qq{Test simple wildCard ?});

@$operands = ("?AthéMat?ques");
@$indexes = ();
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "?athémat?ques";
is($got, $expected, qq{Test simple wildCard ? (x2)});

@$operands = ("Math?matiques", "Foo");
@$indexes = ("all_fields", "all_fields");
@$operators = ("AND");
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "math?matiques AND Foo";
is($got, $expected, qq{Test simple wildCard ? with another operand});

@$operands = ("Math?ma*", "Foo");
@$indexes = ("all_fields", "all_fields");
@$operators = ("AND");
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "math?ma* AND Foo";
is($got, $expected, qq{Test with wildCard ? and *});

@$operands = ("Math?ma*", "Fo*", "BAR");
@$indexes = ("all_fields", "title", "all_fields");
@$operators = ("AND", "AND");
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "math?ma* AND $titleindex:fo* AND BAR";
is($got, $expected, qq{Test wildCard ? and * on multiples operands});

@$operands = ("M?th?maTique", "Fo*", "?A?");
@$indexes = ("title", "all_fields", "all_fields");
@$operators = ("AND", "AND");
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "$titleindex:m?th?matique AND fo* AND ?a?";
is($got, $expected, qq{Test wildCard ? and * on multiples operands and positions});

@$operands = ("M?th?maTiqu?", "Fo*", "?A?");
@$indexes = ("all_fields", "all_fields", "all_fields");
@$operators = ("AND", "AND");
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = "m?th?matiqu? AND fo* AND ?a?";
is($got, $expected, qq{Test wildCard ? and * on multiples operands and positions});

BEGIN { $tests += 3 } # [ TO ] format
@$operands = (qq{[1900-01-01T00:00:00Z TO 2011-01-01T00:00:00Z]});
@$indexes = ("pubdate");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{date_pubdate:[1900-01-01T00:00:00Z TO 2011-01-01T00:00:00Z]};
is($got, $expected, qq{Test date with [ TO ] format});

@$operands = (qq{[* TO *]});
@$indexes = ("title");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{$titleindex:[* TO *]};
is($got, $expected, qq{Test [* TO *] format});

@$operands = (qq{[* TO ZZ]});
@$indexes = ("title");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{$titleindex:[* TO ZZ]};
is($got, $expected, qq{Test [* TO ZZ] format});

BEGIN { $tests += 2 } # test just one " or (
$q = qq{foo \\"bar};
$got = C4::Search::Query->normalSearch($q);
$expected = qq{foo \\"bar};
is($got, $expected, qq{Test just one \" (normalSearch)});

@$operands = (qq{"foo \\"bar"});
@$indexes = ("title");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{(em$titleindex:"foo \\"bar")};
is($got, $expected, qq{Test just one \" (buildQuery)});

BEGIN { $tests += 15 } # Test for date index
$q = qq{pubdate:2000};
$got = C4::Search::Query->normalSearch($q);
$expected = qq{$pubdateindex:"2000-01-01T00:00:00Z"};
is($got, $expected, qq{Date index format with 1 date (normalSearch)});

$q = qq{pubdate:2000 OR pubdate:2001};
$got = C4::Search::Query->normalSearch($q);
$expected = qq{$pubdateindex:"2000-01-01T00:00:00Z" OR date_pubdate:"2001-01-01T00:00:00Z"};
is($got, $expected, qq{Date index format with 1 date (normalSearch)});

#$q = qq{pubdate:[2000 TO 2011]}; # NOT SUPPORTED !
#$got = C4::Search::Query->normalSearch($q);
#$expected = qq{$pubdateindex:[2000-01-01T00:00:00Z TO 2011-01-01T00:00:00Z]};
#is($got, $expected, qq{Date index format with 1 date (normalSearch)});

$q = qq{date_pubdate:"2001-01-01T00:00:00Z"};
$got = C4::Search::Query->normalSearch($q);
$expected = qq{$pubdateindex:"2001-01-01T00:00:00Z"};
is($got, $expected, qq{Date index format iso with 1 date (normalSearch)});
@$operands = (qq{2000});

$q = qq{date_pubdate:2001-01-01T00:00:00Z};
$got = C4::Search::Query->normalSearch($q);
$expected = qq{$pubdateindex:"2001-01-01T00:00:00Z"};
is($got, $expected, qq{Date index format iso (without quote) with 1 date (normalSearch)});
@$operands = (qq{2000});

@$indexes = ("pubdate");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{$pubdateindex:"2000-01-01T00:00:00Z"};
is($got, $expected, qq{Date index format with 1 date(buildQuery)});

@$operands = (qq{maudits}, qq{2000});
@$indexes = ("all_fields", "pubdate");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{maudits AND $pubdateindex:"2000-01-01T00:00:00Z"};
is($got, $expected, qq{Date index format with 1 date(buildQuery)});

@$operands = (qq{2000 2001 2002});
@$indexes = ("pubdate");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{($pubdateindex:"2000-01-01T00:00:00Z" AND date_pubdate:"2001-01-01T00:00:00Z" AND date_pubdate:"2002-01-01T00:00:00Z")};
is($got, $expected, qq{Date index format with x dates (buildQuery)});

@$operands = (qq{[2000 TO 2011]});
@$indexes = ("pubdate");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{$pubdateindex:[2000-01-01T00:00:00Z TO 2011-01-01T00:00:00Z]};
is($got, $expected, qq{Date index format with x dates (buildQuery)});

@$operands = (qq{"2000-01-01T00:00:00Z"});
@$indexes = ("pubdate");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{$pubdateindex:"2000-01-01T00:00:00Z"};
is($got, $expected, qq{Date index format iso (buildQuery)});

@$operands = (qq{[2000-01-01T00:00:00Z TO 2011-01-01T00:00:00Z]});
@$indexes = ("pubdate");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{$pubdateindex:[2000-01-01T00:00:00Z TO 2011-01-01T00:00:00Z]};
is($got, $expected, qq{Date index format iso [date1 TO date2] (buildQuery)});

@$operands = (qq{[2000-01-01T00:00:00Z TO *]});
@$indexes = ("pubdate");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{$pubdateindex:[2000-01-01T00:00:00Z TO *]};
is($got, $expected, qq{Date index format iso [date TO *] (buildQuery)});

@$operands = (qq{[* TO 2011-01-01T00:00:00Z]});
@$indexes = ("pubdate");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{$pubdateindex:[* TO 2011-01-01T00:00:00Z]};
is($got, $expected, qq{Date index format iso [* TO date] (buildQuery)});

@$operands = (qq{(1984 OR 10-1990 OR 01-10-2001)});
@$indexes = ("pubdate");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{$pubdateindex:("1984-01-01T00:00:00Z" OR "1990-10-01T00:00:00Z" OR "2001-10-01T00:00:00Z")};
is($got, $expected, qq{Date index format multi-operand (buildQuery)});

@$operands = (qq{("1984" OR 10-1990 OR "01-10-2001")});
@$indexes = ("pubdate");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{$pubdateindex:("1984-01-01T00:00:00Z" OR "1990-10-01T00:00:00Z" OR "2001-10-01T00:00:00Z")};
is($got, $expected, qq{Date index format multi-operand (with quotes) (buildQuery)});

@$operands = (qq{("1984" 10-1990 "01-10-2001")});
@$indexes = ("pubdate");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{$pubdateindex:("1984-01-01T00:00:00Z" "1990-10-01T00:00:00Z" "2001-10-01T00:00:00Z")};
is($got, $expected, qq{Date index format multi-operand (AND) (buildQuery) END});

BEGIN { $tests += 8 } # Test for exact match
$q = qq{title:"Le crépuscule des maudits"};
$got = C4::Search::Query->normalSearch($q);
$expected = qq{em$titleindex:"Le crépuscule des maudits"};
is($got, $expected, qq{Exactmatch on an index (normalSearch)});

$q = qq{title:"Le crépuscule" title:"des maudits"};
$got = C4::Search::Query->normalSearch($q);
$expected = qq{em$titleindex:"Le crépuscule" em$titleindex:"des maudits"};
is($got, $expected, qq{Exactmatch on multiples index (normalSearch)});

$q = qq{"Le crépuscule des maudits"};
$got = C4::Search::Query->normalSearch($q);
$expected = qq{emallfields:"Le crépuscule des maudits"};
is($got, $expected, qq{Exactmatch on all fields (normalSearch)});

$q = qq{title:"Le crépuscule" "des maudits"};
$got = C4::Search::Query->normalSearch($q);
$expected = qq{em$titleindex:"Le crépuscule" emallfields:"des maudits"};
is($got, $expected, qq{Exactmatch on an index and all fields (normalSearch)});

$q = qq{emallfields:"Le crépuscule des maudits"};
$got = C4::Search::Query->normalSearch($q);
$expected = qq{emallfields:"Le crépuscule des maudits"};
is($got, $expected, qq{Exactmatch on emallfields directly (normalSearch)});

@$operands = (qq{"Le crépuscule des maudits"});
@$indexes = ("emallfields");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{(emallfields:"Le crépuscule des maudits")};
is($got, $expected, qq{Exactmatch on emallfields directly (buildQuery)});

$q = qq{str_foo:"Le crépuscule des maudits"};
$got = C4::Search::Query->normalSearch($q);
$expected = qq{str_foo:"Le crépuscule des maudits"};
is($got, $expected, qq{Exactmatch don't replace str_* index (normalSearch)});

@$operands = (qq{"Le crépuscule des maudits"});
@$indexes = ("str_foo");
@$operators = ();
$got = C4::Search::Query->buildQuery($indexes, $operands, $operators);
$expected = qq{(str_foo:"Le crépuscule des maudits")};
is($got, $expected, qq{Exactmatch don't replace str_* index (buildQuery)});

