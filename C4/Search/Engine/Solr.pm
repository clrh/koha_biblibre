package C4::Search::Engine::Solr;

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

use utf8;
use Modern::Perl;

use C4::AuthoritiesMarc;
use C4::Context;
use C4::Biblio;
use C4::Branch;
use C4::Koha;
use Data::SearchEngine::Solr;
use Data::SearchEngine::Query;
use Data::SearchEngine::Item;
use Data::SearchEngine::Solr::Results;
use Time::Progress;
use Moose;
use List::MoreUtils qw(uniq);
use XML::Simple;

extends 'Data::SearchEngine::Solr';

=head1 NAME

C4::Search::Engine::Solr - Solr functions

=head1 DESCRIPTION

Contains SimpleSearch and IndexRecord for Solr search engine.

=head1 FUNCTIONS

=cut


sub GetSolrConnection {
    C4::Search::Engine::Solr->new(
        url     => C4::Context->preference("SolrAPI"),
        options => { autocommit => 1 }
    );
}

sub GetRessourceTypes {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT DISTINCT(ressource_type) FROM indexes ORDER BY ressource_type");
    $sth->execute();
    return $sth->fetchall_arrayref({});
}

sub GetIndexes {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT * FROM indexes WHERE ressource_type = ? ORDER BY id");
    $sth->execute(shift);
    return $sth->fetchall_arrayref({});
}

sub GetIndexesWithAvlist {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT code, avlist FROM indexes WHERE avlist<>''");
    $sth->execute();
    return $sth->fetchall_arrayref({});
}

sub GetSortableIndexes {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT * FROM indexes WHERE sortable = 1 AND ressource_type = ? ORDER BY code");
    $sth->execute(shift);
    return $sth->fetchall_arrayref({});
}

sub GetFacetedIndexes {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT `type`, `code` FROM indexes WHERE faceted = 1 AND ressource_type = ?");
    $sth->execute(shift);

    my @indexes;

    while ( my $row = $sth->fetchrow_hashref() ) {
        # Facets must be in str field (created by indexrecord)
        push @indexes, 'str_'.$row->{code};
    }

    return \@indexes;
}

sub SetIndexes {
    my ($ressource_type, $indexes) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("DELETE FROM indexes WHERE ressource_type = ?");
    $sth->execute($ressource_type);

    my $query  = "INSERT INTO indexes (`code`,`label`,`type`,`faceted`,`ressource_type`,`mandatory`,`sortable`,`plugin`, `rpn_index`, `ccl_index_name`, `avlist`) VALUES (?,?,?,?,?,?,?,?,?,?,?)";
    my $sth2 = $dbh->prepare($query);
    for ( @$indexes ) {
        $sth2->execute(
	    $_->{'code'},
	    $_->{'label'},
	    $_->{'type'},
	    $_->{'faceted'},
	    $ressource_type,
	    $_->{'mandatory'},
	    $_->{'sortable'},
	    $_->{'plugin'},
      $_->{'rpn_index'},
      $_->{'ccl_index_name'},
      $_->{'avlist'},
	);
    }
}

sub SetMappings {
    my ($ressource_type, $indexes) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("DELETE FROM indexmappings WHERE ressource_type = ?");
    $sth->execute($ressource_type);
    my $query  = "INSERT INTO indexmappings (`field`,`subfield`,`index`,`ressource_type`) VALUES ";
    my $i = 0;
    for ( @$indexes ) {
        $i++;
        $query .= "('".$_->{'field'}."','".$_->{'subfield'}."','".$_->{'index'}."','".$ressource_type."')";
        $query .= "," unless $i eq scalar(@$indexes);
    }
    my $sth2 = $dbh->prepare($query);
    $sth2->execute();
}

sub GetMappings {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT * FROM indexmappings WHERE ressource_type = ? ORDER BY field, subfield");
    $sth->execute(shift);
    return $sth->fetchall_arrayref({});
}

sub GetIndexLabelFromCode {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT label FROM indexes WHERE code = ?");
    $sth->execute(shift);
    my $result = $sth->fetchrow_hashref;
    return $result->{'label'};
}

