package C4::AuthoritiesMarc;

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

use Modern::Perl;

use C4::Context;
use C4::Koha;
use MARC::Record;
use C4::Biblio;
use C4::AuthoritiesMarc::MARC21;
use C4::AuthoritiesMarc::UNIMARC;
use C4::Charset;
use Storable;
use List::MoreUtils qw/any none/;
use C4::Debug;
use C4::Search::Query;
require C4::Search;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {

    # set the version for version checking
    $VERSION = 3.01;

    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
      &GetTagsLabels
      &GetAuthType
      &GetAuthTypeText
      &GetAuthTypeCode
      &GetAuthMARCFromKohaField
      &AUTHhtml2marc

      &AddAuthority
      &ModAuthority
      &DelAuthority
      &GetAuthority
      &GetAuthorityXML

      &CountUsage
      &CountUsageChildren

      &BuildSummary
      &BuildUnimarcHierarchies
      &BuildUnimarcHierarchy

      &merge
      &FindDuplicateAuthority

      &GuessAuthTypeCode
      &GuessAuthId

      &GetIndexBySearchtype
    );
}

=head2 GetAuthMARCFromKohaField 

=over 4

( $tag, $subfield ) = &GetAuthMARCFromKohaField ($kohafield,$authtypecode);
returns tag and subfield linked to kohafield

Comment :
Suppose Kohafield is only linked to ONE subfield

=back

=cut

sub GetAuthMARCFromKohaField {

    #AUTHfind_marc_from_kohafield
    my ( $kohafield, $authtypecode ) = @_;
    my $dbh = C4::Context->dbh;
    return 0, 0 unless $kohafield;
    $authtypecode = "" unless $authtypecode;
    my $marcfromkohafield;
    my $sth = $dbh->prepare("select tagfield,tagsubfield from auth_subfield_structure where kohafield= ? and authtypecode=? ");
    $sth->execute( $kohafield, $authtypecode );
    my ( $tagfield, $tagsubfield ) = $sth->fetchrow;

    return ( $tagfield, $tagsubfield );
}

=head2 CountUsage 

=over 4

$count= &CountUsage($authid)
counts Usage of Authid in bibliorecords. 

=back

=cut

sub CountUsage {

    my $results = C4::Search::SimpleSearch( "*:*", {
        recordtype => 'biblio',
        int_authid     => shift,
    } );

    return $results->pager->{total_entries};
}

=head2 CountUsageChildren 

=over 4

$count= &CountUsageChildren($authid)
counts Usage of narrower terms of Authid in bibliorecords.

=back

=cut

sub CountUsageChildren {
    my ($authid) = @_;
}

=head2 GetAuthTypeCode

=over 4

$authtypecode= &GetAuthTypeCode($authid)
returns authtypecode of an authid

=back

=cut

sub GetAuthTypeCode {

    #AUTHfind_authtypecode
    my ($authid) = @_;
    my $dbh      = C4::Context->dbh;
    my $sth      = $dbh->prepare("select authtypecode from auth_header where authid=?");
    $sth->execute($authid);
    my $authtypecode = $sth->fetchrow;
    return $authtypecode;
}

=head2 GuessAuthTypeCode

=over 4

my $authtypecode = GuessAuthTypeCode($record, [$headingfields]);

=back

Get the record and tries to guess the adequate authtypecode from its content.

=cut

sub GuessAuthTypeCode {
    my ($record, $heading_fields) = @_;
    return unless defined $record;
    $heading_fields //= {
        "MARC21" => {
            '100' => { authtypecode => 'PERSO_NAME' },
            '110' => { authtypecode => 'CORPO_NAME' },
            '111' => { authtypecode => 'MEETI_NAME' },
            '130' => { authtypecode => 'UNIF_TITLE' },
            '148' => { authtypecode => 'CHRON_TERM' },
            '150' => { authtypecode => 'TOPIC_TERM' },
            '151' => { authtypecode => 'GEOGR_NAME' },
            '155' => { authtypecode => 'GENRE/FORM' },
            '180' => { authtypecode => 'GEN_SUBDIV' },
            '181' => { authtypecode => 'GEO_SUBDIV' },
            '182' => { authtypecode => 'CHRON_SUBD' },
            '185' => { authtypecode => 'FORM_SUBD' },
        },

        #200 Personal name	700, 701, 702 4-- with embedded 700, 701, 702 600
        #                    604 with embedded 700, 701, 702
        #210 Corporate or meeting name	710, 711, 712 4-- with embedded 710, 711, 712 601 604 with embedded 710, 711, 712
        #215 Territorial or geographic name 	710, 711, 712 4-- with embedded 710, 711, 712 601, 607 604 with embedded 710, 711, 712
        #216 Trademark 	716 [Reserved for future use]
        #220 Family name 	720, 721, 722 4-- with embedded 720, 721, 722 602 604 with embedded 720, 721, 722
        #230 Title 	500 4-- with embedded 500 605
        #240 Name and title (embedded 200, 210, 215, or 220 and 230) 	4-- with embedded 7-- and 500 7--  604 with embedded 7-- and 500 500
        #245 Name and collective title (embedded 200, 210, 215, or 220 and 235) 	4-- with embedded 7-- and 501 604 with embedded 7-- and 501 7-- 501
        #250 Topical subject 	606
        #260 Place access 	620
        #280 Form, genre or physical characteristics 	608
        #
        #
        # Could also be represented with :
        #leader position 9
        #a = personal name entry
        #b = corporate name entry
        #c = territorial or geographical name
        #d = trademark
        #e = family name
        #f = uniform title
        #g = collective uniform title
        #h = name/title
        #i = name/collective uniform title
        #j = topical subject
        #k = place access
        #l = form, genre or physical characteristics
        "UNIMARC" => {
            '200' => { authtypecode => 'NP' },
            '210' => { authtypecode => 'CO' },
            '215' => { authtypecode => 'SNG' },
            '216' => { authtypecode => 'TM' },
            '220' => { authtypecode => 'FAM' },
            '230' => { authtypecode => 'TU' },
            '235' => { authtypecode => 'CO_UNI_TI' },
            '240' => { authtypecode => 'SAUTTIT' },
            '245' => { authtypecode => 'NAME_COL' },
            '250' => { authtypecode => 'SNC' },
            '260' => { authtypecode => 'PA' },
            '280' => { authtypecode => 'GENRE/FORM' },
        }
    };
    foreach my $field ( keys %{ $heading_fields->{ uc( C4::Context->preference('marcflavour') ) } } ) {
        return $heading_fields->{ uc( C4::Context->preference('marcflavour') ) }->{$field}->{'authtypecode'} if ( defined $record->field($field) );
    }
    return;
}

