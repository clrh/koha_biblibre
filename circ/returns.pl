#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
#           2006 SAN-OP
#           2007 BibLibre, Paul POULAIN
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

=head1 returns.pl

script to execute returns of books

=cut

use strict;

#use warnings; FIXME - Bug 2505

use CGI;
use C4::Context;
use C4::Auth qw/:DEFAULT get_session/;
use C4::Output;
use C4::Circulation;
use C4::Dates qw/format_date/;
use Date::Calc qw/Add_Delta_Days/;
use List::MoreUtils qw/any/;
use C4::Calendar;
use C4::Budgets qw/GetCurrency/;
use C4::Print;
use C4::Reserves;
use C4::Biblio;
use C4::Items;
use C4::Members;
use C4::Overdues qw/CheckBorrowerDebarred/;
use C4::Branch;    # GetBranches GetBranchName
use C4::Koha;      # FIXME : is it still useful ?
#use C4::RotatingCollections;
use C4::Debug;

my $query      = new CGI;
my $remotehost = $query->remote_host();

if ( !C4::Context->userenv ) {
    my $sessionID = $query->cookie("CGISESSID");
    my $session   = get_session($sessionID);
    if ( $session->param('branch') eq 'NO_LIBRARY_SET' ) {

        # no branch set we can't return
        print $query->redirect("/cgi-bin/koha/circ/selectbranchprinter.pl");
        exit;
    }
}

#getting the template
my ( $template, $librarian, $cookie ) = get_template_and_user(
    {   template_name   => "circ/returns.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => "circulate_remaining_permissions" },
    }
);

#####################
#Global vars
my $branches = GetBranches();
my $printers = GetPrinters();

my $printer = C4::Context->userenv ? C4::Context->userenv->{'branchprinter'} : "";
my $overduecharges = ( C4::Context->preference('finesMode') && C4::Context->preference('finesMode') ne 'off' );

my $userenv_branch = C4::Context->userenv->{'branch'} || '';

#
# Some code to handle the error if there is no branch or printer setting.....
#

# Set up the item stack ....
my %returneditems;
my %riduedate;
my %riborrowernumber;
my @inputloop;
foreach ( $query->param ) {
    my $counter;
    if (/ri-(\d*)/) {
        $counter = $1;
        if ( $counter > 20 ) {
            next;
        }
    } else {
        next;
    }

    my %input;
    my $barcode        = $query->param("ri-$counter");
    my $duedate        = $query->param("dd-$counter");
    my $borrowernumber = $query->param("bn-$counter");
    $counter++;

    # decode barcode    ## Didn't we already decode them before passing them back last time??
    $barcode =~ s/^\s*|\s*$//g;    # remove leading/trailing whitespace
    $barcode = barcodedecode($barcode) if ( C4::Context->preference('itemBarcodeInputFilter') );

    ######################
    #Are these lines still useful ?
    $returneditems{$counter}    = $barcode;
    $riduedate{$counter}        = $duedate;
    $riborrowernumber{$counter} = $borrowernumber;

    #######################
    $input{counter}        = $counter;
    $input{barcode}        = $barcode;
    $input{duedate}        = $duedate;
    $input{borrowernumber} = $borrowernumber;
    push( @inputloop, \%input );
}

############
# Deal with the requests....

if ( $query->param('WT-itemNumber') ) {
    updateWrongTransfer( $query->param('WT-itemNumber'), $query->param('WT-waitingAt'), $query->param('WT-From') );
}

if ( $query->param('resbarcode') ) {
    my $item           = $query->param('itemnumber');
    my $borrowernumber = $query->param('borrowernumber');
    my $resbarcode     = $query->param('resbarcode');
    my $reservenumber = $query->param('reservenumber');
    my $diffBranchReturned = $query->param('diffBranch');
    my $iteminfo           = GetBiblioFromItemNumber($item);

    # fix up item type for display
    $iteminfo->{'itemtype'} = C4::Context->preference('item-level_itypes') ? $iteminfo->{'itype'} : $iteminfo->{'itemtype'};
    my $diffBranchSend = ($userenv_branch ne $diffBranchReturned) ? $diffBranchReturned : undef;
# diffBranchSend tells ModReserveAffect whether document is expected in this library or not,
# i.e., whether to apply waiting status
    ModReserveAffect( $item, $borrowernumber, $diffBranchSend, $reservenumber );

#   check if we have other reserves for this document, if we have a return send the message of transfer
    my ( $reservemessages, $nextreservinfo ) = GetOtherReserves($item);

    my ($borr) = GetMemberDetails( $nextreservinfo, 0 );
    my $name = $borr->{'surname'} . ", " . $borr->{'title'} . " " . $borr->{'firstname'};
    if ( $reservemessages->{'transfert'} ) {
        $template->param(
            itemtitle        => $iteminfo->{'title'},
            itembiblionumber => $iteminfo->{'biblionumber'},
            iteminfo         => $iteminfo->{'author'},
            tobranchname     => GetBranchName( $reservemessages->{'transfert'} ),
            name             => $name,
            borrowernumber   => $borrowernumber,
            borcnum          => $borr->{'cardnumber'},
            borfirstname     => $borr->{'firstname'},
            borsurname       => $borr->{'surname'},
            diffbranch       => 1,
        );
    }
}

