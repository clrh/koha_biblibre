#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
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

use strict;
use warnings;

use CGI;
use C4::Output;
use C4::Auth;
use C4::Context;
use C4::AuthoritiesMarc;
use C4::Acquisition;
use C4::Koha;
use C4::Search;
use C4::Search::Query;
use Data::Pagination;

my $query        = new CGI;
my $authtypecode = $query->param('authtypecode') || '[* TO *]';
my $index        = $query->param('index');
my $tagid        = $query->param('tagid');
my $resultstring = $query->param('result');
my $op           = $query->param('op') || "";
my $dbh          = C4::Context->dbh;

my ( $template, $loggedinuser, $cookie );

my $authtypes = getauthtypes;
my @authtypesloop = map { {
    value        => $_,
    selected     => ( $_ eq $authtypecode ),
    authtypetext => $authtypes->{$_}->{'authtypetext'},
    index        => $index,
} } keys %$authtypes;

if ( $op eq 'do_search' ) {
    my $orderby     = $query->param('orderby') || 'score desc';
    my $page        = $query->param('page') || 1;
    my $count       = 20;

    ( $template, $loggedinuser, $cookie ) = get_template_and_user( {
        template_name   => "authorities/searchresultlist-auth.tmpl",
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { catalogue => 1 },
    } );

    my @searchtypes = ('authority_search', 'main_heading', 'all_headings');

    my $indexes;
    my $value;
    my $operands;
    my $operators;
    my $authoritysep = C4::Context->preference('authoritysep');
    # Construct arrays with 3 values
    for my $searchtype (@searchtypes) {
        my $idx = GetIndexBySearchtype($searchtype);
        my $value = $query->param($searchtype);
        # if there is a value
        if ( $value ){
            $value =~ s/$authoritysep//g; # Supression of the authority separator
            my @values = split (' ', $value); # Get all words
            $_ =~ s/"/\\"/g for @values;
            push @$operands, "\"$_\"" for @values; # Each word is an operand
            push @$indexes, $idx for @values; # For each word, push idx corresponding
            push @$operators, 'AND' for @values; # idem for operator
        # Else, if we have not operand and it's the 'all_headings' fields
        } elsif ( not $operands and $searchtype eq 'all_headings' ) {
            # We search all authorities
            push @$operands, "[* TO *]";
            push @$indexes, $idx;
            push @$operators, 'AND';
        }
        $template->param($searchtype => $query->param($searchtype));
    }

    my $authtype_indexname = C4::Search::Query::getIndexName('auth-type');
    my $filters = {
        recordtype => 'authority',
        $authtype_indexname => $authtypecode
    };

    # Construct and Perform the query
    my $q = C4::Search::Query->buildQuery( $indexes, $operands, $operators );
    my $results = SimpleSearch( $q, $filters, { page => $page, count => $count, sort => $orderby, fl => [$authtype_indexname] } );

    # If no resuls, we search on summary index
    # In fact, we search string returned by autocompletion
    if ( not $results->{pager}->{total_entries} ){
        my $indexes = ();
        my $operands = ();
        my $operators = ();

        my $summary_index = C4::Search::Query::getIndexName('auth-summary');
        for my $searchtype (@searchtypes) {
            my $value = $query->param($searchtype);
            if ( $value ){
                $value =~ s/^\s*(.*)\s*$/$1/; # Delete spaces (begin and after string)
                $value =~ s/"/\\"/g;
                push @$operands, "\"$value\"";
                push @$indexes, $summary_index;
                push @$operators, 'AND';
            }
            $template->param($searchtype => $query->param($searchtype));
        }

        $q = C4::Search::Query->buildQuery( $indexes, $operands, $operators );
        $results = SimpleSearch( $q, $filters, { page => $page, count => $count, sort => $orderby, fl => [$authtype_indexname] } );
    }

    my @resultdatas = map {
        my $record = GetAuthority( $_->{'values'}->{'recordid'} );
        {
            authid  => $_->{'values'}->{'recordid'},
            summary => BuildSummary( $record, $_->{'values'}->{'recordid'}, $_->{'values'}->{$authtype_indexname} ),
            used    => CountUsage($_->{values}->{recordid}),
        }
    } @{ $results->{items} };

    my $pager = Data::Pagination->new(
        $results->{'pager'}->{'total_entries'},
        $count,
        20,
        $page,
    );

    my $follower_params = [
        { ind => 'index'            , val => $index        },
        { ind => 'authtypecode'     , val => $authtypecode },
        { ind => 'orderby'         , val => $orderby      },
        { ind => 'op'               , val => 'do_search'   },
        { ind => 'authority_search' , val => $query->param('authority_search') || "" },
        { ind => 'main_heading'     , val => $query->param('main_heading') || "" },
        { ind => 'all_headings'     , val => $query->param('all_headings') || "" },
    ];

    $template->param(
        previous_page  => $pager->{'prev_page'},
        next_page      => $pager->{'next_page'},
        PAGE_NUMBERS   => [ map { { page => $_, current => $_ == $page } } @{ $pager->{'numbers_of_set'} } ],
        current_page   => $page,
        total          => $pager->{'total_entries'},
        follower_params   => $follower_params,
        result         => \@resultdatas,
        orderby        => $orderby,
        authtypecode   => $authtypecode,
    );
} else {
    ( $template, $loggedinuser, $cookie ) = get_template_and_user( {
        template_name   => "authorities/auth_finder.tmpl",
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { catalogue => 1 },
    } );

    $template->param( resultstring => $resultstring, );
}

$template->param(
    tagid         => $tagid,
    index         => $index,
    authtypesloop => \@authtypesloop,
    authtypecode  => $authtypecode,
    name_index_name => C4::Search::Query::getIndexName('auth-summary'),
    usedinxbiblios_index_name => C4::Search::Query::getIndexName('usedinxbiblios'),
);

# Print the page
output_html_with_http_headers $query, $cookie, $template->output;
