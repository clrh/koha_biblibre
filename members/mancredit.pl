#!/usr/bin/perl

#written 11/1/2000 by chris@katipo.oc.nz
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
use CGI;

use C4::Members;
use C4::Branch;
use C4::Accounts;
use C4::Items;

my $input = new CGI;

my $borrowernumber = $input->param('borrowernumber');

#get borrower details
my $data = GetMember( 'borrowernumber' => $borrowernumber );
my $add = $input->param('add');

if ($add) {
	if(checkauth($input))
	{
	    my $barcode = $input->param('barcode');
	    my $itemnum = GetItemnumberFromBarcode($barcode) if $barcode;
	    my $desc    = $input->param('desc');
	    my $note    = $input->param('note');
	    my $meansofpayment    = $input->param('meansofpayment');
	    my $amount  = $input->param('amount') || 0;
	    $amount = -$amount;
	    my $type = $input->param('type');
	    manualinvoice( $borrowernumber, $itemnum, $desc, $type, $amount, $note, $meansofpayment );
	    print $input->redirect("/cgi-bin/koha/members/boraccount.pl?borrowernumber=$borrowernumber");
	}
} else {
    my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {   template_name   => "members/mancredit.tmpl",
            query           => $input,
            type            => "intranet",
            authnotrequired => 0,
            flagsrequired   => { borrowers => 1, updatecharges => 1 },
            debug           => 1,
        }
    );

    if ( $data->{'category_type'} eq 'C' ) {
        my ( $catcodes, $labels ) = GetborCatFromCatType( 'A', 'WHERE category_type = ?' );
        my $cnt = scalar(@$catcodes);
        $template->param( 'CATCODE_MULTI' => 1 ) if $cnt > 1;
        $template->param( 'catcode' => $catcodes->[0] ) if $cnt == 1;
    }

    $template->param( adultborrower => 1 ) if ( $data->{category_type} eq 'A' );
    my ( $picture, $dberror ) = GetPatronImage( $data->{'cardnumber'} );
    $template->param( picture => 1 ) if $picture;

    $template->param(
        borrowernumber => $borrowernumber,
        firstname      => $data->{'firstname'},
        surname        => $data->{'surname'},
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
        is_child       => ( $data->{'category_type'} eq 'C' ),
    );
    $template->param( 'meansofpaymentoptions' => getMeansOfPaymentList() );
    output_html_with_http_headers $input, $cookie, $template->output;
}