my $borrower;
my $returned = 0;
my $messages;
my $issueinformation;
my $itemnumber;
my $biblio;
my $barcode     = $query->param('barcode');
my $exemptfine  = $query->param('exemptfine');
my $dropboxmode = $query->param('dropboxmode');
my $dotransfer  = $query->param('dotransfer');
my $override    = $query->param('override');
my $calendar    = C4::Calendar->new( branchcode => $userenv_branch );

#dropbox: get last open day (today - 1)
my $today       = C4::Dates->new();
my $today_iso   = $today->output('iso');
my $dropboxdate = $calendar->addDate( $today, -1 );
if ($debug) {
    use YAML;
    warn Dump( $query->Vars );
}
if ($dotransfer) {

    # An item has been returned to a branch other than the homebranch, and the librarian has chosen to initiate a transfer
    my $transferitem = $query->param('transferitem');
    my $tobranch     = $query->param('tobranch');
    ModItemTransfer( $transferitem, $userenv_branch, $tobranch );
}

# actually return book and prepare item table.....
if ( $barcode and not $query->param('cancel') ) {
    $barcode =~ s/^\s*|\s*$//g;    # remove leading/trailing whitespace
    $barcode = barcodedecode($barcode) if C4::Context->preference('itemBarcodeInputFilter');
    $itemnumber = GetItemnumberFromBarcode($barcode);

    if ( C4::Context->preference("InProcessingToShelvingCart") ) {
        my $item = GetItem($itemnumber);
        if ( $item->{'location'} eq 'PROC' ) {
            $item->{'location'} = 'CART';
            ModItem( $item, $item->{'biblionumber'}, $item->{'itemnumber'} );
        }
    }

    if ( C4::Context->preference("ReturnToShelvingCart") ) {
        my $item = GetItem($itemnumber);
        $item->{'location'} = 'CART';
        ModItem( $item, $item->{'biblionumber'}, $item->{'itemnumber'} );
    }

    #
    # save the return
    #
    ( $returned, $messages, $issueinformation, $borrower ) = AddReturn( $barcode, $userenv_branch, $exemptfine, $dropboxmode, $override );    # do the return
    my @ips = split (/,|\|/, C4::Context->preference("CI-3M:AuthorizedIPs"));

    #my $pid=fork();
    #unless($pid && $remotehost=~qr(^$ips$)){
    #if (!$pid && any{ $remotehost eq $_ }@ips ){
    if ( any { $remotehost eq $_ } @ips ) {
        system("../services/magnetise.pl $remotehost in");

        #die 0;
    }

    # get biblio description
    $biblio = GetBiblioFromItemNumber($itemnumber);

    # fix up item type for display
    $biblio->{'itemtype'} = C4::Context->preference('item-level_itypes') ? $biblio->{'itype'} : $biblio->{'itemtype'};

    $template->param(
        title            => $biblio->{'title'},
        homebranch       => $biblio->{'homebranch'},
        homebranchname   => GetBranchName( $biblio->{'homebranch'} ),
        author           => $biblio->{'author'},
        itembarcode      => $biblio->{'barcode'},
        itemtype         => $biblio->{'itemtype'},
        ccode            => $biblio->{'ccode'},
        itembiblionumber => $biblio->{'biblionumber'},
    );

    my %input = (
        counter => 0,
        first   => 1,
        barcode => $barcode,
    );

    if ($returned) {
        my $duedate = $issueinformation->{'date_due'};
        $returneditems{0}      = $barcode;
        $riborrowernumber{0}   = $borrower->{'borrowernumber'};
        $riduedate{0}          = $duedate;
        $input{borrowernumber} = $borrower->{'borrowernumber'};
        $input{duedate}        = $duedate;
        $input{return_overdue} = 1 if ( $duedate and $duedate lt $today->output('iso') );
        push( @inputloop, \%input );
    } elsif ( !$messages->{'BadBarcode'} and !$messages->{'Wrongbranch'} ) {
        $input{duedate}   = 0;
        $returneditems{0} = $barcode;
        $riduedate{0}     = 0;
        if ( $messages->{'wthdrawn'} ) {
            $input{withdrawn}      = 1;
            $input{borrowernumber} = 'Item Cancelled';    # FIXME: should be in display layer ?
            $riborrowernumber{0}   = 'Item Cancelled';
        } else {
            $input{borrowernumber} = '&nbsp;';            # This seems clearly bogus.
            $riborrowernumber{0} = '&nbsp;';
        }
        push( @inputloop, \%input );
    }
}
$template->param( inputloop => \@inputloop );