sub GetAvlistFromCode {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT avlist FROM indexes WHERE code = ?");
    $sth->execute(shift);
    my $result = $sth->fetchrow_hashref;
    return $result->{'avlist'};
}

my $hashindex_subfields;

sub GetSubfieldsForIndex {
    my $index = shift;
    return $hashindex_subfields->{$index} if exists ( $hashindex_subfields->{$index});

    my $dbh = C4::Context->dbh;
    my $query = "SELECT field, subfield FROM indexmappings WHERE `index` = ?";
    $query .= " ORDER BY field, subfield";
    my $sth = $dbh->prepare($query);
    $sth->execute($index);
    my $arrayref = $sth->fetchall_arrayref({});

    my $subfields;
    for ( @$arrayref ) {
        push @{ $subfields->{ $_->{'field'} } }, $_->{'subfield'};
    }
    $hashindex_subfields->{$index}=$subfields;

    return $subfields;
}

=head2 LoadSearchPlugin
Return the ComputeValue fonction associated with the plugin
=cut
sub LoadSearchPlugin {
    my $plugin = shift;
    my $list_of_plugins = shift;
    @$list_of_plugins = GetSearchPlugins() if not $list_of_plugins;
    my $r = 0;
    if ( grep( /^$plugin$/, @$list_of_plugins) ) {
        eval "require $plugin";

        return do {
            no strict 'refs';
            my $symbol = $plugin. "::ComputeValue";
            \&{"$symbol"};
        };
    }
}

=head2 LoadSearchPluginSrt
Return the ComputeSrtValue fonction associated with the plugin
=cut
sub LoadSearchPluginSrt {
    my $plugin = shift;
    my $list_of_plugins = shift;
    @$list_of_plugins = GetSearchPlugins() if not $list_of_plugins;
    my $r = 0;
    if ( grep( /^$plugin$/, @$list_of_plugins) ) {
        eval "require $plugin";

        return do {
            no strict 'refs';
            my $symbol = $plugin. "::ComputeSrtValue";
            \&{"$symbol"};
        };
    }
}

=head2 GetConcatMappingsValue
Return value returned by ConcatMappings function if it exists.
If it does not exist, return 0
=cut
sub GetConcatMappingsValue {
    my $plugin = shift;
    my $list_of_plugins = shift;
    $list_of_plugins = GetSearchPlugins() if not $list_of_plugins;
    my $r = 0;
    if ( grep( /^$plugin$/, @$list_of_plugins) ) {
        eval "require $plugin";

        no strict 'refs';
        my $symbol = $plugin. "::ConcatMappings";
        eval {
            $r = &{"$symbol"};
        };

        # If ConcatMappings does not exist, return 0
        if ($@) { return 0 }
    }
    $r;
}

=head2 GetSearchPlugins
Return list of existing plugins in C4/Search/Plugins
=cut
sub GetSearchPlugins {
   use Module::List;
   my $plugins = Module::List::list_modules( "C4::Search::Plugins::", { list_modules => 1 } );
   return keys %$plugins;
}

sub FillSubfieldWithAuthorisedValues {
    my ( $frameworkcode, $fieldcode, $subfieldcode, $value ) = @_;

    my $structure = C4::MarcFramework::GetSubfieldStructure( $fieldcode, $subfieldcode, $frameworkcode );

    given ( $structure->{'authorised_value'} ) {
        when( 'branches' ) {
            return GetBranchName( $value );
        }
        when( 'itemtypes' ) {
            my $itemtype = getitemtypeinfo( $value );
            return $itemtype->{'description'};
        }
        when( '' ) { return $value; }
        default {
            my $tmp = GetAuthorisedValueLib( $structure->{'authorised_value'}, $value );
            return $tmp if $tmp;
        }
    }
    return $value;
}

=head2 SimpleSearch

Search function for Solr Engine.

