#!/usr/bin/perl

# Copyright 2008 Garry Collum and the Koha Koha Development team
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Script to perform searching
# Mostly copied from search.pl, see POD there
use strict;    # always use
use warnings;

## STEP 1. Load things that are used in both search page and
# results page and decide which template to load, operations
# to perform, etc.
## load Koha modules
use C4::Context;
use C4::Output;
use C4::Auth qw(:DEFAULT get_session);
use C4::Languages qw(getAllLanguages getAllLanguagesAuthorizedValues);
use C4::Search;
use C4::Search::Query;
use C4::Biblio;    # GetBiblioData
use C4::Koha;
use C4::Tags qw(get_tags);
use C4::Branch;    # GetBranches
use POSIX qw(ceil floor strftime);
use URI::Escape;
use Storable qw(thaw freeze);
use Data::Pagination;
use C4::XSLT;
use C4::Charset;
use C4::VirtualShelves qw/GetRecentShelves/;
use 5.10.0;


# create a new CGI object
# FIXME: no_undef_params needs to be tested
use CGI qw('-no_undef_params');
my $cgi = new CGI;

BEGIN {
    if ( C4::Context->preference('BakerTaylorEnabled') ) {
        require C4::External::BakerTaylor;
        import C4::External::BakerTaylor qw(&image_url &link_url);
    }
}

my ( $template, $borrowernumber, $cookie );

# decide which template to use
my $template_name;
my $template_type = 'basic';
my @params        = $cgi->param("filters");

my $format = $cgi->param("format") || '';
my $build_grouped_results = C4::Context->preference('OPACGroupResults');
if ( $format =~ /(rss|atom|opensearchdescription)/ ) {
    $template_name = 'opac-opensearch.tmpl';
} elsif ($build_grouped_results) {
    $template_name = 'opac-results-grouped.tmpl';
} elsif ( ( $cgi->param("filters") ) || ( $cgi->param("idx") ) || ( $cgi->param("q") ) || ( $cgi->param('multibranchlimit') ) || ( $cgi->param('limit-yr') ) || ( $cgi->param('tag') ) ) {
    $template_name = 'opac-results.tmpl';
} else {
    $template_name = 'opac-advsearch.tmpl';
    $template_type = 'advsearch';
}

# load the template
( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {   template_name   => $template_name,
        query           => $cgi,
        type            => "opac",
        authnotrequired => 1,
    }
);

if ( $format eq 'rss2' or $format eq 'opensearchdescription' or $format eq 'atom' ) {
    $template->param( $format => 1 );
    $template->param( timestamp => strftime( "%Y-%m-%dT%H:%M:%S-00:00", gmtime ) ) if ( $format eq 'atom' );

    # FIXME - the timestamp is a hack - the biblio update timestamp should be used for each
    # entry, but not sure if that's worth an extra database query for each bib
}
if ( C4::Context->preference("marcflavour") eq "UNIMARC" ) {
    $template->param( 'UNIMARC' => 1 );
} elsif ( C4::Context->preference("marcflavour") eq "MARC21" ) {
    $template->param( 'usmarc' => 1 );
}
$template->param( 'AllowOnShelfHolds' => C4::Context->preference('AllowOnShelfHolds') );
$template->param( 'OPACNoResultsFound' => C4::Context->preference('OPACNoResultsFound') );

if ( C4::Context->preference('BakerTaylorEnabled') ) {
    $template->param(
        BakerTaylorEnabled      => 1,
        BakerTaylorImageURL     => &image_url(),
        BakerTaylorLinkURL      => &link_url(),
        BakerTaylorBookstoreURL => C4::Context->preference('BakerTaylorBookstoreURL'),
    );
}

