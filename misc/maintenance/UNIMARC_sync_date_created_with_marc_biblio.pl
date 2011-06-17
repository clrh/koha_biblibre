#!/usr/bin/perl
#
# This script should be used only with UNIMARC flavour
# It is designed to report some missing information from biblio
# table into  marc data
#
use strict;
use warnings;

BEGIN {
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use C4::Biblio;
use Getopt::Long;
my ($wherestring,$run,$want_help);
my $result           = GetOptions(
    'where:s'        => \$wherestring,
    'run'            => \$run,
    'help|h'         => \$want_help,
);
if ( not $result or $want_help ) { 
    print_usage();
    exit 0;
}
my $debug=$ENV{DEBUG};
sub updateMarc {
    my $id  = shift;
    my $dbh = C4::Context->dbh;
    my $field;
    my $biblio = GetMarcBiblio($id);

    return unless $biblio;
    $debug and warn "=====BEFORE====","\n",$biblio->as_formatted;
    if ( !$biblio->field('099') ) {
        $field = new MARC::Field(
            '099', '', '',
            'c' => '',
            'd' => ''
        );
        $biblio->add_fields($field);
    }

    $field = $biblio->field('099');

    my $sth = $dbh->prepare(
        "SELECT DATE_FORMAT(datecreated,'%Y-%m-%d') as datecreated,
                                    DATE_FORMAT(timestamp,'%Y-%m-%d') as timestamp,
                                    frameworkcode
                                    FROM biblio
                                    WHERE biblionumber = ?"
    );
    $sth->execute($id);
    ( my $bibliorow = $sth->fetchrow_hashref );
    my $frameworkcode = $bibliorow->{'frameworkcode'};

    $field->update(
        'c' => $bibliorow->{'datecreated'},
        'd' => $bibliorow->{'timestamp'}
    );
    $debug and warn $id;
    $debug and warn $biblio->as_formatted;

    if ( &ModBiblio( $biblio, $id, $frameworkcode ) ) {
        $debug and print "\r$id";
    }

}

sub process {

    my $dbh = C4::Context->dbh;

    my $strsth = "SELECT biblionumber FROM biblio JOIN biblioitems USING (biblionumber) ";
    my $sqlwhere = ($wherestring?" WHERE $wherestring ":"");
    my $sth = $dbh->prepare($strsth.$sqlwhere);
    $sth->execute();

    while ( my $biblios = $sth->fetchrow_hashref ) {
        $debug and warn $biblios->{'biblionumber'};
        updateMarc( $biblios->{'biblionumber'} );
        $debug and print ".";
    }

}
exit 1 unless $run;
if ( lc( C4::Context->preference('marcflavour') ) eq "unimarc" ) {
    process();
} else {
    print "this script is UNIMARC only and should be used only on unimarc databases\n";
}

sub print_usage {
    print <<_USAGE_;
$0: Adds datecreated datelast modified to 099\$c 099\$d UNIMARC specific


Parameters:
    -where                  use this to limit modifications to some biblios
    -run                   run the command
    -help or -h            show this message.
_USAGE_
}