# Is there a circulation note?
my $itemnumber = GetItemnumberFromBarcode($barcode);
my $biblionumber = GetBiblionumberFromItemnumber($itemnumber);
my $record = GetMarcBiblio($biblionumber);
my $frameworkcode = GetFrameworkCode($biblionumber);
my $circnotefield = GetRecordValue('circnote', $record, $frameworkcode);
warn Data::Dumper::Dumper($circnotefield);
if (defined @$circnotefield[0]) {
   $template->param(circnote => @$circnotefield[0]->{'subfield'});
}


my $found    = 0;
my $waiting  = 0;
my $reserved = 0;

# new op dev : we check if the document must be returned to his homebranch directly,
#  if the document is transfered, we have warning message .

if ( $messages->{'WasTransfered'} ) {
    $template->param(
        found    => 1,
        transfer => 1,
    );
}

if ( $messages->{'NeedsTransfer'} ) {
    $template->param(
        found         => 1,
        needstransfer => 1,
        itemnumber    => $itemnumber,
    );
}

if ( $messages->{'Wrongbranch'} ) {
    $template->param(
        wrongbranch => $branches->{ $messages->{'Wrongbranch'}->{'Wrongbranch'} }->{'branchname'},
        rightbranch => $branches->{ $messages->{'Wrongbranch'}->{'Rightbranch'} }->{'branchname'},
        barcode     => $barcode,
        exemptfine  => $exemptfine,
        dropboxmode => $dropboxmode,
    );
}

# case of wrong transfert, if the document wasn't transfered to the right library (according to branchtransfer (tobranch) BDD)

if ( $messages->{'WrongTransfer'} and not $messages->{'WasTransfered'} ) {
    $messages->{'WrongTransfer'} = GetBranchName( $messages->{'WrongTransfer'} );
    $template->param(
        WrongTransfer     => 1,
        TransferWaitingAtBC => $messages->{'ResFound'}->{'branchcode'},
        TransferWaitingAt => $messages->{'WrongTransfer'},
        WrongTransferItem => $messages->{'WrongTransferItem'},
    );

    my $reserve    = $messages->{'ResFound'};
    my $branchname = $branches->{ $reserve->{'branchcode'} }->{'branchname'};
    my ($borr) = GetMemberDetails( $reserve->{'borrowernumber'}, 0 );
    my $name = $borr->{'surname'} . ", " . $borr->{'title'} . " " . $borr->{'firstname'};
    $template->param(
        wname           => $name,
        wborfirstname   => $borr->{'firstname'},
        wborsurname     => $borr->{'surname'},
        wbortitle       => $borr->{'title'},
        wborphone       => $borr->{'phone'},
        wboremail       => $borr->{'email'},
        wboraddress     => $borr->{'address'},
        wboraddress2    => $borr->{'address2'},
        wborcity        => $borr->{'city'},
        wborzip         => $borr->{'zipcode'},
        wborrowernumber => $reserve->{'borrowernumber'},
        wborcnum        => $borr->{'cardnumber'},
        wtransfertFrom  => $userenv_branch,
    );
}