# load the branches
my $mybranch = ( C4::Context->preference('SearchMyLibraryFirst') && C4::Context->userenv && C4::Context->userenv->{branch} ) ? C4::Context->userenv->{branch} : '';
my $branches = GetBranches();    # used later in *getRecords, probably should be internalized by those functions after caching in C4::Branch is established
my $branchloop = GetBranchesLoop( $mybranch, 0 );
unless ($mybranch){
    foreach (@$branchloop){
        $_->{'selected'}=0;
    }
}
$template->param(
    branchloop       => $branchloop,
    searchdomainloop => GetBranchCategories( undef, 'searchdomain' ),
    holdingbranch_indexname => C4::Search::Query::getIndexName('holdingbranch'),
);

# load the language limits (for search)
$template->param( search_languages_loop => getAllLanguagesAuthorizedValues() );
$template->param( lang_indexname => C4::Search::Query::getIndexName('lang') );

# load the sorting stuff
my $sort_by = $cgi->param('sort_by') || join(' ', grep { defined } (
        C4::Search::Query::getIndexName(C4::Context->preference('OPACdefaultSortField'))
        , C4::Context->preference('OPACdefaultSortOrder') ) );
my $sortloop = C4::Search::Engine::Solr::GetSortableIndexes('biblio');
for ( @$sortloop ) { # because html template is stupid
    $_->{'asc_selected'}  = $sort_by eq $_->{'type'}.'_'.$_->{'code'}.' asc';
    $_->{'desc_selected'} = $sort_by eq $_->{'type'}.'_'.$_->{'code'}.' desc';
}

$template->param(
    'sort_by'  => $sort_by,
    'sortloop' => $sortloop,
);

# load the Type stuff
my $itemtypes = GetItemTypes;

#Give ability to search in authorised values
my $indexandavlist = C4::Search::Engine::Solr::GetIndexesWithAvlist;

# the index parameter is different for item-level itemtypes
my $itype_or_itemtype = ( C4::Context->preference("item-level_itypes") ) ? 'itype' : 'itemtype';
my @itemtypesloop;
my $cnt;
my $advanced_search_types = C4::Context->preference("AdvancedSearchTypes");
my $itype_or_ccode;
my @itypes = $cgi->param('itypes');
my @indexes = $cgi->param('idx');
my @operators = $cgi->param('op');
my @operands = $cgi->param('q');
$operands[0] = '[* TO *]' if not defined $operands[0];

my $query_cgi = "q=" .       join("&q=", @operands);
$query_cgi   .= "&itypes=" . join("&itypes=", @itypes)  if (@itypes);
$query_cgi   .= "&idx=" .    join("&idx=", @indexes)    if (@indexes);
$query_cgi   .= "&op=" .     join("&op=", @operators)   if (@operators);
$query_cgi   .= "&filters=" .join("&filters=", @params) if (@params);
$query_cgi   .= "&sort_by=$sort_by"                     if ($sort_by);

if ( !$advanced_search_types or $advanced_search_types eq 'itemtypes' ) {
    $itype_or_ccode = 'itype';
} else {
    $itype_or_ccode = 'ccode';
}

my $itype_indexname = C4::Search::Query::getIndexName($itype_or_ccode);
# Build itemtypesloop
# Set selected itypes
if ( $itype_or_ccode ne 'ccode') {
    foreach my $thisitemtype ( sort { $itemtypes->{$a}->{'description'} cmp $itemtypes->{$b}->{'description'} } keys %$itemtypes ) {
        my $selected = grep {$_ eq $thisitemtype} @itypes;
        my %row = (
            number      => $cnt++,
            indexname   => $itype_indexname,
            code        => $thisitemtype,
            selected    => $selected,
            description => $itemtypes->{$thisitemtype}->{'description'},
            count5      => $cnt % 4,
            imageurl    => getitemtypeimagelocation( 'opac', $itemtypes->{$thisitemtype}->{'imageurl'} ),
        );
        push @itemtypesloop, \%row;
    }
} else {
    my $advsearchtypes = GetAuthorisedValues($advanced_search_types, undef, 1);
    for my $thisitemtype ( sort { $a->{'lib'} cmp $b->{'lib'} } @$advsearchtypes ) {
        my $selected = grep {$_ eq $thisitemtype} @itypes;
        my %row = (
            number      => $cnt++,
            indexname   => $itype_indexname,
            code        => $thisitemtype->{authorised_value},
            selected    => $selected,
            description => $thisitemtype->{'lib'},
            count5      => $cnt % 4,
            imageurl    => getitemtypeimagelocation( 'opac', $thisitemtype->{'imageurl'} ),
        );
        push @itemtypesloop, \%row;
    }
}