=head2 GuessAuthId

=over 4

my $authtid = GuessAuthId($record);

=back

Get the record and tries to guess the adequate authtypecode from its content.

=cut

sub GuessAuthId {
    my ($record) = @_;
    return unless ( $record && $record->field('001') );

    #    my $authtypecode=GuessAuthTypeCode($record);
    #    my ($tag,$subfield)=GetAuthMARCFromKohaField("auth_header.authid",$authtypecode);
    #    if ($tag > 010) {return $record->subfield($tag,$subfield)}
    #    else {return $record->field($tag)->data}
    return $record->field('001')->data;
}

=head2 GetTagsLabels

=over 4

$tagslabel= &GetTagsLabels($forlibrarian,$authtypecode)
returns a ref to hashref of authorities tag and subfield structure.

tagslabel usage : 
$tagslabel->{$tag}->{$subfield}->{'attribute'}
where attribute takes values in :
  lib
  tab
  mandatory
  repeatable
  authorised_value
  authtypecode
  value_builder
  kohafield
  seealso
  hidden
  isurl
  link

=back

=cut

sub GetTagsLabels {
    my ( $forlibrarian, $authtypecode ) = @_;
    my $dbh = C4::Context->dbh;
    $authtypecode = "" unless $authtypecode;
    my $sth;
    my $libfield = ( $forlibrarian == 1 ) ? 'liblibrarian' : 'libopac';

    # check that authority exists
    $sth = $dbh->prepare("SELECT count(*) FROM auth_tag_structure WHERE authtypecode=?");
    $sth->execute($authtypecode);
    my ($total) = $sth->fetchrow;
    $authtypecode = "" unless ( $total > 0 );
    $sth = $dbh->prepare(
        "SELECT auth_tag_structure.tagfield,auth_tag_structure.liblibrarian,auth_tag_structure.libopac,auth_tag_structure.mandatory,auth_tag_structure.repeatable 
 FROM auth_tag_structure 
 WHERE authtypecode=? 
 ORDER BY tagfield"
    );

    $sth->execute($authtypecode);
    my ( $liblibrarian, $libopac, $tag, $res, $tab, $mandatory, $repeatable );

    while ( ( $tag, $liblibrarian, $libopac, $mandatory, $repeatable ) = $sth->fetchrow ) {
        $res->{$tag}->{lib}        = ( $forlibrarian or !$libopac ) ? $liblibrarian : $libopac;
        $res->{$tag}->{tab}        = " ";                                                         # XXX
        $res->{$tag}->{mandatory}  = $mandatory;
        $res->{$tag}->{repeatable} = $repeatable;
    }
    $sth = $dbh->prepare(
        "SELECT tagfield,tagsubfield,liblibrarian,libopac,tab, mandatory, repeatable,authorised_value,frameworkcode as authtypecode,value_builder,kohafield,seealso,hidden,isurl 
FROM auth_subfield_structure 
WHERE authtypecode=? 
ORDER BY tagfield,tagsubfield"
    );
    $sth->execute($authtypecode);

    my $subfield;
    my $authorised_value;
    my $value_builder;
    my $kohafield;
    my $seealso;
    my $hidden;
    my $isurl;
    my $link;

    while (
        (   $tag, $subfield, $liblibrarian,, $libopac, $tab, $mandatory, $repeatable,
            $authorised_value, $authtypecode, $value_builder, $kohafield, $seealso, $hidden, $isurl, $link
        )
        = $sth->fetchrow
      ) {
        $res->{$tag}->{$subfield}->{lib}              = ( $forlibrarian or !$libopac ) ? $liblibrarian : $libopac;
        $res->{$tag}->{$subfield}->{tab}              = $tab;
        $res->{$tag}->{$subfield}->{mandatory}        = $mandatory;
        $res->{$tag}->{$subfield}->{repeatable}       = $repeatable;
        $res->{$tag}->{$subfield}->{authorised_value} = $authorised_value;
        $res->{$tag}->{$subfield}->{authtypecode}     = $authtypecode;
        $res->{$tag}->{$subfield}->{value_builder}    = $value_builder;
        $res->{$tag}->{$subfield}->{kohafield}        = $kohafield;
        $res->{$tag}->{$subfield}->{seealso}          = $seealso;
        $res->{$tag}->{$subfield}->{hidden}           = $hidden;
        $res->{$tag}->{$subfield}->{isurl}            = $isurl;
        $res->{$tag}->{$subfield}->{link}             = $link;
    }
    return $res;
}

=head2 AddAuthority

=over 4

$authid= &AddAuthority($record, $authid,$authtypecode)
returns authid of the newly created authority

Either Create Or Modify existing authority.

=back

=cut