#
# reserve found and item arrived at the expected branch
#
if ( $messages->{'ResFound'} ) {
    my $reserve    = $messages->{'ResFound'};
    my $branchname = $branches->{ $reserve->{'branchcode'} }->{'branchname'};
    my ($borr) = GetMemberDetails( $reserve->{'borrowernumber'}, 0 );

    if ( $reserve->{'ResFound'} eq "Waiting" or $reserve->{'ResFound'} eq "Reserved" ) {
        if ( $reserve->{'ResFound'} eq "Waiting" ) {
            $template->param( waiting => ( $userenv_branch eq $reserve->{'branchcode'} ? 1 : 0 ), );
        } elsif ( $reserve->{'ResFound'} eq "Reserved" ) {
            $template->param(
                intransit    => ( $userenv_branch eq $reserve->{'branchcode'} ? 0 : 1 ),
                transfertodo => ( $userenv_branch eq $reserve->{'branchcode'} ? 0 : 1 ),
                resbarcode   => $barcode,
                reserved     => 1,
            );
        }
        my $debarred = CheckBorrowerDebarred( $reserve->{borrowernumber} );

        # same params for Waiting or Reserved
        $template->param(
            found          => 1,
            currentbranch  => $branches->{$userenv_branch}->{'branchname'},
            destbranchname => $branches->{ $reserve->{'branchcode'} }->{'branchname'},
            name           => $borr->{'surname'} . ", " . $borr->{'title'} . " " . $borr->{'firstname'},
            borfirstname   => $borr->{'firstname'},
            borsurname     => $borr->{'surname'},
            bortitle       => $borr->{'title'},
            borphone       => $borr->{'phone'},
            boremail       => $borr->{'email'},
            boraddress     => $borr->{'address'},
            boraddress2    => $borr->{'address2'},
            borcity        => $borr->{'city'},
            borzip         => $borr->{'zipcode'},
            borcnum        => $borr->{'cardnumber'},
            debarred       => $debarred,
            gonenoaddress  => $borr->{'gonenoaddress'},
            barcode        => $barcode,
            reservenumber  => $reserve->{'reservenumber'},
            destbranch	   => $reserve->{'branchcode'},
            borrowernumber => $reserve->{'borrowernumber'},
            itemnumber     => $reserve->{'itemnumber'},
            reservenotes   => $reserve->{'reservenotes'},
        );
    }    # else { ; }  # error?
}
$borrower->{'flags'} = C4::Members::patronflags($borrower);

# Error Messages
my @errmsgloop;
foreach my $code ( keys %$messages ) {
    my %err;
    my $exit_required_p = 0;
    if ( $code eq 'BadBarcode' ) {
        $err{badbarcode} = 1;
        $err{msg}        = $messages->{'BadBarcode'};
    } elsif ( $code eq 'NotIssued' ) {
        $err{notissued} = 1;
        $err{msg}       = $branches->{ $messages->{'IsPermanent'} }->{'branchname'};
    } elsif ( $code eq 'WasLost' ) {
        $err{waslost} = 1;
    } elsif ( $code eq 'ResFound' ) {
        ;    # FIXME... anything to do here?
    } elsif ( $code eq 'WasReturned' ) {
        ;    # FIXME... anything to do here?
    } elsif ( $code eq 'WasTransfered' ) {
        ;    # FIXME... anything to do here?
    } elsif ( $code eq 'NotForLoan' ) {
        my $fw               = GetFrameworkCode( $biblio->{'biblionumber'} );
        my $category         = GetAuthValCode( 'items.notforloan', $fw );
        my $authorizedvalues = GetAuthorisedValues( $category, $messages->{$code} );

        foreach my $authvalue (@$authorizedvalues) {
            $err{notforloan} = $authvalue->{lib} if $authvalue->{'authorised_value'} eq $messages->{$code};
        }
    } elsif ( $code eq 'Damaged' ) {
        my $fw               = GetFrameworkCode( $biblio->{'biblionumber'} );
        my $category         = GetAuthValCode( 'items.damaged', $fw );
        my $authorizedvalues = GetAuthorisedValues( $category, $messages->{$code} );

        foreach my $authvalue (@$authorizedvalues) {
            $err{damaged} = $authvalue->{lib} if $authvalue->{'authorised_value'} eq $messages->{$code};
        }
    } elsif ( $code eq 'Debarred' ) {
        $err{debarred}            = format_date( $messages->{'Debarred'} );
        $err{debarcardnumber}     = $borrower->{cardnumber};
        $err{debarborrowernumber} = $borrower->{borrowernumber};
        $err{debarname}           = "$borrower->{firstname} $borrower->{surname}";
    } elsif ( $code eq 'HaveFines' ) {
        $err{havefines}      = $borrower->{'flags'}->{'CHARGES'}->{'amount'} . %{ GetCurrency() }->{symbol};
        $err{finecardnumber} = $borrower->{cardnumber};
        $err{finename}       = "$borrower->{firstname} $borrower->{surname}";
    } elsif ( $code eq 'wthdrawn' ) {
        $err{withdrawn} = 1;
        $exit_required_p = 1;
    } elsif ( ( $code eq 'IsPermanent' ) && ( not $messages->{'ResFound'} ) ) {
        if ( $messages->{'IsPermanent'} ne $userenv_branch ) {
            $err{ispermanent} = 1;
            $err{msg}         = $branches->{ $messages->{'IsPermanent'} }->{'branchname'};
        }
    } elsif ( $code eq 'WrongTransfer' ) {
        ;    # FIXME... anything to do here?
    } elsif ( $code eq 'WrongTransferItem' ) {
        ;    # FIXME... anything to do here?
    } elsif ( $code eq 'NeedsTransfer' ) {
    } elsif ( $code eq 'Wrongbranch' ) {
    } else {
        die "Unknown error code $code";    # note we need all the (empty) elsif's above, or we die.
                                           # This forces the issue of staying in sync w/ Circulation.pm
    }
    if (%err) {
        push( @errmsgloop, \%err );
    }
    last if $exit_required_p;
}
$template->param( errmsgloop => \@errmsgloop );

