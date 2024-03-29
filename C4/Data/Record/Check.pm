package C4::Data::Record::Check;

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
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use Modern::Perl;
use MARC::Field;
use MARC::Record;
use C4::AuthoritiesMarc;
use C4::Charset;
use C4::Context;
use C4::Search;
use C4::Search::Query;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $DEBUG);

@ISA    = qw(Exporter);
@EXPORT = qw(
  &BiblioAddAuthorities
);

=head2 BiblioAddAuthorities

( $countlinked, $countcreated ) = BiblioAddAuthorities($record, $frameworkcode);

this function finds the authorities linked to the biblio
    * search in the authority DB for the same authid (in $9 of the biblio)
    * search in the authority DB for the same 001 (in $3 of the biblio in UNIMARC)
    * search in the authority DB for the same values (exactly) (in all subfields of the biblio)
OR adds a new authority record
 if the authority is found, the biblio is modified accordingly to be connected to the authority.
 if the authority is not found, it's added, and the biblio is then modified to be connected to the authority.

=over 2

=item C<input arg:>

    * $record is the MARC record in question (marc blob)
    * $frameworkcode is the bibliographic framework to use (if it is "" it uses the default framework)

=item C<Output arg:>

    * $countlinked is the number of authorities records that are linked to this authority
    * $countcreated

=back

=cut
sub BiblioAddAuthorities {
    my ( $record, $frameworkcode ) = @_;
    my $dbh   = C4::Context->dbh;
    my $query = $dbh->prepare(qq|
        SELECT authtypecode,tagfield,tagsubfield
        FROM marc_subfield_structure
        WHERE frameworkcode=?
        AND (authtypecode IS NOT NULL AND authtypecode<>\"\")
    |);

    $query->execute($frameworkcode);
    my ( $countcreated, $countlinked );
    while ( my $data = $query->fetchrow_hashref ) {
        foreach my $field ( $record->field( $data->{tagfield} ) ) {
            # For each field linked to an authority type

            # Skip this field if already linked to an authority
            next if ( $field->subfield('9') );

            my $authtypedata = GetAuthType( $data->{authtypecode} );
            next unless $authtypedata;

            # No authorities id in the tag.
            # Search if there is any authorities to link to.
            my $query = '*:*';
            my $authtype_index = C4::Search::Query::getIndexName('auth-type');
            my $filters = {
                recordtype   => 'authority',
                $authtype_index => $data->{authtypecode},
            };
            my $auth_heading_index_name = C4::Search::Query::getIndexName('auth-heading');
            foreach ( $field->subfields ) {
                my $subfieldtag = $_->[0];
                my $subfieldvalue = $_->[1];
                utf8::encode($subfieldvalue);
                if ($subfieldtag =~ /[A-z]/) {
                    $query .= qq{ AND $auth_heading_index_name:"$subfieldvalue" };
                }
            }
            my $auth_heading_main_index_name = C4::Search::Query::getIndexName('auth-heading-main');
            foreach my $subfieldvalue ($field->subfield($data->{tagsubfield})) {
                utf8::encode($subfieldvalue);
                $query .= qq{ AND $auth_heading_main_index_name:"$subfieldvalue" };
            }
            my $res = SimpleSearch( $query, $filters );
            my $duplicate_found = 0;
            if ( !$$res{error} ) {
                foreach my $item (@{ $res->items }) {
                    # Search returned results, loop over all of them
                    # to find a matching authority
                    if( field_is_authority_duplicate($field, $item->{values}->{recordid},
                        $authtypedata->{auth_tag_to_report})
                    ) {
                        $field->add_subfields( '9' => $item->{'values'}->{'recordid'} );
                        $countlinked++;
                        $duplicate_found = 1;
                        last;
                    }
                }
            }

            if(not $duplicate_found) {
                # No duplicate authority was found,
                # build authority record, add it to Authorities, get authid and add it to 9
                ###NOTICE : This is only valid if a subfield is linked to one and only one authtypecode
                ###NOTICE : This can be a problem. We should also look into other types and rejected forms.
                my $marcrecordauth = MARC::Record->new();
                if ( C4::Context->preference('marcflavour') eq 'MARC21' ) {
                    $marcrecordauth->leader('     nz  a22     o  4500');
                    SetMarcUnicodeFlag( $marcrecordauth, 'MARC21' );
                }
                my $authfield = MARC::Field->new( $authtypedata->{auth_tag_to_report}, '', '', "a" => "" . $field->subfield('a') );
                map { $authfield->add_subfields( $_->[0] => $_->[1] ) if ( $_->[0] =~ /[A-z]/ && $_->[0] ne "a" ) } $field->subfields();
                $marcrecordauth->insert_fields_ordered($authfield);

                # bug 2317: ensure new authority knows it's using UTF-8; currently
                # only need to do this for MARC21, as MARC::Record->as_xml_record() handles
                # automatically for UNIMARC (by not transcoding)
                # FIXME: AddAuthority() instead should simply explicitly require that the MARC::Record
                # use UTF-8, but as of 2008-08-05, did not want to introduce that kind
                # of change to a core API just before the 3.0 release.

                if ( C4::Context->preference('marcflavour') eq 'MARC21' ) {
                    $marcrecordauth->insert_fields_ordered( MARC::Field->new( '667', '', '', 'a' => "Machine generated authority record." ) );
                    my $cite = $record->author() . ", " . $record->title_proper() . ", " . $record->publication_date() . " ";
                    $cite =~ s/^[\s\,]*//;
                    $cite =~ s/[\s\,]*$//;
                    $cite = "Work cat.: (" . C4::Context->preference('MARCOrgCode') . ")" . $record->subfield( '999', 'c' ) . ": " . $cite;
                    $marcrecordauth->insert_fields_ordered( MARC::Field->new( '670', '', '', 'a' => $cite ) );
                }


                my $authid = AddAuthority( $marcrecordauth, '', $data->{authtypecode} );
                $countcreated++;
                $field->add_subfields( '9' => $authid );
            }
        }
    }
    return ( $countlinked, $countcreated );
}

=head2 field_is_authority_duplicate

    if(field_is_authority_duplicate($field, $authid, $authfieldtag)) {
        print "duplicate";
    }

Given a MARC::Field ($field), an authority id ($authid) and the authority field
tag to report for this authority type ($authfieldtag), this subroutine check if
the field and the authority are equivalent, according to system preference
AuthSubfieldsToCheck.

Return true if they are equivalent, false otherwise

=cut

sub field_is_authority_duplicate {
    my ($field, $authid, $authfieldtag) = @_;

    my $auth = GetAuthority($authid);
    return 0 unless $auth;

    my @subfields_to_check = split / /, C4::Context->preference('AuthSubfieldsToCheck');
    foreach my $subfieldtag (@subfields_to_check) {
        my @field_values = $field->subfield($subfieldtag);
        my @auth_values = $auth->subfield($authfieldtag, $subfieldtag);

        # Remove leading, trailing and multiple whitespaces
        s/^\s+// foreach (@field_values, @auth_values);
        s/\s+$// foreach (@field_values, @auth_values);
        s/\s+/ / foreach (@field_values, @auth_values);

        # Return if arrays are not equals
        return 0 if(not @field_values ~~ @auth_values);
    }
    return 1;
}


1;