sub AddAuthority {

    # pass the MARC::Record to this function, and it will create the records in the authority table
    my ( $record, $authid, $authtypecode ) = @_;
    my $dbh    = C4::Context->dbh;
    my $leader = '     nz  a22     o  4500';    #Leader for incomplete MARC21 record

    # if authid empty => true add, find a new authid number
    my $format;
    if ( uc( C4::Context->preference('marcflavour') ) eq 'UNIMARC' ) {
        $format = 'UNIMARCAUTH';
    } else {
        $format = 'MARC21';
    }

    SetUTF8Flag($record);
    if ( $format eq "MARC21" ) {
        if ( !$record->leader ) {
            $record->leader($leader);
        }
        if ( !$record->field('003') ) {
            $record->insert_fields_ordered( MARC::Field->new( '003', C4::Context->preference('MARCOrgCode') ) );
        }
        my $time = POSIX::strftime( "%Y%m%d%H%M%S", localtime );
        if ( !$record->field('005') ) {
            $record->insert_fields_ordered( MARC::Field->new( '005', $time . ".0" ) );
        }
        my $date = POSIX::strftime( "%y%m%d", localtime );
        if ( !$record->field('008') ) {
            $record->insert_fields_ordered( MARC::Field->new( '008', $date . "|||a||||||           | |||     d" ) );
        }
        if ( !$record->field('040') ) {
            $record->insert_fields_ordered(
                MARC::Field->new(
                    '040', '', '',
                    'a' => C4::Context->preference('MARCOrgCode'),
                    'c' => C4::Context->preference('MARCOrgCode')
                )
            );
        }
    }

    if ( $format eq "UNIMARCAUTH" ) {
        $record->leader("     nx  j22             ") unless ( $record->leader() );
        my $date = POSIX::strftime( "%Y%m%d", localtime );
        if ( my $string = $record->subfield( '100', "a" ) ) {
            $string =~ s/fre50/frey50/;
            $record->field('100')->update( 'a' => $string );
        } elsif ( $record->field('100') ) {
            $record->field('100')->update( 'a' => $date . "afrey50      ba0" );
        } else {
            $record->append_fields( MARC::Field->new( '100', ' ', ' ', 'a' => $date . "afrey50      ba0" ) );
        }
    }
    my ( $auth_type_tag, $auth_type_subfield ) = get_auth_type_location($authtypecode);
    if ( !$authid and $format eq "MARC21" ) {

        # only need to do this fix when modifying an existing authority
        C4::AuthoritiesMarc::MARC21::fix_marc21_auth_type_location( $record, $auth_type_tag, $auth_type_subfield );
    }
    if ( my $field = $record->field($auth_type_tag) ) {
        $field->update( $auth_type_subfield => $authtypecode );
    } else {
        $record->add_fields( $auth_type_tag, '', '', $auth_type_subfield => $authtypecode );
    }

    my $auth_exists = 0;
    my $oldRecord;
    if ( !$authid ) {
        my $sth = $dbh->prepare("select max(authid) from auth_header");
        $sth->execute;
        ($authid) = $sth->fetchrow;
        $authid = $authid + 1;
        ##Insert the recordID in MARC record
        unless ( $record->field('001') && $record->field('001')->data() eq $authid ) {
            $record->delete_field( $record->field('001') );
            $record->insert_fields_ordered( MARC::Field->new( '001', $authid ) );
        }
    } else {
        $auth_exists = $dbh->do( qq(select authid from auth_header where authid=?), undef, $authid );

        #     warn "auth_exists = $auth_exists";
    }
    if ( $auth_exists > 0 ) {
        $oldRecord = GetAuthority($authid);
        $record->add_fields( '001', $authid ) unless ( $record->field('001') );

        #       warn "\n\n\n enregistrement".$record->as_formatted;
        my $sth = $dbh->prepare("update auth_header set authtypecode=?,marc=?,marcxml=? where authid=?");
        $sth->execute( $authtypecode, $record->as_usmarc, $record->as_xml_record($format), $authid ) or die $sth->errstr;
        $sth->finish;
    } else {
        my $sth = $dbh->prepare("insert into auth_header (authid,datecreated,authtypecode,marc,marcxml) values (?,now(),?,?,?)");
        $sth->execute( $authid, $authtypecode, $record->as_usmarc, $record->as_xml_record($format) );
        $sth->finish;
    }
    C4::Search::IndexRecord("authority", [ $authid ] );
    return ($authid);
}

=head2 DelAuthority

=over 4

$authid= &DelAuthority($authid)
Deletes $authid

=back

=cut

sub DelAuthority {
    my ($authid) = @_;
    my $dbh = C4::Context->dbh;

    C4::Search::Engine::Solr::DeleteRecordIndex( "authority", $authid );
    $dbh->do("delete from auth_header where authid=$authid");

}

sub ModAuthority {
    my ( $authid, $record, $authtypecode, $merge ) = @_;
    my $dbh = C4::Context->dbh;

    #Now rewrite the $record to table with an add
    my $oldrecord = GetAuthority($authid);
    $authid = AddAuthority( $record, $authid, $authtypecode );

### If a library thinks that updating all biblios is a long process and wishes to leave that to a cron job to use merge_authotities.p
### they should have a system preference "dontmerge=1" otherwise by default biblios will be updated
### the $merge flag is now depreceated and will be removed at code cleaning
    if ( C4::Context->preference('MergeAuthoritiesOnUpdate') ) {
        &merge( $authid, $oldrecord, $authid, $record );
    } else {

        # save the file in tmp/modified_authorities
        my $cgidir = C4::Context->intranetdir . "/cgi-bin";
        unless ( opendir( DIR, "$cgidir" ) ) {
            $cgidir = C4::Context->intranetdir . "/";
            closedir(DIR);
        }

        my $filename = $cgidir . "/tmp/modified_authorities/$authid.authid";
        unless (-e $filename){
	    store $oldrecord, "$filename";
	}
    }
    C4::Search::IndexRecord("authority", [ $authid ] );
    return $authid;
}

=head2 GetAuthorityXML 

=over 4

$marcxml= &GetAuthorityXML( $authid)
returns xml form of record $authid

=back

=cut