$template->param(
    itemtypeloop => \@itemtypesloop,
    itemtypelib => C4::Search::Engine::Solr::GetIndexLabelFromCode( $itype_or_ccode ) # Lib for category
);

# The following should only be loaded if we're bringing up the advanced search template
if ( $template_type && $template_type eq 'advsearch' ) {

    # set the default sorting
    my $default_sort_by = C4::Search::Query::getIndexName(C4::Context->preference('OPACdefaultSortField')) . "_" . C4::Context->preference('OPACdefaultSortOrder')
      if ( C4::Context->preference('OPACdefaultSortField') && C4::Context->preference('OPACdefaultSortOrder') );
    $template->param( $default_sort_by => 1 );

    # determine what to display next to the search boxes (ie, boolean option
    # shouldn't appear on the first one, scan indexes should, adding a new
    # box should only appear on the last, etc.
    my $indexloop = C4::Search::Engine::Solr::GetIndexes('biblio');
    my $search_boxes_count = C4::Context->preference("OPACAdvSearchInputCount") || 3;
    my @search_boxes_array = map {{ indexloop => $indexloop }} 1..$search_boxes_count;
    
    $template->param(
        uc( C4::Context->preference("marcflavour") ) => 1,                     # we already did this for UNIMARC
        advsearch                                    => 1,
        search_boxes_loop                            => \@search_boxes_array,
        indexandavlist                               => $indexandavlist,
        availability_indexname                       => C4::Search::Query::getIndexName('availability'),
    );

    # use the global setting by default
    if ( C4::Context->preference("expandedSearchOption") == 1 ) {
        $template->param( expanded_options => C4::Context->preference("expandedSearchOption") );
    }

    if ( C4::Context->preference("OpacAdvancedSearchContent") ne '' ) {
        $template->param( OpacAdvancedSearchContent => C4::Context->preference("OpacAdvancedSearchContent") );
    }

    # but let the user override it
    if ( defined $cgi->param('expanded_options') ) {
        if ( ( $cgi->param('expanded_options') == 0 ) || ( $cgi->param('expanded_options') == 1 ) ) {
            $template->param( expanded_options => $cgi->param('expanded_options') );
        }
    }
    output_html_with_http_headers $cgi, $cookie, $template->output;
    exit;
}

### OK, if we're this far, we're performing an actual search

# Params that can only have one value
my $count            = $cgi->param('count') || C4::Context->preference('OPACnumSearchResults') || 20;
my $page             = $cgi->param('page') || 1;

#clean operands array
for (my $i = $#indexes; $i >= 0; $i--) {
  splice @indexes,$i,1 if $i > $#operands;
}

my %filters;
# This array is used to build facets GUI
my @tplfilters;
for my $filter ( $cgi->param('filters') ) {
    next if not $filter;
    my ($k, @v) = $filter =~ /(?: \\. | [^:] )+/xg;
    my $v = join ':', @v;
    push @{$filters{$k}}, $v;
    $v =~ s/^"(.*)"$/$1/; # Remove quotes around
    push @tplfilters, {
        'ind' => $k,
        'val' => $v,
    };
}

push @{$filters{recordtype}}, 'biblio';
$template->param('filters' => \@tplfilters );

# Limit groups of Libraries
if( $cgi->param('multibranchlimit') ) {
    my $indexname = C4::Search::Query::getIndexName('homebranch');
    my @branches = @{ GetBranchesInCategory( $cgi->param('multibranchlimit') ) };
    push @{$filters{$indexname}}, '(' . join( " OR ", @branches ) . ')';
}

