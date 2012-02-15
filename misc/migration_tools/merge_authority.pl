#!/usr/bin/perl
# script that rebuild thesaurus from biblio table.

use Modern::Perl;

BEGIN {

    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/kohalib.pl" };
}

# Koha modules used
use C4::Context;
use C4::Search;
use C4::Biblio;
use C4::AuthoritiesMarc;
use Time::HiRes qw(gettimeofday);
use Storable;

use Getopt::Long;
my ( $version, $verbose, $mergefrom, $mergeto, $noconfirm, $batch );
GetOptions(
    'h'   => \$version,
    'f:s' => \$mergefrom,
    't:s' => \$mergeto,
    'v'   => \$verbose,
    'n'   => \$noconfirm,
    'b'   => \$batch,
);

if ( $version || ( (not $mergefrom) && !$batch ) ) {
    print <<EOF
Script to merge an authority into another
parameters :
\th : this version/help screen
\tv : verbose mode (show many things on screen)
\tf : the authority number to merge (the one that can be deleted after the merge).
\tt : the authority number where to merge
\tn : don't ask for confirmation (useful for batch mergings, should not be used on command line)
\tb : batch Merging

All biblios with the authority in -t will be modified to be "connected" to authority -f
SAMPLE :
./merge_authority.pl -f 2457 -t 531

Before doing anything, the script will show both authorities and ask for confirmation. Of course, you can merge only 2 authorities of the same kind.
EOF
      ;    #
    die;
}    #/'

my $dbh = C4::Context->dbh;

$| = 1;    # flushes output
my $authfrom = GetAuthority($mergefrom);
my $authto   = GetAuthority($mergeto);

my $authtypecodefrom = GetAuthTypeCode($mergefrom);
my $authtypecodeto   = GetAuthTypeCode($mergeto);

unless ( $noconfirm || $batch ) {
    print "************\n";
    print "You will merge authority : $mergefrom ($authtypecodefrom)\n" . $authfrom->as_formatted;
    print "\n*************\n";
    print "Into authority : $mergeto ($authtypecodeto)\n" . $authto->as_formatted;
    print "\n\nDo you confirm (enter YES)?";
    my $confirm = <STDIN>;
    chop $confirm;
    unless ( uc($confirm) eq 'YES' and $authtypecodefrom eq $authtypecodeto ) {
        print "IMPOSSIBLE : authorities are not of the same type ($authtypecodefrom vs $authtypecodeto) !!!\n" if $authtypecodefrom ne $authtypecodeto;
        print "Merge cancelled\n";
        exit;
    }
}
my $starttime = gettimeofday;
print "Merging\n" unless $noconfirm;
if ($batch) {
    my $cgidir = C4::Context->intranetdir . "/cgi-bin";
    unless ( opendir( DIR, "$cgidir/tmp/modified_authorities" ) ) {
        $cgidir = C4::Context->intranetdir;
        opendir( DIR, "$cgidir/tmp/modified_authorities" ) || die "can't opendir $cgidir/tmp/modified_authorities: $!";
    }
    while ( my $authid_filename = readdir(DIR) ) {
        if ( $authid_filename =~ /\.authid$/ ) {
            my $authid = $authid_filename;
            my $filepath = "$cgidir/tmp/modified_authorities/$authid_filename";
            $authid =~ s/\.authid$//;
            print "managing $authid\n" if $verbose;
            my $authfrom = retrieve $filepath;
            merge( $authid, $authfrom, $authid, $authto ) ;
            unlink($filepath) or warn "Couldn't unlink file $filepath: $!";
        }
    }
    closedir DIR;
} else {
    if (merge( $mergefrom, $authfrom, $mergeto, $authto )){
        #Could add mergefrom authority to mergeto rejected forms before deletion
        DelAuthority($mergefrom) unless ($mergefrom==$mergeto);
    }
}
my $timeneeded = gettimeofday - $starttime;
print "Done in $timeneeded seconds\n" unless $noconfirm;