# patrontable ....
if ($borrower) {
    my @flagloop;
    my $flags = $borrower->{flags};
    foreach my $flag ( sort keys %$flags ) {
        my %flaginfo;
        if ( $flag eq 'CHARGES' ) {
            $flaginfo{msg}            = $flag;
            $flaginfo{charges}        = 1;
            $flaginfo{chargeamount}   = $flags->{$flag}->{amount};
            $flaginfo{borrowernumber} = $borrower->{borrowernumber};
        } elsif ( $flag eq 'WAITING' ) {
            $flaginfo{msg}     = $flag;
            $flaginfo{waiting} = 1;
            my @waitingitemloop;
            my $items = $flags->{$flag}->{'itemlist'};
            foreach my $item (@$items) {
                my $biblio = GetBiblioFromItemNumber( $item->{'itemnumber'} );
                push @waitingitemloop,
                  { biblionumber => $biblio->{'biblionumber'},
                    author       => $biblio->{'author'},
                    itemtype     => $item->{'ccode'},
                    reservedate  => format_date( $item->{'reservedate'} ),
                    waitingdate  => format_date( $item->{'waitingdate'} ),
                    maxpickupdate=> format_date( sprintf("%d-%02d-%02d",GetMaxPickupDate($item->{'waitingdate'}, $borrower->{borrowernumber},$item ))),
                    barcode      => $item->{'barcode'},
                    title        => $biblio->{'title'},
                    brname       => $branches->{ $item->{'branchcode'} }->{'branchname'},
                    waitinghere  => ( $item->{'branchcode'} eq $userenv_branch )
                  };
            }
            $flaginfo{itemloop} = \@waitingitemloop;
        } elsif ( $flag =~ /DEBARRED|LOST|GNA/ ) {
            if ( $flag ne "GNA" ) {
                $flag = lc($flag);
            } else {
                $flag = "gonenoaddress";
            }
            %flaginfo = ( $flag => 1, $flag . "comment" => $borrower->{ $flag . "comment" }, dateend => $flags->{ uc($flag) }->{dateend} );
        } elsif ( $flag eq 'ODUES' ) {
            my $items = $flags->{$flag}->{'itemlist'};
            my @itemloop;
            foreach my $item ( sort { $a->{'date_due'} cmp $b->{'date_due'} } @$items ) {
                my $biblio = GetBiblioFromItemNumber( $item->{'itemnumber'} );
                push @itemloop,
                  { duedate   => format_date( $item->{'date_due'} ),
                    biblionum => $biblio->{'biblionumber'},
                    barcode   => $biblio->{'barcode'},
                    title     => $biblio->{'title'},
                    brname    => $branches->{ $biblio->{'holdingbranch'} }->{'branchname'},
                  };
            }
            $flaginfo{itemloop} = \@itemloop;
            $flaginfo{overdue}  = 1;
        } else {
            $flaginfo{other} = 1;
            $flaginfo{msg}   = $flags->{$flag}->{'message'};
        }
        push( @flagloop, \%flaginfo );
    }
    $template->param(
        flagloop         => \@flagloop,
        riborrowernumber => $borrower->{'borrowernumber'},
        riborcnum        => $borrower->{'cardnumber'},
        riborsurname     => $borrower->{'surname'},
        ribortitle       => $borrower->{'title'},
        riborfirstname   => $borrower->{'firstname'}
    );
}