# append year limits if they exist
my $limit_yr = $cgi->param('limit-yr');
if ( $limit_yr ) {
    my $op;
    my $pubdate_indexname = C4::Search::Query::getIndexName('pubdate');
    if ( $limit_yr =~ /\d{4}-\d{4}/ ) {
        my ( $yr1, $yr2 ) = split( /-/, $limit_yr );
        $op = "[$yr1 TO $yr2]";
    } elsif ( $limit_yr =~ /-\d{4}/ ) {
        $limit_yr =~ /-(\d{4})/;
        $op = "[* TO $1]";
    } elsif ( $limit_yr =~ /\d{4}-/ ) {
        $limit_yr =~ /(\d{4})-/;
        $op = "[$1 TO *]";
    } elsif ( $limit_yr =~ /\d{4}/ ) {
        $op = $limit_yr;
    } else {
        #FIXME: Should return a error to the user, incorect date format specified
    }
    if ( not @indexes ) {
        $operands[0] .= " AND " if $operands[0];
        $operands[0] .= "$pubdate_indexname:$op";
    } else {
        push @operands, $op;
        push @operators, 'AND';
        push @indexes, $pubdate_indexname;
    }
}

if ( C4::Context->preference('TagsEnabled') ) {
    $template->param( TagsEnabled => 1 );
    foreach (qw(TagsShowOnList TagsInputOnList)) {
        C4::Context->preference($_) and $template->param( $_ => 1 );
    }
}

my $query_desc;
my $tag = $cgi->param('tag');
if ($tag) {
    $query_desc = "tag=$tag";
    $query_cgi  = "tag=$tag";
    warn $tag;
    my $taglist = get_tags( { term => $tag, approved => 1 } );
    my @biblionumber = map { $_->{biblionumber} } @$taglist;
    my $biblionumber_indexname = C4::Search::Query::getIndexName('recordid');
    if ( @biblionumber ) {
        $operands[0] = "$biblionumber_indexname:(" . join(' OR ', @biblionumber)  .")";
    } else {
        $operands[0] = "";
    }
}

my $end_query = C4::Context->preference('SearchOPACHides');
my $q = C4::Search::Query->buildQuery(\@indexes, \@operands, \@operators);
my $q_mod = $end_query
        ? $q . " " . C4::Search::Query->normalSearch( $end_query )
        : $q;
$query_desc = $q if not $tag;

# perform the search
my $res = SimpleSearch( $q_mod, \%filters, { page => $page, count => $count, sort => $sort_by, facets => $format =~ /rss|atom/ ? 0 : 1 } );
C4::Context->preference("DebugLevel") eq '2' && warn "OpacSolrSimpleSearch:q=$q_mod:";

if ($$res{error}){
    $template->param(query_error => $$res{error});
    output_with_http_headers $cgi, $cookie, $template->output, 'html';
    exit;
}

my $total = $res->{'pager'}->{'total_entries'},

