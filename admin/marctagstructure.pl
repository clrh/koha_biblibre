#!/usr/bin/perl

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
use CGI;
use C4::Auth;
use C4::Koha;
use C4::Context;
use C4::Output;
use C4::Context;
use C4::MarcFramework;

# retrieve parameters
my $input                 = new CGI;
my $frameworkcode         = $input->param('frameworkcode') || '';           # set to select framework
my $existingframeworkcode = $input->param('existingframeworkcode') || '';
my $searchfield           = $input->param('searchfield') || 0;

# set when we have to create a new framework (in frameworkcode) by copying an old one (in existingframeworkcode)
my $frameworkinfo = getframeworkinfo($frameworkcode);
$searchfield =~ s/\,//g;

my $offset = $input->param('offset') || 0;
my $op     = $input->param('op')     || '';
my $dspchoice = $input->param('select_display');

my $script_name = "/cgi-bin/koha/admin/marctagstructure.pl";

my $dbh = C4::Context->dbh;

# open template
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => "admin/marctagstructure.tmpl",
        query           => $input,
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
    push @frameworkloop,
      { value         => $thisframeworkcode,
        selected      => ( $thisframeworkcode eq $frameworkcode ) ? 1 : 0,
        frameworktext => $frameworks->{$thisframeworkcode}->{'frameworktext'},
      };
}

# check that framework is defined in marc_tag_structure
unless ( C4::MarcFramework::TagStructureExists($frameworkcode) ) {

    # if frameworkcode does not exists, then OP must be changed to "create framework" if we are not on the way to create it
    # (op = itemtyp_create_confirm)
    if ( $op eq "framework_create_confirm" ) {
        C4::MarcFramework::DuplicateFramework( $frameworkcode, $existingframeworkcode );
        $op = "";    # unset $op to go back to framework list
    } else {
        $op = "framework_create";
    }
}
$template->param(
    frameworkloop => \@frameworkloop,
    frameworkcode => $frameworkcode,
    frameworktext => $frameworkinfo->{frameworktext},
    script_name   => $script_name,
    ( $op || 'else' ) => 1,
);