sub GetAuthorityXML {

    # Returns MARC::XML of the authority passed in parameter.
    my ($authid) = @_;
    if ( uc( C4::Context->preference('marcflavour') ) eq 'UNIMARC' ) {
        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare("select marcxml from auth_header where authid=? ");
        $sth->execute($authid);
        my ($marcxml) = $sth->fetchrow;
        return $marcxml;
    } else {

        # for MARC21, call GetAuthority instead of
        # getting the XML directly since we may
        # need to fix up the location of the authority
        # code -- note that this is reasonably safe
        # because GetAuthorityXML is used only by the
        # indexing processes like zebraqueue_start.pl
        my $record = GetAuthority($authid);
        return $record->as_xml_record('MARC21');
    }
}

=head2 GetAuthority 

=over 4

$record= &GetAuthority( $authid)
Returns MARC::Record of the authority passed in parameter.

=back

=cut

sub GetAuthority {
    my ($authid) = @_;
    my $dbh      = C4::Context->dbh;
    my $sth      = $dbh->prepare("select authtypecode, marcxml from auth_header where authid=?");
    $sth->execute($authid);
    my ( $authtypecode, $marcxml ) = $sth->fetchrow;
    my $record = eval {
        MARC::Record->new_from_xml( StripNonXmlChars($marcxml),
            'UTF-8', ( C4::Context->preference("marcflavour") eq "UNIMARC" ? "UNIMARCAUTH" : C4::Context->preference("marcflavour") ) );
    };
    return undef if ($@);
    $record->encoding('UTF-8');

    if ( C4::Context->preference("marcflavour") eq "MARC21" ) {
        my ( $auth_type_tag, $auth_type_subfield ) = get_auth_type_location($authtypecode);
        C4::AuthoritiesMarc::MARC21::fix_marc21_auth_type_location( $record, $auth_type_tag, $auth_type_subfield );
    }
    return ($record);
}

=head2 GetAuthType 

=over 4

$result = &GetAuthType($authtypecode)

=back

If the authority type specified by C<$authtypecode> exists,
returns a hashref of the type's fields.  If the type
does not exist, returns undef.

=cut

sub GetAuthType {
    my ($authtypecode) = @_;
    my $dbh = C4::Context->dbh;
    my $sth;
    if ( defined $authtypecode ) {    # NOTE - in MARC21 framework, '' is a valid authority
                                      # type (FIXME but why?)
        $sth = $dbh->prepare("select * from auth_types where authtypecode=?");
        $sth->execute($authtypecode);
        if ( my $res = $sth->fetchrow_hashref ) {
            return $res;
        }
    }
    return;
}

sub GetAuthTypeText {
    my ($authtypecode) = @_;
    my $dbh = C4::Context->dbh;
    my $sth;
    $sth = $dbh->prepare("select authtypetext from auth_types where authtypecode=?");
    $sth->execute($authtypecode);
    return $sth->fetchrow;
}

sub AUTHhtml2marc {
    my ( $rtags, $rsubfields, $rvalues, %indicators ) = @_;
    my $dbh     = C4::Context->dbh;
    my $prevtag = -1;
    my $record  = MARC::Record->new();

    #---- TODO : the leader is missing

    #     my %subfieldlist=();
    my $prevvalue;    # if tag <10
    my $field;        # if tag >=10
    for ( my $i = 0 ; $i < @$rtags ; $i++ ) {

        # rebuild MARC::Record
        if ( @$rtags[$i] ne $prevtag ) {
            if ( $prevtag < 10 ) {
                if ($prevvalue) {
                    $record->add_fields( ( sprintf "%03s", $prevtag ), $prevvalue );
                }
            } else {
                if ($field) {
                    $record->add_fields($field);
                }
            }
            $indicators{ @$rtags[$i] } .= '  ';
            if ( @$rtags[$i] < 10 ) {
                $prevvalue = @$rvalues[$i];
                undef $field;
            } else {
                undef $prevvalue;
                $field = MARC::Field->new(
                    ( sprintf "%03s", @$rtags[$i] ),
                    substr( $indicators{ @$rtags[$i] }, 0, 1 ),
                    substr( $indicators{ @$rtags[$i] }, 1, 1 ),
                    @$rsubfields[$i] => @$rvalues[$i]
                );
            }
            $prevtag = @$rtags[$i];
        } else {
            if ( @$rtags[$i] < 10 ) {
                $prevvalue = @$rvalues[$i];
            } else {
                if ( length( @$rvalues[$i] ) > 0 ) {
                    $field->add_subfields( @$rsubfields[$i] => @$rvalues[$i] );
                }
            }
            $prevtag = @$rtags[$i];
        }
    }

    # the last has not been included inside the loop... do it now !
    $record->add_fields($field) if $field;
    return $record;
}

=head2 FindDuplicateAuthority

=over 4

$record= &FindDuplicateAuthority( $record, $authtypecode)
return $authid,Summary if duplicate is found.

Comments : an improvement would be to return All the records that match.

=back

=cut