params: 
  $q           = solr's query
  $filters     = hashref (ex: {recordtype => 'biblio'}
                or {ste_author => ['knuth', 'pratt'] }
  $page        = page number for pagination
  $max_results = max returned results
  $sort        = field sorting

Before the call: 
  You must call normalSearch or buildQuery function et call SimpleSearch with the query returned

Examples:

  We have a simple query already constructed. We call normalSearch.
    my $query = "title=programming and author=knuth";
    $query = C4::Search::Query->normalSearch($query);
    my %filters = { recordtype => 'biblio' } # We find in biblios
    my $results = C4::Search::Engine::SimpleSearch($query, \%filters);
    
  We want hits number:
    my $hits = $$results{pager}{total_entries};
  
  print recordids:
    print $_->{'values'}->{'recordid'} for @{ $results->items };

  If we watn a adv search, we have 3 arrays : indexes, operands and operators
  We must call buildquery: 
  my @indexes = ("title", "author");
  my @operators = ("and");
  my @operands = ("programming", "knuth");
  my $query = C4::Search::Query->buildQuery(\@indexes, \@operands, \@operators);
  # Here $query = "txt_title=programming AND txt_author=knuth"
  my $results = C4::Search::Engine::SimpleSearch($query);

  If we call buildQuery without indexes, it call normalSearch with first operands (prabably contains the query):
  my @indexes = ();
  my @operators = ();
  my @operands = ("title=programming and author=knuth");
  my $query = C4::Search::Query->buildQuery(\@indexes, \@operands, \@operators);
  # Here $query = "txt_title=programming AND txt_author=knuth"
  my $results = C4::Search::Engine::SimpleSearch($query);

=cut

sub SimpleSearch {
    my ( $q, $filters, $page, $max_results, $sort) = @_;

    $q           ||= '*:*';
    $filters     ||= {};
    $page        ||= 1;
    $max_results ||= 999999999;
    $sort        ||= 'score desc';

    # sort is done on srt_* fields
    $sort =~ s/(^|,)\s*(str|txt|int|date|ste)_/$1srt_$2_/g;

    my $sc = GetSolrConnection;

    my $recordtype = ref($filters->{recordtype}) eq 'ARRAY'
                    ? $filters->{recordtype}[0]
                    : $filters->{recordtype}
                if defined $filters && defined $filters->{recordtype};
    $sc->options->{'facet'}          = 'true';
    $sc->options->{'facet.mincount'} = 1;
    $sc->options->{'facet.limit'}    = C4::Context->preference("numFacetsDisplay") || 10;
    $sc->options->{'facet.field'}    = GetFacetedIndexes($recordtype);
    $sc->options->{'sort'}           = $sort;

    # Construct filters
    $sc->options->{'fq'} = [
        map {
            my $idx = $_;
            ref($filters->{$idx}) eq 'ARRAY'
                ?
                    '('
                    . join( ' AND ',
                        map {
                            my $filter_str = $_;
                            utf8::decode($filter_str);
                            my $quotes_existed = ( $filter_str =~ m/^".*"$/ );
                            $filter_str =~ s/^"(.*)"$/$1/; #remove quote around value if exist
                            $filter_str =~ s/[^\\]\K"/\\"/g;
                            $filter_str = qq{"$filter_str"} # Add quote around value if not exist
                                if not $filter_str =~ /^".*"$/
                                    and $quotes_existed;
                            qq{$idx:$filter_str};
                        } @{ $filters->{$idx} } )
                    . ')'
                : "$idx:$filters->{$idx}";
        } keys %$filters
    ];

    utf8::decode($q);
    my $sq = Data::SearchEngine::Query->new(
        page  => $page,
        count => $max_results,
        query => $q,
    );

    # Get results
    my $result = eval { $sc->search( $sq ) };

    # Get error if exists
    if ( $@ ) {
        my $err = $@;

        warn $err;

        $err =~ s#^[^\n]*\n##; # Delete first line
        if ( not $err =~ 'Connection refused' ) {
            my $document = XMLin( $err );
            $err = "$$document{body}{h2} : $$document{body}{pre}";
        }
       $$result{error} = $err;
    }

    return $result; # if (ref($result) eq "Data::SearchEngine::Solr::Results");
}

=head2 AddRecordToIndexRecordQueue

Push recordids list in IndexRecordQueue if it launch
else call IndexRecord

=cut
sub AddRecordToIndexRecordQueue {
    my ( $recordtype, $recordids, $force_reindex ) = @_;

    my $scriptpath = C4::Context->config('intranetdir') . "/misc/solr/IndexRecordQueue.pl";

    my $status;

    if ( -e $scriptpath ) {
        my $max_itt = 10;
        while ( not defined $status and $max_itt > 0) {
            $status = qx#$scriptpath status#;
            sleep 0.5;
            $max_itt--;
        }
    }

    # Verify IndexRecordQueue.pl is started
    # Else call IndexRecord directly
    if ( not defined $status or not $status =~ /Running: *yes/ ) {
        return IndexRecord($recordtype, $recordids);
    }

    # Append recordtype recordids in file
    my $recordids_str = ref($recordids) eq 'ARRAY'
                    ? join " ", @$recordids
                    : $recordids;
    warn "Add Records To Queue: $recordtype, $recordids_str";
    system(qq/$scriptpath -a "$recordtype $recordids_str"/) == 0 or die "Could not indexing these biblionumbers : $recordids_str";

}

=head2 IndexRecord

Index all records with id in recordsids and recordtype=$recordtype ('biblio' or 'authority').

=cut
sub IndexRecord {
    my $recordtype = shift;
    my $recordids  = shift;
    my $debug = C4::Context->preference("DebugLevel");

    my $indexes = GetIndexes( $recordtype );
    my $sc      = GetSolrConnection;

    my @recordpush;
    my $g;

    my $recordids_str = ref($recordids) eq 'ARRAY'
                    ? join " ", @$recordids
                    : $recordids;
    warn "IndexRecord called with $recordtype $recordids_str";

    my @list_of_plugins = GetSearchPlugins;
    for my $id ( @$recordids ) {
        my $record;
        my $frameworkcode;
        my $recordid = "${recordtype}_$id";

        if ( $recordtype eq "authority" ) {
            $record = GetAuthority( $id );
        } elsif ( $recordtype eq "biblio" ) {
            $record = GetMarcBiblio( $id );
            $frameworkcode = GetFrameworkCode( $id );
        }

        next unless ( $record );

        my $solrrecord = Data::SearchEngine::Item->new(
            'id'    => $recordid,
            'score' => 1,
        );

        $solrrecord->set_value( 'recordtype', $recordtype );
        $solrrecord->set_value( 'recordid'  , $id );
        warn "Indexing $recordtype $id";

        for my $index ( @$indexes ) {
            eval {
                my @values;
                my @srt_values;
                my $mapping = GetSubfieldsForIndex( $index->{'code'} );
                my $concatmappings = 1;

                if ( $index->{'plugin'} ) {
                    $concatmappings = &GetConcatMappingsValue( $index->{'plugin'}, \@list_of_plugins );
                    my $plugin = LoadSearchPlugin( $index->{'plugin'}, \@list_of_plugins ) if $index->{'plugin'};

                    warn "Plugin $index->{plugin} no exists !" and next if not $plugin;

                    @values = &$plugin( $record, $mapping );

                    $plugin = LoadSearchPluginSrt( $index->{'plugin'}, \@list_of_plugins ) if $index->{'plugin'};
                    eval {
                        @srt_values = &$plugin( $record, $mapping );
                    };

                    if ($@) {
                        @srt_values = @values;
                    }

                }

                if ( $concatmappings ) {
                    for my $tag ( sort keys %$mapping ) {
                        for my $field ( $record->field( $tag ) ) {
                            if ( $field->is_control_field ) {
                                push @values, $field->data;
                            } else {

                                for my $code ( @{ $mapping->{$tag} } ) {

                                    my @sfvals = $code eq '*'
                                               ? map { $_->[1] } $field->subfields
                                               : map { $_      } $field->subfield( $code );

                                    for ( @sfvals ) {
                                        $_ = NormalizeDate( $_ ) if $index->{'type'} eq 'date';
                                        #$_ = FillSubfieldWithAuthorisedValues( $frameworkcode, $tag, $code, $_ ) if $recordtype eq "biblio";
                                        push @values, $_ if $_;
                                    }
                                }
                            }
                        }
                    }
                    if ( not $index->{plugin} ) {
                        @srt_values = @values;
                    }
                }
                @values = uniq (@values); #Removes duplicates

                $solrrecord->set_value(       $index->{'type'}."_".$index->{'code'},    \@values);
                if ($index->{'sortable'} and @srt_values > 0 and $index->{'code'}=~/title/){
                    $solrrecord->set_value("srt_".$index->{'type'}."_".$index->{'code'}, C4::Search::_remove_initial_stopwords($srt_values[0]));
                }
                elsif ($index->{'sortable'} and @srt_values > 0){
                    $solrrecord->set_value("srt_".$index->{'type'}."_".$index->{'code'}, $srt_values[0]);
                }

                # Add index str for facets if it's not exist
                if ( $index->{'faceted'} and @values > 0 and $index->{'type'} ne 'str' ) {
                    $solrrecord->set_value("str_".$index->{'code'}, $values[0]);
                }
            };
            if ( $@ ) {
                chomp $@;
                warn "Error during indexation : recordid $id, index $index->{'code'} ( $@ )";
            }
        }
        push @recordpush, $solrrecord;

        if ( @recordpush == 5000 ) {
            $debug eq '2' && print "id:".$id." ".`date`;
            if (defined $g) {
              $g->stop;
              $debug eq '2' && print "Building - ".$g->elapsed_str;
            }

            my $p = new Time::Progress;
            $p->restart;

            $sc->add( \@recordpush );
            @recordpush = ();

            $p->stop;
            $debug eq '2' && print "Indexing - ".$p->elapsed_str;

            $g = new Time::Progress;
            $g->restart;
        }
    }
    $sc->add( \@recordpush );
}

    
sub DeleteRecordIndex {
    my ( $recordtype, $id ) = @_;
    my $sc = GetSolrConnection;
    $sc->remove("id:${recordtype}_${id}", []);
}

sub NormalizeDate {
    my $date = shift;
    given( $date ) {
        when( /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/ ) {  return $date  }
        when( /^(\d{2}).(\d{2}).(\d{4})$/ ) { return "$3-$2-$1T00:00:00Z" }
        when( /^(\d{4}).(\d{2}).(\d{2})$/ ) { return "$1-$2-$3T00:00:00Z" }
        when( /^(\d{4}).(\d{2})$/         ) { return "$1-$2-01T00:00:00Z" }
        when( /^(\d{2}).(\d{4})$/         ) { return "$2-$1-01T00:00:00Z" }
        when( /^(\d{4})$/                 ) { return "$1-01-01T00:00:00Z" }
    }
    return undef;
}

sub buildDateOperand {
    my $operand = shift;
    $operand =~ s/\\:/:/g;
    $operand =~ s/^"(.*)"$/$1/; # Remove existing quote around date
    my $date = '"' . NormalizeDate($operand) . '"'
            if $operand
                and $operand ne '""' # FIX for rpn (harvestdate,alwaysMatches="")
                and not $operand =~ /\[.*TO.*\]/;
    $operand = $date if defined $date;

    return "[" . NormalizeDate($1) . " TO *]"
            if $operand =~ /\[(.*)\sTO\s\*\]/;
    return "[* TO " . NormalizeDate($1) . "]"
            if $operand =~ /\[\*\sTO\s(.*)\]/;
    return "[" . NormalizeDate($1) . " TO " . NormalizeDate($2) . "]"
            if $operand =~ /\[(.*)\sTO\s(.*)\]/;

    return $operand;
}

# overide add method in Data::SearchEngine::Solr to not use optimize function!
sub add {
    my ($self, $items, $options) = @_;

    my @docs;
    foreach my $item (@{ $items }) {
        my $doc = WebService::Solr::Document->new;
        $doc->add_fields(id => $item->id);

        foreach my $key ($item->keys) {
            my $val = $item->get_value($key);
            if(ref($val)) {
                foreach my $v (@{ $val }) {
                    $doc->add_fields($key => $v);
                }
            }  else {
                $doc->add_fields($key => $val);
            }
        }
        push(@docs, $doc);
    }

    $self->_solr->add(\@docs, $options);

}


1;