################## ADD_FORM ##################################
# called by default. Used to create form to add or  modify a record
if ( $op eq 'add_form' ) {

    #---- if primkey exists, it's a modify action, so read values to modify...
    my $data = C4::MarcFramework::GetTagStructure( $searchfield, $frameworkcode ) if $searchfield;

    my $sth = $dbh->prepare("select distinct category from authorised_values");
    $sth->execute;
    my @authorised_values;
    push @authorised_values, "";
    while ( ( my $category ) = $sth->fetchrow_array ) {
        push @authorised_values, $category;
    }
    my $authorised_value = CGI::scrolling_list(
        -name     => 'authorised_value',
        -values   => \@authorised_values,
        -size     => 1,
        -id       => "authorised_value",
        -multiple => 0,
        -default  => $data->{'authorised_value'},
    );

    if ($searchfield) {
        $template->param( searchfield            => $searchfield );
        $template->param( action                 => "Modify tag" );
        $template->param( 'heading-modify-tag-p' => 1 );
    } else {
        $template->param( action              => "Add tag" );
        $template->param( 'heading-add-tag-p' => 1 );
    }
    $template->param( 'use-heading-flags-p' => 1 );
    $template->param(
        liblibrarian => $data->{'liblibrarian'},
        libopac      => $data->{'libopac'},
        repeatable   => CGI::checkbox(
            -name    => 'repeatable',
            -checked => $data->{'repeatable'} ? 'checked' : '',
            -value   => 1,
            -label   => '',
            -id      => 'repeatable'
        ),
        mandatory => CGI::checkbox(
            -name    => 'mandatory',
            -checked => $data->{'mandatory'} ? 'checked' : '',
            -value   => 1,
            -label   => '',
            -id      => 'mandatory'
        ),
        authorised_value => $authorised_value,
        frameworkcode    => $frameworkcode,
    );    # FIXME: move checkboxes to presentation layer
          # END $OP eq ADD_FORM
################## ADD_VALIDATE ##################################
    # called by add_form, used to insert/modify data in DB
} elsif ( $op eq 'add_validate' ) {
    my $tagfield         = $input->param('tagfield');
    my $liblibrarian     = $input->param('liblibrarian');
    my $libopac          = $input->param('libopac');
    my $repeatable       = $input->param('repeatable') ? 1 : 0;
    my $mandatory        = $input->param('mandatory') ? 1 : 0;
    my $authorised_value = $input->param('authorised_value');
    unless ( C4::Context->config('demo') == 1 ) {
        if ( $input->param('modif') ) {
            C4::MarcFramework::ModTagStructure( $liblibrarian, $libopac, $repeatable, $mandatory, $authorised_value, $frameworkcode, $tagfield );
        } else {
            C4::MarcFramework::AddTagStructure( $tagfield, $liblibrarian, $libopac, $repeatable, $mandatory, $authorised_value, $frameworkcode );
        }
    }
    print $input->redirect("/cgi-bin/koha/admin/marctagstructure.pl?searchfield=$tagfield&frameworkcode=$frameworkcode");
    exit;

    # END $OP eq ADD_VALIDATE
################## DELETE_CONFIRM ##################################
    # called by default form, used to confirm deletion of data in DB
} elsif ( $op eq 'delete_confirm' ) {
    my $data = C4::MarcFramework::GetTagStructure( $searchfield, $frameworkcode );
    $template->param(
        liblibrarian  => $data->{'liblibrarian'},
        searchfield   => $searchfield,
        frameworkcode => $frameworkcode,
    );

    # END $OP eq DELETE_CONFIRM
################## DELETE_CONFIRMED ##################################
    # called by delete_confirm, used to effectively confirm deletion of data in DB
} elsif ( $op eq 'delete_confirmed' ) {
    unless ( C4::Context->config('demo') == 1 ) {
        C4::MarcFramework::DelTagStructure( $searchfield, $frameworkcode );
        C4::MarcFramework::DelSubfieldStructure( $searchfield, $frameworkcode );
    }
    $template->param(
        searchfield   => $searchfield,
        frameworkcode => $frameworkcode,
    );

    # END $OP eq DELETE_CONFIRMED
################## ITEMTYPE_CREATE ##################################
    # called automatically if an unexisting  frameworkis selected
} elsif ( $op eq 'framework_create' ) {
    $template->param(
        existingframeworkloop => C4::MarcFramework::GetExistingFrameworks,
        frameworkcode         => $frameworkcode,
    );
################## DEFAULT ##################################
} else {    # DEFAULT
            # here, $op can be unset or set to "framework_create_confirm".
    if ( $searchfield ne '' ) {
        $template->param( searchfield => $searchfield );
    }
    my $cnt = 0;
    if ($dspchoice) {

        #here, user only wants used tags/subfields displayed
        $searchfield =~ s/\'/\\\'/g;
        my @data = split( ' ', $searchfield );
        my $sth = $dbh->prepare( "
		      SELECT marc_tag_structure.tagfield AS mts_tagfield,
		              marc_tag_structure.liblibrarian as mts_liblibrarian,
		              marc_tag_structure.libopac as mts_libopac,
		              marc_tag_structure.repeatable as mts_repeatable,
		              marc_tag_structure.mandatory as mts_mandatory,
		              marc_tag_structure.authorised_value as mts_authorized_value,
		              marc_subfield_structure.*
                FROM marc_tag_structure 
                LEFT JOIN marc_subfield_structure ON (marc_tag_structure.tagfield=marc_subfield_structure.tagfield AND marc_tag_structure.frameworkcode=marc_subfield_structure.frameworkcode) WHERE (marc_tag_structure.tagfield >= ? and marc_tag_structure.frameworkcode=?) AND marc_subfield_structure.tab>=0 ORDER BY marc_tag_structure.tagfield,marc_subfield_structure.tagsubfield"
        );

        #could be ordoned by tab
        $sth->execute( $data[0], $frameworkcode );
        my @results = ();
        while ( my $data = $sth->fetchrow_hashref ) {
            push( @results, $data );
            $cnt++;
        }

        my @loop_data = ();
        my $j         = 1;
        my $i         = $offset;
        while ( $i < $cnt ) {
            my %row_data;    # get a fresh hash for the row data
            $row_data{tagfield}         = $results[$i]->{'mts_tagfield'};
            $row_data{liblibrarian}     = $results[$i]->{'mts_liblibrarian'};
            $row_data{repeatable}       = $results[$i]->{'mts_repeatable'};
            $row_data{mandatory}        = $results[$i]->{'mts_mandatory'};
            $row_data{authorised_value} = $results[$i]->{'mts_authorised_value'};
            $row_data{subfield_link}    = "marc_subfields_structure.pl?op=add_form&amp;tagfield=" . $results[$i]->{'mts_tagfield'} . "&amp;frameworkcode=" . $frameworkcode;
            $row_data{edit}             = "$script_name?op=add_form&amp;searchfield=" . $results[$i]->{'mts_tagfield'} . "&amp;frameworkcode=" . $frameworkcode;
            $row_data{delete}           = "$script_name?op=delete_confirm&amp;searchfield=" . $results[$i]->{'mts_tagfield'} . "&amp;frameworkcode=" . $frameworkcode;
            $j                          = $i;
            my @internal_loop = ();

            while ( ( $results[$i]->{'tagfield'} == $results[$j]->{'tagfield'} ) and ( $j < $cnt ) ) {
                my %subfield_data;
                $subfield_data{tagsubfield}      = $results[$j]->{'tagsubfield'};
                $subfield_data{liblibrarian}     = $results[$j]->{'liblibrarian'};
                $subfield_data{kohafield}        = $results[$j]->{'kohafield'};
                $subfield_data{repeatable}       = $results[$j]->{'repeatable'};
                $subfield_data{mandatory}        = $results[$j]->{'mandatory'};
                $subfield_data{tab}              = $results[$j]->{'tab'};
                $subfield_data{seealso}          = $results[$j]->{'seealso'};
                $subfield_data{authorised_value} = $results[$j]->{'authorised_value'};
                $subfield_data{authtypecode}     = $results[$j]->{'authtypecode'};
                $subfield_data{value_builder}    = $results[$j]->{'value_builder'};

                # 				warn "tagfield :  ".$results[$j]->{'tagfield'}." tagsubfield :".$results[$j]->{'tagsubfield'};
                push @internal_loop, \%subfield_data;
                $j++;
            }
            $row_data{'subfields'} = \@internal_loop;
            push( @loop_data, \%row_data );
            $i = $j;
        }
        $template->param(
            select_display => "True",
            loop           => \@loop_data
        );
    } else {

        #here, normal old style : display every tags
        my ( $count, $results ) = C4::MarcFramework::SearchTag( $searchfield, $frameworkcode );
        $cnt = $count;
        my @loop_data = ();
        for ( my $i = $offset ; $i < $count ; $i++ ) {
            my %row_data;    # get a fresh hash for the row data
            $row_data{tagfield}         = $results->[$i]{'tagfield'};
            $row_data{liblibrarian}     = $results->[$i]{'liblibrarian'};
            $row_data{repeatable}       = $results->[$i]{'repeatable'};
            $row_data{mandatory}        = $results->[$i]{'mandatory'};
            $row_data{authorised_value} = $results->[$i]{'authorised_value'};
            $row_data{subfield_link}    = "marc_subfields_structure.pl?tagfield=" . $results->[$i]{'tagfield'} . "&amp;frameworkcode=" . $frameworkcode;
            $row_data{edit}             = "$script_name?op=add_form&amp;searchfield=" . $results->[$i]{'tagfield'} . "&amp;frameworkcode=" . $frameworkcode;
            $row_data{delete}           = "$script_name?op=delete_confirm&amp;searchfield=" . $results->[$i]{'tagfield'} . "&amp;frameworkcode=" . $frameworkcode;
            push( @loop_data, \%row_data );
        }
        $template->param( loop => \@loop_data );
    }
    if ( $offset > 0 ) {
        $template->param(
            searchfield   => $searchfield,
            script_name   => $script_name,
            frameworkcode => $frameworkcode,
        );
    }
    if ( $offset < $cnt ) {
        $template->param(
            searchfield   => $searchfield,
            script_name   => $script_name,
            frameworkcode => $frameworkcode,
        );
    }
}    #---- END $OP eq DEFAULT

output_html_with_http_headers $input, $cookie, $template->output;

