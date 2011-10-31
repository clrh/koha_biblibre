#!/usr/bin/perl
#

use strict;
use warnings;

use CGI;
use JSON;

use C4::Auth;
use C4::Circulation qw/CanBookBeRenewed/;
use C4::Context;
use C4::Koha qw/getitemtypeimagelocation/;
use C4::Reserves qw/CheckReserves/;
use C4::Utils::DataTables;
use Log::LogLite;

my $input = new CGI;

my $planneddate_to = $input->param('planneddate_to');
my $planneddate_from = $input->param('planneddate_from');
my $claimdatefrom = $input->param('claimdatefrom');
my $claimdateto = $input->param('claimdateto');

# Fetch DataTables parameters
my %dtparam = dt_get_params( $input );

while ( my ( $k, $v ) = each %dtparam ) {
    $v =~ s/^dt_(.+)/$1/;
    $dtparam{$k} = $v;
}

my $dbh = C4::Context->dbh;

# Build the query
my $select = <<EOQ;
    SELECT SQL_CALC_FOUND_ROWS
    serialid, aqbooksellerid, name AS suppliername, biblio.title, planneddate, serialseq,
    serial.status, serial.subscriptionid, claimdate, claims_count,
    branches.branchname
EOQ
my $from = <<EOQ;
    FROM serial
    LEFT JOIN subscription  ON serial.subscriptionid=subscription.subscriptionid 
    LEFT JOIN biblio        ON subscription.biblionumber=biblio.biblionumber
    LEFT JOIN aqbooksellers ON subscription.aqbooksellerid = aqbooksellers.id
    LEFT JOIN branches ON branches.branchcode = subscription.branchcode
EOQ
my $where = <<EOQ;
    WHERE (serial.STATUS = 4 OR ((planneddate < now() AND serial.STATUS =1) OR serial.STATUS = 3 OR serial.STATUS = 7))
EOQ
my @bind_params;
my ( $planneddate_q , $planneddate_f  ) = dt_build_query( 'range_dates', $planneddate_from, $planneddate_to, 'planneddate' );
my ( $claimdate_q, $claimdate_f ) = dt_build_query('range_dates', $claimdatefrom, $claimdateto, 'claimdate');

my $where_filters;
$where_filters .= ( $planneddate_q    ? $planneddate_q : '' );
push @bind_params, scalar( @$planneddate_f )    > 0 ? @$planneddate_f : ();

$where_filters .= ( $claimdate_q ? $claimdate_q : '' );
push @bind_params, scalar( @$claimdate_f ) > 0 ? @$claimdate_f : ();

my ($filters, $filter_params) = dt_build_having(\%dtparam);
my $having = @$filters ? " HAVING ". join(" AND ", @$filters) : '';
my $order_by = dt_build_orderby(\%dtparam);
my $limit .= " LIMIT ?,? ";

my $query = $select . $from . $where . $where_filters . ( $having || '' ) . $order_by . $limit;
push @bind_params, @$filter_params, $dtparam{'iDisplayStart'}, $dtparam{'iDisplayLength'};
my $sth = $dbh->prepare($query);
$sth->execute(@bind_params);
my $results = $sth->fetchall_arrayref({});

$sth = $dbh->prepare("SELECT FOUND_ROWS()");
$sth->execute;
my ($iTotalDisplayRecords) = $sth->fetchrow_array;

# This is mandatory for DataTables to show the total number of results
my $select_total_count = "SELECT COUNT(*) ";
$sth = $dbh->prepare($select_total_count.$from.$where);
$sth->execute();
my ($iTotalRecords) = $sth->fetchrow_array;

my @aaData = ();
foreach(@$results) {
    my %row = %{$_};
    $row{'planneddate'} = C4::Dates->new($row{'planneddate'}, 'iso')->output();
    push @aaData, \%row;
}

my ($template, $loggedinuser, $cookie, $flags) = get_template_and_user({
    template_name   => 'serials/tables/claims.tmpl',
    query           => $input,
    type            => 'intranet',
    authnotrequired => 0,
    flagsrequired   => { circulate => 'circulate_remaining_permission' },
});

$template->param(
    sEcho => $dtparam{'sEcho'},
    iTotalRecords => $iTotalRecords,
    iTotalDisplayRecords => $iTotalDisplayRecords,
    aaData => \@aaData,
);

print $input->header('application/json');
print $template->output();