sub FindDuplicateAuthority {

    my ( $record, $authtypecode ) = @_;

    #    warn "IN for ".$record->as_formatted;
    my $dbh = C4::Context->dbh;

    #    warn "".$record->as_formatted;
    my $sth = $dbh->prepare("select auth_tag_to_report from auth_types where authtypecode=?");
    $sth->execute($authtypecode);
    my ($auth_tag_to_report) = $sth->fetchrow;
    $sth->finish;

    my $query        = 'at=' . $authtypecode . ' ';
    my $filtervalues = qr([\001-\040\!\'\"\`\#\$\%\&\*\+,\-\./:;<=>\?\@\(\)\{\[\]\}_\|\~]);
    if ( $record->field($auth_tag_to_report) ) {
        foreach ( $record->field($auth_tag_to_report)->subfields() ) {
            $_->[1] =~ s/$filtervalues/ /g;
            $query .= " and he,wrdl=\"" . $_->[1] . "\"" if ( $_->[0] =~ /[A-z]/ );
        }
    }

    $query = C4::Search::Query->normalSearch($query);
    my $results = C4::Search::SimpleSearch($query);

    # there is at least 1 result => return the 1st one
    if ( @{$results->items} > 0 ) {
        my $authid = @{$results->items}[0]->{values}->{recordid};
        my $authrecord = GetAuthority($authid);

        return $authid, BuildSummary( $authrecord, $authid, $authtypecode);
    }

    # no result, returns nothing
    return;
}

=head2 BuildSummary

=over 4

$text= &BuildSummary( $record, $authid, $authtypecode)
return HTML encoded Summary

Comment : authtypecode can be infered from both record and authid.
Moreover, authid can also be inferred from $record.
Would it be interesting to delete those things.

=back

=cut

sub BuildSummary {
## give this a Marc record to return summary
    my ( $record, $authid, $authtypecode ) = @_;
    my $dbh = C4::Context->dbh;
    my $summary;

    # handle $authtypecode is NULL or eq ""
    if ($authtypecode) {
        my $authref = GetAuthType($authtypecode);
        $summary = $authref->{summary};
    }

    # FIXME: should use I18N.pm
    my %language;
    $language{'fre'} = "Français";
    $language{'eng'} = "Anglais";
    $language{'ger'} = "Allemand";
    $language{'ita'} = "Italien";
    $language{'spa'} = "Espagnol";
    my %thesaurus;
    $thesaurus{'1'} = "Peuples";
    $thesaurus{'2'} = "Anthroponymes";
    $thesaurus{'3'} = "Oeuvres";
    $thesaurus{'4'} = "Chronologie";
    $thesaurus{'5'} = "Lieux";
    $thesaurus{'6'} = "Sujets";

    #thesaurus a remplir

    # if the library has a summary defined, use it. Otherwise, build a standard one
    # FIXME - it appears that the summary field in the authority frameworks
    #         can work as a display template.  However, this doesn't
    #         suit the MARC21 version, so for now the "templating"
    #         feature will be enabled only for UNIMARC for backwards
    #         compatibility.
    if ( $summary and C4::Context->preference('marcflavour') eq 'UNIMARC' ) {
        my @matches = ($summary =~ m/\[(.*?)(\d{3})([\*a-z0-9])(.*?)\]/g);
        my (@textbefore, @tag, @subtag, @textafter);
        for(my $i = 0; $i < scalar @matches; $i++){
            push @textbefore, $matches[$i] if($i%4 == 0);
            push @tag,        $matches[$i] if($i%4 == 1);
            push @subtag,     $matches[$i] if($i%4 == 2);
            push @textafter,  $matches[$i] if($i%4 == 3);
        }
        for(my $i = scalar @tag; $i >= 0; $i--){
            my $textbefore = $textbefore[$i] || '';
            my $tag = $tag[$i] || '';
            my $subtag = $subtag[$i] || '';
            my $textafter = $textafter[$i] || '';
            my $value = '';
            my $field = $record->field($tag);
            if ( $field ) {
                if($subtag eq '*') {
                    if($tag < 10) {
                        $value = $textbefore . $field->data() . $textafter;
                    }
                } else {
                    my @subfields = $field->subfield($subtag);
                    if(@subfields > 0) {
                        $value = $textbefore . join (" - ", @subfields) . $textafter;
                    }
                }
            }
            $summary =~ s/\[\Q$textbefore$tag$subtag$textafter\E\]/$value/;
        }
        $summary =~ s/\\n/<br \/>/g;
    } else {
        my $heading;
        my $altheading;
        my $seealso;
        my $broaderterms;
        my $narrowerterms;
        my $see;
        my $seeheading;
        my $notes;
        my @fields = $record->fields();

        if ( C4::Context->preference('marcflavour') eq 'UNIMARC' ) {

            # construct UNIMARC summary, that is quite different from MARC21 one
            # accepted form
            foreach my $field ( $record->field('2..') ) {
                $heading .= $field->as_string('abcdefghijlmnopqrstuvwxyz');
            }

            # rejected form(s)
            foreach my $field ( $record->field('3..') ) {
                $notes .= '<span class="note">' . $field->subfield('a') . "</span>\n";
            }
            foreach my $field ( $record->field('4..') ) {
                if ( $field->subfield('2') ) {
                    my $thesaurus = "thes. : " . $thesaurus{"$field->subfield('2')"} . " : ";
                    $see .= '<span class="UF">' . $thesaurus . $field->as_string('abcdefghijlmnopqrstuvwxyz') . "</span> -- \n";
                }
            }

            # see :
            foreach my $field ( $record->field('5..') ) {

                if ( ( $field->subfield('5') ) && ( $field->subfield('a') ) && ( $field->subfield('5') eq 'g' ) ) {
                    $broaderterms .= '<span class="BT"> ' . $field->as_string('abcdefgjxyz') . "</span> -- \n";
                } elsif ( ( $field->subfield('5') ) && ( $field->as_string ) && ( $field->subfield('5') eq 'h' ) ) {
                    $narrowerterms .= '<span class="NT">' . $field->as_string('abcdefgjxyz') . "</span> -- \n";
                } elsif ( $field->subfield('a') ) {
                    $seealso .= '<span class="RT">' . $field->as_string('abcdefgxyz') . "</a></span> -- \n";
                }
            }

            # // form
            foreach my $field ( $record->field('7..') ) {
                my $lang = substr( $field->subfield('8'), 3, 3 );
                $seeheading .= '<span class="langue"> En ' . $language{$lang} . ' : </span><span class="OT"> ' . $field->subfield('a') . "</span><br />\n";
            }
            $broaderterms  =~ s/-- \n$// if $broaderterms;
            $narrowerterms =~ s/-- \n$// if $narrowerterms;
            $seealso       =~ s/-- \n$// if $seealso;
            $see           =~ s/-- \n$// if $see;
            $summary = "<b>" . $heading . "</b><br />" . ( $notes ? "$notes <br />" : "" );
            $summary .= '<p><div class="label">TG : ' . $broaderterms . '</div></p>'  if ($broaderterms);
            $summary .= '<p><div class="label">TS : ' . $narrowerterms . '</div></p>' if ($narrowerterms);
            $summary .= '<p><div class="label">TA : ' . $seealso . '</div></p>'       if ($seealso);
            $summary .= '<p><div class="label">EP : ' . $see . '</div></p>'           if ($see);
            $summary .= '<p><div class="label">' . $seeheading . '</div></p>'         if ($seeheading);
        } else {

            # construct MARC21 summary
            # FIXME - looping over 1XX is questionable
            # since MARC21 authority should have only one 1XX
            foreach my $field ( $record->field('1..') ) {
                next if "152" eq $field->tag();    # FIXME - 152 is not a good tag to use
                                                   # in MARC21 -- purely local tags really ought to be
                                                   # 9XX
                if ( $record->field('100') ) {
                    $heading .= $field->as_string('abcdefghjklmnopqrstvxyz68');
                } elsif ( $record->field('110') ) {
                    $heading .= $field->as_string('abcdefghklmnoprstvxyz68');
                } elsif ( $record->field('111') ) {
                    $heading .= $field->as_string('acdefghklnpqstvxyz68');
                } elsif ( $record->field('130') ) {
                    $heading .= $field->as_string('adfghklmnoprstvxyz68');
                } elsif ( $record->field('148') ) {
                    $heading .= $field->as_string('abvxyz68');
                } elsif ( $record->field('150') ) {

                    #    $heading.= $field->as_string('abvxyz68');
                    $heading .= $field->as_formatted();
                    my $tag = $field->tag();
                    $heading =~ s /^$tag//g;
                    $heading =~ s /\_/\$/g;
                } elsif ( $record->field('151') ) {
                    $heading .= $field->as_string('avxyz68');
                } elsif ( $record->field('155') ) {
                    $heading .= $field->as_string('abvxyz68');
                } elsif ( $record->field('180') ) {
                    $heading .= $field->as_string('vxyz68');
                } elsif ( $record->field('181') ) {
                    $heading .= $field->as_string('vxyz68');
                } elsif ( $record->field('182') ) {
                    $heading .= $field->as_string('vxyz68');
                } elsif ( $record->field('185') ) {
                    $heading .= $field->as_string('vxyz68');
                } else {
                    $heading .= $field->as_string();
                }
            }    #See From
            foreach my $field ( $record->field('4..') ) {
                $seeheading .= "<br />&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<i>used for/see from:</i> " . $field->as_string();
            }    #See Also
            foreach my $field ( $record->field('5..') ) {
                $altheading .= "<br />&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<i>see also:</i> " . $field->as_string();
            }
            $summary .= ": " if $summary;
            $summary .= $heading . $seeheading . $altheading;
        }
    }
    return $summary;
}


sub _get_authid_subfield{
    my ($field)=@_;
        return $field->subfield('9')||$field->subfield('3');
}
=head2 BuildUnimarcHierarchies

=over 4

$text= &BuildUnimarcHierarchies( $authid, $force)
return text containing trees for hierarchies
for them to be stored in auth_header

Example of text:
122,1314,2452;1324,2342,3,2452

=back

=cut

sub BuildUnimarcHierarchies{
  my $authid = shift @_;
#   warn "authid : $authid";
  my $force = shift @_;
  my @globalresult;
  my $dbh=C4::Context->dbh;
  my $hierarchies;
  my $data = GetHeaderAuthority($authid);
  if ($data->{'authtrees'} and not $force){
    return $data->{'authtrees'};
#  } elsif ($data->{'authtrees'}){
#    $hierarchies=$data->{'authtrees'};
  } else {
    my $record = GetAuthority($authid);
    my $found;
    return unless $record;
    foreach my $field ($record->field('5..')){
      if ($field->subfield('5') && $field->subfield('5') eq 'g'){
		my $subfauthid=_get_authid_subfield($field);
        next if ($subfauthid eq $authid);
        my $parentrecord = GetAuthority($subfauthid);
        my $localresult=$hierarchies;
        my $trees;
        $trees = BuildUnimarcHierarchies($subfauthid);
        my @trees;
        if ($trees=~/;/){
           @trees = split(/;/,$trees);
        } else {
           push @trees, $trees;
        }
        foreach (@trees){
          $_.= ",$authid";
        }
        @globalresult = (@globalresult,@trees); 
        $found=1; 
      }    
      $hierarchies=join(";",@globalresult);
    } 
    #Unless there is no ancestor, I am alone.
    $hierarchies="$authid" unless ($hierarchies);
  } 

  AddAuthorityTrees($authid,$hierarchies);
  return $hierarchies;
}

=head2 BuildUnimarcHierarchy

=over 4

$ref= &BuildUnimarcHierarchy( $record, $class,$authid)
return a hashref in order to display hierarchy for record and final Authid $authid

"loopparents"
"loopchildren"
"class"
"loopauthid"
"current_value"
"value"

"ifparents"  
"ifchildren" 
Those two latest ones should disappear soon.

=back

=cut

sub BuildUnimarcHierarchy{
  my $record = shift @_;
  my $class = shift @_;
  my $authid_constructed = shift @_;
  return unless $record;
  my $authid=$record->field('001')->data();
  my %cell;
  my $parents=""; my $children="";
  my (@loopparents,@loopchildren);
  foreach my $field ($record->field('5..')){
	my $subfauthid=_get_authid_subfield($field);
    if ($field->subfield('5') && $field->subfield('a')){
      if ($field->subfield('5') eq 'h'){
        push @loopchildren, { "childauthid"=>$subfauthid,"childvalue"=>$field->subfield('a')};
      }elsif ($field->subfield('5') eq 'g'){
        push @loopparents, { "parentauthid"=>$subfauthid,"parentvalue"=>$field->subfield('a')};
      }
          # brothers could get in there with an else
    }
  }
  $cell{"ifparents"}     = 1              if ( scalar(@loopparents) > 0 );
  $cell{"ifchildren"}    = 1              if ( scalar(@loopchildren) > 0 );
  $cell{"loopparents"}   = \@loopparents  if ( scalar(@loopparents) > 0 );
  $cell{"loopchildren"}  = \@loopchildren if ( scalar(@loopchildren) > 0 );
  $cell{"class"}         = $class;
  $cell{"loopauthid"}    = $authid;
  $cell{"current_value"} = 1              if $authid eq $authid_constructed;
  $cell{"value"} = $record->subfield( '2..', "a" );
  return \%cell;
}

=head2 GetHeaderAuthority

=over 4

$ref= &GetHeaderAuthority( $authid)
return a hashref in order auth_header table data

=back

=cut

sub GetHeaderAuthority {
    my $authid = shift @_;
    my $sql    = "SELECT * from auth_header WHERE authid = ?";
    my $dbh    = C4::Context->dbh;
    my $rq     = $dbh->prepare($sql);
    $rq->execute($authid);
    my $data = $rq->fetchrow_hashref;
    return $data;
}

=head2 AddAuthorityTrees

=over 4

$ref= &AddAuthorityTrees( $authid, $trees)
return success or failure

=back

=cut

sub AddAuthorityTrees {
    my $authid = shift @_;
    my $trees  = shift @_;
    my $sql    = "UPDATE IGNORE auth_header set authtrees=? WHERE authid = ?";
    my $dbh    = C4::Context->dbh;
    my $rq     = $dbh->prepare($sql);
    return $rq->execute( $trees, $authid );
}

=head2 merge

=over 4

$ref= &merge(mergefrom,$MARCfrom,$mergeto,$MARCto)


Could add some feature : Migrating from a typecode to an other for instance.
Then we should add some new parameter : bibliotargettag, authtargettag

=back

=cut


# Test if a subfield exist in a subfield list
sub _test_subfcode_presence{
    my ($subfields,$subfcode)=@_;
    return grep{$_->[0] eq $subfcode} @$subfields;
}

sub _test_string{
    my ($string,@fields)=@_;
    my $return=0;
    for my $field (@fields) {
        if (grep {$_->[1] =~/$string/i} $field->subfields){
            $return=1;
            last; 
        }
    }
    return $return;
}

sub _process_subfcode_4_merge{
    my ($tagfield,$bibliosubfields,$authorityrecord, $authoritysubfields)=@_;
    return unless (uc(C4::Context->preference('marcflavour')) eq 'UNIMARC');
    if (   $tagfield eq "606"
        or $tagfield eq "600"
        or $tagfield eq "607"
        or $tagfield eq "700"
        or $tagfield eq "701"
        or $tagfield eq "702"
        or $tagfield eq "710"
        or $tagfield eq "711"
        or $tagfield eq "712"
        ) {
        my $authtypecode = GuessAuthTypeCode($authorityrecord); 
        my $authtag = GetAuthType($authtypecode);
        my $chronological_auth
            = _test_string( 'chronologique', $authorityrecord->field('3..') );
        my $subfz_absent
            = not _test_subfcode_presence( $authoritysubfields, 'z' );
        if ( _test_subfcode_presence( $bibliosubfields, "a" ) ) {
            if ( $authtag->{'auth_type_code'} eq '215' and $tagfield ne "607") {
                return "y";
            } elsif ( $chronological_auth and $subfz_absent ) {
                return "z";
            } else {
                return "x";
            }
        }
        return;
    }
    return;
}

sub merge {
    my ( $mergefrom, $MARCfrom, $mergeto, $MARCto ) = @_;
    my $dbh              = C4::Context->dbh;
    my $authtypecodefrom = GetAuthTypeCode($mergefrom);
    my $authtypecodeto   = GetAuthTypeCode($mergeto);
    $MARCfrom ||=GetAuthority($mergefrom);
    $MARCto   ||=GetAuthority($mergeto);

    #     warn "mergefrom : $authtypecodefrom $mergefrom mergeto : $authtypecodeto $mergeto ";
    # return if authority does not exist
    return "error MARCFROM not a marcrecord " . Data::Dumper::Dumper($MARCfrom) if scalar( $MARCfrom->fields() ) == 0;
    return "error MARCTO not a marcrecord" . Data::Dumper::Dumper($MARCto)      if scalar( $MARCto->fields() ) == 0;

    # search the tag to report
    my $sth = $dbh->prepare("select auth_tag_to_report from auth_types where authtypecode=?");
    $sth->execute($authtypecodefrom);
    my ($auth_tag_to_report_from) = $sth->fetchrow;
    $sth->execute($authtypecodeto);
    my ($auth_tag_to_report_to) = $sth->fetchrow;

    my @record_to;
    @record_to = grep {$_->[0]!~/[0-9]/} $MARCto->field($auth_tag_to_report_to)->subfields() if $MARCto->field($auth_tag_to_report_to);
    $debug and warn 'champs a fusionner',Data::Dumper::Dumper(@record_to);
    my $field_to;
    $field_to = $MARCto->field($auth_tag_to_report_to) if $MARCto->field($auth_tag_to_report_to);
    my @record_from;
    @record_from = $MARCfrom->field($auth_tag_to_report_from)->subfields() if $MARCfrom->field($auth_tag_to_report_from);


    my @reccache;
    my @edited_biblios;

    # search all biblio tags using this authority.
    #Getting marcbiblios impacted by the change.
    my $query = C4::Search::Query->normalSearch(qq{an=$mergefrom});
    my $results = C4::Search::SimpleSearch($query);

    if ($results->{error}){
        die $results->{error};
    }
    $debug and warn scalar(@{$results->{items}});

    foreach my $rawrecord( @{$results->{items}} ) {
        my $marcrecord = GetMarcBiblio($rawrecord->{values}->{recordid});
        SetUTF8Flag($marcrecord);
        push @reccache, $marcrecord;
    }

    #warn scalar(@reccache)." biblios to update";
    # Get All candidate Tags for the change
    # (This will reduce the search scope in marc records).
    $sth = $dbh->prepare("select distinct tagfield from marc_subfield_structure where authtypecode<>''");
    $sth->execute();
    my @tags_using_authtype;
    while ( my ($tagfield) = $sth->fetchrow ) {
        push @tags_using_authtype, $tagfield;
    }
    my $tag_to=0;  
    foreach my $marcrecord (@reccache) {
        foreach my $tagfield (@tags_using_authtype) {
            foreach my $field ( $marcrecord->field($tagfield) ) {
                my $update;
                my $tag = $field->tag();
                my @newsubfields;
                my %indexes;

                #get to next field if no subfield
                my @localsubfields = $field->subfields();
                my $index_9_auth   = 0;
                my $found          = 0;
                for my $subf (@localsubfields) {

                    if (    ( $subf->[0] eq "9" )
                        and ( $subf->[1] == $mergefrom ) ) {
                        $found = 1;
                        $debug && warn "found $mergefrom " . $subf->[1];
                        last;
                    }
                    $index_9_auth++;
                }

                next if ( $index_9_auth >= $#localsubfields and !$found );

                # Removes the data if before the $9
                my $index = 0;
                for my $subf ( @localsubfields[ 0 .. $index_9_auth ] ) {
                    if (any {
                                $subf->[1] eq $_->[1]
                        }
                        @record_from
                        ) {
                        $debug && warn "found $subf->[0] " . $subf->[1];
                        splice @localsubfields, $index, 1;
                        $index_9_auth--;
                    } else {
                        $index++;
                    }
                }

                #Get the next $9 subfield
                my $nextindex_9 = 0;
                for my $subf (
                    @localsubfields[ $index_9_auth + 1 .. $#localsubfields ] )
                {
                    last if ($subf->[0] =~ /[1-9]/);
                    $nextindex_9++;
                }

      #Change the first tag if required
      # That is : change the first tag ($a) to what it is in the biblio record
      # Since some composed authorities will place the $a into $x or $y

                my @previous_subfields
                    = @localsubfields[ 0 .. $index_9_auth ];
                if (my $changesubfcode = _process_subfcode_4_merge(
                        $tag, \@previous_subfields, $MARCto, \@record_to
                    )
                    ) {
                    $record_to[0]->[0] = $changesubfcode
                        if defined($changesubfcode);
                }

                splice(
                    @localsubfields, $index_9_auth,
                    $nextindex_9 + 1,
                    ( [ 9, $mergeto ], @record_to )
                );

    #very nice api for MARC::Record
    # It seems that some elements localsubfields can be undefined so skip them
                @newsubfields
                    = map { ( defined $_ ? @$_ : () ) } @localsubfields;

                #filter to subfields which are not in the subfield
                my $field_to = MARC::Field->new(
                    ( $tag_to ? $tag_to : $tag ), $field->indicator(1),
                    $field->indicator(2), @newsubfields
                );
                $marcrecord->delete_field($field);
                $marcrecord->insert_fields_ordered($field_to);
            }    #for each tag
        }    #foreach tagfield
        my ( $bibliotag, $bibliosubf )
            = GetMarcFromKohaField( "biblio.biblionumber", "" );
        my $biblionumber;
        if ( $bibliotag < 10 ) {
            $biblionumber = $marcrecord->field($bibliotag)->data;
        } else {
            $biblionumber = $marcrecord->subfield( $bibliotag, $bibliosubf );
        }

        unless ($biblionumber) {
            warn "pas de numéro de notice bibliographique dans : "
                . $marcrecord->as_formatted;
            next;
        }

        &ModBiblio( $marcrecord, $biblionumber,
            GetFrameworkCode($biblionumber) );
        push @edited_biblios, $biblionumber;

    }    #foreach $marc
    DelAuthority($mergefrom) if ( $mergefrom != $mergeto );
    return @edited_biblios;

}    #sub

=head2 get_auth_type_location

=over 4

my ($tag, $subfield) = get_auth_type_location($auth_type_code);

=back

Get the tag and subfield used to store the heading type
for indexing purposes.  The C<$auth_type> parameter is
optional; if it is not supplied, assume ''.

This routine searches the MARC authority framework
for the tag and subfield whose kohafield is 
C<auth_header.authtypecode>; if no such field is
defined in the framework, default to the hardcoded value
specific to the MARC format.

=cut

sub get_auth_type_location {
    my $auth_type_code = @_ ? shift : '';

    my ( $tag, $subfield ) = GetAuthMARCFromKohaField( 'auth_header.authtypecode', $auth_type_code );
    if ( defined $tag and defined $subfield and $tag != 0 and $subfield != 0 ) {
        return ( $tag, $subfield );
    } else {
        if ( C4::Context->preference('marcflavour') eq "MARC21" ) {
            return C4::AuthoritiesMarc::MARC21::default_auth_type_location();
        } else {
            return C4::AuthoritiesMarc::UNIMARC::default_auth_type_location();
        }
    }
}

sub GetIndexBySearchtype {
    my ($searchtype) = @_;
    my $index;
    given ( $searchtype ) {
        when ( 'authority_search' ) { # Chercher dans la vedette ($a)
            $index = 'auth-heading-main';
        }
        when ( 'main_heading' ) { # Recherche vedette
            $index = 'auth-heading';
        }
        default { # Rechercher toutes les vedettes
            $index = 'all_fields';
        }
    }
    return C4::Search::Query::getIndexName($index);
}


END { }    # module clean-up code here (global destructor)

1;
__END__

=head1 AUTHOR

Koha Developement team <info@koha.org>

Paul POULAIN paul.poulain@free.fr

=cut

