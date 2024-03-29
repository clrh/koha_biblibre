#!/usr/bin/perl
# Copyright 2009 SARL BibLibre
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
use C4::Auth;
use C4::Biblio;
use C4::Koha;
use C4::Output;

my $query = new CGI;

my $framework = $query->param('framework') || "";

my $field        = $query->param('fieldname');
my $fieldcode    = $query->param('marcfield');
my $subfieldcode = $query->param('marcsubfield');
my $op           = $query->param('op');
my $id           = $query->param('id');

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => "admin/fieldmapping.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { parameters => 1 },
        debug           => 1,
    }
);

# get framework list
my $frameworks = getframeworks();
my @frameworkloop;
foreach my $thisframeworkcode ( keys %$frameworks ) {
    my $selected = 1 if $thisframeworkcode eq $framework;
    my %row = (
        value         => $thisframeworkcode,
        selected      => $selected,
        frameworktext => $frameworks->{$thisframeworkcode}->{'frameworktext'},
    );
    push @frameworkloop, \%row;
}

if ( $op eq "delete" and $id ) {
    DeleteFieldMapping($id);
    print $query->redirect( "/cgi-bin/koha/admin/fieldmapping.pl?framework=" . $framework );
    exit;
}

# insert operation
if ( $field and $fieldcode ) {
    SetFieldMapping( $framework, $field, $fieldcode, $subfieldcode );
}

my $fieldloop = GetFieldMapping($framework);

$template->param(
    frameworkloop => \@frameworkloop,
    framework     => $framework,
    fields        => $fieldloop,
);

output_html_with_http_headers $query, $cookie, $template->output;