# Opac search history
my $newsearchcookie;
my $limit_desc;
my $limit_cgi;
if ( C4::Context->preference('EnableOpacSearchHistory')
  and $format !~ /rss|atom|opensearchdescription/ )
{
    my @recentSearches;

    # Getting the (maybe) already sent cookie
    my $searchcookie = $cgi->cookie('KohaOpacRecentSearches');
    if ($searchcookie) {
        $searchcookie = uri_unescape($searchcookie);
        if ( thaw($searchcookie) ) {
            @recentSearches = @{ thaw($searchcookie) };
        }
    }

    # Adding the new search if needed
    if ( not defined $borrowernumber or $borrowernumber eq '' ) {

        # To a cookie (the user is not logged in)

        if ( not defined $page or $page == 1 ) {
            push @recentSearches,
              { "query_desc" => $query_desc || "unknown",
                "query_cgi"  => $query_cgi  || "unknown",
                "time"       => time(),
                "total"      => $total
              };
            $template->param( ShowOpacRecentSearchLink => 1 );
        }

        # Only the 15 more recent searches are kept
        # TODO: This has been done because of cookies' max size, which is
        # usually 4KB. A real check on cookie actual size would be better
        # than setting an arbitrary limit on the number of searches
        shift @recentSearches if (@recentSearches > 15);

        # Pushing the cookie back
        $newsearchcookie = $cgi->cookie(
            -name => 'KohaOpacRecentSearches',

            # We uri_escape the whole freezed structure so we're sure we won't have any encoding problems
            -value   => uri_escape( freeze( \@recentSearches ) ),
            -expires => ''
        );
        $cookie = [ $cookie, $newsearchcookie ];
    } else {

        # To the session (the user is logged in)
        if ( not defined $page or $page == 1 ) {
            AddSearchHistory( $borrowernumber, $cgi->cookie("CGISESSID"), $q, $query_cgi, $limit_desc, $limit_cgi, $total );
            $template->param( ShowOpacRecentSearchLink => 1 );
        }
    }
}

my $pager = Data::Pagination->new(
    $total,
    $count,
    20,
    $page,
);

# This array is used to build pagination, facets links, sort form
my @follower_params = map { {
    ind => 'filters',
    val => $_->{'ind'}.':"'.$_->{'val'}.'"'
} } @tplfilters;
$operands[0] = "*:*" if not defined $operands[0];
push @follower_params, map { { ind => 'q'      , val => $_ } } @operands;
push @follower_params, map { { ind => 'idx'    , val => $_ } } @indexes;
push @follower_params, map { { ind => 'op'     , val => $_ } } @operators;
push @follower_params, { ind => 'sort_by', val => $sort_by };
push @follower_params, { ind => 'tag', val => $tag } if $tag;
push @follower_params, { ind => 'multibranchlimit', val => $cgi->param('multibranchlimit') } if $cgi->param('multibranchlimit');

# Pager template params
$template->param(
    previous_page => $pager->{'prev_page'},
    next_page     => $pager->{'next_page'},
    PAGE_NUMBERS  => [ map { { page => $_, current => $_ == $page } } @{ $pager->{'numbers_of_set'} } ],
    current_page  => $page,
    follower_params  => \@follower_params,
);

# populate results with records
my @results;
my $subfieldstosearch = C4::Search::getSubfieldsToSearch();
my $itemtag = C4::Search::getItemTag();
my $b = C4::Search::getBranches();
for my $searchresult ( @{ $res->items } ) {
    my $interface = 'opac';
    my $biblionumber = $searchresult->{'values'}->{'recordid'};

    my $biblio = C4::Search::getItemsInfos($biblionumber, $interface,
        $itemtypes, $subfieldstosearch, $itemtag, $b);

    my $display = 1;
    if (C4::Context->preference('hidelostitems') or C4::Context->preference('hidenoitems')) {
        if (C4::Context->preference('hidelostitems') and $biblio->{items_count} > 0 and $biblio->{itemlostcount} >= $biblio->{items_count}) {
            $display = 0;
        }
        if (C4::Context->preference('hidenoitems') and $biblio->{availablecount} == 0) {
            $display = 0;
        }
    }
    if ($display == 1) {
        $biblio->{result_number} = ++$biblio->{shown};
        push( @results, $biblio);
    }
}

