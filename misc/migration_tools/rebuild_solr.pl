#!/usr/bin/perl

use strict;
use warnings;
use C4::Context;
use C4::Search;
use Data::Dumper;
use Getopt::Long;
use LWP::Simple;
use XML::Simple;

$|=1; # flushes output

if ( C4::Context->preference("SearchEngine") ne 'Solr' ) {
    warn "System preference 'SearchEngine' not equal 'Solr'.";
    warn "We can not indexing";
    exit(1);
}

#Setup

my ( $reset, $number, $recordtype, $biblionumbers, $optimize, $info, $want_help );
GetOptions(
    'r'   => \$reset,
    'n:s' => \$number,
    't:s' => \$recordtype,
    'w:s' => \$biblionumbers,
    'o'   => \$optimize,
    'i'   => \$info,
    'h|help' => \$want_help,
);
my $debug = C4::Context->preference("DebugLevel");
my $solrurl = C4::Context->preference("SolrAPI");

my $ping = &PingCommand;
if (!defined $ping) {
    print "Solr is Down\n";
    exit(1);
}

#Script

&PrintHelp if ($want_help);
&PrintInfo if ($info);
if ($reset){
  if ($recordtype){
      &ResetIndex("recordtype:".$recordtype);
  } else {
      &ResetIndex("*:*");
  }
}

if (defined $biblionumbers){
    if (not defined $recordtype) { print "You must specify a recordtype\n"; exit 1;}
    &IndexBiblio($_) for split ',', $biblionumbers;
} elsif  (defined $recordtype) {
    &IndexData;
    &Optimize;
}

if ($optimize) {
    &Optimize;
}

#Functions

sub IndexBiblio {
    my ($biblionumber) = @_;
    IndexRecord($recordtype, [ $biblionumber ] );
}

sub IndexData {
    my $dbh = C4::Context->dbh;
        $dbh->do('SET NAMES UTF8;');

    my $query;
    if ( $recordtype eq 'biblio' ) {
      $query = "SELECT biblionumber FROM biblio ORDER BY biblionumber";
    } elsif ( $recordtype eq 'authority' ) {
      $query = "SELECT authid FROM auth_header ORDER BY authid";
    }
    $query .= " LIMIT $number" if $number;

    my $sth = $dbh->prepare( $query );
    $sth->execute();

    IndexRecord($recordtype, [ map { $_->[0] } @{ $sth->fetchall_arrayref } ] );

    $sth->finish;
}

sub ResetIndex {
    &ResetCommand;
    &CommitCommand;
    $debug eq '2' && &CountAllDocs eq 0 && warn  "Index cleaned!"
}

sub CommitCommand {
    my $commiturl = "/update?stream.body=%3Ccommit/%3E";
    my $urlreturns = get $solrurl.$commiturl;
}

sub PingCommand {
    my $pingurl = "/admin/ping";
    my $urlreturns = get $solrurl.$pingurl;
}

sub ResetCommand {
    my ($query) = @_;
    my $deleteurl = "/update?stream.body=%3Cdelete%3E%3Cquery%3E".$query."%3C/query%3E%3C/delete%3E";
    my $urlreturns = get $solrurl.$deleteurl;
}

sub Optimize {
    my $sc = C4::Search::Engine::Solr::GetSolrConnection;
    $sc->_solr->optimize;
}

sub CountAllDocs {
    my $queryurl = "/select/?q=*:*";
    my $urlreturns = get $solrurl.$queryurl;
    my $xmlsimple = XML::Simple->new();
    my $data = $xmlsimple->XMLin($urlreturns);
    return $data->{result}->{numFound};
}

sub PrintInfo {
    my $count = &CountAllDocs;
    print <<_USAGE_;
SolrAPI = $solrurl
How many indexed documents = $count;
_USAGE_
}

sub PrintHelp {
    print <<_USAGE_;
$0: reindex biblios and/or authorities in Solr.

Use this batch job to reindex all biblio or authority records in your Koha database.  This job is useful only if you are using Solr search engine.

Parameters:
    -t biblio               index bibliographic records

    -t authority            index authority records

    -r                      clear Solr index before adding records to index - use this option carefully!

    -n 100                  index 100 first records

    -n "100,2"              index 2 records after 100th (101 and 102)

    -w 101                  index biblio with biblionumber equals 101

    -o                      launch optimize command at the end of indexing

    -i                      gives solr install information: SolrAPI value and count all documents indexed

    --help or -h            show this message.
_USAGE_
}
