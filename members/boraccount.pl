#!/usr/bin/perl

#writen 11/1/2000 by chris@katipo.oc.nz
#script to display borrowers account details

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

use C4::Auth;
use C4::Output;
use C4::Dates qw/format_date/;
use CGI;
use C4::Members;
use C4::Branch;
use C4::Accounts;

my $input = new CGI;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => "members/boraccount.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { borrowers => 1, updatecharges => 1 },
        debug           => 1,
    }
);

my $borrowernumber = $input->param('borrowernumber');
my $action = $input->param('action') || '';

#get borrower details
my $data = GetMember( 'borrowernumber' => $borrowernumber );

if ( $action eq 'reverse' ) {
    ReversePayment( $input->param('accountlineid') );
}

if ( $data->{'category_type'} eq 'C' ) {
    my ( $catcodes, $labels ) = GetborCatFromCatType( 'A', 'WHERE category_type = ?' );
    my $cnt = scalar(@$catcodes);
    $template->param( 'CATCODE_MULTI' => 1 ) if $cnt > 1;
    $template->param( 'catcode' => $catcodes->[0] ) if $cnt == 1;
}

#get account details
my ( $total, $accts, undef ) = GetMemberAccountRecords($borrowernumber);
my $totalcredit;
if ( $total <= 0 ) {
    $totalcredit = 1;
}

my $reverse_col = 0;    # Flag whether we need to show the reverse column
foreach my $accountline ( @{$accts} ) {
    $accountline->{amount} += 0.00;
    if ( $accountline->{amount} <= 0 ) {
        $accountline->{amountcredit} = 1;
    }
    $accountline->{amountoutstanding} += 0.00;
    if ( $accountline->{amountoutstanding} <= 0 ) {
        $accountline->{amountoutstandingcredit} = 1;
    }

    $accountline->{date}              = format_date( $accountline->{date} );
    $accountline->{amount}            = sprintf '%.2f', $accountline->{amount};
    $accountline->{amountoutstanding} = sprintf '%.2f', $accountline->{amountoutstanding};
    if ( $accountline->{accounttype} eq 'Pay' ) {
        $accountline->{payment} = 1;
        $reverse_col = 1;
    }
    if ( $accountline->{accounttype} ne 'F' && $accountline->{accounttype} ne 'FU' ) {
        $accountline->{printtitle} = 1;
    }
    
    if ( $accountline->{accounttype} ne 'F' && $accountline->{accounttype} ne 'FU' ) {
        $accountline->{printtitle} = 1;
    }
    if ( $accountline->{manager_id} ne '' ) {
       my $datamanager = GetMember( 'borrowernumber' => $accountline->{manager_id} );
    	$accountline->{manager_details}=$datamanager->{'firstname'}." ".$datamanager->{'surname'};
    }
}

$template->param( adultborrower => 1 ) if ( $data->{'category_type'} eq 'A' );

my ( $picture, $dberror ) = GetPatronImage( $data->{'cardnumber'} );
$template->param( picture => 1 ) if $picture;

$template->param(
    finesview      => 1,
    firstname      => $data->{'firstname'},
    surname        => $data->{'surname'},
    borrowernumber => $borrowernumber,
    cardnumber     => $data->{'cardnumber'},
    categorycode   => $data->{'categorycode'},
    category_type  => $data->{'category_type'},
    categoryname   => $data->{'description'},
    address        => $data->{'address'},
    address2       => $data->{'address2'},
    city           => $data->{'city'},
    zipcode        => $data->{'zipcode'},
    country        => $data->{'country'},
    phone          => $data->{'phone'},
    email          => $data->{'email'},
    branchcode     => $data->{'branchcode'},
    branchname     => GetBranchName( $data->{'branchcode'} ),
    total          => sprintf( "%.2f", $total ),
    totalcredit    => $totalcredit,
    is_child       => ( $data->{'category_type'} eq 'C' ),
    reverse_col    => $reverse_col,
    accounts       => $accts
);

output_html_with_http_headers $input, $cookie, $template->output;