my @facets;
## If there's just one result, redirect to the detail page
if ( @results == 1
    && $format ne 'rss2'
    && $format ne 'opensearchdescription'
    && $format ne 'atom' ) {
    my $biblionumber = $res->{'items'}->[0]->{'values'}->{C4::Search::Query::getIndexName('recordid')};
    if ( C4::Context->preference('BiblioDefaultView') eq 'isbd' ) {
        print $cgi->redirect("/cgi-bin/koha/opac-ISBDdetail.pl?biblionumber=$biblionumber");
    } elsif ( C4::Context->preference('BiblioDefaultView') eq 'marc' ) {
        print $cgi->redirect("/cgi-bin/koha/opac-MARCdetail.pl?biblionumber=$biblionumber");
    } else {
        print $cgi->redirect("/cgi-bin/koha/opac-detail.pl?biblionumber=$biblionumber");
    }
    exit;
} elsif ( @results > 1 and %{$res->facets}) {
    # build facets
    my $facets_ordered = C4::Search::Engine::Solr::GetFacetedIndexes("biblio");
    for my $index ( @$facets_ordered ) {
        my $facet = $res->facets->{$index};
        if ( @$facet > 1 ) {
            my @values;
            $index =~ m/^([^_]*)_(.*)$/;
            my ($type, $code) = ($1, $2);
            my $avlist=C4::Search::Engine::Solr::GetAvlistFromCode($code);
            for ( my $i = 0 ; $i < scalar(@$facet) ; $i++ ) {
                my $value = $facet->[$i++];
                my $count = $facet->[$i];
                utf8::encode($value);
                my $lib;
                if ( $avlist ) {
                    $lib = GetAuthorisedValueLib $avlist,$value;
                } else {
                    if ( $code =~/branch/ ) {
                        $lib = GetBranchName $value;
                    }
                    if ( $code =~/itype/  or $code =~ /ccode/ ) {
                        $lib = GetSupportName $value;
                    }
                    if ( $code =~ /pubdate/ ) {
                        $lib = C4::Dates->new($value, 'iso')->output('iso');
                    }
                }
                $lib ||=$value;
                push @values, {
                    'lib'     => $lib,
                    'value'   => $value,
                    'count'   => $count,
                    'active'  => ( $filters{$index} and scalar( grep /"?\Q$value\E"?/, @{ $filters{$index} } ) ) ? 1 : 0,
                    'filters' => \@tplfilters,
                };
            }

            push @facets, {
                'indexname'  => $index,
                'label'      => C4::Search::Engine::Solr::GetIndexLabelFromCode($code),
                'values'     => \@values,
                'size'      => scalar(@values),
            };
        }
    }
}

my $availability_indexname = C4::Search::Query::getIndexName('availability');
$template->param(
    'total'          => ( @results == 0 ) ? 0 : $total,
    'opacfacets'     => 1,
    'SEARCH_RESULTS' => \@results,
    'facets_loop'    => \@facets,
    'query'          => $q,
    'query_desc'     => $query_desc,
    'searchdesc'     => $q,
    'availability'   => $filters{$availability_indexname},
    'count'          => $count,
    'tag'            => $tag,
    countRSS         => C4::Context->preference('numSearchRSSResults') || 50,
    RSS_sort_by      => C4::Search::Query::getIndexName('acqdate'),
    author_indexname => C4::Search::Query::getIndexName('author'),
    availability_indexname => $availability_indexname,
);

# VI. BUILD THE TEMPLATE
# Build drop-down list for 'Add To:' menu...
my $shelfcount = 10;
my ($pubshelves) = GetRecentShelves(2, $shelfcount, $borrowernumber);
my ($openshelves) = GetRecentShelves(3, $shelfcount, undef); # Also get 'open' shelves
push @$pubshelves, @{ $openshelves };
if ($pubshelves) {
    $template->param( addpubshelves     => scalar(@$pubshelves) );
    $template->param( addpubshelvesloop => $pubshelves );
}

my ($barshelves) = GetRecentShelves(1, undef, $borrowernumber);
if ( defined $barshelves ) {
    $template->param( addbarshelves     => scalar(@$barshelves) );
    $template->param( addbarshelvesloop => $barshelves );
}

my $content_type = ( $format eq 'rss' or $format eq 'atom' ) ? $format : 'html';

# If GoogleIndicTransliteration system preference is On Set paramter to load Google's javascript in OPAC search screens
if ( C4::Context->preference('GoogleIndicTransliteration') ) {
    $template->param( 'GoogleIndicTransliteration' => 1 );
}

output_with_http_headers $cgi, $cookie, $template->output, $content_type;
