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

=head1 NAME

blinddetail-biblio-search.pl : script to show an authority in MARC format

=head1 SYNOPSIS


=head1 DESCRIPTION

This script needs an authid

It shows the authority in a (nice) MARC format depending on authority MARC
parameters tables.

=head1 FUNCTIONS

=over 2

=cut

use strict;
use warnings;

use C4::AuthoritiesMarc;
use C4::Auth;
use C4::Output;
use CGI;

my $query = new CGI;

my $authid       = $query->param('authid');
my $index        = $query->param('index');

# open template
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => "authorities/blinddetail-biblio-search.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { editcatalogue => 'edit_catalogue' },
    }
);

# fill arrays
my @subfields_loop = ();
if ($authid) {
    my $record = GetAuthority($authid);
    my $authtypecode = GetAuthTypeCode($authid);
    my $auth_type = GetAuthType($authtypecode);
    foreach my $field ( $record->field( $auth_type->{auth_tag_to_report} ) ) {
        foreach my $subfield ($field->subfields) {
            push @subfields_loop, {
                marc_subfield => $subfield->[0] || '@',
                marc_value => $subfield->[1]
            };
        }
    }
}

$template->param( "subfields_loop" => \@subfields_loop );

$template->param(
    authid => $authid ? $authid : "",
    index  => $index,
);

output_html_with_http_headers $query, $cookie, $template->output;

