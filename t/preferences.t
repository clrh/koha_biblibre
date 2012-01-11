#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use C4::Context;

plan tests => 3;

my $numSearchResults = C4::Context->preference("numSearchResults");

C4::Context->clear_syspref_cache;

C4::Context->set_preference("SearchEngine", "Solr");
is( C4::Context->preference("SearchEngine"), "Solr");
is( C4::Context->preference("numSearchResults"), $numSearchResults);

C4::Context->clear_syspref_cache;

is( C4::Context->preference("SearchEngine"), "Solr");