#set up so only the last 8 returned items display (make for faster loading pages)
my $returned_counter = ( C4::Context->preference('numReturnedItemsToShow') ) ? C4::Context->preference('numReturnedItemsToShow') : 10;
my $count = 0;
my @riloop;
foreach ( sort { $a <=> $b } keys %returneditems ) {
    my %ri;
    if ( $count++ < $returned_counter ) {
        my $bar_code = $returneditems{$_};
        my $duedate  = $riduedate{$_};
        if ($duedate) {
            my @tempdate = split( /-/, $duedate );
            $ri{year}    = $tempdate[0];
            $ri{month}   = $tempdate[1];
            $ri{day}     = $tempdate[2];
            $ri{duedate} = format_date($duedate);
            my ($b) = GetMemberDetails( $riborrowernumber{$_}, 0 );
            $ri{return_overdue}  = 1 if ( $duedate lt $today->output('iso') );
            $ri{borrowernumber}  = $b->{'borrowernumber'};
            $ri{borcnum}         = $b->{'cardnumber'};
            $ri{borfirstname}    = $b->{'firstname'};
            $ri{borsurname}      = $b->{'surname'};
            $ri{bortitle}        = $b->{'title'};
            $ri{bornote}         = $b->{'borrowernotes'};
            $ri{borcategorycode} = $b->{'categorycode'};
        } else {
            $ri{borrowernumber} = $riborrowernumber{$_};
        }

        #        my %ri;
        my $biblio = GetBiblioFromItemNumber( GetItemnumberFromBarcode($bar_code) );
        my $item   = GetItem( GetItemnumberFromBarcode($bar_code) );

        # fix up item type for display
        $biblio->{'itemtype'} = C4::Context->preference('item-level_itypes') ? $biblio->{'itype'} : $biblio->{'itemtype'};
        $ri{itembiblionumber} = $biblio->{'biblionumber'};
        $ri{itemtitle}        = $biblio->{'title'};
        $ri{itemauthor}       = $biblio->{'author'};
        $ri{itemnote}         = $biblio->{'itemnotes'};
        $ri{itemnumber}       = $biblio->{'itemnumber'};
        $ri{itemtype}         = $item->{'itype'};
        $ri{ccode}            = $item->{'ccode'};
        $ri{itemcallnumber}   = $item->{'itemcallnumber'};
        $ri{homebranch}       = $item->{'homebranch'};
        $ri{holdingbranch}    = $item->{'holdingbranch'};
        $ri{barcode}          = $bar_code;
        my $shelflocations    = GetKohaAuthorisedValues('items.location','');
        $ri{itemlocation}     = $shelflocations->{$biblio->{'location'}};
        
    }
    else {
        last;
    }
    push @riloop, \%ri;
}

$template->param(
    riloop         => \@riloop,
    genbrname      => $branches->{$userenv_branch}->{'branchname'},
    genprname      => $printers->{$printer}->{'printername'},
    branchname     => $branches->{$userenv_branch}->{'branchname'},
    printer        => $printer,
    errmsgloop     => \@errmsgloop,
    exemptfine     => $exemptfine,
    dropboxmode    => $dropboxmode,
    dropboxdate    => $dropboxdate->output(),
    overduecharges => $overduecharges,
    soundon        => C4::Context->preference("SoundOn"),
);

# RotatingCollection is not usable
#my $itemnumber = GetItemnumberFromBarcode( $query->param('barcode') );
#if ($itemnumber) {
#    my ( $holdingBranch, $collectionBranch ) = GetCollectionItemBranches($itemnumber);
#    if ( !( $holdingBranch eq $collectionBranch ) ) {
#        $template->param(
#            collectionItemNeedsTransferred => 1,
#            collectionBranch               => GetBranchName($collectionBranch),
#        );
#    }
#}

# actually print the page!
output_html_with_http_headers $query, $cookie, $template->output;
