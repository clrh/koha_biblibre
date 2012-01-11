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

=head1 cataloguing:addbooks.pl

	TODO

=cut

use strict;
use warnings;
use CGI;
use C4::Auth;
use C4::Biblio;
use C4::Breeding;
use C4::Output;
use C4::Koha;
use C4::Search;
use Data::Pagination;

my $input   = new CGI;
my $succes  = $input->param('biblioitem');
my $query   = $input->param('q');
my @value   = $input->param('value');
my $page    = $input->param('page') || 1;
my $sort_by = $input->param('sort_by');
my $count   = 20;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user( {
    template_name   => "cataloguing/addbooks.tmpl",
    query           => $input,
    type            => "intranet",
    authnotrequired => 0,
    flagsrequired   => { editcatalogue => 'edit_catalogue' },
    debug           => 1,
} );

# Get framework list
my $frameworks = getframeworks;
my @frameworkcodeloop = map { {
    value         => $_,
    frameworktext => $frameworks->{$_}->{'frameworktext'},
} } keys %{$frameworks};

# Searching the catalog.
if ( $query ) {

    # Regular search
    my $res = SimpleSearch( $query, { recordtype => 'biblio' }, { page => $page, count => $count, sort => $sort_by } );
    my @results = map { GetBiblio $_->{'values'}->{'recordid'} } @{ $res->items };
    my $pager = Data::Pagination->new(
        $res->{'pager'}->{'total_entries'},
        $count,
        20,
        $page,
    );

    # BreedingSearch
    my ( $title, $isbn );
    $query =~ /^(\d{10}|\d{12}.)$/ ? $isbn = $1 : $title = $1;
    my ( $breeding_count, @breeding_loop ) = BreedingSearch( $title, $isbn );

    # set the default sorting
    my $sort_by = $input->param('sort_by') || join(' ', grep { defined } (
            C4::Search::Query::getIndexName(C4::Context->preference('defaultSortField'))
                                          , C4::Context->preference('defaultSortOrder') ) );
    my $sortloop = C4::Search::Engine::Solr::GetSortableIndexes('biblio');
    for ( @$sortloop ) { # because html template is stupid
        $_->{'asc_selected'}  = $sort_by eq $_->{'type'}.'_'.$_->{'code'}.' asc';
        $_->{'desc_selected'} = $sort_by eq $_->{'type'}.'_'.$_->{'code'}.' desc';
    }

    $template->param(
        'sort_by'  => $sort_by,
        'sortloop' => $sortloop,
    );

    $template->param(
        query          => $query,
        total          => $res->{'pager'}->{'total_entries'},
        resultsloop    => \@results,
        PAGE_NUMBERS   => [ map { { page => $_, current => $_ == $page } } @{ $pager->{'numbers_of_set'} } ],
        follower_params => [ { ind => 'q', val => $query }, { ind => 'sort_by', val => $sort_by } ],
        breeding_count => $breeding_count,
        breeding_loop  => \@breeding_loop,
    );
}

$template->param(
    frameworkcodeloop   => \@frameworkcodeloop,
    z3950_search_params => C4::Search::z3950_search_args($query),
);

output_html_with_http_headers $input, $cookie, $template->output;
