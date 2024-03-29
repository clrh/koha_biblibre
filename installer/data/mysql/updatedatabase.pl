#!/usr/bin/perl

# Database Updater
# This script checks for required updates to the database.

# Part of the Koha Library Software www.koha.org
# Licensed under the GPL.

# Bugs/ToDo:
# - Would also be a good idea to offer to do a backup at this time...

# NOTE:  If you do something more than once in here, make it table driven.

# NOTE: Please keep the version in kohaversion.pl up-to-date!

use strict;
use warnings;

# CPAN modules
use DBI;
use Getopt::Long;

# Koha modules
use C4::Context;
use C4::Installer;

use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8' );

# FIXME - The user might be installing a new database, so can't rely
# on /etc/koha.conf anyway.

my $debug = 0;

my ($sth, $sti,
    $query,
    %existingtables,    # tables already in database
    %types,
    $table,
    $column,
    $type, $null, $key, $default, $extra,
    $prefitem,          # preference item in systempreferences table
);

my $silent;
GetOptions( 's' => \$silent );
my $dbh = C4::Context->dbh;
$| = 1;                 # flushes output

=item

    Deal with virtualshelves

=cut
my $compare_version=C4::Context->preference("Version");
my $DBversion = "3.00.00.001";

if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {

    # update virtualshelves table to
    #
    $dbh->do("ALTER TABLE `bookshelf` RENAME `virtualshelves`");
    $dbh->do("ALTER TABLE `shelfcontents` RENAME `virtualshelfcontents`");
    $dbh->do("ALTER TABLE `virtualshelfcontents` ADD `biblionumber` INT( 11 ) NOT NULL default '0' AFTER shelfnumber");
    $dbh->do("UPDATE `virtualshelfcontents` SET biblionumber=(SELECT biblionumber FROM items WHERE items.itemnumber=virtualshelfcontents.itemnumber)");

    # drop all foreign keys : otherwise, we can't drop itemnumber field.
    DropAllForeignKeys('virtualshelfcontents');
    $dbh->do("ALTER TABLE `virtualshelfcontents` ADD KEY biblionumber (biblionumber)");

    # create the new foreign keys (on biblionumber)
    $dbh->do(
"ALTER TABLE `virtualshelfcontents` ADD CONSTRAINT `virtualshelfcontents_ibfk_1` FOREIGN KEY (`shelfnumber`) REFERENCES `virtualshelves` (`shelfnumber`) ON DELETE CASCADE ON UPDATE CASCADE"
    );

    # re-create the foreign key on virtualshelf
    $dbh->do(
"ALTER TABLE `virtualshelfcontents` ADD CONSTRAINT `shelfcontents_ibfk_2` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`) ON DELETE CASCADE ON UPDATE CASCADE"
    );
    $dbh->do("ALTER TABLE `virtualshelfcontents` DROP `itemnumber`");
    print "Upgrade to $DBversion done (virtualshelves)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.002";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("DROP TABLE sessions");
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `sessions` (
  `id` varchar(32) NOT NULL,
  `a_session` text NOT NULL,
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
    );
    print "Upgrade to $DBversion done (sessions uses CGI::session, new table structure for sessions)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.003";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    if ( C4::Context->preference("opaclanguages") eq "fr" ) {
        $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ReservesNeedReturns','0','Si ce paramètre est mis à 1, une réservation posée sur un exemplaire présent sur le site devra être passée en retour pour être disponible. Sinon, elle sera automatiquement disponible, Koha considère que le bibliothécaire place la réservation en ayant le document en mains','','YesNo')"
        );
    } else {
        $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ReservesNeedReturns','0','If set, a reserve done on an item available in this branch need a check-in, otherwise, a reserve on a specific item, that is on the branch & available is considered as available','','YesNo')"
        );
    }
    print "Upgrade to $DBversion done (adding ReservesNeedReturns systempref, in circulation)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.004";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("INSERT IGNORE INTO `systempreferences` VALUES ('DebugLevel','2','set the level of error info sent to the browser. 0=none, 1=some, 2=most','0|1|2','Choice')");
    print "Upgrade to $DBversion done (adding DebugLevel systempref, in 'Admin' tab)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.005";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `tags` (
                    `entry` varchar(255) NOT NULL default '',
                    `weight` bigint(20) NOT NULL default 0,
                    PRIMARY KEY  (`entry`)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
                "
    );
    print "Upgrade to $DBversion done (adding tags table )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.006";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("UPDATE issues SET issuedate=timestamp WHERE issuedate='0000-00-00'");
    print "Upgrade to $DBversion done (filled issues.issuedate with timestamp)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.007";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SessionStorage','mysql','Use mysql or a temporary file for storing session data','mysql|tmp','Choice')"
    );
    print "Upgrade to $DBversion done (set SessionStorage variable)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.008";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `biblio` ADD `datecreated` DATE NOT NULL AFTER `timestamp` ;");
    $dbh->do("UPDATE biblio SET datecreated=timestamp");
    print "Upgrade to $DBversion done (biblio creation date)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.009";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {

    # Create backups of call number columns
    # in case default migration needs to be customized
    #
    # UPGRADE NOTE: temp_upg_biblioitems_call_num should be dropped
    #               after call numbers have been transformed to the new structure
    #
    # Not bothering to do the same with deletedbiblioitems -- assume
    # default is good enough.
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `temp_upg_biblioitems_call_num` AS
              SELECT `biblioitemnumber`, `biblionumber`,
                     `classification`, `dewey`, `subclass`,
                     `lcsort`, `ccode`
              FROM `biblioitems`"
    );

    # biblioitems changes
    $dbh->do(
        "ALTER TABLE `biblioitems` CHANGE COLUMN `volumeddesc` `volumedesc` TEXT,
                                    ADD `cn_source` VARCHAR(10) DEFAULT NULL AFTER `ccode`,
                                    ADD `cn_class` VARCHAR(30) DEFAULT NULL AFTER `cn_source`,
                                    ADD `cn_item` VARCHAR(10) DEFAULT NULL AFTER `cn_class`,
                                    ADD `cn_suffix` VARCHAR(10) DEFAULT NULL AFTER `cn_item`,
                                    ADD `cn_sort` VARCHAR(30) DEFAULT NULL AFTER `cn_suffix`,
                                    ADD `totalissues` INT(10) AFTER `cn_sort`"
    );

    # default mapping of call number columns:
    #   cn_class = concatentation of classification + dewey,
    #              trimmed to fit -- assumes that most users do not
    #              populate both classification and dewey in a single record
    #   cn_item  = subclass
    #   cn_source = left null
    #   cn_sort = lcsort
    #
    # After upgrade, cn_sort will have to be set based on whatever
    # default call number scheme user sets as a preference.  Misc
    # script will be added at some point to do that.
    #
    $dbh->do(
        "UPDATE `biblioitems`
              SET cn_class = SUBSTR(TRIM(CONCAT_WS(' ', `classification`, `dewey`)), 1, 30),
                    cn_item = subclass,
                    `cn_sort` = `lcsort`
            "
    );

    # Now drop the old call number columns
    $dbh->do(
        "ALTER TABLE `biblioitems` DROP COLUMN `classification`,
                                        DROP COLUMN `dewey`,
                                        DROP COLUMN `subclass`,
                                        DROP COLUMN `lcsort`,
                                        DROP COLUMN `ccode`"
    );

    # deletedbiblio changes
    $dbh->do(
        "ALTER TABLE `deletedbiblio` ALTER COLUMN `frameworkcode` SET DEFAULT '',
                                        DROP COLUMN `marc`,
                                        ADD `datecreated` DATE NOT NULL AFTER `timestamp`"
    );
    $dbh->do("UPDATE deletedbiblio SET datecreated = timestamp");

    # deletedbiblioitems changes
    $dbh->do(
        "ALTER TABLE `deletedbiblioitems`
                        MODIFY `publicationyear` TEXT,
                        CHANGE `volumeddesc` `volumedesc` TEXT,
                        MODIFY `collectiontitle` MEDIUMTEXT DEFAULT NULL AFTER `volumedesc`,
                        MODIFY `collectionissn` TEXT DEFAULT NULL AFTER `collectiontitle`,
                        MODIFY `collectionvolume` MEDIUMTEXT DEFAULT NULL AFTER `collectionissn`,
                        MODIFY `editionstatement` TEXT DEFAULT NULL AFTER `collectionvolume`,
                        MODIFY `editionresponsibility` TEXT DEFAULT NULL AFTER `editionstatement`,
                        MODIFY `place` VARCHAR(255) DEFAULT NULL AFTER `size`,
                        MODIFY `marc` LONGBLOB,
                        ADD `cn_source` VARCHAR(10) DEFAULT NULL AFTER `url`,
                        ADD `cn_class` VARCHAR(30) DEFAULT NULL AFTER `cn_source`,
                        ADD `cn_item` VARCHAR(10) DEFAULT NULL AFTER `cn_class`,
                        ADD `cn_suffix` VARCHAR(10) DEFAULT NULL AFTER `cn_item`,
                        ADD `cn_sort` VARCHAR(30) DEFAULT NULL AFTER `cn_suffix`,
                        ADD `totalissues` INT(10) AFTER `cn_sort`,
                        ADD `marcxml` LONGTEXT NOT NULL AFTER `totalissues`,
                        ADD KEY `isbn` (`isbn`),
                        ADD KEY `publishercode` (`publishercode`)
                    "
    );

    $dbh->do(
        "UPDATE `deletedbiblioitems`
                SET `cn_class` = SUBSTR(TRIM(CONCAT_WS(' ', `classification`, `dewey`)), 1, 30),
               `cn_item` = `subclass`,
                `cn_sort` = `lcsort`
            "
    );
    $dbh->do(
        "ALTER TABLE `deletedbiblioitems`
                        DROP COLUMN `classification`,
                        DROP COLUMN `dewey`,
                        DROP COLUMN `subclass`,
                        DROP COLUMN `lcsort`,
                        DROP COLUMN `ccode`
            "
    );

    # deleteditems changes
    $dbh->do(
        "ALTER TABLE `deleteditems`
                        MODIFY `barcode` VARCHAR(20) DEFAULT NULL,
                        MODIFY `price` DECIMAL(8,2) DEFAULT NULL,
                        MODIFY `replacementprice` DECIMAL(8,2) DEFAULT NULL,
                        DROP `bulk`,
                        MODIFY `itemcallnumber` VARCHAR(30) DEFAULT NULL AFTER `wthdrawn`,
                        MODIFY `holdingbranch` VARCHAR(10) DEFAULT NULL,
                        DROP `interim`,
                        MODIFY `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP AFTER `paidfor`,
                        DROP `cutterextra`,
                        ADD `cn_source` VARCHAR(10) DEFAULT NULL AFTER `onloan`,
                        ADD `cn_sort` VARCHAR(30) DEFAULT NULL AFTER `cn_source`,
                        ADD `ccode` VARCHAR(10) DEFAULT NULL AFTER `cn_sort`,
                        ADD `materials` VARCHAR(10) DEFAULT NULL AFTER `ccode`,
                        ADD `uri` VARCHAR(255) DEFAULT NULL AFTER `materials`,
                        MODIFY `marc` LONGBLOB AFTER `uri`,
                        DROP KEY `barcode`,
                        DROP KEY `itembarcodeidx`,
                        DROP KEY `itembinoidx`,
                        DROP KEY `itembibnoidx`,
                        ADD UNIQUE KEY `delitembarcodeidx` (`barcode`),
                        ADD KEY `delitembinoidx` (`biblioitemnumber`),
                        ADD KEY `delitembibnoidx` (`biblionumber`),
                        ADD KEY `delhomebranch` (`homebranch`),
                        ADD KEY `delholdingbranch` (`holdingbranch`)"
    );
    $dbh->do("UPDATE deleteditems SET `ccode` = `itype`");
    $dbh->do("ALTER TABLE deleteditems DROP `itype`");
    $dbh->do("UPDATE `deleteditems` SET `cn_sort` = `itemcallnumber`");

    # items changes
    $dbh->do(
        "ALTER TABLE `items` ADD `cn_source` VARCHAR(10) DEFAULT NULL AFTER `onloan`,
                                ADD `cn_sort` VARCHAR(30) DEFAULT NULL AFTER `cn_source`,
                                ADD `ccode` VARCHAR(10) DEFAULT NULL AFTER `cn_sort`,
                                ADD `materials` VARCHAR(10) DEFAULT NULL AFTER `ccode`,
                                ADD `uri` VARCHAR(255) DEFAULT NULL AFTER `materials`
            "
    );
    $dbh->do(
        "ALTER TABLE `items`
                        DROP KEY `itembarcodeidx`,
                        ADD UNIQUE KEY `itembarcodeidx` (`barcode`)"
    );

    # map items.itype to items.ccode and
    # set cn_sort to itemcallnumber -- as with biblioitems.cn_sort,
    # will have to be subsequently updated per user's default
    # classification scheme
    $dbh->do(
        "UPDATE `items` SET `cn_sort` = `itemcallnumber`,
                            `ccode` = `itype`"
    );

    $dbh->do(
        "ALTER TABLE `items` DROP `cutterextra`,
                                DROP `itype`"
    );

    print "Upgrade to $DBversion done (major changes to biblio, biblioitems, items, and deleted* versions of same\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.010";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("CREATE INDEX `userid` ON borrowers (`userid`) ");
    print "Upgrade to $DBversion done (userid index added)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.011";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `branchcategories` CHANGE `categorycode` `categorycode` varchar(10) ");
    $dbh->do("ALTER TABLE `branchcategories` CHANGE `categoryname` `categoryname` varchar(32) ");
    $dbh->do("ALTER TABLE `branchcategories` ADD COLUMN `categorytype` varchar(16) ");
    $dbh->do("UPDATE `branchcategories` SET `categorytype` = 'properties'");
    $dbh->do("ALTER TABLE `branchrelations` CHANGE `categorycode` `categorycode` varchar(10) ");
    print "Upgrade to $DBversion done (added branchcategory type)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.012";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `class_sort_rules` (
                               `class_sort_rule` varchar(10) NOT NULL default '',
                               `description` mediumtext,
                               `sort_routine` varchar(30) NOT NULL default '',
                               PRIMARY KEY (`class_sort_rule`),
                               UNIQUE KEY `class_sort_rule_idx` (`class_sort_rule`)
                             ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `class_sources` (
                               `cn_source` varchar(10) NOT NULL default '',
                               `description` mediumtext,
                               `used` tinyint(4) NOT NULL default 0,
                               `class_sort_rule` varchar(10) NOT NULL default '',
                               PRIMARY KEY (`cn_source`),
                               UNIQUE KEY `cn_source_idx` (`cn_source`),
                               KEY `used_idx` (`used`),
                               CONSTRAINT `class_source_ibfk_1` FOREIGN KEY (`class_sort_rule`)
                                          REFERENCES `class_sort_rules` (`class_sort_rule`)
                             ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type)
              VALUES('DefaultClassificationSource','ddc',
                     'Default classification scheme used by the collection. E.g., Dewey, LCC, etc.', NULL,'free')"
    );
    $dbh->do(
        "INSERT IGNORE INTO `class_sort_rules` (`class_sort_rule`, `description`, `sort_routine`) VALUES
                               ('dewey', 'Default filing rules for DDC', 'Dewey'),
                               ('lcc', 'Default filing rules for LCC', 'LCC'),
                               ('generic', 'Generic call number filing rules', 'Generic')"
    );
    $dbh->do(
        "INSERT IGNORE INTO `class_sources` (`cn_source`, `description`, `used`, `class_sort_rule`) VALUES
                            ('ddc', 'Dewey Decimal Classification', 1, 'dewey'),
                            ('lcc', 'Library of Congress Classification', 1, 'lcc'),
                            ('udc', 'Universal Decimal Classification', 0, 'generic'),
                            ('sudocs', 'SuDoc Classification (U.S. GPO)', 0, 'generic'),
                            ('z', 'Other/Generic Classification Scheme', 0, 'generic')"
    );
    print "Upgrade to $DBversion done (classification sources added)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.013";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `import_batches` (
              `import_batch_id` int(11) NOT NULL auto_increment,
              `template_id` int(11) default NULL,
              `branchcode` varchar(10) default NULL,
              `num_biblios` int(11) NOT NULL default 0,
              `num_items` int(11) NOT NULL default 0,
              `upload_timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP,
              `overlay_action` enum('replace', 'create_new', 'use_template') NOT NULL default 'create_new',
              `import_status` enum('staging', 'staged', 'importing', 'imported', 'reverting', 'reverted', 'cleaned') NOT NULL default 'staging',
              `batch_type` enum('batch', 'z3950') NOT NULL default 'batch',
              `file_name` varchar(100),
              `comments` mediumtext,
              PRIMARY KEY (`import_batch_id`),
              KEY `branchcode` (`branchcode`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `import_records` (
              `import_record_id` int(11) NOT NULL auto_increment,
              `import_batch_id` int(11) NOT NULL,
              `branchcode` varchar(10) default NULL,
              `record_sequence` int(11) NOT NULL default 0,
              `upload_timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP,
              `import_date` DATE default NULL,
              `marc` longblob NOT NULL,
              `marcxml` longtext NOT NULL,
              `marcxml_old` longtext NOT NULL,
              `record_type` enum('biblio', 'auth', 'holdings') NOT NULL default 'biblio',
              `overlay_status` enum('no_match', 'auto_match', 'manual_match', 'match_applied') NOT NULL default 'no_match',
              `status` enum('error', 'staged', 'imported', 'reverted', 'items_reverted') NOT NULL default 'staged',
              `import_error` mediumtext,
              `encoding` varchar(40) NOT NULL default '',
              `z3950random` varchar(40) default NULL,
              PRIMARY KEY (`import_record_id`),
              CONSTRAINT `import_records_ifbk_1` FOREIGN KEY (`import_batch_id`)
                          REFERENCES `import_batches` (`import_batch_id`) ON DELETE CASCADE ON UPDATE CASCADE,
              KEY `branchcode` (`branchcode`),
              KEY `batch_sequence` (`import_batch_id`, `record_sequence`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `import_record_matches` (
              `import_record_id` int(11) NOT NULL,
              `candidate_match_id` int(11) NOT NULL,
              `score` int(11) NOT NULL default 0,
              CONSTRAINT `import_record_matches_ibfk_1` FOREIGN KEY (`import_record_id`)
                          REFERENCES `import_records` (`import_record_id`) ON DELETE CASCADE ON UPDATE CASCADE,
              KEY `record_score` (`import_record_id`, `score`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `import_biblios` (
              `import_record_id` int(11) NOT NULL,
              `matched_biblionumber` int(11) default NULL,
              `control_number` varchar(25) default NULL,
              `original_source` varchar(25) default NULL,
              `title` varchar(128) default NULL,
              `author` varchar(80) default NULL,
              `isbn` varchar(14) default NULL,
              `issn` varchar(9) default NULL,
              `has_items` tinyint(1) NOT NULL default 0,
              CONSTRAINT `import_biblios_ibfk_1` FOREIGN KEY (`import_record_id`)
                          REFERENCES `import_records` (`import_record_id`) ON DELETE CASCADE ON UPDATE CASCADE,
              KEY `matched_biblionumber` (`matched_biblionumber`),
              KEY `title` (`title`),
              KEY `isbn` (`isbn`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `import_items` (
              `import_items_id` int(11) NOT NULL auto_increment,
              `import_record_id` int(11) NOT NULL,
              `itemnumber` int(11) default NULL,
              `branchcode` varchar(10) default NULL,
              `status` enum('error', 'staged', 'imported', 'reverted') NOT NULL default 'staged',
              `marcxml` longtext NOT NULL,
              `import_error` mediumtext,
              PRIMARY KEY (`import_items_id`),
              CONSTRAINT `import_items_ibfk_1` FOREIGN KEY (`import_record_id`)
                          REFERENCES `import_records` (`import_record_id`) ON DELETE CASCADE ON UPDATE CASCADE,
              KEY `itemnumber` (`itemnumber`),
              KEY `branchcode` (`branchcode`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );

    $dbh->do(
        "INSERT IGNORE INTO `import_batches`
                (`overlay_action`, `import_status`, `batch_type`, `file_name`)
              SELECT distinct 'create_new', 'staged', 'z3950', `file`
              FROM   `marc_breeding`"
    );

    $dbh->do(
        "INSERT IGNORE INTO `import_records`
                (`import_batch_id`, `import_record_id`, `record_sequence`, `marc`, `record_type`, `status`,
                `encoding`, `z3950random`, `marcxml`, `marcxml_old`)
              SELECT `import_batch_id`, `id`, 1, `marc`, 'biblio', 'staged', `encoding`, `z3950random`, '', ''
              FROM `marc_breeding`
              JOIN `import_batches` ON (`file_name` = `file`)"
    );

    $dbh->do(
        "INSERT IGNORE INTO `import_biblios`
                (`import_record_id`, `title`, `author`, `isbn`)
              SELECT `import_record_id`, `title`, `author`, `isbn`
              FROM   `marc_breeding`
              JOIN   `import_records` ON (`import_record_id` = `id`)"
    );

    $dbh->do(
        "UPDATE `import_batches`
              SET `num_biblios` = (
              SELECT COUNT(*)
              FROM `import_records`
              WHERE `import_batch_id` = `import_batches`.`import_batch_id`
              )"
    );

    $dbh->do("DROP TABLE `marc_breeding`");

    print "Upgrade to $DBversion done (import_batches et al. added)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.014";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE subscription ADD lastbranch VARCHAR(4)");
    print "Upgrade to $DBversion done (userid index added)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.015";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `saved_sql` (
           `id` int(11) NOT NULL auto_increment,
           `borrowernumber` int(11) default NULL,
           `date_created` datetime default NULL,
           `last_modified` datetime default NULL,
           `savedsql` text,
           `last_run` datetime default NULL,
           `report_name` varchar(255) default NULL,
           `type` varchar(255) default NULL,
           `notes` text,
           PRIMARY KEY  (`id`),
           KEY boridx (`borrowernumber`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `saved_reports` (
           `id` int(11) NOT NULL auto_increment,
           `report_id` int(11) default NULL,
           `report` longtext,
           `date_run` datetime default NULL,
           PRIMARY KEY  (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
    );
    print "Upgrade to $DBversion done (saved_sql and saved_reports added)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.016";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        " CREATE TABLE IF NOT EXISTS reports_dictionary (
          id int(11) NOT NULL auto_increment,
          name varchar(255) default NULL,
          description text,
          date_created datetime default NULL,
          date_modified datetime default NULL,
          saved_sql text,
          area int(11) default NULL,
          PRIMARY KEY  (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 "
    );
    print "Upgrade to $DBversion done (reports_dictionary) added)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.017";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE action_logs DROP PRIMARY KEY");
    $dbh->do("ALTER TABLE action_logs ADD KEY  timestamp (timestamp,user)");
    $dbh->do("ALTER TABLE action_logs ADD action_id INT(11) NOT NULL FIRST");
    $dbh->do("UPDATE action_logs SET action_id = if (\@a, \@a:=\@a+1, \@a:=1)");
    $dbh->do("ALTER TABLE action_logs MODIFY action_id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY");
    print "Upgrade to $DBversion done (added column to action_logs)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.019";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE biblio MODIFY biblionumber INT(11) NOT NULL AUTO_INCREMENT");
    $dbh->do("ALTER TABLE biblioitems MODIFY biblioitemnumber INT(11) NOT NULL AUTO_INCREMENT");
    $dbh->do("ALTER TABLE items MODIFY itemnumber INT(11) NOT NULL AUTO_INCREMENT");
    print "Upgrade to $DBversion done (made bib/item PKs auto_increment)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.020";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "ALTER TABLE deleteditems
              DROP KEY `delitembarcodeidx`,
              ADD KEY `delitembarcodeidx` (`barcode`)"
    );
    print "Upgrade to $DBversion done (dropped uniqueness of key on deleteditems.barcode)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.021";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE items CHANGE homebranch homebranch VARCHAR(10)");
    $dbh->do("ALTER TABLE deleteditems CHANGE homebranch homebranch VARCHAR(10)");
    $dbh->do("ALTER TABLE statistics CHANGE branch branch VARCHAR(10)");
    $dbh->do("ALTER TABLE subscription CHANGE lastbranch lastbranch VARCHAR(10)");
    print "Upgrade to $DBversion done (extended missed branchcode columns to 10 chars)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.022";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "ALTER TABLE items
                ADD `damaged` tinyint(1) default NULL AFTER notforloan"
    );
    $dbh->do(
        "ALTER TABLE deleteditems
                ADD `damaged` tinyint(1) default NULL AFTER notforloan"
    );
    print "Upgrade to $DBversion done (adding damaged column to items table)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.023";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type)
         VALUES ('yuipath','http://yui.yahooapis.com/2.3.1/build','Insert the path to YUI libraries','','free')"
    );
    print "Upgrade to $DBversion done (adding new system preference for controlling YUI path)\n";
    SetVersion($DBversion);
}
$DBversion = "3.00.00.024";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE biblioitems CHANGE  itemtype itemtype VARCHAR(10)");
    print "Upgrade to $DBversion done (changing itemtype to (10))\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.025";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE items ADD COLUMN itype VARCHAR(10)");
    $dbh->do("ALTER TABLE deleteditems ADD COLUMN itype VARCHAR(10) AFTER uri");
    if ( C4::Context->preference('item-level_itypes') ) {
        $dbh->do('update items,biblioitems set items.itype=biblioitems.itemtype where items.biblionumber=biblioitems.biblionumber and itype is null');
    }
    print "Upgrade to $DBversion done (reintroduce items.itype - fill from itemtype)\n ";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.026";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('HomeOrHoldingBranch','homebranch','homebranch|holdingbranch','With independent branches turned on this decides whether to check the items holdingbranch or homebranch at circulatilon','choice')"
    );
    print "Upgrade to $DBversion done (adding new system preference for choosing whether homebranch or holdingbranch is checked in circulation)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.027";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `marc_matchers` (
                `matcher_id` int(11) NOT NULL auto_increment,
                `code` varchar(10) NOT NULL default '',
                `description` varchar(255) NOT NULL default '',
                `record_type` varchar(10) NOT NULL default 'biblio',
                `threshold` int(11) NOT NULL default 0,
                PRIMARY KEY (`matcher_id`),
                KEY `code` (`code`),
                KEY `record_type` (`record_type`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `matchpoints` (
                `matcher_id` int(11) NOT NULL,
                `matchpoint_id` int(11) NOT NULL auto_increment,
                `search_index` varchar(30) NOT NULL default '',
                `score` int(11) NOT NULL default 0,
                PRIMARY KEY (`matchpoint_id`),
                CONSTRAINT `matchpoints_ifbk_1` FOREIGN KEY (`matcher_id`)
                           REFERENCES `marc_matchers` (`matcher_id`) ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `matchpoint_components` (
                `matchpoint_id` int(11) NOT NULL,
                `matchpoint_component_id` int(11) NOT NULL auto_increment,
                sequence int(11) NOT NULL default 0,
                tag varchar(3) NOT NULL default '',
                subfields varchar(40) NOT NULL default '',
                offset int(4) NOT NULL default 0,
                length int(4) NOT NULL default 0,
                PRIMARY KEY (`matchpoint_component_id`),
                KEY `by_sequence` (`matchpoint_id`, `sequence`),
                CONSTRAINT `matchpoint_components_ifbk_1` FOREIGN KEY (`matchpoint_id`)
                           REFERENCES `matchpoints` (`matchpoint_id`) ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `matchpoint_component_norms` (
                `matchpoint_component_id` int(11) NOT NULL,
                `sequence`  int(11) NOT NULL default 0,
                `norm_routine` varchar(50) NOT NULL default '',
                KEY `matchpoint_component_norms` (`matchpoint_component_id`, `sequence`),
                CONSTRAINT `matchpoint_component_norms_ifbk_1` FOREIGN KEY (`matchpoint_component_id`)
                           REFERENCES `matchpoint_components` (`matchpoint_component_id`) ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `matcher_matchpoints` (
                `matcher_id` int(11) NOT NULL,
                `matchpoint_id` int(11) NOT NULL,
                CONSTRAINT `matcher_matchpoints_ifbk_1` FOREIGN KEY (`matcher_id`)
                           REFERENCES `marc_matchers` (`matcher_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `matcher_matchpoints_ifbk_2` FOREIGN KEY (`matchpoint_id`)
                           REFERENCES `matchpoints` (`matchpoint_id`) ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `matchchecks` (
                `matcher_id` int(11) NOT NULL,
                `matchcheck_id` int(11) NOT NULL auto_increment,
                `source_matchpoint_id` int(11) NOT NULL,
                `target_matchpoint_id` int(11) NOT NULL,
                PRIMARY KEY (`matchcheck_id`),
                CONSTRAINT `matcher_matchchecks_ifbk_1` FOREIGN KEY (`matcher_id`)
                           REFERENCES `marc_matchers` (`matcher_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `matcher_matchchecks_ifbk_2` FOREIGN KEY (`source_matchpoint_id`)
                           REFERENCES `matchpoints` (`matchpoint_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `matcher_matchchecks_ifbk_3` FOREIGN KEY (`target_matchpoint_id`)
                           REFERENCES `matchpoints` (`matchpoint_id`) ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    print "Upgrade to $DBversion done (added C4::Matcher serialization tables)\n ";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.028";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('canreservefromotherbranches','1','','With Independent branches on, can a user from one library reserve an item from another library','YesNo')"
    );
    print "Upgrade to $DBversion done (adding new system preference for changing reserve/holds behaviour with independent branches)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.029";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `import_batches` ADD `matcher_id` int(11) NULL AFTER `import_batch_id`");
    print "Upgrade to $DBversion done (adding matcher_id to import_batches)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.030";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do( "
CREATE TABLE IF NOT EXISTS services_throttle (
  service_type varchar(10) NOT NULL default '',
  service_count varchar(45) default NULL,
  PRIMARY KEY  (service_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
" );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('FRBRizeEditions',0,'','If ON, Koha will query one or more ISBN web services for associated ISBNs and display an Editions tab on the details pages','YesNo')"
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('XISBN',0,'','Use with FRBRizeEditions. If ON, Koha will use the OCLC xISBN web service in the Editions tab on the detail pages. See: http://www.worldcat.org/affiliate/webservices/xisbn/app.jsp','YesNo')"
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('OCLCAffiliateID','','','Use with FRBRizeEditions and XISBN. You can sign up for an AffiliateID here: http://www.worldcat.org/wcpa/do/AffiliateUserServices?method=initSelfRegister','free')"
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('XISBNDailyLimit',499,'','The xISBN Web service is free for non-commercial use when usage does not exceed 500 requests per day','free')"
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('PINESISBN',0,'','Use with FRBRizeEditions. If ON, Koha will use PINES OISBN web service in the Editions tab on the detail pages.','YesNo')"
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('ThingISBN',0,'','Use with FRBRizeEditions. If ON, Koha will use the ThingISBN web service in the Editions tab on the detail pages.','YesNo')"
    );
    print "Upgrade to $DBversion done (adding services throttle table and sysprefs for xISBN)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.031";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {

    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('QueryStemming',1,'If ON, enables query stemming',NULL,'YesNo')");
    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('QueryFuzzy',1,'If ON, enables fuzzy option for searches',NULL,'YesNo')");
    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('QueryWeightFields',1,'If ON, enables field weighting',NULL,'YesNo')");
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('WebBasedSelfCheck',0,'If ON, enables the web-based self-check system',NULL,'YesNo')");
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('numSearchResults',20,'Specify the maximum number of results to display on a page of results',NULL,'free')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACnumSearchResults',20,'Specify the maximum number of results to display on a page of results',NULL,'free')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('maxItemsInSearchResults',20,'Specify the maximum number of items to display for each result on a page of results',NULL,'free')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('defaultSortField',NULL,'Specify the default field used for sorting','relevance|popularity|call_number|pubdate|acqdate|title|author','Choice')"
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('defaultSortOrder',NULL,'Specify the default sort order','asc|dsc|az|za','Choice')");
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACdefaultSortField',NULL,'Specify the default field used for sorting','relevance|popularity|call_number|pubdate|acqdate|title|author','Choice')"
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACdefaultSortOrder',NULL,'Specify the default sort order','asc|dsc|za|az','Choice')"
    );
    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('staffClientBaseURL','','Specify the base URL of the staff client',NULL,'free')");
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('minPasswordLength',3,'Specify the minimum length of a patron/staff password',NULL,'free')"
    );
    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('noItemTypeImages',0,'If ON, disables item-type images',NULL,'YesNo')");
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('emailLibrarianWhenHoldIsPlaced',0,'If ON, emails the librarian whenever a hold is placed',NULL,'YesNo')"
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('holdCancelLength','','Specify how many days before a hold is canceled',NULL,'free')");
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('libraryAddress','','The address to use for printing receipts, overdues, etc. if different than physical address',NULL,'free')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('finesMode','test','Choose the fines mode, test or production','test|production','Choice')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('globalDueDate','','If set, allows a global static due date for all checkouts',NULL,'free')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('itemBarcodeInputFilter','','If set, allows specification of a item barcode input filter','cuecat','Choice')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('singleBranchMode',0,'Operate in Single-branch mode, hide branch selection in the OPAC',NULL,'YesNo')"
    );
    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('URLLinkText','','Text to display as the link anchor in the OPAC',NULL,'free')");
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACSubscriptionDisplay','economical','Specify how to display subscription information in the OPAC','economical|off|full','Choice')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACDisplayExtendedSubInfo',1,'If ON, extended subscription information is displayed in the OPAC',NULL,'YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACViewOthersSuggestions',0,'If ON, allows all suggestions to be displayed in the OPAC',NULL,'YesNo')"
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACURLOpenInNewWindow',0,'If ON, URLs in the OPAC open in a new window',NULL,'YesNo')"
    );
    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACUserCSS',0,'Add CSS to be included in the OPAC',NULL,'free')");

    print "Upgrade to $DBversion done (adding additional system preference)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.032";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("UPDATE `marc_subfield_structure` SET `kohafield` = 'items.wthdrawn' WHERE `kohafield` = 'items.withdrawn'");
    print "Upgrade to $DBversion done (fixed MARC framework references to items.withdrawn)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.033";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("INSERT IGNORE INTO `userflags` VALUES(17,'staffaccess','Modify login / permissions for staff users',0)");
    print "Upgrade to $DBversion done (Adding permissions flag for staff member access modification.  )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.034";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `virtualshelves` ADD COLUMN `sortfield` VARCHAR(16) ");
    print "Upgrade to $DBversion done (Adding sortfield for Virtual Shelves.  )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.035";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "UPDATE marc_subfield_structure
              SET authorised_value = 'cn_source'
              WHERE kohafield IN ('items.cn_source', 'biblioitems.cn_source')
              AND (authorised_value is NULL OR authorised_value = '')"
    );
    print "Upgrade to $DBversion done (MARC frameworks: make classification source a drop-down)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.036";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACItemsResultsDisplay','statuses','statuses : show only the status of items in result list. itemdisplay : show full location of items (branch+location+callnumber) as in staff interface','statuses|itemdetails','Choice');"
    );
    print "Upgrade to $DBversion done (OPACItemsResultsDisplay systempreference added)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.037";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactfirstname` varchar(255)");
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactsurname` varchar(255)");
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactaddress1` varchar(255)");
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactaddress2` varchar(255)");
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactaddress3` varchar(255)");
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactzipcode` varchar(50)");
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactphone` varchar(50)");
    print "Upgrade to $DBversion done (Adding Alternative Contact Person information to borrowers table)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.038";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"UPDATE `systempreferences` set explanation='Choose the fines mode, off, test (emails admin report) or production (accrue overdue fines).  Requires fines cron script' , options='off|test|production' where variable='finesMode'"
    );
    $dbh->do("DELETE FROM `systempreferences` WHERE variable='hideBiblioNumber'");
    print "Upgrade to $DBversion done ('alter finesMode systempreference, remove superfluous syspref.')\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.039";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('uppercasesurnames',0,'If ON, surnames are converted to upper case in patron entry form',NULL,'YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('CircControl','ItemHomeLibrary','Specify the agency that controls the circulation and fines policy','PickupLibrary|PatronLibrary|ItemHomeLibrary','Choice')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('finesCalendar','noFinesWhenClosed','Specify whether to use the Calendar in calculating duedates and fines','ignoreCalendar|noFinesWhenClosed','Choice')"
    );

    # $dbh->do("DELETE FROM `systempreferences` WHERE variable='HomeOrHoldingBranch'"); # Bug #2752
    print "Upgrade to $DBversion done ('add circ sysprefs CircControl, finesCalendar, and uppercasesurnames, and delete HomeOrHoldingBranch.')\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.040";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('previousIssuesDefaultSortOrder','asc','Specify the sort order of Previous Issues on the circulation page','asc|desc','Choice')"
    );
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('todaysIssuesDefaultSortOrder','desc','Specify the sort order of Todays Issues on the circulation page','asc|desc','Choice')"
    );
    print "Upgrade to $DBversion done ('add circ sysprefs todaysIssuesDefaultSortOrder and previousIssuesDefaultSortOrder.')\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.041";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {

    # Strictly speaking it is not necessary to explicitly change
    # NULL values to 0, because the ALTER TABLE statement will do that.
    # However, setting them first avoids a warning.
    $dbh->do("UPDATE items SET notforloan = 0 WHERE notforloan IS NULL");
    $dbh->do("UPDATE items SET damaged = 0 WHERE damaged IS NULL");
    $dbh->do("UPDATE items SET itemlost = 0 WHERE itemlost IS NULL");
    $dbh->do("UPDATE items SET wthdrawn = 0 WHERE wthdrawn IS NULL");
    $dbh->do(
        "ALTER TABLE items
                MODIFY notforloan tinyint(1) NOT NULL default 0,
                MODIFY damaged    tinyint(1) NOT NULL default 0,
                MODIFY itemlost   tinyint(1) NOT NULL default 0,
                MODIFY wthdrawn   tinyint(1) NOT NULL default 0"
    );
    $dbh->do("UPDATE deleteditems SET notforloan = 0 WHERE notforloan IS NULL");
    $dbh->do("UPDATE deleteditems SET damaged = 0 WHERE damaged IS NULL");
    $dbh->do("UPDATE deleteditems SET itemlost = 0 WHERE itemlost IS NULL");
    $dbh->do("UPDATE deleteditems SET wthdrawn = 0 WHERE wthdrawn IS NULL");
    $dbh->do(
        "ALTER TABLE deleteditems
                MODIFY notforloan tinyint(1) NOT NULL default 0,
                MODIFY damaged    tinyint(1) NOT NULL default 0,
                MODIFY itemlost   tinyint(1) NOT NULL default 0,
                MODIFY wthdrawn   tinyint(1) NOT NULL default 0"
    );
    print "Upgrade to $DBversion done (disallow NULL in several item status columns)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.042";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE aqbooksellers CHANGE name name mediumtext NOT NULL");
    print "Upgrade to $DBversion done (disallow NULL in aqbooksellers.name; part of fix for bug 1251)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.043";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"ALTER TABLE `currency` ADD `symbol` varchar(5) default NULL AFTER currency, ADD `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP AFTER symbol"
    );
    print "Upgrade to $DBversion done (currency table: add symbol and timestamp columns)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.044";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "ALTER TABLE deletedborrowers
  ADD `altcontactfirstname` varchar(255) default NULL,
  ADD `altcontactsurname` varchar(255) default NULL,
  ADD `altcontactaddress1` varchar(255) default NULL,
  ADD `altcontactaddress2` varchar(255) default NULL,
  ADD `altcontactaddress3` varchar(255) default NULL,
  ADD `altcontactzipcode` varchar(50) default NULL,
  ADD `altcontactphone` varchar(50) default NULL
  "
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES
('OPACBaseURL',NULL,'Specify the Base URL of the OPAC, e.g., opac.mylibrary.com, the http:// will be added automatically by Koha.',NULL,'Free'),
('language','en','Set the default language in the staff client.',NULL,'Languages'),
('QueryAutoTruncate',1,'If ON, query truncation is enabled by default',NULL,'YesNo'),
('QueryRemoveStopwords',0,'If ON, stopwords listed in the Administration area will be removed from queries',NULL,'YesNo')
  "
    );
    print "Upgrade to $DBversion done (syncing deletedborrowers table with borrowers table)\n";
    SetVersion($DBversion);
}

#-- http://www.w3.org/International/articles/language-tags/

#-- RFC4646
$DBversion = "3.00.00.045";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do( "
CREATE TABLE IF NOT EXISTS language_subtag_registry (
        subtag varchar(25),
        type varchar(25), -- language-script-region-variant-extension-privateuse
        description varchar(25), -- only one of the possible descriptions for ease of reference, see language_descriptions for the complete list
        added date,
        KEY `subtag` (`subtag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8" );

    #-- TODO: add suppress_scripts
    #-- this maps three letter codes defined in iso639.2 back to their
    #-- two letter equivilents in rfc4646 (LOC maintains iso639+)
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS language_rfc4646_to_iso639 (
        rfc4646_subtag varchar(25),
        iso639_2_code varchar(25),
        KEY `rfc4646_subtag` (`rfc4646_subtag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );

    $dbh->do(
        "CREATE TABLE IF NOT EXISTS language_descriptions (
        subtag varchar(25),
        type varchar(25),
        lang varchar(25),
        description varchar(255),
        KEY `lang` (`lang`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );

    #-- bi-directional support, keyed by script subcode
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS language_script_bidi (
        rfc4646_subtag varchar(25), -- script subtag, Arab, Hebr, etc.
        bidi varchar(3), -- rtl ltr
        KEY `rfc4646_subtag` (`rfc4646_subtag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );

    #-- BIDI Stuff, Arabic and Hebrew
    $dbh->do(
        "INSERT IGNORE INTO language_script_bidi(rfc4646_subtag,bidi)
VALUES( 'Arab', 'rtl')"
    );
    $dbh->do(
        "INSERT IGNORE INTO language_script_bidi(rfc4646_subtag,bidi)
VALUES( 'Hebr', 'rtl')"
    );

    #-- TODO: need to map language subtags to script subtags for detection
    #-- of bidi when script is not specified (like ar, he)
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS language_script_mapping (
        language_subtag varchar(25),
        script_subtag varchar(25),
        KEY `language_subtag` (`language_subtag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );

    #-- Default mappings between script and language subcodes
    $dbh->do(
        "INSERT IGNORE INTO language_script_mapping(language_subtag,script_subtag)
VALUES( 'ar', 'Arab')"
    );
    $dbh->do(
        "INSERT IGNORE INTO language_script_mapping(language_subtag,script_subtag)
VALUES( 'he', 'Hebr')"
    );

    print "Upgrade to $DBversion done (adding language subtag registry and basic BiDi support NOTE: You should import the subtag registry SQL)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.046";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "ALTER TABLE `subscription` CHANGE `numberlength` `numberlength` int(11) default '0' ,
    		 CHANGE `weeklength` `weeklength` int(11) default '0'"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `serialitems` (`serialid` int(11) NOT NULL, `itemnumber` int(11) NOT NULL, UNIQUE KEY `serialididx` (`serialid`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("INSERT IGNORE INTO `serialitems` SELECT `serialid`,`itemnumber` from serial where NOT ISNULL(itemnumber) && itemnumber <> '' && itemnumber NOT LIKE '%,%'");
    print "Upgrade to $DBversion done (Add serialitems table to link serial issues to items. )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.047";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacRenewalAllowed',0,'If ON, users can renew their issues directly from their OPAC account',NULL,'YesNo');"
    );
    print "Upgrade to $DBversion done ( Added OpacRenewalAllowed syspref )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.048";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `items` ADD `more_subfields_xml` longtext default NULL AFTER `itype`");
    print "Upgrade to $DBversion done (added items.more_subfields_xml)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.049";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `z3950servers` ADD `encoding` text default NULL AFTER type ");
    print "Upgrade to $DBversion done ( Added encoding field to z3950servers table )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.050";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacHighlightedWords','0','If Set, query matched terms are highlighted in OPAC',NULL,'YesNo');"
    );
    print "Upgrade to $DBversion done ( Added OpacHighlightedWords syspref )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.051";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("UPDATE systempreferences SET explanation = 'Define the current theme for the OPAC interface.' WHERE variable = 'opacthemes';");
    print "Upgrade to $DBversion done ( Corrected opacthemes explanation. )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.052";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `deleteditems` ADD `more_subfields_xml` LONGTEXT DEFAULT NULL AFTER `itype`");
    print "Upgrade to $DBversion done ( Adding missing column to deleteditems table. )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.053";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `printers_profile` (
            `prof_id` int(4) NOT NULL auto_increment,
            `printername` varchar(40) NOT NULL,
            `tmpl_id` int(4) NOT NULL,
            `paper_bin` varchar(20) NOT NULL,
            `offset_horz` float default NULL,
            `offset_vert` float default NULL,
            `creep_horz` float default NULL,
            `creep_vert` float default NULL,
            `unit` char(20) NOT NULL default 'POINT',
            PRIMARY KEY  (`prof_id`),
            UNIQUE KEY `printername` (`printername`,`tmpl_id`,`paper_bin`),
            CONSTRAINT `printers_profile_pnfk_1` FOREIGN KEY (`tmpl_id`) REFERENCES `labels_templates` (`tmpl_id`) ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8 "
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `labels_profile` (
            `tmpl_id` int(4) NOT NULL,
            `prof_id` int(4) NOT NULL,
            UNIQUE KEY `tmpl_id` (`tmpl_id`),
            UNIQUE KEY `prof_id` (`prof_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8 "
    );
    print "Upgrade to $DBversion done ( Printer Profile tables added )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.054";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"UPDATE systempreferences SET options = 'incremental|annual|hbyymmincr|OFF', explanation = 'Used to autogenerate a barcode: incremental will be of the form 1, 2, 3; annual of the form 2007-0001, 2007-0002; hbyymmincr of the form HB08010001 where HB = Home Branch' WHERE variable = 'autoBarcode';"
    );
    print "Upgrade to $DBversion done ( Added another barcode autogeneration sequence to barcode.pl. )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.056";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    if ( C4::Context->preference("marcflavour") eq 'UNIMARC' ) {
        $dbh->do(
"INSERT IGNORE INTO `marc_subfield_structure` (`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value` , `authtypecode`, `value_builder`, `isurl`, `hidden`, `frameworkcode`, `seealso`, `link`, `defaultvalue`) VALUES ('995', 'v', 'Note sur le N° de périodique','Note sur le N° de périodique', 0, 0, 'items.enumchron', 10, '', '', '', 0, 0, '', '', '', NULL) "
        );
    } else {
        $dbh->do(
"INSERT IGNORE INTO `marc_subfield_structure` (`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value` , `authtypecode`, `value_builder`, `isurl`, `hidden`, `frameworkcode`, `seealso`, `link`, `defaultvalue`) VALUES ('952', 'h', 'Serial Enumeration / chronology','Serial Enumeration / chronology', 0, 0, 'items.enumchron', 10, '', '', '', 0, 0, '', '', '', NULL) "
        );
    }
    $dbh->do("ALTER TABLE `items` ADD `enumchron` VARCHAR(80) DEFAULT NULL;");
    print "Upgrade to $DBversion done ( Added item.enumchron column, and framework map to 952h )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.057";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH','0','if ON, OAI-PMH server is enabled',NULL,'YesNo');");
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH:archiveID','KOHA-OAI-TEST','OAI-PMH archive identification',NULL,'Free');");
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH:MaxCount','50','OAI-PMH maximum number of records by answer to ListRecords and ListIdentifiers queries',NULL,'Integer');"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH:Set','SET,Experimental set\r\nSET:SUBSET,Experimental subset','OAI-PMH exported set, the set name is followed by a comma and a short description, one set by line',NULL,'Free');"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH:Subset',\"itemtype='BOOK'\",'Restrict answer to matching raws of the biblioitems table (experimental)',NULL,'Free');"
    );
    SetVersion($DBversion);
}

$DBversion = "3.00.00.058";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "ALTER TABLE `opac_news`
                CHANGE `lang` `lang` VARCHAR( 25 )
                CHARACTER SET utf8
                COLLATE utf8_general_ci
                NOT NULL default ''"
    );
    print "Upgrade to $DBversion done ( lang field in opac_news made longer )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.059";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {

    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `labels_templates` (
            `tmpl_id` int(4) NOT NULL auto_increment,
            `tmpl_code` char(100)  default '',
            `tmpl_desc` char(100) default '',
            `page_width` float default '0',
            `page_height` float default '0',
            `label_width` float default '0',
            `label_height` float default '0',
            `topmargin` float default '0',
            `leftmargin` float default '0',
            `cols` int(2) default '0',
            `rows` int(2) default '0',
            `colgap` float default '0',
            `rowgap` float default '0',
            `active` int(1) default NULL,
            `units` char(20)  default 'PX',
            `fontsize` int(4) NOT NULL default '3',
            PRIMARY KEY  (`tmpl_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
    );
    $dbh->do(
        "CREATE TABLE  IF NOT EXISTS `printers_profile` (
            `prof_id` int(4) NOT NULL auto_increment,
            `printername` varchar(40) NOT NULL,
            `tmpl_id` int(4) NOT NULL,
            `paper_bin` varchar(20) NOT NULL,
            `offset_horz` float default NULL,
            `offset_vert` float default NULL,
            `creep_horz` float default NULL,
            `creep_vert` float default NULL,
            `unit` char(20) NOT NULL default 'POINT',
            PRIMARY KEY  (`prof_id`),
            UNIQUE KEY `printername` (`printername`,`tmpl_id`,`paper_bin`),
            CONSTRAINT `printers_profile_pnfk_1` FOREIGN KEY (`tmpl_id`) REFERENCES `labels_templates` (`tmpl_id`) ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8 "
    );
    print "Upgrade to $DBversion done ( Added labels_templates table if it did not exist. )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.060";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `patronimage` (
            `cardnumber` varchar(16) NOT NULL,
            `mimetype` varchar(15) NOT NULL,
            `imagefile` mediumblob NOT NULL,
            PRIMARY KEY  (`cardnumber`),
            CONSTRAINT `patronimage_fk1` FOREIGN KEY (`cardnumber`) REFERENCES `borrowers` (`cardnumber`) ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
    );
    print "Upgrade to $DBversion done ( Added patronimage table. )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.061";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE labels_templates ADD COLUMN font char(10) NOT NULL DEFAULT 'TR';");
    print "Upgrade to $DBversion done ( Added font column to labels_templates )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.062";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `old_issues` (
                `borrowernumber` int(11) default NULL,
                `itemnumber` int(11) default NULL,
                `date_due` date default NULL,
                `branchcode` varchar(10) default NULL,
                `issuingbranch` varchar(18) default NULL,
                `returndate` date default NULL,
                `lastreneweddate` date default NULL,
                `return` varchar(4) default NULL,
                `renewals` tinyint(4) default NULL,
                `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
                `issuedate` date default NULL,
                KEY `old_issuesborridx` (`borrowernumber`),
                KEY `old_issuesitemidx` (`itemnumber`),
                KEY `old_bordate` (`borrowernumber`,`timestamp`),
                CONSTRAINT `old_issues_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`)
                    ON DELETE SET NULL ON UPDATE SET NULL,
                CONSTRAINT `old_issues_ibfk_2` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`)
                    ON DELETE SET NULL ON UPDATE SET NULL
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `old_reserves` (
                `borrowernumber` int(11) default NULL,
                `reservedate` date default NULL,
                `biblionumber` int(11) default NULL,
                `constrainttype` varchar(1) default NULL,
                `branchcode` varchar(10) default NULL,
                `notificationdate` date default NULL,
                `reminderdate` date default NULL,
                `cancellationdate` date default NULL,
                `reservenotes` mediumtext,
                `priority` smallint(6) default NULL,
                `found` varchar(1) default NULL,
                `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
                `itemnumber` int(11) default NULL,
                `waitingdate` date default NULL,
                KEY `old_reserves_borrowernumber` (`borrowernumber`),
                KEY `old_reserves_biblionumber` (`biblionumber`),
                KEY `old_reserves_itemnumber` (`itemnumber`),
                KEY `old_reserves_branchcode` (`branchcode`),
                CONSTRAINT `old_reserves_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`)
                    ON DELETE SET NULL ON UPDATE SET NULL,
                CONSTRAINT `old_reserves_ibfk_2` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`)
                    ON DELETE SET NULL ON UPDATE SET NULL,
                CONSTRAINT `old_reserves_ibfk_3` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`)
                    ON DELETE SET NULL ON UPDATE SET NULL
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );

    # move closed transactions to old_* tables
    $dbh->do("INSERT IGNORE INTO old_issues SELECT * FROM issues WHERE returndate IS NOT NULL");
    $dbh->do("DELETE FROM issues WHERE returndate IS NOT NULL");
    $dbh->do("INSERT IGNORE INTO old_reserves SELECT * FROM reserves WHERE cancellationdate IS NOT NULL OR found = 'F'");
    $dbh->do("DELETE FROM reserves WHERE cancellationdate IS NOT NULL OR found = 'F'");

    print "Upgrade to $DBversion done ( Added old_issues and old_reserves tables )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.063";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "ALTER TABLE deleteditems
                CHANGE COLUMN booksellerid booksellerid MEDIUMTEXT DEFAULT NULL,
                ADD COLUMN enumchron VARCHAR(80) DEFAULT NULL AFTER more_subfields_xml,
                ADD COLUMN copynumber SMALLINT(6) DEFAULT NULL AFTER enumchron;"
    );
    $dbh->do(
        "ALTER TABLE items
                CHANGE COLUMN booksellerid booksellerid MEDIUMTEXT,
                ADD COLUMN copynumber SMALLINT(6) DEFAULT NULL AFTER enumchron;"
    );
    print
"Upgrade to $DBversion done ( Changed items.booksellerid and deleteditems.booksellerid to MEDIUMTEXT and added missing items.copynumber and deleteditems.copynumber to fix Bug 1927)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.064";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AmazonLocale','US','Use to set the Locale of your Amazon.com Web Services','US|CA|DE|FR|JP|UK','Choice');"
    );
    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AWSAccessKeyID','','See:  http://aws.amazon.com','','free');");
    $dbh->do("DELETE FROM `systempreferences` WHERE variable='AmazonDevKey';");
    $dbh->do("DELETE FROM `systempreferences` WHERE variable='XISBNAmazonSimilarItems';");
    $dbh->do("DELETE FROM `systempreferences` WHERE variable='OPACXISBNAmazonSimilarItems';");
    print "Upgrade to $DBversion done (IMPORTANT: Upgrading to Amazon.com Associates Web Service 4.0 ) \n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.065";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `patroncards` (
                `cardid` int(11) NOT NULL auto_increment,
                `batch_id` varchar(10) NOT NULL default '1',
                `borrowernumber` int(11) NOT NULL,
                `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
                PRIMARY KEY  (`cardid`),
                KEY `patroncards_ibfk_1` (`borrowernumber`),
                CONSTRAINT `patroncards_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
    );
    print "Upgrade to $DBversion done (Adding patroncards table for patroncards generation feature. ) \n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.066";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "ALTER TABLE `virtualshelfcontents` MODIFY `dateadded` timestamp NOT NULL
DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP;
"
    );
    print "Upgrade to $DBversion done (fix for bug 1873: virtualshelfcontents dateadded column empty. ) \n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.067";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("UPDATE systempreferences SET explanation = 'Enable patron images for the Staff Client', type = 'YesNo' WHERE variable = 'patronimages'");
    print "Upgrade to $DBversion done (Updating patronimages syspref to reflect current kohastructure.sql. ) \n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.068";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `permissions` (
                `module_bit` int(11) NOT NULL DEFAULT 0,
                `code` varchar(30) DEFAULT NULL,
                `description` varchar(255) DEFAULT NULL,
                PRIMARY KEY  (`module_bit`, `code`),
                CONSTRAINT `permissions_ibfk_1` FOREIGN KEY (`module_bit`) REFERENCES `userflags` (`bit`)
                    ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `user_permissions` (
                `borrowernumber` int(11) NOT NULL DEFAULT 0,
                `module_bit` int(11) NOT NULL DEFAULT 0,
                `code` varchar(30) DEFAULT NULL,
                CONSTRAINT `user_permissions_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`)
                    ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `user_permissions_ibfk_2` FOREIGN KEY (`module_bit`, `code`)
                    REFERENCES `permissions` (`module_bit`, `code`)
                    ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );

    $dbh->do(
        "INSERT IGNORE INTO permissions (module_bit, code, description) VALUES
    (13, 'edit_news', 'Write news for the OPAC and staff interfaces'),
    (13, 'label_creator', 'Create printable labels and barcodes from catalog and patron data'),
    (13, 'edit_calendar', 'Define days when the library is closed'),
    (13, 'moderate_comments', 'Moderate patron comments'),
    (13, 'edit_notices', 'Define notices'),
    (13, 'edit_notice_status_triggers', 'Set notice/status triggers for overdue items'),
    (13, 'view_system_logs', 'Browse the system logs'),
    (13, 'inventory', 'Perform inventory (stocktaking) of your catalogue'),
    (13, 'stage_marc_import', 'Stage MARC records into the reservoir'),
    (13, 'manage_staged_marc', 'Managed staged MARC records, including completing and reversing imports'),
    (13, 'export_catalog', 'Export bibliographic and holdings data'),
    (13, 'import_patrons', 'Import patron data'),
    (13, 'delete_anonymize_patrons', 'Delete old borrowers and anonymize circulation history (deletes borrower reading history)'),
    (13, 'batch_upload_patron_images', 'Upload patron images in batch or one at a time'),
    (13, 'schedule_tasks', 'Schedule tasks to run')"
    );

    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('GranularPermissions','0','Use detailed staff user permissions',NULL,'YesNo')");

    print "Upgrade to $DBversion done (adding permissions and user_permissions tables and GranularPermissions syspref) \n";
    SetVersion($DBversion);
}
$DBversion = "3.00.00.069";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE labels_conf CHANGE COLUMN class classification int(1) DEFAULT NULL;");
    print "Upgrade to $DBversion done ( Correcting columname in labels_conf )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.070";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $sth = $dbh->prepare("SELECT value FROM systempreferences WHERE variable='yuipath'");
    $sth->execute;
    my ($value) = $sth->fetchrow;
    $value =~ s/2.3.1/2.5.1/;
    $dbh->do("UPDATE systempreferences SET value='$value' WHERE variable='yuipath';");
    print "Update yuipath syspref to 2.5.1 if necessary\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.071";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(" ALTER TABLE `subscription` ADD `serialsadditems` TINYINT( 1 ) NOT NULL DEFAULT '0';");

    # fill the new field with the previous systempreference value, then drop the syspref
    my $sth = $dbh->prepare("SELECT value FROM systempreferences WHERE variable='serialsadditems'");
    $sth->execute;
    my ($serialsadditems) = $sth->fetchrow();
    $dbh->do("UPDATE subscription SET serialsadditems=$serialsadditems");
    $dbh->do("DELETE FROM systempreferences WHERE variable='serialsadditems'");
    print "Upgrade to $DBversion done ( moving serialsadditems from syspref to subscription )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.072";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE labels_conf ADD COLUMN formatstring mediumtext DEFAULT NULL AFTER printingtype");
    print "Upgrade to $DBversion done ( Adding format string to labels generator. )\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.073";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("DROP TABLE IF EXISTS `tags_all`;");
    $dbh->do(
        q#
	CREATE TABLE IF NOT EXISTS `tags_all` (
	  `tag_id`         int(11) NOT NULL auto_increment,
	  `borrowernumber` int(11) NOT NULL,
	  `biblionumber`   int(11) NOT NULL,
	  `term`      varchar(255) NOT NULL,
	  `language`       int(4) default NULL,
	  `date_created` datetime  NOT NULL,
	  PRIMARY KEY  (`tag_id`),
	  KEY `tags_borrowers_fk_1` (`borrowernumber`),
	  KEY `tags_biblionumber_fk_1` (`biblionumber`),
	  CONSTRAINT `tags_borrowers_fk_1` FOREIGN KEY (`borrowernumber`)
		REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
	  CONSTRAINT `tags_biblionumber_fk_1` FOREIGN KEY (`biblionumber`)
		REFERENCES `biblio`     (`biblionumber`)  ON DELETE CASCADE ON UPDATE CASCADE
	) ENGINE=InnoDB DEFAULT CHARSET=utf8;
	#
    );
    $dbh->do("DROP TABLE IF EXISTS `tags_approval`;");
    $dbh->do(
        q#
	CREATE TABLE IF NOT EXISTS `tags_approval` (
	  `term`   varchar(255) NOT NULL,
	  `approved`     int(1) NOT NULL default '0',
	  `date_approved` datetime       default NULL,
	  `approved_by` int(11)          default NULL,
	  `weight_total` int(9) NOT NULL default '1',
	  PRIMARY KEY  (`term`),
	  KEY `tags_approval_borrowers_fk_1` (`approved_by`),
	  CONSTRAINT `tags_approval_borrowers_fk_1` FOREIGN KEY (`approved_by`)
		REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE
	) ENGINE=InnoDB DEFAULT CHARSET=utf8;
	#
    );
    $dbh->do("DROP TABLE IF EXISTS `tags_index`;");
    $dbh->do(
        q#
	CREATE TABLE IF NOT EXISTS `tags_index` (
	  `term`    varchar(255) NOT NULL,
	  `biblionumber` int(11) NOT NULL,
	  `weight`        int(9) NOT NULL default '1',
	  PRIMARY KEY  (`term`,`biblionumber`),
	  KEY `tags_index_biblionumber_fk_1` (`biblionumber`),
	  CONSTRAINT `tags_index_term_fk_1` FOREIGN KEY (`term`)
		REFERENCES `tags_approval` (`term`)  ON DELETE CASCADE ON UPDATE CASCADE,
	  CONSTRAINT `tags_index_biblionumber_fk_1` FOREIGN KEY (`biblionumber`)
		REFERENCES `biblio` (`biblionumber`) ON DELETE CASCADE ON UPDATE CASCADE
	) ENGINE=InnoDB DEFAULT CHARSET=utf8;
	#
    );
    $dbh->do(
        q#
	INSERT IGNORE INTO `systempreferences` VALUES
		('BakerTaylorBookstoreURL','','','URL template for \"My Libary Bookstore\" links, to which the \"key\" value is appended, and \"https://\" is prepended.  It should include your hostname and \"Parent Number\".  Make this variable empty to turn MLB links off.  Example: ocls.mylibrarybookstore.com/MLB/actions/searchHandler.do?nextPage=bookDetails&parentNum=10923&key=',''),
		('BakerTaylorEnabled','0','','Enable or disable all Baker & Taylor features.','YesNo'),
		('BakerTaylorPassword','','','Baker & Taylor Password for Content Cafe (external content)','Textarea'),
		('BakerTaylorUsername','','','Baker & Taylor Username for Content Cafe (external content)','Textarea'),
		('TagsEnabled','1','','Enables or disables all tagging features.  This is the main switch for tags.','YesNo'),
		('TagsExternalDictionary',NULL,'','Path on server to local ispell executable, used to set $Lingua::Ispell::path  This dictionary is used as a \"whitelist\" of pre-allowed tags.',''),
		('TagsInputOnDetail','1','','Allow users to input tags from the detail page.',         'YesNo'),
		('TagsInputOnList',  '0','','Allow users to input tags from the search results list.', 'YesNo'),
		('TagsModeration',  NULL,'','Require tags from patrons to be approved before becoming visible.','YesNo'),
		('TagsShowOnDetail','10','','Number of tags to display on detail page.  0 is off.',        'Integer'),
		('TagsShowOnList',   '6','','Number of tags to display on search results list.  0 is off.','Integer')
	#
    );
    print "Upgrade to $DBversion done (Baker/Taylor,Tags: sysprefs and tables (tags_all, tags_index, tags_approval)) \n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.074";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        q#update itemtypes set imageurl = concat( 'npl/', imageurl )
                  where imageurl not like 'http%'
                    and imageurl is not NULL
                    and imageurl != ''#
    );
    print "Upgrade to $DBversion done (updating imagetype.imageurls to reflect new icon locations.)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.075";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(q(alter table authorised_values add imageurl varchar(200) default NULL));
    print "Upgrade to $DBversion done (adding imageurl field to authorised_values table)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.076";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "ALTER TABLE import_batches
              ADD COLUMN nomatch_action enum('create_new', 'ignore') NOT NULL default 'create_new' AFTER overlay_action"
    );
    $dbh->do(
        "ALTER TABLE import_batches
              ADD COLUMN item_action enum('always_add', 'add_only_for_matches', 'add_only_for_new', 'ignore')
                  NOT NULL default 'always_add' AFTER nomatch_action"
    );
    $dbh->do(
        "ALTER TABLE import_batches
              MODIFY overlay_action  enum('replace', 'create_new', 'use_template', 'ignore')
                  NOT NULL default 'create_new'"
    );
    $dbh->do(
        "ALTER TABLE import_records
              MODIFY status  enum('error', 'staged', 'imported', 'reverted', 'items_reverted',
                                  'ignored') NOT NULL default 'staged'"
    );
    $dbh->do(
        "ALTER TABLE import_items
              MODIFY status enum('error', 'staged', 'imported', 'reverted', 'ignored') NOT NULL default 'staged'"
    );

    print "Upgrade to $DBversion done (changes to import_batches and import_records)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.077";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {

    # drop these tables only if they exist and none of them are empty
    # these tables are not defined in the packaged 2.2.9, but since it is believed
    # that at least one library may be using them in a post-2.2.9 but pre-3.0 Koha,
    # some care is taken.
    my ($print_error) = $dbh->{PrintError};
    $dbh->{PrintError} = 0;
    my ($raise_error) = $dbh->{RaiseError};
    $dbh->{RaiseError} = 1;

    my $count   = 0;
    my $do_drop = 1;
    eval { $count = $dbh->do("SELECT 1 FROM categorytable"); };
    if ( $count > 0 ) {
        $do_drop = 0;
    }
    eval { $count = $dbh->do("SELECT 1 FROM mediatypetable"); };
    if ( $count > 0 ) {
        $do_drop = 0;
    }
    eval { $count = $dbh->do("SELECT 1 FROM subcategorytable"); };
    if ( $count > 0 ) {
        $do_drop = 0;
    }

    if ($do_drop) {
        $dbh->do("DROP TABLE IF EXISTS `categorytable`");
        $dbh->do("DROP TABLE IF EXISTS `mediatypetable`");
        $dbh->do("DROP TABLE IF EXISTS `subcategorytable`");
    }

    $dbh->{PrintError} = $print_error;
    $dbh->{RaiseError} = $raise_error;
    print "Upgrade to $DBversion done (drop categorytable, subcategorytable, and mediatypetable)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.078";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    my ($print_error) = $dbh->{PrintError};
    $dbh->{PrintError} = 0;

    unless ( $dbh->do("SELECT 1 FROM browser") ) {
        $dbh->{PrintError} = $print_error;
        $dbh->do(
            "CREATE TABLE IF NOT EXISTS `browser` (
                    `level` int(11) NOT NULL,
                    `classification` varchar(20) NOT NULL,
                    `description` varchar(255) NOT NULL,
                    `number` bigint(20) NOT NULL,
                    `endnode` tinyint(4) NOT NULL
                  ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
        );
    }
    $dbh->{PrintError} = $print_error;
    print "Upgrade to $DBversion done (add browser table if not already present)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.079";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    my ($print_error) = $dbh->{PrintError};
    $dbh->{PrintError} = 0;

    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable, value,options,type, explanation)VALUES
        ('AddPatronLists','categorycode','categorycode|category_type','Choice','Allow user to choose what list to pick up from when adding patrons')"
    );
    print "Upgrade to $DBversion done (add browser table if not already present)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.080";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE subscription CHANGE monthlength monthlength int(11) default '0'");
    $dbh->do("ALTER TABLE deleteditems MODIFY marc LONGBLOB AFTER copynumber");
    $dbh->do("ALTER TABLE aqbooksellers CHANGE name name mediumtext NOT NULL");
    print "Upgrade to $DBversion done (catch up on DB schema changes since alpha and beta)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.081";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `borrower_attribute_types` (
                `code` varchar(10) NOT NULL,
                `description` varchar(255) NOT NULL,
                `repeatable` tinyint(1) NOT NULL default 0,
                `unique_id` tinyint(1) NOT NULL default 0,
                `opac_display` tinyint(1) NOT NULL default 0,
                `password_allowed` tinyint(1) NOT NULL default 0,
                `staff_searchable` tinyint(1) NOT NULL default 0,
                `authorised_value_category` varchar(10) default NULL,
                PRIMARY KEY  (`code`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `borrower_attributes` (
                `borrowernumber` int(11) NOT NULL,
                `code` varchar(10) NOT NULL,
                `attribute` varchar(30) default NULL,
                `password` varchar(30) default NULL,
                KEY `borrowernumber` (`borrowernumber`),
                KEY `code_attribute` (`code`, `attribute`),
                CONSTRAINT `borrower_attributes_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`)
                    ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `borrower_attributes_ibfk_2` FOREIGN KEY (`code`) REFERENCES `borrower_attribute_types` (`code`)
                    ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ExtendedPatronAttributes','0','Use extended patron IDs and attributes',NULL,'YesNo')");
    print "Upgrade to $DBversion done (added borrower_attributes and  borrower_attribute_types)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.082";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(q(alter table accountlines add column lastincrement decimal(28,6) default NULL));
    print "Upgrade to $DBversion done (adding lastincrement column to accountlines table)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.083";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(qq(UPDATE systempreferences SET value='local' where variable='yuipath' and value like "%/intranet-tmpl/prog/%"));
    print "Upgrade to $DBversion done (Changing yuipath behaviour in managing a local value)\n";
    SetVersion($DBversion);
}
$DBversion = "3.00.00.084";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('RenewSerialAddsSuggestion','0','if ON, adds a new suggestion at serial subscription renewal',NULL,'YesNo')"
    );
    $dbh->do(
        "INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('GoogleJackets','0','if ON, displays jacket covers from Google Books API',NULL,'YesNo')");
    print "Upgrade to $DBversion done (add new sysprefs)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.085";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    if ( C4::Context->preference("marcflavour") eq 'MARC21' ) {
        $dbh->do("UPDATE marc_subfield_structure SET tab = 0 WHERE tab =  9 AND tagfield = '037'");
        $dbh->do("UPDATE marc_subfield_structure SET tab = 1 WHERE tab =  6 AND tagfield in ('100', '110', '111', '130')");
        $dbh->do("UPDATE marc_subfield_structure SET tab = 2 WHERE tab =  6 AND tagfield in ('240', '243')");
        $dbh->do("UPDATE marc_subfield_structure SET tab = 4 WHERE tab =  6 AND tagfield in ('400', '410', '411', '440')");
        $dbh->do("UPDATE marc_subfield_structure SET tab = 5 WHERE tab =  9 AND tagfield = '584'");
        $dbh->do("UPDATE marc_subfield_structure SET tab = 7 WHERE tab = -6 AND tagfield = '760'");
    }
    print "Upgrade to $DBversion done (move editing tab of various MARC21 subfields)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.086";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `tmp_holdsqueue` (
  	`biblionumber` int(11) default NULL,
  	`itemnumber` int(11) default NULL,
  	`barcode` varchar(20) default NULL,
  	`surname` mediumtext NOT NULL,
  	`firstname` text,
  	`phone` text,
  	`borrowernumber` int(11) NOT NULL,
  	`cardnumber` varchar(16) default NULL,
  	`reservedate` date default NULL,
  	`title` mediumtext,
  	`itemcallnumber` varchar(30) default NULL,
  	`holdingbranch` varchar(10) default NULL,
  	`pickbranch` varchar(10) default NULL,
  	`notes` text
	) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );

    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('RandomizeHoldsQueueWeight','0','if ON, the holds queue in circulation will be randomized, either based on all location codes, or by the location codes specified in StaticHoldsQueueWeight',NULL,'YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('StaticHoldsQueueWeight','0','Specify a list of library location codes separated by commas -- the list of codes will be traversed and weighted with first values given higher weight for holds fulfillment -- alternatively, if RandomizeHoldsQueueWeight is set, the list will be randomly selective',NULL,'TextArea')"
    );

    print "Upgrade to $DBversion done (Table structure for table `tmp_holdsqueue`)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.087";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` VALUES ('AutoEmailOpacUser','0','','Sends notification emails containing new account details to patrons - when account is created.','YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` VALUES ('AutoEmailPrimaryAddress','OFF','email|emailpro|B_email|cardnumber|OFF','Defines the default email address where Account Details emails are sent.','Choice')"
    );
    print "Upgrade to $DBversion done (added 2 new 'AutoEmailOpacUser' sysprefs)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.088";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('OPACShelfBrowser','1','','Enable/disable Shelf Browser on item details page','YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('OPACItemHolds','1','Allow OPAC users to place hold on specific items. If OFF, users can only request next available copy.','','YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('XSLTDetailsDisplay','0','','Enable XSL stylesheet control over details page display on OPAC WARNING: MARC21 Only','YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('XSLTResultsDisplay','0','','Enable XSL stylesheet control over results page display on OPAC WARNING: MARC21 Only','YesNo')"
    );
    print "Upgrade to $DBversion done (added 2 new 'AutoEmailOpacUser' sysprefs)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.089";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES('AdvancedSearchTypes','itemtypes','itemtypes|ccode','Select which set of fields comprise the Type limit in the advanced search','Choice')"
    );
    print "Upgrade to $DBversion done (added new AdvancedSearchTypes syspref)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.090";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do( "
        CREATE TABLE IF NOT EXISTS `branch_borrower_circ_rules` (
          `branchcode` VARCHAR(10) NOT NULL,
          `categorycode` VARCHAR(10) NOT NULL,
          `maxissueqty` int(4) default NULL,
          PRIMARY KEY (`categorycode`, `branchcode`),
          CONSTRAINT `branch_borrower_circ_rules_ibfk_1` FOREIGN KEY (`categorycode`) REFERENCES `categories` (`categorycode`)
            ON DELETE CASCADE ON UPDATE CASCADE,
          CONSTRAINT `branch_borrower_circ_rules_ibfk_2` FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`)
            ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    " );
    $dbh->do( "
        CREATE TABLE IF NOT EXISTS `default_borrower_circ_rules` (
          `categorycode` VARCHAR(10) NOT NULL,
          `maxissueqty` int(4) default NULL,
          PRIMARY KEY (`categorycode`),
          CONSTRAINT `borrower_borrower_circ_rules_ibfk_1` FOREIGN KEY (`categorycode`) REFERENCES `categories` (`categorycode`)
            ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    " );
    $dbh->do( "
        CREATE TABLE IF NOT EXISTS `default_branch_circ_rules` (
          `branchcode` VARCHAR(10) NOT NULL,
          `maxissueqty` int(4) default NULL,
          PRIMARY KEY (`branchcode`),
          CONSTRAINT `default_branch_circ_rules_ibfk_1` FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`)
            ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    " );
    $dbh->do( "
        CREATE TABLE IF NOT EXISTS `default_circ_rules` (
            `singleton` enum('singleton') NOT NULL default 'singleton',
            `maxissueqty` int(4) default NULL,
            PRIMARY KEY (`singleton`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    " );
    print "Upgrade to $DBversion done (added several circ rules tables)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.091";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(<<'END_SQL');
ALTER TABLE borrowers
ADD `smsalertnumber` varchar(50) default NULL
END_SQL

    $dbh->do(<<'END_SQL');
CREATE TABLE IF NOT EXISTS `message_attributes` (
  `message_attribute_id` int(11) NOT NULL auto_increment,
  `message_name` varchar(20) NOT NULL default '',
  `takes_days` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`message_attribute_id`),
  UNIQUE KEY `message_name` (`message_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
END_SQL

    $dbh->do(<<'END_SQL');
CREATE TABLE IF NOT EXISTS `message_transport_types` (
  `message_transport_type` varchar(20) NOT NULL,
  PRIMARY KEY  (`message_transport_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
END_SQL

    $dbh->do(<<'END_SQL');
CREATE TABLE IF NOT EXISTS `message_transports` (
  `message_attribute_id` int(11) NOT NULL,
  `message_transport_type` varchar(20) NOT NULL,
  `is_digest` tinyint(1) NOT NULL default '0',
  `letter_module` varchar(20) NOT NULL default '',
  `letter_code` varchar(20) NOT NULL default '',
  PRIMARY KEY  (`message_attribute_id`,`message_transport_type`,`is_digest`),
  KEY `message_transport_type` (`message_transport_type`),
  KEY `letter_module` (`letter_module`,`letter_code`),
  CONSTRAINT `message_transports_ibfk_1` FOREIGN KEY (`message_attribute_id`) REFERENCES `message_attributes` (`message_attribute_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `message_transports_ibfk_2` FOREIGN KEY (`message_transport_type`) REFERENCES `message_transport_types` (`message_transport_type`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `message_transports_ibfk_3` FOREIGN KEY (`letter_module`, `letter_code`) REFERENCES `letter` (`module`, `code`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
END_SQL

    $dbh->do(<<'END_SQL');
CREATE TABLE IF NOT EXISTS `borrower_message_preferences` (
  `borrower_message_preference_id` int(11) NOT NULL auto_increment,
  `borrowernumber` int(11) NOT NULL default '0',
  `message_attribute_id` int(11) default '0',
  `days_in_advance` int(11) default '0',
  `wants_digets` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`borrower_message_preference_id`),
  KEY `borrowernumber` (`borrowernumber`),
  KEY `message_attribute_id` (`message_attribute_id`),
  CONSTRAINT `borrower_message_preferences_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `borrower_message_preferences_ibfk_2` FOREIGN KEY (`message_attribute_id`) REFERENCES `message_attributes` (`message_attribute_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
END_SQL

    $dbh->do(<<'END_SQL');
CREATE TABLE IF NOT EXISTS `borrower_message_transport_preferences` (
  `borrower_message_preference_id` int(11) NOT NULL default '0',
  `message_transport_type` varchar(20) NOT NULL default '0',
  PRIMARY KEY  (`borrower_message_preference_id`,`message_transport_type`),
  KEY `message_transport_type` (`message_transport_type`),
  CONSTRAINT `borrower_message_transport_preferences_ibfk_1` FOREIGN KEY (`borrower_message_preference_id`) REFERENCES `borrower_message_preferences` (`borrower_message_preference_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `borrower_message_transport_preferences_ibfk_2` FOREIGN KEY (`message_transport_type`) REFERENCES `message_transport_types` (`message_transport_type`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
END_SQL

    $dbh->do(<<'END_SQL');
CREATE TABLE IF NOT EXISTS `message_queue` (
  `message_id` int(11) NOT NULL auto_increment,
  `borrowernumber` int(11) NOT NULL,
  `subject` text,
  `content` text,
  `message_transport_type` varchar(20) NOT NULL,
  `status` enum('sent','pending','failed','deleted') NOT NULL default 'pending',
  `time_queued` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  KEY `message_id` (`message_id`),
  KEY `borrowernumber` (`borrowernumber`),
  KEY `message_transport_type` (`message_transport_type`),
  CONSTRAINT `messageq_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `messageq_ibfk_2` FOREIGN KEY (`message_transport_type`) REFERENCES `message_transport_types` (`message_transport_type`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
END_SQL

    $dbh->do(<<'END_SQL');
INSERT IGNORE INTO `systempreferences`
  (variable,value,explanation,options,type)
VALUES
('EnhancedMessagingPreferences',0,'If ON, allows patrons to select to receive additional messages about items due or nearly due.','','YesNo')
END_SQL

    $dbh->do( <<'END_SQL');
INSERT IGNORE INTO `letter`
(module, code, name, title, content)
VALUES
('circulation','DUE','Item Due Reminder','Item Due Reminder','Dear <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nThe following item is now due:\r\n\r\n<<biblio.title>> by <<biblio.author>>'),
('circulation','DUEDGST','Item Due Reminder (Digest)','Item Due Reminder','You have <<count>> items due'),
('circulation','PREDUE','Advance Notice of Item Due','Advance Notice of Item Due','Dear <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nThe following item will be due soon:\r\n\r\n<<biblio.title>> by <<biblio.author>>'),
('circulation','PREDUEDGST','Advance Notice of Item Due (Digest)','Advance Notice of Item Due','You have <<count>> items due soon'),
('circulation','EVENT','Upcoming Library Event','Upcoming Library Event','Dear <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nThis is a reminder of an upcoming library event in which you have expressed interest.');
END_SQL

    my @sql_scripts = (
        'installer/data/mysql/en/mandatory/message_transport_types.sql',
        'installer/data/mysql/en/optional/sample_notices_message_attributes.sql',
        'installer/data/mysql/en/optional/sample_notices_message_transports.sql',
    );

    my $installer = C4::Installer->new();
    foreach my $script (@sql_scripts) {
        my $full_path = $installer->get_file_path_from_name($script);
        my $error     = $installer->load_sql($full_path);
        warn $error if $error;
    }

    print
"Upgrade to $DBversion done (Table structure for table `message_queue`, `message_transport_types`, `message_attributes`, `message_transports`, `borrower_message_preferences`, and `borrower_message_transport_preferences`.  Alter `borrowers` table,\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.092";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES('AllowOnShelfHolds', '0', '', 'Allow hold requests to be placed on items that are not on loan', 'YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES('AllowHoldsOnDamagedItems', '1', '', 'Allow hold requests to be placed on damaged items', 'YesNo')"
    );
    print "Upgrade to $DBversion done (added new AllowOnShelfHolds syspref)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.093";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `items` MODIFY COLUMN `copynumber` VARCHAR(32) DEFAULT NULL");
    $dbh->do("ALTER TABLE `deleteditems` MODIFY COLUMN `copynumber` VARCHAR(32) DEFAULT NULL");
    print "Upgrade to $DBversion done (Change data type of items.copynumber to allow free text)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.094";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `marc_subfield_structure` MODIFY `tagsubfield` VARCHAR(1) NOT NULL DEFAULT '' COLLATE utf8_bin");
    print "Upgrade to $DBversion done (Change Collation of marc_subfield_structure to allow mixed case in subfield labels.)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.095";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    if ( C4::Context->preference("marcflavour") eq 'MARC21' ) {
        $dbh->do("UPDATE marc_subfield_structure SET authtypecode = 'MEETI_NAME' WHERE authtypecode = 'Meeting Name'");
        $dbh->do("UPDATE marc_subfield_structure SET authtypecode = 'CORPO_NAME' WHERE authtypecode = 'CORP0_NAME'");
    }
    print "Upgrade to $DBversion done (fix invalid authority types in MARC21 frameworks [bug 2254])\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.096";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $sth = $dbh->prepare("SHOW COLUMNS FROM borrower_message_preferences LIKE 'wants_digets'");
    $sth->execute();
    if ( my $row = $sth->fetchrow_hashref ) {
        $dbh->do("ALTER TABLE borrower_message_preferences CHANGE wants_digets wants_digest tinyint(1) NOT NULL default 0");
    }
    print "Upgrade to $DBversion done (fix name borrower_message_preferences.wants_digest)\n";
    SetVersion($DBversion);
}

$DBversion = '3.00.00.097';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {

    $dbh->do('ALTER TABLE message_queue ADD to_address   mediumtext default NULL');
    $dbh->do('ALTER TABLE message_queue ADD from_address mediumtext default NULL');
    $dbh->do('ALTER TABLE message_queue ADD content_type text');
    $dbh->do('ALTER TABLE message_queue CHANGE borrowernumber borrowernumber int(11) default NULL');

    print "Upgrade to $DBversion done (updating 4 fields in message_queue table)\n";
    SetVersion($DBversion);
}

$DBversion = '3.00.00.098';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {

    $dbh->do(q(DELETE FROM message_transport_types WHERE message_transport_type = 'rss'));
    $dbh->do(q(DELETE FROM message_transports WHERE message_transport_type = 'rss'));

    print "Upgrade to $DBversion done (removing unused RSS message_transport_type)\n";
    SetVersion($DBversion);
}

$DBversion = '3.00.00.099';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES('OpacSuppression', '0', '', 'Turn ON the OPAC Suppression feature, requires further setup, ask your system administrator for details', 'YesNo')"
    );
    print "Upgrade to $DBversion done (Adding OpacSuppression syspref)\n";
    SetVersion($DBversion);
}

$DBversion = '3.00.00.100';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do('ALTER TABLE virtualshelves ADD COLUMN lastmodified timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP');
    print "Upgrade to $DBversion done (Adding lastmodified column to virtualshelves)\n";
    SetVersion($DBversion);
}

$DBversion = '3.00.00.101';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do('ALTER TABLE `overduerules` CHANGE `categorycode` `categorycode` VARCHAR(10) NOT NULL');
    $dbh->do('ALTER TABLE `deletedborrowers` CHANGE `categorycode` `categorycode` VARCHAR(10) NOT NULL');
    print "Upgrade to $DBversion done (Updating columnd definitions for patron category codes in notice/statsu triggers and deletedborrowers tables.)\n";
    SetVersion($DBversion);
}

$DBversion = '3.00.00.102';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do('ALTER TABLE serialitems MODIFY `serialid` int(11) NOT NULL AFTER itemnumber');
    $dbh->do('ALTER TABLE serialitems DROP KEY serialididx');
    $dbh->do('ALTER TABLE serialitems ADD CONSTRAINT UNIQUE KEY serialitemsidx (itemnumber)');

    # before setting constraint, delete any unvalid data
    $dbh->do('DELETE from serialitems WHERE serialid not in (SELECT serial.serialid FROM serial)');
    $dbh->do('ALTER TABLE serialitems ADD CONSTRAINT serialitems_sfk_1 FOREIGN KEY (serialid) REFERENCES serial (serialid) ON DELETE CASCADE ON UPDATE CASCADE');
    print "Upgrade to $DBversion done (Updating serialitems table to allow for multiple items per serial fixing kohabug 2380)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.103";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("DELETE FROM systempreferences WHERE variable='serialsadditems'");
    print "Upgrade to $DBversion done ( Verifying the removal of serialsadditems from syspref fixing kohabug 2219)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.104";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("DELETE FROM systempreferences WHERE variable='noOPACHolds'");
    print "Upgrade to $DBversion done (remove superseded 'noOPACHolds' system preference per bug 2413)\n";
    SetVersion($DBversion);
}

$DBversion = '3.00.00.105';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {

    # it is possible that this syspref is already defined since the feature was added some time ago.
    unless ( $dbh->do(q(SELECT variable FROM systempreferences WHERE variable = 'SMSSendDriver')) ) {
        $dbh->do(<<'END_SQL');
INSERT IGNORE INTO `systempreferences`
  (variable,value,explanation,options,type)
VALUES
('SMSSendDriver','','Sets which SMS::Send driver is used to send SMS messages.','','free')
END_SQL
    }
    print "Upgrade to $DBversion done (added SMSSendDriver system preference)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.106";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("DELETE FROM systempreferences WHERE variable='noOPACHolds'");

    # db revision 105 didn't apply correctly, so we're rolling this into 106
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences`
   (variable,value,explanation,options,type)
	VALUES
	('SMSSendDriver','','Sets which SMS::Send driver is used to send SMS messages.','','free')"
    );

    print "Upgrade to $DBversion done (remove default '0000-00-00' in subscriptionhistory.enddate field)\n";
    $dbh->do("ALTER TABLE `subscriptionhistory` CHANGE `enddate` `enddate` DATE NULL DEFAULT NULL ");
    $dbh->do("UPDATE subscriptionhistory SET enddate=NULL WHERE enddate='0000-00-00'");
    SetVersion($DBversion);
}

$DBversion = '3.00.00.107';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(<<'END_SQL');
UPDATE systempreferences
  SET explanation = CONCAT( explanation, '. WARNING: this feature is very resource consuming on collections with large numbers of items.' )
  WHERE variable = 'OPACShelfBrowser'
    AND explanation NOT LIKE '%WARNING%'
END_SQL
    $dbh->do(<<'END_SQL');
UPDATE systempreferences
  SET explanation = CONCAT( explanation, '. WARNING: this feature is very resource consuming.' )
  WHERE variable = 'CataloguingLog'
    AND explanation NOT LIKE '%WARNING%'
END_SQL
    print "Upgrade to $DBversion done (warning added to OPACShelfBrowser system preference)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.000';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    print "Upgrade to $DBversion done (start of 3.1)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.001';
if ( C4::Context->preference('Version') < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.04.001") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do( "
	        CREATE TABLE IF NOT EXISTS hold_fill_targets (
	            `borrowernumber` int(11) NOT NULL,
	            `biblionumber` int(11) NOT NULL,
	            `itemnumber` int(11) NOT NULL,
	            `source_branchcode`  varchar(10) default NULL,
	            `item_level_request` tinyint(4) NOT NULL default 0,
	            PRIMARY KEY `itemnumber` (`itemnumber`),
	            KEY `bib_branch` (`biblionumber`, `source_branchcode`),
	            CONSTRAINT `hold_fill_targets_ibfk_1` FOREIGN KEY (`borrowernumber`)
	                REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
	            CONSTRAINT `hold_fill_targets_ibfk_2` FOREIGN KEY (`biblionumber`)
	                REFERENCES `biblio` (`biblionumber`) ON DELETE CASCADE ON UPDATE CASCADE,
	            CONSTRAINT `hold_fill_targets_ibfk_3` FOREIGN KEY (`itemnumber`)
	                REFERENCES `items` (`itemnumber`) ON DELETE CASCADE ON UPDATE CASCADE,
	            CONSTRAINT `hold_fill_targets_ibfk_4` FOREIGN KEY (`source_branchcode`)
	                REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
	        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
	    " );
	    $dbh->do( "
	        ALTER TABLE tmp_holdsqueue
	            ADD item_level_request tinyint(4) NOT NULL default 0
	    " );
	
	    print "Upgrade to $DBversion done (add hold_fill_targets table and a column to tmp_holdsqueue)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.002';
if ( C4::Context->preference('Version') < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.01.001")or $compare_version >TransformToNum("3.01.00.000"))
	{
	    # use statistics where available
	    $dbh->do( "
	        ALTER TABLE statistics ADD KEY  tmp_stats (type, itemnumber, borrowernumber)
	    " );
	    $dbh->do( "
	        UPDATE issues iss
	        SET issuedate = (
	            SELECT max(datetime)
	            FROM statistics
	            WHERE type = 'issue'
	            AND itemnumber = iss.itemnumber
	            AND borrowernumber = iss.borrowernumber
	        )
	        WHERE issuedate IS NULL;
	    " );
	    $dbh->do("ALTER TABLE statistics DROP KEY tmp_stats");
	
	    # default to last renewal date
	    $dbh->do( "
	        UPDATE issues
	        SET issuedate = lastreneweddate
	        WHERE issuedate IS NULL
	        and lastreneweddate IS NOT NULL
	    " );
	
	    my $num_bad_issuedates = $dbh->selectrow_array("SELECT COUNT(*) FROM issues WHERE issuedate IS NULL");
	    if ( $num_bad_issuedates > 0 ) {
	        print STDERR "After the upgrade to $DBversion, there are still $num_bad_issuedates loan(s) with a NULL (blank) loan date. ",
	          "Please check the issues table in your database.";
	    }
	    print "Upgrade to $DBversion done (bug 2582: set null issues.issuedate to lastreneweddate)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.01.00.003";
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.01.002") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do(
	"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('AllowRenewalLimitOverride', '0', 'if ON, allows renewal limits to be overridden on the circulation screen',NULL,'YesNo')"
	    );
	    print "Upgrade to $DBversion done (add new syspref)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.004';
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.04.004") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do(
	"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACDisplayRequestPriority','0','Show patrons the priority level on holds in the OPAC','','YesNo')"
	    );
	    print "Upgrade to $DBversion done (added OPACDisplayRequestPriority system preference)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.005';
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.02.001") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do( "
	        INSERT IGNORE INTO `letter` (module, code, name, title, content)
	        VALUES('reserves', 'HOLD', 'Hold Available for Pickup', 'Hold Available for Pickup at <<branches.branchname>>', 'Dear <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nYou have a hold available for pickup as of <<reserves.waitingdate>>:\r\n\r\nTitle: <<biblio.title>>\r\nAuthor: <<biblio.author>>\r\nCopy: <<items.copynumber>>\r\nLocation: <<branches.branchname>>\r\n<<branches.branchaddress1>>\r\n<<branches.branchaddress2>>\r\n<<branches.branchaddress3>>')
	    " );
	    $dbh->do("INSERT IGNORE INTO `message_attributes` (message_attribute_id, message_name, takes_days) values(4, 'Hold Filled', 0)");
	    $dbh->do("INSERT IGNORE INTO `message_transports` (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) values(4, 'sms', 0, 'reserves', 'HOLD')");
	    $dbh->do("INSERT IGNORE INTO `message_transports` (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) values(4, 'email', 0, 'reserves', 'HOLD')");
	    print "Upgrade to $DBversion done (Add letter for holds notifications)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.006';
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.02.002") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("ALTER TABLE `biblioitems` ADD KEY issn (issn)");
	    print "Upgrade to $DBversion done (add index on biblioitems.issn)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.01.00.007";
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.02.003") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='intranetmainUserblock'");
	    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='intranetuserjs'");
	    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='opacheader'");
	    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='OpacMainUserBlock'");
	    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='OpacNav'");
	    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='opacuserjs'");
	    $dbh->do("UPDATE `systempreferences` SET options='30|10', type='Textarea' WHERE variable='OAI-PMH:Set'");
	    $dbh->do("UPDATE `systempreferences` SET options='50' WHERE variable='intranetstylesheet'");
	    $dbh->do("UPDATE `systempreferences` SET options='50' WHERE variable='intranetcolorstylesheet'");
	    $dbh->do("UPDATE `systempreferences` SET options='10' WHERE variable='globalDueDate'");
	    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='numSearchResults'");
	    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='OPACnumSearchResults'");
	    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='ReservesMaxPickupDelay'");
	    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='TransfersMaxDaysWarning'");
	    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='StaticHoldsQueueWeight'");
	    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='holdCancelLength'");
	    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='XISBNDailyLimit'");
	    $dbh->do("UPDATE `systempreferences` SET type='Float' WHERE variable='gist'");
	    $dbh->do("UPDATE `systempreferences` SET type='Free' WHERE variable='BakerTaylorUsername'");
	    $dbh->do("UPDATE `systempreferences` SET type='Free' WHERE variable='BakerTaylorPassword'");
	    $dbh->do("UPDATE `systempreferences` SET type='Textarea', options='70|10' WHERE variable='ISBD'");
	    print "Upgrade to $DBversion done (fix display of many sysprefs)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.008';
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.04.008") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do(
	        "CREATE TABLE IF NOT EXISTS branch_transfer_limits (
	                          limitId int(8) NOT NULL auto_increment,
	                          toBranch varchar(4) NOT NULL,
	                          fromBranch varchar(4) NOT NULL,
	                          itemtype varchar(4) NOT NULL,
	                          PRIMARY KEY  (limitId)
	                          ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
	    );
	
	    $dbh->do(
	"INSERT IGNORE INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'UseBranchTransferLimits', '0', '', 'If ON, Koha will will use the rules defined in branch_transfer_limits to decide if an item transfer should be allowed.', 'YesNo')"
	    );
	
	    print "Upgrade to $DBversion done (added branch_transfer_limits table and UseBranchTransferLimits system preference)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.01.00.009";
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.02.004") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("ALTER TABLE permissions MODIFY `code` varchar(64) DEFAULT NULL");
	    $dbh->do("ALTER TABLE user_permissions MODIFY `code` varchar(64) DEFAULT NULL");
	    $dbh->do("INSERT IGNORE INTO permissions (module_bit, code, description) VALUES ( 1, 'circulate_remaining_permissions', 'Remaining circulation permissions')");
	    $dbh->do("INSERT IGNORE INTO permissions (module_bit, code, description) VALUES ( 1, 'override_renewals', 'Override blocked renewals')");
	    print "Upgrade to $DBversion done (added subpermissions for circulate permission)\n";
	}
	SetVersion($DBversion);
}

$DBversion = '3.01.00.010';
if ( C4::Context->preference('Version') < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.02.005") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("ALTER TABLE `borrower_attributes` MODIFY COLUMN `attribute` VARCHAR(64) DEFAULT NULL");
	    $dbh->do("ALTER TABLE `borrower_attributes` MODIFY COLUMN `password` VARCHAR(64) DEFAULT NULL");
	    print "Upgrade to $DBversion done (bug 2687: increase length of borrower attribute fields)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.011';
if ( C4::Context->preference('Version') < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.02.006") or $compare_version >TransformToNum("3.01.00.000"))
	{
    # Yes, the old value was ^M terminated.
    my $bad_value =
"function prepareEmailPopup(){\r\n  if (!document.getElementById) return false;\r\n  if (!document.getElementById('reserveemail')) return false;\r\n  rsvlink = document.getElementById('reserveemail');\r\n  rsvlink.onclick = function() {\r\n      doReservePopup();\r\n      return false;\r\n	}\r\n}\r\n\r\nfunction doReservePopup(){\r\n}\r\n\r\nfunction prepareReserveList(){\r\n}\r\n\r\naddLoadEvent(prepareEmailPopup);\r\naddLoadEvent(prepareReserveList);";

    my $intranetuserjs = C4::Context->preference('intranetuserjs');
    if ( $intranetuserjs and $intranetuserjs eq $bad_value ) {
        my $sql = <<'END_SQL';
UPDATE systempreferences
SET value = ''
WHERE variable = 'intranetuserjs'
END_SQL
        $dbh->do($sql);
    }
    print "Upgrade to $DBversion done (removed bogus intranetuserjs syspref)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.01.00.012";
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.05.001") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do(
	"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('AllowHoldPolicyOverride', '0', 'Allow staff to override hold policies when placing holds',NULL,'YesNo')"
	    );
	    $dbh->do( "
	        CREATE TABLE IF NOT EXISTS `branch_item_rules` (
	          `branchcode` varchar(10) NOT NULL,
	          `itemtype` varchar(10) NOT NULL,
	          `holdallowed` tinyint(1) default NULL,
	          PRIMARY KEY  (`itemtype`,`branchcode`),
	          KEY `branch_item_rules_ibfk_2` (`branchcode`),
	          CONSTRAINT `branch_item_rules_ibfk_1` FOREIGN KEY (`itemtype`) REFERENCES `itemtypes` (`itemtype`) ON DELETE CASCADE ON UPDATE CASCADE,
	          CONSTRAINT `branch_item_rules_ibfk_2` FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
	        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
	    " );
	    $dbh->do( "
	        CREATE TABLE IF NOT EXISTS `default_branch_item_rules` (
	          `itemtype` varchar(10) NOT NULL,
	          `holdallowed` tinyint(1) default NULL,
	          PRIMARY KEY  (`itemtype`),
	          CONSTRAINT `default_branch_item_rules_ibfk_1` FOREIGN KEY (`itemtype`) REFERENCES `itemtypes` (`itemtype`) ON DELETE CASCADE ON UPDATE CASCADE
	        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
	    " );
	    $dbh->do( "
	        ALTER TABLE default_branch_circ_rules
	            ADD COLUMN holdallowed tinyint(1) NULL
	    " );
	    $dbh->do( "
	        ALTER TABLE default_circ_rules
	            ADD COLUMN holdallowed tinyint(1) NULL
	    " );
	    print "Upgrade to $DBversion done (Add tables and system preferences for holds policies)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.013';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do( "
        CREATE TABLE IF NOT EXISTS item_circulation_alert_preferences (
            id           int(11) AUTO_INCREMENT,
            branchcode   varchar(10) NOT NULL,
            categorycode varchar(10) NOT NULL,
            item_type    varchar(10) NOT NULL,
            notification varchar(16) NOT NULL,
            PRIMARY KEY (id),
            KEY (branchcode, categorycode, item_type, notification)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    " );

    $dbh->do(q{ ALTER TABLE `message_queue` ADD metadata text DEFAULT NULL           AFTER content;  });
    $dbh->do(q{ ALTER TABLE `message_queue` ADD letter_code varchar(64) DEFAULT NULL AFTER metadata; });

    $dbh->do(
        q{
        INSERT IGNORE INTO `letter` (`module`, `code`, `name`, `title`, `content`) VALUES
        ('circulation','CHECKIN','Item Check-in','Check-ins','The following items have been checked in:\r\n----\r\n<<biblio.title>>\r\n----\r\nThank you.');
    }
    );
    $dbh->do(
        q{
        INSERT IGNORE INTO `letter` (`module`, `code`, `name`, `title`, `content`) VALUES
        ('circulation','CHECKOUT','Item Checkout','Checkouts','The following items have been checked out:\r\n----\r\n<<biblio.title>>\r\n----\r\nThank you for visiting <<branches.branchname>>.');
    }
    );
    $dbh->do(q{SET FOREIGN_KEY_CHECKS = 0;});
    $dbh->do(q{INSERT IGNORE INTO message_attributes (message_attribute_id, message_name, takes_days) VALUES (5, 'Item Check-in', 0);});
    $dbh->do(q{INSERT IGNORE INTO message_attributes (message_attribute_id, message_name, takes_days) VALUES (6, 'Item Checkout', 0);});

    $dbh->do(
        q{INSERT IGNORE INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (5, 'email', 0, 'circulation', 'CHECKIN');}
    );
    $dbh->do(
        q{INSERT IGNORE INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (5, 'sms',   0, 'circulation', 'CHECKIN');}
    );
    $dbh->do(
        q{INSERT IGNORE INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (6, 'email', 0, 'circulation', 'CHECKOUT');}
    );
    $dbh->do(
        q{INSERT IGNORE INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (6, 'sms',   0, 'circulation', 'CHECKOUT');}
    );
    $dbh->do(q{SET FOREIGN_KEY_CHECKS = 1;});

    print "Upgrade to $DBversion done (data for Email Checkout Slips project)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.014";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
	$dbh->do("CREATE TABLE IF NOT EXISTS `branch_transfer_limits` (`limitId` int(8) NOT NULL AUTO_INCREMENT, `toBranch` varchar(10) NOT NULL, `fromBranch` varchar(10) NOT NULL, `itemtype` varchar(10) DEFAULT NULL, PRIMARY KEY (`limitId`)) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    $dbh->do("ALTER TABLE `branch_transfer_limits` CHANGE `itemtype` `itemtype` VARCHAR( 4 ) CHARACTER SET utf8 COLLATE utf8_general_ci NULL");
    $dbh->do("ALTER TABLE `branch_transfer_limits` ADD `ccode` VARCHAR( 10 ) NULL ;");
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` )
    VALUES (
    'BranchTransferLimitsType', 'ccode', 'itemtype|ccode', 'When using branch transfer limits, choose whether to limit by itemtype or collection code.', 'Choice'
    );"
    );

    print "Upgrade to $DBversion done ( Updated table for Branch Transfer Limits)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.015';
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsClientCode', '0', 'Client Code for using Syndetics Solutions content','','free')"
    );

    $dbh->do("INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsEnabled', '0', 'Turn on Syndetics Enhanced Content','','YesNo')");

    $dbh->do("INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsCoverImages', '0', 'Display Cover Images from Syndetics','','YesNo')");

    $dbh->do(
        "INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsTOC', '0', 'Display Table of Content information from Syndetics','','YesNo')");

    $dbh->do("INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsSummary', '0', 'Display Summary Information from Syndetics','','YesNo')");

    $dbh->do("INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsEditions', '0', 'Display Editions from Syndetics','','YesNo')");

    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsExcerpt', '0', 'Display Excerpts and first chapters on OPAC from Syndetics','','YesNo')"
    );

    $dbh->do("INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsReviews', '0', 'Display Reviews on OPAC from Syndetics','','YesNo')");

    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsAuthorNotes', '0', 'Display Notes about the Author on OPAC from Syndetics','','YesNo')"
    );

    $dbh->do("INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsAwards', '0', 'Display Awards on OPAC from Syndetics','','YesNo')");

    $dbh->do(
        "INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsSeries', '0', 'Display Series information on OPAC from Syndetics','','YesNo')"
    );

    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsCoverImageSize', 'MC', 'Choose the size of the Syndetics Cover Image to display on the OPAC detail page, MC is Medium, LC is Large','MC|LC','Choice')"
    );

    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACAmazonCoverImages', '0', 'Display cover images on OPAC from Amazon Web Services','','YesNo')"
    );

    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('AmazonCoverImages', '0', 'Display Cover Images in Staff Client from Amazon Web Services','','YesNo')"
    );

    $dbh->do("UPDATE systempreferences SET variable='AmazonEnabled' WHERE variable = 'AmazonContent'");

    $dbh->do("UPDATE systempreferences SET variable='OPACAmazonEnabled' WHERE variable = 'OPACAmazonContent'");

    print "Upgrade to $DBversion done (added Syndetics Enhanced Content system preferences)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.016";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('Babeltheque',0,'Turn ON Babeltheque content  - See babeltheque.com to subscribe to this service','','YesNo')"
    );
    print "Upgrade to $DBversion done (Added Babeltheque syspref)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.017";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `subscription` ADD `staffdisplaycount` VARCHAR(10) NULL;");
    $dbh->do("ALTER TABLE `subscription` ADD `opacdisplaycount` VARCHAR(10) NULL;");
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` )
    VALUES (
    'StaffSerialIssueDisplayCount', '3', '', 'Number of serial issues to display per subscription in the Staff client', 'Integer'
    );"
    );
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` )
    VALUES (
    'OPACSerialIssueDisplayCount', '3', '', 'Number of serial issues to display per subscription in the OPAC', 'Integer'
    );"
    );

    print "Upgrade to $DBversion done ( Updated table for Serials Display)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.018";
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.02.008") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("ALTER TABLE deletedborrowers ADD `smsalertnumber` varchar(50) default NULL");
	    print "Upgrade to $DBversion done (added deletedborrowers.smsalertnumber, missed in 3.00.00.091)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.01.00.019";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACShowCheckoutName','0','Displays in the OPAC the name of patron who has checked out the material. WARNING: Most sites should leave this off. It is intended for corporate or special sites which need to track who has the item.','','YesNo')"
    );
    print "Upgrade to $DBversion done (adding OPACShowCheckoutName systempref)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.020";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES('LibraryThingForLibrariesID','','See:http://librarything.com/forlibraries/','','free')");
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES('LibraryThingForLibrariesEnabled','0','Enable or Disable Library Thing for Libraries Features','','YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES('LibraryThingForLibrariesTabbedView','0','Put LibraryThingForLibraries Content in Tabs.','','YesNo')"
    );
    print "Upgrade to $DBversion done (adding LibraryThing for Libraries sysprefs)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.021";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    my $enable_reviews = C4::Context->preference('OPACAmazonEnabled') ? '1' : '0';
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACAmazonReviews', '$enable_reviews', 'Display Amazon readers reviews on OPAC','','YesNo')"
    );
    print "Upgrade to $DBversion done (adding OPACAmazonReviews syspref)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.022';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `labels_conf` MODIFY COLUMN `formatstring` mediumtext DEFAULT NULL");
    print "Upgrade to $DBversion done (bug 2945: increase size of labels_conf.formatstring)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.023';
if ( C4::Context->preference('Version') < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.02.009") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("ALTER TABLE biblioitems        MODIFY COLUMN isbn VARCHAR(30) DEFAULT NULL");
	    $dbh->do("ALTER TABLE deletedbiblioitems MODIFY COLUMN isbn VARCHAR(30) DEFAULT NULL");
	    $dbh->do("ALTER TABLE import_biblios     MODIFY COLUMN isbn VARCHAR(30) DEFAULT NULL");
	    $dbh->do("ALTER TABLE suggestions        MODIFY COLUMN isbn VARCHAR(30) DEFAULT NULL");
	    print "Upgrade to $DBversion done (bug 2765: increase width of isbn column in several tables)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.01.00.024";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE labels MODIFY COLUMN batch_id int(10) NOT NULL default 1;");
    print "Upgrade to $DBversion done (change labels.batch_id from varchar to int)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.025';
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.04.012") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do(
	"INSERT IGNORE INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'ceilingDueDate', '', '', 'If set, date due will not be past this date.  Enter date according to the dateformat System Preference', 'free')"
	    );
	
	    print "Upgrade to $DBversion done (added ceilingDueDate system preference)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.026';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'numReturnedItemsToShow', '20', '', 'Number of returned items to show on the check-in page', 'Integer')"
    );

    print "Upgrade to $DBversion done (added numReturnedItemsToShow system preference)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.028';
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.02.011") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    my $enable_reviews = C4::Context->preference('AmazonEnabled') ? '1' : '0';
	    $dbh->do(
	"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('AmazonReviews', '$enable_reviews', 'Display Amazon reviews on staff interface','','YesNo')"
	    );
	    print "Upgrade to $DBversion done (added AmazonReviews)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.029';
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.02.012") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do(
	        q( UPDATE language_rfc4646_to_iso639
	                SET iso639_2_code = 'spa'
	                WHERE rfc4646_subtag = 'es'
	                AND   iso639_2_code = 'rus' )
	    );
	    print "Upgrade to $DBversion done (fixed bug 2599: using Spanish search limit retrieves Russian results)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.01.00.030";
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.01.005") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do(
	"INSERT IGNORE INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'AllowNotForLoanOverride', '0', '', 'If ON, Koha will allow the librarian to loan a not for loan item.', 'YesNo')"
	    );
	    print "Upgrade to $DBversion done (added AllowNotForLoanOverride system preference)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.01.00.031";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "ALTER TABLE branch_transfer_limits
              MODIFY toBranch   varchar(10) NOT NULL,
              MODIFY fromBranch varchar(10) NOT NULL,
              MODIFY itemtype   varchar(10) NULL"
    );
    print "Upgrade to $DBversion done (fix column widths in branch_transfer_limits)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.032";
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.01.007") or $compare_version >TransformToNum("3.01.00.000"))
	{
    $dbh->do(<<ENDOFRENEWAL);
INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('RenewalPeriodBase', 'now', 'Set whether the renewal date should be counted from the date_due or from the moment the Patron asks for renewal ','date_due|now','Choice');
ENDOFRENEWAL
    print "Upgrade to $DBversion done (Change the field)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.01.00.033";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        q/
        ALTER TABLE borrower_message_preferences
        MODIFY borrowernumber int(11) default NULL,
        ADD    categorycode varchar(10) default NULL AFTER borrowernumber,
        ADD KEY `categorycode` (`categorycode`),
        ADD CONSTRAINT `borrower_message_preferences_ibfk_3`
                       FOREIGN KEY (`categorycode`) REFERENCES `categories` (`categorycode`)
                       ON DELETE CASCADE ON UPDATE CASCADE
    /
    );
    print "Upgrade to $DBversion done (DB changes to allow patron category defaults for messaging preferences)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.034";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `subscription` ADD COLUMN `graceperiod` INT(11) NOT NULL default '0';");
    print "Upgrade to $DBversion done (Adding graceperiod column to subscription table)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.035';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(q{ ALTER TABLE `subscription` ADD location varchar(80) NULL DEFAULT '' AFTER callnumber; });
    print "Upgrade to $DBversion done (Adding location to subscription table)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.036';
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.04.018") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do(
	        "UPDATE systempreferences SET explanation = 'Choose the default detail view in the staff interface; choose between normal, labeled_marc, marc or isbd'
	              WHERE variable = 'IntranetBiblioDefaultView'
	              AND   explanation = 'IntranetBiblioDefaultView'"
	    );
	    $dbh->do(
	        "UPDATE systempreferences SET type = 'Choice', options = 'normal|marc|isbd|labeled_marc'
	              WHERE variable = 'IntranetBiblioDefaultView'"
	    );
	    $dbh->do("INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES('viewISBD','1','Allow display of ISBD view of bibiographic records','','YesNo')");
	    $dbh->do(
	"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES('viewLabeledMARC','0','Allow display of labeled MARC view of bibiographic records','','YesNo')"
	    );
	    $dbh->do("INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES('viewMARC','1','Allow display of MARC view of bibiographic records','','YesNo')");
	    print "Upgrade to $DBversion done (new viewISBD, viewLabeledMARC, viewMARC sysprefs and tweak IntranetBiblioDefaultView)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.037';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do('ALTER TABLE authorised_values ADD KEY `lib` (`lib`)');
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES('FilterBeforeOverdueReport','0','Do not run overdue report until filter selected','','YesNo')"
    );
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (added FilterBeforeOverdueReport syspref and new index on authorised_values)\n";
}

$DBversion = "3.01.00.038";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {

    # update branches table
    #
    $dbh->do("ALTER TABLE branches ADD `branchzip` varchar(25) default NULL AFTER `branchaddress3`");
    $dbh->do("ALTER TABLE branches ADD `branchcity` mediumtext AFTER `branchzip`");
    $dbh->do("ALTER TABLE branches ADD `branchcountry` text AFTER `branchcity`");
    $dbh->do("ALTER TABLE branches ADD `branchurl` mediumtext AFTER `branchemail`");
    $dbh->do("ALTER TABLE branches ADD `branchnotes` mediumtext AFTER `branchprinter`");
    print "Upgrade to $DBversion done (add ZIP, city, country, URL, and notes column to branches)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.039';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type)VALUES('SpineLabelFormat', '<itemcallnumber><copynumber>', '30|10', 'This preference defines the format for the quick spine label printer. Just list the fields you would like to see in the order you would like to see them, surrounded by <>, for example <itemcallnumber>.', 'Textarea')"
    );
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type)VALUES('SpineLabelAutoPrint', '0', '', 'If this setting is turned on, a print dialog will automatically pop up for the quick spine label printer.', 'YesNo')"
    );
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (added SpineLabelFormat and SpineLabelAutoPrint sysprefs)\n";
}

$DBversion = '3.01.00.040';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES('AllowHoldDateInFuture','0','If set a date field is displayed on the Hold screen of the Staff Interface, allowing the hold date to be set in the future.','','YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES('OPACAllowHoldDateInFuture','0','If set, along with the AllowHoldDateInFuture system preference, OPAC users can set the date of a hold to be in the future.','','YesNo')"
    );
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (AllowHoldDateInFuture and OPACAllowHoldDateInFuture sysprefs)\n";
}

$DBversion = '3.01.00.041';
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.04.013") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do(
	"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AWSPrivateKey','','See:  http://aws.amazon.com.  Note that this is required after 2009/08/15 in order to retrieve any enhanced content other than book covers from Amazon.','','free')"
	    );
	    print "Upgrade to $DBversion done (added AWSPrivateKey syspref - note that if you use enhanced content from Amazon, this should be set right away.)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.042';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACFineNoRenewals','99999','Fine Limit above which user canmot renew books via OPAC','','Integer')"
    );
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (added OPACFineNoRenewals syspref)\n";
}

$DBversion = '3.01.00.043';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do('ALTER TABLE items ADD COLUMN permanent_location VARCHAR(80) DEFAULT NULL AFTER location');
    $dbh->do('UPDATE items SET permanent_location = location');
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'NewItemsDefaultLocation', '', '', 'If set, all new items will have a location of the given Location Code ( Authorized Value type LOC )', '')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'InProcessingToShelvingCart', '0', '', 'If set, when any item with a location code of PROC is ''checked in'', it''s location code will be changed to CART.', 'YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'ReturnToShelvingCart', '0', '', 'If set, when any item is ''checked in'', it''s location code will be changed to CART.', 'YesNo')"
    );
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (amended Item added NewItemsDefaultLocation, InProcessingToShelvingCart, ReturnToShelvingCart sysprefs)\n";
}

$DBversion = '3.01.00.044';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES( 'DisplayClearScreenButton', '0', 'If set to yes, a clear screen button will appear on the circulation page.', 'If set to yes, a clear screen button will appear on the circulation page.', 'YesNo')"
    );
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (added DisplayClearScreenButton system preference)\n";
}

$DBversion = '3.01.00.045';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type)VALUES('HidePatronName', '0', '', 'If this is switched on, patron''s cardnumber will be shown instead of their name on the holds and catalog screens', 'YesNo')"
    );
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (added a preference to hide the patrons name in the staff catalog)";
}

$DBversion = "3.01.00.046";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {

    # update borrowers table
    #
    $dbh->do("ALTER TABLE borrowers ADD `country` text AFTER zipcode");
    $dbh->do("ALTER TABLE borrowers ADD `B_country` text AFTER B_zipcode");
    $dbh->do("ALTER TABLE deletedborrowers ADD `country` text AFTER zipcode");
    $dbh->do("ALTER TABLE deletedborrowers ADD `B_country` text AFTER B_zipcode");
    print "Upgrade to $DBversion done (add country and B_country to borrowers)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.047';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE items MODIFY itemcallnumber varchar(255);");
    $dbh->do("ALTER TABLE deleteditems MODIFY itemcallnumber varchar(255);");
    $dbh->do("ALTER TABLE tmp_holdsqueue MODIFY itemcallnumber varchar(255);");
    SetVersion($DBversion);
    print " Upgrade to $DBversion done (bug 2761: change max length of itemcallnumber to 255 from 30)\n";
}

$DBversion = '3.01.00.048';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("UPDATE userflags SET flagdesc='View Catalog (Librarian Interface)' WHERE bit=2;");
    $dbh->do("UPDATE userflags SET flagdesc='Edit Catalog (Modify bibliographic/holdings data)' WHERE bit=9;");
    $dbh->do("UPDATE userflags SET flagdesc='Allow to edit authorities' WHERE bit=14;");
    $dbh->do("UPDATE userflags SET flagdesc='Allow to access to the reports module' WHERE bit=16;");
    $dbh->do("UPDATE userflags SET flagdesc='Allow to manage serials subscriptions' WHERE bit=15;");
    SetVersion($DBversion);
    print " Upgrade to $DBversion done (bug 2611: fix spelling/capitalization in permission flag descriptions)\n";
}

$DBversion = '3.01.00.049';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("UPDATE permissions SET description = 'Perform inventory (stocktaking) of your catalog' WHERE code = 'inventory';");
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (bug 2611: changed catalogue to catalog per the standard)\n";
}

$DBversion = '3.01.00.050';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('OPACSearchForTitleIn','<li class=\"yuimenuitem\">\n<a target=\"_blank\" class=\"yuimenuitemlabel\" href=\"http://worldcat.org/search?q=TITLE\">Other Libraries (WorldCat)</a></li>\n<li class=\"yuimenuitem\">\n<a class=\"yuimenuitemlabel\" href=\"http://www.scholar.google.com/scholar?q=TITLE\" target=\"_blank\">Other Databases (Google Scholar)</a></li>\n<li class=\"yuimenuitem\">\n<a class=\"yuimenuitemlabel\" href=\"http://www.bookfinder.com/search/?author=AUTHOR&amp;title=TITLE&amp;st=xl&amp;ac=qr\" target=\"_blank\">Online Stores (Bookfinder.com)</a></li>','Enter the HTML that will appear in the ''Search for this title in'' box on the detail page in the OPAC.  Enter TITLE, AUTHOR, or ISBN in place of their respective variables in the URL.  Leave blank to disable ''More Searches'' menu.','70|10','Textarea');"
    );
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (bug 1934: Add OPACSearchForTitleIn syspref)\n";
}

$DBversion = '3.01.00.051';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("UPDATE systempreferences SET explanation='Fine limit above which user cannot renew books via OPAC' WHERE variable='OPACFineNoRenewals';");
    $dbh->do("UPDATE systempreferences SET explanation='If set to ON, a clear screen button will appear on the circulation page.' WHERE variable='DisplayClearScreenButton';");
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (fixed typos in new sysprefs)\n";
}

$DBversion = '3.01.00.052';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do('ALTER TABLE deleteditems ADD COLUMN permanent_location VARCHAR(80) DEFAULT NULL AFTER location');
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (bug 3481: add permanent_location column to deleteditems)\n";
}

$DBversion = '3.01.00.053';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    my $upgrade_script = C4::Context->config("intranetdir") . "/installer/data/mysql/labels_upgrade.pl";
    system("perl $upgrade_script");
    print
"Upgrade to $DBversion done (Migrated labels tables and data to new schema.) NOTE: All existing label batches have been assigned to the first branch in the list of branches. This is ONLY true of migrated label batches.\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.054';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE borrowers ADD `B_address2` text AFTER B_address");
    $dbh->do("ALTER TABLE borrowers ADD `altcontactcountry` text AFTER altcontactzipcode");
    $dbh->do("ALTER TABLE deletedborrowers ADD `B_address2` text AFTER B_address");
    $dbh->do("ALTER TABLE deletedborrowers ADD `altcontactcountry` text AFTER altcontactzipcode");
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (bug 1600, bug 3454: add altcontactcountry and B_address2 to borrowers and deletedborrowers)\n";
}

$DBversion = '3.01.00.055';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
qq|UPDATE systempreferences set explanation='Enter the HTML that will appear in the ''Search for this title in'' box on the detail page in the OPAC.  Enter {TITLE}, {AUTHOR}, or {ISBN} in place of their respective variables in the URL. Leave blank to disable ''More Searches'' menu.', value='<li><a  href="http://worldcat.org/search?q={TITLE}" target="_blank">Other Libraries (WorldCat)</a></li>\n<li><a href="http://www.scholar.google.com/scholar?q={TITLE}" target="_blank">Other Databases (Google Scholar)</a></li>\n<li><a href="http://www.bookfinder.com/search/?author={AUTHOR}&amp;title={TITLE}&amp;st=xl&amp;ac=qr" target="_blank">Online Stores (Bookfinder.com)</a></li>' WHERE variable='OPACSearchForTitleIn'|
    );
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (changed OPACSearchForTitleIn per requests in bug 1934)\n";
}

$DBversion = '3.01.00.056';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('OPACPatronDetails','1','If OFF the patron details tab in the OPAC is disabled.','','YesNo');"
    );
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (Bug 1172 : Add OPACPatronDetails syspref)\n";
}

$DBversion = '3.01.00.057';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('OPACFinesTab','1','If OFF the patron fines tab in the OPAC is disabled.','','YesNo');"
    );
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (Bug 2576 : Add OPACFinesTab syspref)\n";
}

$DBversion = '3.01.00.058';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `language_subtag_registry` ADD `id` INT( 11 ) NOT NULL AUTO_INCREMENT PRIMARY KEY;");
    $dbh->do("ALTER TABLE `language_rfc4646_to_iso639` ADD `id` INT( 11 ) NOT NULL AUTO_INCREMENT PRIMARY KEY;");
    $dbh->do("ALTER TABLE `language_descriptions` ADD `id` INT( 11 ) NOT NULL AUTO_INCREMENT PRIMARY KEY;");
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (Added primary keys to language tables)\n";
}

$DBversion = '3.01.00.059';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type)VALUES('DisplayOPACiconsXSLT', '1', '', 'If ON, displays the format, audience, type icons in XSLT MARC21 results and display pages.', 'YesNo')"
    );
    SetVersion($DBversion);
    print "Upgrade to $DBversion done (added DisplayOPACiconsXSLT sysprefs)\n";
}

$DBversion = '3.01.00.060';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('AllowAllMessageDeletion','0','Allow any Library to delete any message','','YesNo');");
    $dbh->do('DROP TABLE IF EXISTS messages');
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS messages ( `message_id` int(11) NOT NULL auto_increment,
        `borrowernumber` int(11) NOT NULL,
        `branchcode` varchar(4) default NULL,
        `message_type` varchar(1) NOT NULL,
        `message` text NOT NULL,
        `message_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`message_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
    );

    print "Upgrade to $DBversion done ( Added AllowAllMessageDeletion syspref and messages table )\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.061';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES('ShowPatronImageInWebBasedSelfCheck', '0', 'If ON, displays patron image when a patron uses web-based self-checkout', '', 'YesNo')"
    );
    print "Upgrade to $DBversion done ( Added ShowPatronImageInWebBasedSelfCheck system preference )\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.062";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("INSERT IGNORE INTO permissions (module_bit, code, description) VALUES ( 13, 'manage_csv_profiles', 'Manage CSV export profiles')");
    $dbh->do(
        q/
	CREATE TABLE IF NOT EXISTS `export_format` (
	  `export_format_id` int(11) NOT NULL auto_increment,
	  `profile` varchar(255) NOT NULL,
	  `description` mediumtext NOT NULL,
	  `marcfields` mediumtext NOT NULL,
	  PRIMARY KEY  (`export_format_id`)
	) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Used for CSV export';
    /
    );
    print "Upgrade to $DBversion done (added csv export profiles)\n";
}

$DBversion = "3.01.00.063";
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.04.016") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do( "
	        CREATE TABLE IF NOT EXISTS `fieldmapping` (
	          `id` int(11) NOT NULL auto_increment,
	          `field` varchar(255) NOT NULL,
	          `frameworkcode` char(4) NOT NULL default '',
	          `fieldcode` char(3) NOT NULL,
	          `subfieldcode` char(1) NOT NULL,
	          PRIMARY KEY  (`id`)
	        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
	    print "Upgrade to $DBversion done (Bug 2576 : Add OPACFinesTab syspref)" ;
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.065';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do('ALTER TABLE issuingrules ADD COLUMN `renewalsallowed` smallint(6) NOT NULL default "0" AFTER `issuelength`;');
    $sth = $dbh->prepare("SELECT itemtype, renewalsallowed FROM itemtypes");
    $sth->execute();

    my $sthupd = $dbh->prepare("UPDATE issuingrules SET renewalsallowed = ? WHERE itemtype = ?");

    while ( my $row = $sth->fetchrow_hashref ) {
        $sthupd->execute( $row->{renewalsallowed}, $row->{itemtype} );
    }

    $dbh->do('ALTER TABLE itemtypes DROP COLUMN `renewalsallowed`;');

    SetVersion($DBversion);
    print "Upgrade to $DBversion done (Moving allowed renewals from itemtypes to issuingrule)\n";
}

$DBversion = '3.01.00.066';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do('ALTER TABLE issuingrules ADD COLUMN `reservesallowed` smallint(6) NOT NULL default "0" AFTER `renewalsallowed`;');

    my $maxreserves = C4::Context->preference('maxreserves');
    $sth = $dbh->prepare('UPDATE issuingrules SET reservesallowed = ?;');
    $sth->execute($maxreserves);

    $dbh->do('DELETE FROM systempreferences WHERE variable = "maxreserves";');

    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value, options, explanation, type) VALUES('ReservesControlBranch','PatronLibrary','ItemHomeLibrary|PatronLibrary','Branch checked for members reservations rights','Choice')"
    );

    SetVersion($DBversion);
    print "Upgrade to $DBversion done (Moving max allowed reserves from system preference to issuingrule)\n";
}

$DBversion = "3.01.00.067";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("INSERT IGNORE INTO permissions (module_bit, code, description) VALUES ( 13, 'batchmod', 'Perform batch modification of items')");
    $dbh->do("INSERT IGNORE INTO permissions (module_bit, code, description) VALUES ( 13, 'batchdel', 'Perform batch deletion of items')");
    print "Upgrade to $DBversion done (added permissions for batch modification and deletion)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.068";
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.06.009") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    my $count_column=count_column_from_table("finedays","issuingrules");
	    if($count_column==0)
	    {
			$dbh->do("ALTER TABLE issuingrules ADD COLUMN `finedays` int(11) default NULL AFTER `fine` ");
	    }
	    print "Upgrade done (Adding finedays in issuingrules table)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.01.00.069";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (`variable`, `value`, `options`, `explanation`, `type`) VALUES ('EnableOpacSearchHistory', '1', '', 'Enable or disable opac search history', 'YesNo')"
    );

    my $create = <<SEARCHHIST;
CREATE TABLE IF NOT EXISTS `search_history` (
  `userid` int(11) NOT NULL,
  `sessionid` varchar(32) NOT NULL,
  `query_desc` varchar(255) NOT NULL,
  `query_cgi` varchar(255) NOT NULL,
  `total` int(11) NOT NULL,
  `time` timestamp NOT NULL default CURRENT_TIMESTAMP,
  KEY `userid` (`userid`),
  KEY `sessionid` (`sessionid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Opac search history results';
SEARCHHIST
    $dbh->do($create);

    print "Upgrade done (added OPAC search history preference and table)\n";
}

$DBversion = "3.01.00.070";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE authorised_values ADD COLUMN `lib_opac` VARCHAR(80) default NULL AFTER `lib`");
    print "Upgrade done (Added a lib_opac field in authorised_values table)\n";
}

$DBversion = "3.01.00.071";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `subscription` ADD `enddate` date default NULL");
    $dbh->do("ALTER TABLE subscriptionhistory CHANGE enddate histenddate DATE default NULL");
    print "Upgrade to $DBversion done ( Adding enddate to subscription)\n";
}

=item

Acquisitions update

=cut

$DBversion = "3.01.00.072";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('OpacPrivacy', '0', 'if ON, allows patrons to define their privacy rules (reading history)',NULL,'YesNo')"
    );

    # create a new syspref for the 'Mr anonymous' patron
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('AnonymousPatron', '0', \"Set the identifier (borrowernumber) of the 'Mister anonymous' patron. Used for Suggestion and reading history privacy\",NULL,'')"
    );

    # fill AnonymousPatron with AnonymousSuggestion value (copy)
    my $sth = $dbh->prepare("SELECT value FROM systempreferences WHERE variable='AnonSuggestions'");
    $sth->execute;
    my ($value) = $sth->fetchrow() || 0;
    $dbh->do("UPDATE systempreferences SET value='$value' WHERE variable='AnonymousPatron'");

    # set AnonymousSuggestion do YesNo
    # 1st, set the value (1/True if it had a borrowernumber)
    $dbh->do("UPDATE systempreferences SET value=1 WHERE variable='AnonSuggestions' AND value>0");

    # 2nd, change the type to Choice
    $dbh->do("UPDATE systempreferences SET type='YesNo' WHERE variable='AnonSuggestions'");

    # borrower reading record privacy : 0 : forever, 1 : laws, 2 : don't keep at all
    $dbh->do("ALTER TABLE `borrowers` ADD `privacy` INTEGER NOT NULL DEFAULT 1;");
    print "Upgrade to $DBversion done (add new syspref and column in borrowers)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.073';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(<<'END_SQL');
CREATE TABLE IF NOT EXISTS `aqcontract` (
  `contractnumber` int(11) NOT NULL auto_increment,
  `contractstartdate` date default NULL,
  `contractenddate` date default NULL,
  `contractname` varchar(50) default NULL,
  `contractdescription` mediumtext,
  `booksellerid` int(11) not NULL,
    PRIMARY KEY  (`contractnumber`),
        CONSTRAINT `booksellerid_fk1` FOREIGN KEY (`booksellerid`)
        REFERENCES `aqbooksellers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;
END_SQL
    print "Upgrade to $DBversion done (adding aqcontract table)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.074';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `aqbasket` ADD COLUMN `basketname` varchar(50) default NULL AFTER `basketno`");
    $dbh->do("ALTER TABLE `aqbasket` ADD COLUMN `note` mediumtext AFTER `basketname`");
    $dbh->do("ALTER TABLE `aqbasket` ADD COLUMN `booksellernote` mediumtext AFTER `note`");
    $dbh->do("ALTER TABLE `aqbasket` ADD COLUMN `contractnumber` int(11) AFTER `booksellernote`");
    $dbh->do("ALTER TABLE `aqbasket` ADD FOREIGN KEY (`contractnumber`) REFERENCES `aqcontract` (`contractnumber`)");
    print "Upgrade to $DBversion done (edit aqbasket table done)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.075';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `aqorders` ADD COLUMN `uncertainprice` tinyint(1)");

    print "Upgrade to $DBversion done (adding uncertainprices)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.076';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `aqbasketgroups` (
                         `id` int(11) NOT NULL auto_increment,
                         `name` varchar(50) default NULL,
                         `closed` tinyint(1) default NULL,
                         `booksellerid` int(11) NOT NULL,
                         PRIMARY KEY (`id`),
                         KEY `booksellerid` (`booksellerid`),
                         CONSTRAINT `aqbasketgroups_ibfk_1` FOREIGN KEY (`booksellerid`) REFERENCES `aqbooksellers` (`id`) ON UPDATE CASCADE ON DELETE CASCADE
                         ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
    );
    $dbh->do("ALTER TABLE aqbasket ADD COLUMN `basketgroupid` int(11)");
    $dbh->do("ALTER TABLE aqbasket ADD FOREIGN KEY (`basketgroupid`) REFERENCES `aqbasketgroups` (`id`) ON UPDATE CASCADE ON DELETE SET NULL");
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('pdfformat','pdfformat::layout2pages','Controls what script is used for printing (basketgroups)','','free')"
    );
    print "Upgrade to $DBversion done (adding basketgroups)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.077';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {

    $dbh->do("SET FOREIGN_KEY_CHECKS=0 ");
    $dbh->do(
        qq|
                    CREATE TABLE IF NOT EXISTS `aqbudgetperiods` (
                    `budget_period_id` int(11) NOT NULL auto_increment,
                    `budget_period_startdate` date NOT NULL,
                    `budget_period_enddate` date NOT NULL,
                    `budget_period_active` tinyint(1) default '0',
                    `budget_period_description` mediumtext,
                    `budget_period_locked` tinyint(1) default NULL,
                    `sort1_authcat` varchar(10) default NULL,
                    `sort2_authcat` varchar(10) default NULL,
                    PRIMARY KEY  (`budget_period_id`)
                    ) ENGINE=InnoDB  DEFAULT CHARSET=utf8 |
    );

    $dbh->do(<<ADDPERIODS);
INSERT IGNORE INTO aqbudgetperiods (budget_period_startdate,budget_period_enddate,budget_period_active,budget_period_description,budget_period_locked)
SELECT DISTINCT startdate, enddate, NOW() BETWEEN startdate and enddate, concat(startdate," ",enddate),NOT NOW() BETWEEN startdate AND enddate from aqbudget
ADDPERIODS

    # SORRY , NO AQBUDGET/AQBOOKFUND -> AQBUDGETS IMPORT JUST YET,
    # BUT A NEW CLEAN AQBUDGETS TABLE CREATE FOR NOW..
    # DROP TABLE IF EXISTS `aqbudget`;
    #CREATE TABLE `aqbudget` (
    #  `bookfundid` varchar(10) NOT NULL default ',
    #    `startdate` date NOT NULL default 0,
    #	  `enddate` date default NULL,
    #	    `budgetamount` decimal(13,2) default NULL,
    #		  `aqbudgetid` tinyint(4) NOT NULL auto_increment,
    #		    `branchcode` varchar(10) default NULL,
    DropAllForeignKeys('aqbudget');

    #$dbh->do("drop table aqbudget;");

    my $maxbudgetid = $dbh->selectcol_arrayref(<<IDsBUDGET);
SELECT MAX(aqbudgetid) from aqbudget
IDsBUDGET
	if(defined($$maxbudgetid[0]))
	{
	    $dbh->do(<<BUDGETAUTOINCREMENT);
	ALTER TABLE aqbudget AUTO_INCREMENT=$$maxbudgetid[0]
BUDGETAUTOINCREMENT
	}
    
    $dbh->do(<<BUDGETNAME);
ALTER TABLE aqbudget RENAME `aqbudgets`
BUDGETNAME

    $dbh->do(<<BUDGETS);
ALTER TABLE `aqbudgets`
   CHANGE  COLUMN aqbudgetid `budget_id` int(11) NOT NULL AUTO_INCREMENT,
   CHANGE  COLUMN branchcode `budget_branchcode` varchar(10) default NULL,
   CHANGE  COLUMN budgetamount `budget_amount` decimal(28,6) NOT NULL default '0.00',
   CHANGE  COLUMN bookfundid   `budget_code` varchar(30) default NULL,
   ADD     COLUMN `budget_parent_id` int(11) default NULL,
   ADD     COLUMN `budget_name` varchar(80) default NULL,
   ADD     COLUMN `budget_encumb` decimal(28,6) default '0.00',
   ADD     COLUMN `budget_expend` decimal(28,6) default '0.00',
   ADD     COLUMN `budget_notes` mediumtext,
   ADD     COLUMN `budget_description` mediumtext,
   ADD     COLUMN `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
   ADD     COLUMN `budget_amount_sublevel`  decimal(28,6) AFTER `budget_amount`,
   ADD     COLUMN `budget_period_id` int(11) default NULL,
   ADD     COLUMN `sort1_authcat` varchar(80) default NULL,
   ADD     COLUMN `sort2_authcat` varchar(80) default NULL,
   ADD     COLUMN `budget_owner_id` int(11) default NULL,
   ADD     COLUMN `budget_permission` int(1) default '0';
BUDGETS

    $dbh->do(<<BUDGETCONSTRAINTS);
ALTER TABLE `aqbudgets`
   ADD CONSTRAINT `aqbudgets_ifbk_1` FOREIGN KEY (`budget_period_id`) REFERENCES `aqbudgetperiods` (`budget_period_id`) ON DELETE CASCADE ON UPDATE CASCADE
BUDGETCONSTRAINTS

    #    $dbh->do(<<BUDGETPKDROP);
    #ALTER TABLE `aqbudgets`
    #   DROP PRIMARY KEY
    #BUDGETPKDROP
    #    $dbh->do(<<BUDGETPKADD);
    #ALTER TABLE `aqbudgets`
    #   ADD PRIMARY KEY budget_id
    #BUDGETPKADD

    my $query_period   = $dbh->prepare(qq|SELECT budget_period_id from aqbudgetperiods where budget_period_startdate=? and budget_period_enddate=?|);
    my $query_bookfund = $dbh->prepare(qq|SELECT * from aqbookfund where bookfundid=?|);
    my $selectbudgets  = $dbh->prepare(qq|SELECT * from aqbudgets|);
    my $updatebudgets  = $dbh->prepare(qq|UPDATE aqbudgets SET budget_period_id= ? , budget_name=?, budget_branchcode=? where budget_id=?|);
    $selectbudgets->execute;
    while ( my $databudget = $selectbudgets->fetchrow_hashref ) {
        $query_period->execute( $$databudget{startdate}, $$databudget{enddate} );
        my ($budgetperiodid) = $query_period->fetchrow;
        $query_bookfund->execute( $$databudget{budget_code} );
        my $databf = $query_bookfund->fetchrow_hashref;
        my $branchcode = $$databudget{budget_branchcode} || $$databf{branchcode};
        $updatebudgets->execute( $budgetperiodid, $$databf{bookfundname}, $branchcode, $$databudget{budget_id} );
    }
    $dbh->do(<<BUDGETDROPDATES);
ALTER TABLE `aqbudgets`
   DROP startdate,
   DROP enddate
BUDGETDROPDATES

    $dbh->do(
        "CREATE TABLE IF NOT EXISTS `aqbudgets_planning` (
                    `plan_id` int(11) NOT NULL auto_increment,
                    `budget_id` int(11) NOT NULL,
                    `budget_period_id` int(11) NOT NULL,
                    `estimated_amount` decimal(28,6) default NULL,
                    `authcat` varchar(30) NOT NULL,
                    `authvalue` varchar(30) NOT NULL,
					`display` tinyint(1) DEFAULT 1,
                        PRIMARY KEY  (`plan_id`),
                        CONSTRAINT `aqbudgets_planning_ifbk_1` FOREIGN KEY (`budget_id`) REFERENCES `aqbudgets` (`budget_id`) ON DELETE CASCADE ON UPDATE CASCADE
                        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
    );

    $dbh->do(
        "ALTER TABLE `aqorders`
                    ADD COLUMN `budget_id` tinyint(4) NOT NULL,
                    ADD COLUMN `budgetgroup_id` int(11) NOT NULL,
                    ADD COLUMN  `sort1_authcat` varchar(10) default NULL,
                    ADD COLUMN  `sort2_authcat` varchar(10) default NULL"
    );

    # cannot do until aqorderbreakdown removed
    #    $dbh->do("DROP TABLE aqbookfund ");

    #    $dbh->do("ALTER TABLE aqorders  ADD FOREIGN KEY (`budget_id`) REFERENCES `aqbudgets` (`budget_id`) ON UPDATE CASCADE  " ); ????
    $dbh->do("SET FOREIGN_KEY_CHECKS=1 ");

    print "Upgrade to $DBversion done (Adding new aqbudgetperiods, aqbudgets and aqbudget_planning tables  )\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.078';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE aqbudgetperiods ADD COLUMN budget_period_total decimal(28,6)");
    print "Upgrade to $DBversion done (adds 'budget_period_total' column to aqbudgetperiods table)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.079';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE currency ADD COLUMN active  tinyint(1)");

    print "Upgrade to $DBversion done (adds 'active' column to currencies table)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.080';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(<<BUDG_PERM );
INSERT IGNORE INTO permissions (module_bit, code, description) VALUES
            (11, 'vendors_manage', 'Manage vendors'),
            (11, 'contracts_manage', 'Manage contracts'),
            (11, 'period_manage', 'Manage periods'),
            (11, 'budget_manage', 'Manage budgets'),
            (11, 'budget_modify', "Modify budget (can't create lines but can modify existing ones)"),
            (11, 'planning_manage', 'Manage budget plannings'),
            (11, 'order_manage', 'Manage orders & basket'),
            (11, 'group_manage', 'Manage orders & basketgroups'),
            (11, 'order_receive', 'Manage orders & basket'),
            (11, 'budget_add_del', "Add and delete budgets (but can't modify budgets)");
BUDG_PERM

    print "Upgrade to $DBversion done (adds permissions for the acquisitions module)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.081';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE aqbooksellers ADD COLUMN `gstrate` decimal(6,4) default NULL");
    if ( my $gist = C4::Context->preference("gist") ) {
        my $sql = $dbh->prepare("UPDATE aqbooksellers set `gstrate`=? ");
        $sql->execute($gist);
    }
    print "Upgrade to $DBversion done (added per-supplier gstrate setting)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.082";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    if ( C4::Context->preference("opaclanguages") eq "fr" ) {
        $dbh->do(
qq#INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AcqCreateItem','ordering',"Définit quand l'exemplaire est créé : à la commande, à la livraison, au catalogage",'ordering|receiving|cataloguing','Choice')#
        );
    } else {
        $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AcqCreateItem','ordering','Define when the item is created : when ordering, when receiving, or in cataloguing module','ordering|receiving|cataloguing','Choice')"
        );
    }
    print "Upgrade to $DBversion done (adding ReservesNeedReturns systempref, in circulation)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.083";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq|
 CREATE TABLE IF NOT EXISTS `aqorders_items` (
  `ordernumber` int(11) NOT NULL,
  `itemnumber` int(11) NOT NULL,
  `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`itemnumber`),
  KEY `ordernumber` (`ordernumber`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8   |
    );

    $dbh->do(qq| DROP TABLE aqorderbreakdown |);
    $dbh->do('DROP TABLE aqbookfund');
    print "Upgrade to $DBversion done (New aqorders_items table for acqui)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.084";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
qq# INSERT IGNORE INTO `systempreferences` VALUES ('CurrencyFormat','US','US|FR','Determines the display format of currencies. eg: ''36000'' is displayed as ''360 000,00''  in ''FR'' or 360,000.00''  in ''US''.','Choice')  #
    );

    print "Upgrade to $DBversion done (CurrencyFormat syspref added)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.085";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER table aqorders drop column title");
    $dbh->do("ALTER TABLE `aqorders` CHANGE `budget_id` `budget_id` INT( 11 ) NOT NULL");
    print "Upgrade to $DBversion done update budget_id size that should not be a tinyint\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.086";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(<<SUGGESTIONS);
ALTER table suggestions
    ADD budgetid INT(11),
    ADD branchcode VARCHAR(10) default NULL,
    ADD acceptedby INT(11) default NULL,
    ADD accepteddate date default NULL,
    ADD suggesteddate date default NULL,
    ADD manageddate date default NULL,
    ADD rejectedby INT(11) default NULL,
    ADD rejecteddate date default NULL,
    ADD collectiontitle text default NULL,
    ADD itemtype VARCHAR(30) default NULL
    ;
SUGGESTIONS
    print "Upgrade to $DBversion done Suggestions";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.087";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER table aqbudgets drop column budget_amount_sublevel;");
    print "Upgrade to $DBversion done drop column budget_amount_sublevel from aqbudgets\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.088";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(qq# INSERT IGNORE INTO `systempreferences` VALUES ('intranetbookbag','1','','If ON, enables display of Cart feature in the intranet','YesNo')  #);

    print "Upgrade to $DBversion done (intranetbookbag syspref added)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.090";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do( "
       INSERT IGNORE INTO `permissions` (`module_bit`, `code`, `description`) VALUES
		(16, 'execute_reports', 'Execute SQL reports'),
		(16, 'create_reports', 'Create SQL Reports')
	" );

    print "Upgrade to $DBversion done (granular permissions for guided reports added)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.091";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do( "
	UPDATE `systempreferences` SET `options` = 'holdings|serialcollection|subscriptions'
	WHERE `systempreferences`.`variable` = 'opacSerialDefaultTab' LIMIT 1
	" );

    print "Upgrade to $DBversion done (opac-detail default tag updated)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.092";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    if ( C4::Context->preference("opaclanguages") =~ /fr/ ) {
        $dbh->do(
            qq{
INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('RoutingListAddReserves','1','Si activé, des reservations sont automatiquement créées pour chaque lecteur de la liste de circulation d''un numéro de périodique','','YesNo');
	}
        );
    } else {
        $dbh->do(
            qq{
INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('RoutingListAddReserves','1','If ON the patrons on routing lists are automatically added to holds on the issue.','','YesNo');
	}
        );
    }
    print "Upgrade to $DBversion done (Added RoutingListAddReserves syspref)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.093";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{
	ALTER TABLE biblioitems ADD INDEX issn_idx (issn);
	}
    );
    print "Upgrade to $DBversion done (added index to ISSN)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.094";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{
	ALTER TABLE aqbasketgroups ADD deliveryplace VARCHAR(10) default NULL, ADD deliverycomment VARCHAR(255) default NULL;
	}
    );

    print "Upgrade to $DBversion done (adding deliveryplace deliverycomment to basketgroups)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.095";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{
	ALTER TABLE items ADD stocknumber VARCHAR(32) DEFAULT NULL COMMENT "stores the inventory number";
	}
    );
    $dbh->do(
        qq{
	ALTER TABLE items ADD UNIQUE INDEX itemsstocknumberidx (stocknumber);
	}
    );
    $dbh->do(
        qq{
	ALTER TABLE deleteditems ADD stocknumber VARCHAR(32) DEFAULT NULL COMMENT "stores the inventory number of deleted items";
	}
    );
    $dbh->do(
        qq{
	ALTER TABLE deleteditems ADD UNIQUE INDEX deleteditemsstocknumberidx (stocknumber);
	}
    );
    if ( C4::Context->preference('marcflavour') eq 'UNIMARC' ) {
        $dbh->do(
            qq{
	INSERT IGNORE INTO marc_subfield_structure (frameworkcode,tagfield, tagsubfield, tab, repeatable, mandatory,kohafield)
	SELECT DISTINCT (frameworkcode),995,"j",10,0,0,"items.stocknumber" from biblio_framework ;
		}
        );

        #Previously, copynumber was used as stocknumber
        $dbh->do(
            qq{
	UPDATE items set stocknumber=copynumber;
		}
        );
        $dbh->do(
            qq{
	UPDATE items set copynumber=NULL;
		}
        );
    }
    print "Upgrade to $DBversion done (stocknumber field added)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.096";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('OrderPdfTemplate','','Uploads a PDF template to use for printing baskets','NULL','Upload')"
    );
    $dbh->do("UPDATE systempreferences SET variable='OrderPdfFormat' WHERE variable='pdfformat'");
    print "Upgrade to $DBversion done (PDF orders system preferences added and updated)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.097";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{
	ALTER TABLE aqbasketgroups ADD billingplace VARCHAR(10) default NULL AFTER deliverycomment;
	}
    );

    print "Upgrade to $DBversion done (Adding billingplace to aqbasketgroups)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.098";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{
	ALTER TABLE auth_subfield_structure MODIFY frameworkcode VARCHAR(10) NULL;
	}
    );

    print "Upgrade to $DBversion done (changing frameworkcode length in auth_subfield_structure)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.099";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{
		INSERT IGNORE INTO `permissions` (`module_bit`, `code`, `description`) VALUES
                (9, 'edit_catalogue', 'Edit catalogue'),
		(9, 'fast_cataloging', 'Fast cataloging')
	}
    );

    print "Upgrade to $DBversion done (granular permissions for cataloging added)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.100";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (`variable`, `value`, `options`, `explanation`, `type`) VALUES ('casAuthentication', '0', '', 'Enable or disable CAS authentication', 'YesNo'), ('casLogout', '1', '', 'Does a logout from Koha should also log out of CAS ?', 'YesNo'), ('casServerUrl', 'https://localhost:8443/cas', '', 'URL of the cas server', 'Free')"
    );
    print "Upgrade done (added CAS authentication system preferences)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.101";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "INSERT IGNORE INTO systempreferences 
           (variable, value, options, explanation, type)
         VALUES (
            'OverdueNoticeBcc', '', '', 
            'Email address to Bcc outgoing notices sent by email',
            'free')
         "
    );
    print "Upgrade to $DBversion done (added OverdueNoticeBcc system preferences)\n";
    SetVersion($DBversion);
}
$DBversion = "3.01.00.102";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do( "UPDATE permissions set description = 'Edit catalog (Modify bibliographic/holdings data)' where module_bit = 9 and code = 'edit_catalogue'" );
    print "Upgrade done (fixed spelling error in edit_catalogue permission)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.103";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("INSERT IGNORE INTO permissions (module_bit, code, description) VALUES (13, 'moderate_tags', 'Moderate patron tags')");
    print "Upgrade done (adding patron permissions for tags tool)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.104";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {

    my ( $maninv_count, $borrnotes_count );
    eval { $maninv_count = $dbh->do("SELECT 1 FROM authorised_values WHERE category='MANUAL_INV'"); };
    if ( $maninv_count == 0 ) {
        $dbh->do("INSERT IGNORE INTO authorised_values (category,authorised_value,lib) VALUES ('MANUAL_INV','Copier Fees','.25')");
    }
    eval { $borrnotes_count = $dbh->do("SELECT 1 FROM authorised_values WHERE category='BOR_NOTES'"); };
    if ( $borrnotes_count == 0 ) {
        $dbh->do("INSERT IGNORE INTO authorised_values (category,authorised_value,lib) VALUES ('BOR_NOTES','ADDR','Address Notes')");
    }

    $dbh->do("INSERT IGNORE INTO authorised_values (category,authorised_value,lib) VALUES ('LOC','CART','Book Cart')");
    $dbh->do("INSERT IGNORE INTO authorised_values (category,authorised_value,lib) VALUES ('LOC','PROC','Processing Center')");

    print
      "Upgrade to $DBversion done ( add defaults to authorized values for MANUAL_INV and BOR_NOTES and add new default LOC authorized values for shelf to cart processing )\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.105";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do( "
      CREATE TABLE IF NOT EXISTS `collections` (
        `colId` int(11) NOT NULL auto_increment,
        `colTitle` varchar(100) NOT NULL default '',
        `colDesc` text NOT NULL,
        `colBranchcode` varchar(4) default NULL COMMENT 'branchcode for branch where item should be held.',
        PRIMARY KEY  (`colId`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    " );

    $dbh->do( "
      CREATE TABLE IF NOT EXISTS `collections_tracking` (
        `ctId` int(11) NOT NULL auto_increment,
        `colId` int(11) NOT NULL default '0' COMMENT 'collections.colId',
        `itemnumber` int(11) NOT NULL default '0' COMMENT 'items.itemnumber',
        PRIMARY KEY  (`ctId`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    " );
    $dbh->do( "
        INSERT IGNORE INTO permissions (module_bit, code, description) 
        VALUES ( 13, 'rotating_collections', 'Manage Rotating collections')" );
    print "Upgrade to $DBversion done (added collection and collection_tracking tables for rotating collections functionality)\n";
    SetVersion($DBversion);
}
$DBversion = "3.01.00.106";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES ( 'OpacAddMastheadLibraryPulldown', '0', '', 'Adds a pulldown menu to select the library to search on the opac masthead.', 'YesNo' )"
    );
    print "Upgrade done (added OpacAddMastheadLibraryPulldown system preferences)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.107';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    my $upgrade_script = C4::Context->config("intranetdir") . "/installer/data/mysql/patroncards_upgrade.pl";
    system("perl $upgrade_script");
    print "Upgrade to $DBversion done (Migrated labels and patroncards tables and data to new schema.)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.108';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{
	ALTER TABLE `export_format` ADD `csv_separator` VARCHAR( 2 ) NOT NULL AFTER `marcfields` ,
	ADD `field_separator` VARCHAR( 2 ) NOT NULL AFTER `csv_separator` ,
	ADD `subfield_separator` VARCHAR( 2 ) NOT NULL AFTER `field_separator` 
	}
    );
    print "Upgrade done (added separators for csv export)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.109";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{
	ALTER TABLE `export_format` ADD `encoding` VARCHAR(255) NOT NULL AFTER `subfield_separator`
	}
    );
    print "Upgrade done (added encoding for csv export)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.110';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do('ALTER TABLE `categories` ADD COLUMN `enrolmentperioddate` DATE NULL DEFAULT NULL AFTER `enrolmentperiod`');
    print "Upgrade done (Add enrolment period date support)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.111';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    print "Upgrade done (mark DBrev for 3.2-alpha release)\n";
    SetVersion($DBversion);
}
$DBversion = "3.01.00.112";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do( "UPDATE systempreferences set value='../koha-tmpl/opac-tmpl/prog/en/xslt/"
          . C4::Context->preference('marcflavour')
          . "slim2OPACDetail.xsl',type='Free' where variable='XSLTDetailsDisplay' AND value=1;" );
    $dbh->do( "UPDATE systempreferences set value='../koha-tmpl/opac-tmpl/prog/en/xslt/"
          . C4::Context->preference('marcflavour')
          . "slim2OPACResults.xsl',type='Free' where variable='XSLTResultsDisplay' AND value=1;" );
    $dbh->do( "INSERT IGNORE INTO systempreferences set value='../koha-tmpl/intranet-tmpl/prog/en/xslt/"
          . C4::Context->preference('marcflavour')
          . "slim2IntranetDetails.xsl',type='Free', variable='IntranetXSLTResultsDisplay';" );
    print "Upgrade to $DBversion done (Improve XSLT)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.112';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('SpineLabelShowPrintOnBibDetails', '0', '', 'If turned on, a \"Print Label\" link will appear for each item on the bib details page in the staff interface.', 'YesNo');"
    );
    print "Upgrade done ( added Show Spine Label Printer on Bib Items Details preferences )\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.113';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    my $value = C4::Context->preference("XSLTResultsDisplay");
    $dbh->do(
        "INSERT IGNORE INTO systempreferences (variable,value,type)
         VALUES('OPACXSLTResultsDisplay','$value','YesNo')"
    );
    $value = C4::Context->preference("XSLTDetailsDisplay");
    $dbh->do(
        "INSERT IGNORE INTO systempreferences (variable,value,type)
         VALUES('OPACXSLTDetailsDisplay','$value','YesNo')"
    );
    print
"Upgrade done (added two new syspref: OPACXSLTResultsDisplay and OPACXSLTDetailDisplay). You may have to go in Admin > System preference to tweak XSLT related syspref both in OPAC and Search tabs.\n     ";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.114';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES('AutoSelfCheckAllowed', '0', 'For corporate and special libraries which want web-based self-check available from any PC without the need for a manual staff login. Most libraries will want to leave this turned off. If on, requires self-check ID and password to be entered in AutoSelfCheckID and AutoSelfCheckPass sysprefs.', '', 'YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AutoSelfCheckID','','Staff ID with circulation rights to be used for automatic web-based self-check. Only applies if AutoSelfCheckAllowed syspref is turned on.','','free')"
    );
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AutoSelfCheckPass','','Password to be used for automatic web-based self-check. Only applies if AutoSelfCheckAllowed syspref is turned on.','','free')"
    );
    print "Upgrade to $DBversion done ( Added AutoSelfCheckAllowed, AutoSelfCheckID, and AutoShelfCheckPass system preference )\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.115';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do('UPDATE aqorders SET quantityreceived = 0 WHERE quantityreceived IS NULL');
    $dbh->do('ALTER TABLE aqorders MODIFY COLUMN quantityreceived smallint(6) NOT NULL DEFAULT 0');
    print "Upgrade to $DBversion done ( Default aqorders.quantityreceived to 0 )\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.116';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    if ( C4::Context->preference('OrderPdfFormat') eq 'pdfformat::example' ) {
        $dbh->do("UPDATE `systempreferences` set value='pdfformat::layout2pages' WHERE variable='OrderPdfFormat'");
    }
    print "Upgrade done ( corrected default OrderPdfFormat value if still set wrong )\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.117';
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.05.003") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("UPDATE language_rfc4646_to_iso639 SET iso639_2_code = 'por' WHERE rfc4646_subtag='pt' ");
	    print "Upgrade to $DBversion done (corrected ISO 639-2 language code for Portuguese)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.118';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    my ($count) = $dbh->selectrow_array(
        "SELECT count(*) FROM information_schema.columns
                                         WHERE table_name = 'aqbudgets_planning'
                                         AND column_name = 'display'"
    );
    if ( $count < 1 ) {
        $dbh->do("ALTER TABLE aqbudgets_planning ADD COLUMN display tinyint(1) DEFAULT 1");
    }
    print "Upgrade to $DBversion done (bug 4203: add display column to aqbudgets_planning if missing)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.119';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    eval { require Locale::Currency::Format };
    if ( !$@ ) {
        print "Upgrade to $DBversion done (Locale::Currency::Format installed.)\n";
        SetVersion($DBversion);
    } else {
        print "Upgrade to $DBversion done.\n";
        print
"NOTICE: The Locale::Currency::Format package is not installed on your system or not found in \@INC.\nThis dependency is required in order to include fine information in overdue notices.\nPlease ask your system administrator to install this package.\n";
        SetVersion($DBversion);
    }
}

$DBversion = '3.01.00.120';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        q{
INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('soundon','0','Enable circulation sounds during checkin and checkout in the staff interface.  Not supported by all web browsers yet.','','YesNo');
}
    );
    print "Upgrade to $DBversion done (bug 1080: add soundon system preference for circulation sounds)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.121';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `reserves` ADD `expirationdate` DATE DEFAULT NULL");
    $dbh->do("ALTER TABLE `reserves` ADD `lowestPriority` tinyint(1) NOT NULL");
    $dbh->do("ALTER TABLE `old_reserves` ADD `expirationdate` DATE DEFAULT NULL");
    $dbh->do("ALTER TABLE `old_reserves` ADD `lowestPriority` tinyint(1) NOT NULL");
    print "Upgrade to $DBversion done ( Added Additional Fields to Reserves tables )\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.122';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        q{
      INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)
      VALUES ('OAI-PMH:ConfFile', '', 'If empty, Koha OAI Server operates in normal mode, otherwise it operates in extended mode.','','File');
}
    );
    print "Upgrade to $DBversion done. — Add a new system preference OAI-PMF:ConfFile\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.123";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        "INSERT IGNORE INTO `permissions` (`module_bit`, `code`, `description`) VALUES
        (6, 'place_holds', 'Place holds for patrons')"
    );
    $dbh->do(
        "INSERT IGNORE INTO `permissions` (`module_bit`, `code`, `description`) VALUES
        (6, 'modify_holds_priority', 'Modify holds priority')"
    );
    $dbh->do("UPDATE `userflags` SET `flagdesc` = 'Place and modify holds for patrons' WHERE `flag` = 'reserveforothers'");
    print "Upgrade to $DBversion done (Add granular permission for holds modification and update description of reserveforothers permission)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.124';
if ( C4::Context->preference('Version') < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.03.001") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do( "
	        INSERT IGNORE INTO `letter` (module, code, name, title, content)         VALUES('reserves', 'HOLDPLACED', 'Hold Placed on Item', 'Hold Placed on Item','A hold has been placed on the following item : <<title>> (<<biblionumber>>) by the user <<firstname>> <<surname>> (<<cardnumber>>).');
	    " );
	    print "Upgrade to $DBversion done (bug 3242: add HOLDPLACED letter template, which is used when emailLibrarianWhenHoldIsPlaced is enabled)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.01.00.125';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do( "
        INSERT IGNORE INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'PrintNoticesMaxLines', '0', '', 'If greater than 0, sets the maximum number of lines an overdue notice will print. If the number of items is greater than this number, the notice will end with a warning asking the borrower to check their online account for a full list of overdue items.', 'Integer' );
    " );
    $dbh->do( "
        INSERT IGNORE INTO message_transport_types (message_transport_type) values ('print');
    " );
    print "Upgrade to $DBversion done (bug 3482: Printable hold and overdue notices)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.126";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('ILS-DI','0','Enable ILS-DI services. See http://your.opac.name/cgi-bin/koha/ilsdi.pl for online documentation.','','YesNo')"
    );
    $dbh->do(
"INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('ILS-DI:AuthorizedIPs','127.0.0.1','A comma separated list of IP addresses authorized to access the web services.','','free')"
    );

    print "Upgrade to $DBversion done (Adding ILS-DI updates and ILS-DI:Authorized_IPs)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.127';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE messages CHANGE branchcode branchcode varchar(10);");
    print "Upgrade to $DBversion done (bug 4190: messages in patron account did not work with branchcodes > 4)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.128';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do('CREATE INDEX budget_id ON aqorders (budget_id );');
    print "Upgrade to $DBversion done (bug 4331: index orders by budget_id)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.129";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("UPDATE `permissions` SET `code` = 'items_batchdel' WHERE `permissions`.`module_bit` =13 AND `permissions`.`code` = 'batchdel' LIMIT 1 ;");
    $dbh->do("UPDATE `permissions` SET `code` = 'items_batchmod' WHERE `permissions`.`module_bit` =13 AND `permissions`.`code` = 'batchmod' LIMIT 1 ;");
    print "Upgrade done (Change permissions names for item batch modification / deletion)\n";

    SetVersion($DBversion);
}

$DBversion = "3.01.00.130";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("UPDATE reserves SET expirationdate = NULL WHERE expirationdate = '0000-00-00'");
    print "Upgrade done (change reserves.expirationdate values of 0000-00-00 to NULL (bug 1532)";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.131";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        q{
INSERT IGNORE INTO message_transport_types (message_transport_type) VALUES ('print'),('feed');
    }
    );
    print "Upgrade to $DBversion done (adding print and feed message transport types)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.132";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        q{
    ALTER TABLE language_descriptions ADD INDEX subtag_type_lang (subtag, type, lang);
    }
    );
    print "Upgrade to $DBversion done (Adding index to language_descriptions table)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.133';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do(
"INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('OverduesBlockCirc','noblock','When checking out an item should overdues block checkout, generate a confirmation dialogue, or allow checkout','noblock|confirmation|block','Choice')"
    );
    print "Upgrade to $DBversion done (bug 4405: added OverduesBlockCirc syspref to control whether circulation is blocked if a borrower has overdues)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.134';
if ( C4::Context->preference('Version') < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.06.007") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("INSERT IGNORE INTO `permissions` (`module_bit` , `code` , `description`) VALUES ('9', 'edit_items', 'Edit items');");
	    print "Upgrade to $DBversion done (Added 'Edit Items' permission)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.01.00.135";
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.05.002") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("UPDATE systempreferences SET options = 'Calendar|Days|Datedue' WHERE variable = 'useDaysMode'");
	    print "Upgrade to $DBversion done (upgrade useDaysMode syspref)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.01.00.136";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{
	CREATE TABLE IF NOT EXISTS pending_offline_operations (
	    operationid INT(11) NOT NULL AUTO_INCREMENT,
	    userid VARCHAR(30) NOT NULL,
	    branchcode VARCHAR(10) NOT NULL,
	    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    action VARCHAR(10) NOT NULL,
	    barcode VARCHAR(20) NOT NULL,
	    cardnumber VARCHAR(16) NULL,
	    PRIMARY KEY (operationid)
	);
	}
    );

    print "Upgrade to $DBversion done (adding one table : pending_offline_operations)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.137";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    my $borrowers = $dbh->selectcol_arrayref( "SELECT borrowernumber from borrowers where debarred <>0;", { Columns => [1] } );
    $dbh->do("ALTER TABLE borrowers MODIFY debarred DATE DEFAULT NULL;");
    $dbh->do( "UPDATE borrowers set debarred='9999-12-31' where borrowernumber IN (" . join( ",", @$borrowers ) . ");" ) if ($borrowers and scalar(@$borrowers)>0);
    $dbh->do("ALTER TABLE borrowers ADD COLUMN debarredcomment VARCHAR(255) DEFAULT NULL AFTER debarred;");
    print "Upgrade done (Change borrowers.debarred into Date )\n";

    SetVersion($DBversion);
}

$DBversion = "3.02.00.001";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("UPDATE `permissions` SET `code` = 'items_batchdel' WHERE `permissions`.`module_bit` =13 AND `permissions`.`code` = 'batchdel' LIMIT 1 ;");
    $dbh->do("UPDATE `permissions` SET `code` = 'items_batchmod' WHERE `permissions`.`module_bit` =13 AND `permissions`.`code` = 'batchmod' LIMIT 1 ;");
    print "Upgrade done (Change permissions names for item batch modification / deletion)\n";

    SetVersion($DBversion);
}

#$DBversion = "3.02.00.003";
#if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
#    $dbh->do("INSERT IGNORE INTO systempreferences SET variable='IndependentBranchPatron',value=0");
#
#    print "Upgrade to $DBversion done (IndependentBranchPatron syspref added)\n";
#    SetVersion($DBversion);
#}

$DBversion = "3.02.00.003";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.06.004") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("INSERT IGNORE INTO systempreferences  (variable,value,explanation,options,type) VALUES('IndependentBranchPatron','0','If ON, librarian patron search can only be done on patron of same library as librarian',NULL,'YesNo');");
	    print "Upgrade to $DBversion done (Add IndependentBranchPatron system preference to be able to limit patron search to librarian's Library)\n";
	}
    SetVersion ($DBversion);
}


$DBversion = '3.02.00.004';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
	my $count_column=count_column_from_table("enrolmentperioddate","categories");
    if($count_column==0)
    {
    $dbh->do('ALTER TABLE `categories` ADD COLUMN `enrolmentperioddate` DATE NULL DEFAULT NULL AFTER `enrolmentperiod`');
    }
    print "Upgrade done (Add enrolment period date support)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.005";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{
	ALTER TABLE items ADD statisticvalue VARCHAR(80);
	}
    );

    print "Upgrade to $DBversion done (adding statisticvalue field to items)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.006";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE issuingrules ADD COLUMN `allowonshelfholds` TINYINT(1) NOT NULL DEFAULT '0';");

    my $sth = $dbh->prepare("SELECT value from systempreferences where variable = 'AllowOnShelfHolds';");
    $sth->execute();
    my $data = $sth->fetchrow_hashref();

    my $updsth = $dbh->prepare("UPDATE issuingrules SET allowonshelfholds = ?");
    $updsth->execute( $data->{value} );

    $dbh->do("DELETE FROM systempreferences where variable = 'AllowOnShelfHolds';");
    print "Upgrade done (Migrating AllowOnShelfHold to smart-rules)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.007";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `borrowers` ADD `gonenoaddresscomment` VARCHAR(255) DEFAULT NULL AFTER `gonenoaddress`");
    $dbh->do("ALTER TABLE `borrowers` ADD `lostcomment` VARCHAR(255) DEFAULT NULL AFTER `lost`");

    print "Upgrade to $DBversion done (add comments in borrowers)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.008";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE issuingrules MODIFY renewalsallowed SMALLINT(6) NULL DEFAULT NULL;");
    $dbh->do("ALTER TABLE issuingrules MODIFY reservesallowed SMALLINT(6) NULL DEFAULT NULL;");
    $dbh->do("ALTER TABLE issuingrules MODIFY allowonshelfholds TINYINT(1) NULL DEFAULT NULL;");
    $dbh->do('ALTER TABLE issuingrules ADD COLUMN `renewalperiod` SMALLINT(6) NULL default NULL AFTER `renewalsallowed`;');

    print "Upgrade done (Allow NULL in issuingrules)\n";
    print "Upgrade done (Add renewalperiod)\n";

    SetVersion($DBversion);
}

$DBversion = '3.02.00.009';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
	my $count_column=count_column_from_table("enrolmentperioddate","categories");
    if($count_column==0)
    {
    $dbh->do('ALTER TABLE `categories` ADD COLUMN `enrolmentperioddate` DATE NULL DEFAULT NULL AFTER `enrolmentperiod`');
    }
    print "Upgrade done (Add enrolment period date support)\n";
    SetVersion($DBversion);
}

$DBversion = '3.02.00.010';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `issuingrules` ADD `holdrestricted` TINYINT( 1 ) NULL default NULL ");
    $dbh->do(
        'INSERT IGNORE INTO issuingrules (branchcode, categorycode, itemtype,holdrestricted,maxissueqty)
                SELECT "*","*","*",holdallowed,maxissueqty
                FROM default_circ_rules defaults
              ON DUPLICATE KEY update maxissueqty=defaults.maxissueqty, holdrestricted=defaults.holdallowed'
    );
    $dbh->do(
        'INSERT IGNORE INTO issuingrules (branchcode, itemtype, categorycode,maxissueqty)
                    SELECT "*","*",categorycode,maxissueqty from default_borrower_circ_rules defaults
              ON DUPLICATE KEY update maxissueqty=defaults.maxissueqty'
    );
    $dbh->do(
        'INSERT IGNORE INTO issuingrules (branchcode, categorycode, itemtype,holdrestricted,maxissueqty)
                    SELECT branchcode,"*","*",holdallowed,maxissueqty from default_branch_circ_rules defaults
              ON DUPLICATE KEY update maxissueqty=defaults.maxissueqty, holdrestricted=defaults.holdallowed'
    );
    $dbh->do(
        'INSERT IGNORE INTO issuingrules (branchcode, categorycode, itemtype,holdrestricted)
                    SELECT "*","*",itemtype,holdallowed from default_branch_item_rules defaults 
              ON DUPLICATE KEY update holdrestricted=defaults.holdallowed'
    );
    for my $tablename ( qw(default_circ_rules default_branch_circ_rules default_branch_item_rules default_borrower_circ_rules) ) {
        $dbh->do("DROP TABLE $tablename");
    }
    print "Upgrade done (Updating Circulation rules\n Inserting defaults values into issuingrules \n removing defaults table)\n";
    SetVersion($DBversion);
}

$DBversion = '3.02.00.011';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
	my $count_column=count_column_from_table("renewalperiod","issuingrules");
    if($count_column==0)
    {
    	$dbh->do('ALTER TABLE issuingrules ADD COLUMN `renewalperiod` SMALLINT(6) NULL default NULL AFTER `renewalsallowed`;');
    }
    print "Upgrade done (Add renewalperiod)\n";
    SetVersion($DBversion);
}

$DBversion = '3.02.00.012';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{INSERT IGNORE INTO `saved_sql` (
    `id`, `borrowernumber`, `date_created`, `last_modified`, `savedsql`, `last_run`, `report_name`, `type`, `notes`)
    VALUES 
    (NULL , '0', NULL , NULL , 'select branchcode, count(*) from borrowers where dateexpiry >= <<start_date>> and dateexpiry <= <<end_date>> group by branchcode', NULL, 'ESGBU_Patrons', '1', ''),
    (NULL , '0', NULL , NULL , 'select branchcode, count(borrowers.borrowernumber) from borrowers, statistics where borrowers.borrowernumber = statistics.borrowernumber AND statistics.datetime >= <<start_date>> AND  statistics.datetime <= <<end_date>> AND (type = "issue" or type = "renew") group by branchcode', NULL, 'ESGBU_Active_Patrons', '1', ''),
    (NULL , '0', NULL , NULL , 'select branch, count(*) from statistics where (type="issue" or type="renew") and datetime >= <<start_date>> and datetime <= <<end_date>> group by branch', NULL, 'ESGBU_Number_of_issues', '1', ''),
    (NULL , '0', NULL , NULL , 'SELECT substring(marcxml,LOCATE("<leader>",marcxml)+8+6,1) rtype , count(*) from biblioitems GROUP BY rtype', NULL, 'ESGBU_Item_Types', '1', '')
    ;}
    );
    print "Upgrade done (Add ESGBU saved reports)\n";
    SetVersion($DBversion);
}

$DBversion = '3.02.00.013';
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.06.005") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do(
	qq{INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACviewISBD','1','Allow display of ISBD view of bibiographic records in OPAC','','YesNo');}
	    );
	    $dbh->do(
	qq{INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACviewMARC','1','Allow display of MARC view of bibiographic records in OPAC','','YesNo');}
	    );
	    print "Upgrade to $DBversion done (Added OPAC ISBD and MARC view sysprefs)\n";
	}
    SetVersion($DBversion);
}

$DBversion = '3.02.00.014';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
qq{INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACPickupLocation','1','Allow choice for Pickup Library reserve at OPAC','','YesNo');}
    );

    print "Upgrade to $DBversion done (Added OPACPickupLocation sysprefs)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.015";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("INSERT IGNORE INTO permissions (module_bit, code, description) VALUES (1, 'view_borrowers_logs', 'Enables log access for the borrower on staff viw')");
    print "Upgrade to $DBversion done (Adding permissions for staff member access to borrowers logs.  )\n";
    SetVersion($DBversion);
}
$DBversion = "3.02.00.016";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        q{
INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('CI-3M:AuthorizedIPs','','Liste des IPs autorisées pour la magnétisation 3M','','Free');
    }
    );
    print "Upgrade to $DBversion done (Adding permissions for staff member access to borrowers logs.  )\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.017";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	$dbh->do("UPDATE authorised_values SET authorised_value=UPPER(authorised_value) WHERE category='COUNTRY'");
    print "Upgrade to $DBversion done (Converts COUNTRY authorised values to uppercase)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.02.00.018';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
      INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)
      VALUES ('OPACSearchReboundBy', 'term', 'determines if the search rebound use authority number or term.','term|authority','Choice');
});
    print "Upgrade to $DBversion done. — Add a new system preference OPACSearchReboundBy\n";
    SetVersion ($DBversion);
}

$DBversion = '3.02.00.019';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
      ALTER TABLE reserves ADD `reservenumber` int(11) NOT NULL AUTO_INCREMENT FIRST, ADD PRIMARY KEY (`reservenumber`);
});
    $dbh->do(q{
      ALTER TABLE old_reserves ADD `reservenumber` int(11) NOT NULL AUTO_INCREMENT FIRST, ADD PRIMARY KEY (`reservenumber`);
});

    print "Upgrade to $DBversion done. — Add reservenumber in reserves table\n";
    SetVersion ($DBversion);
}

$DBversion = '3.02.00.020';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
      ALTER TABLE borrower_attribute_types ADD `display_checkout` TINYINT(1) NOT NULL DEFAULT '0';
});
    print "Upgrade to $DBversion done. — Add display_checkout in borrower_attribute_types table\n";
    SetVersion ($DBversion);
}

$DBversion = '3.02.00.021';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
      INSERT IGNORE INTO permissions (module_bit, code, description) VALUES(13, 'batchedit', 'Perform batch modification of records');
});
    print "Upgrade to $DBversion done. — Add permission to batch modifications on records\n";
    SetVersion ($DBversion);
}

$DBversion = '3.02.00.022';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
      DELETE FROM `systempreferences` WHERE variable='XSLTDetailsDisplay';
});
    $dbh->do(q{
      DELETE FROM `systempreferences` WHERE variable='XSLTResultsDisplay';
});
    $dbh->do(q{
      INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES('OPACXSLTResultsDisplay','','','Enable XSL stylesheet control over results page display on OPAC exemple : ../koha-tmpl/opac-tmpl/prog/en/xslt/MARC21slim2OPACResults.xsl','Free');
});
    print "Upgrade to $DBversion done. — Delete XSLTDetailsDisplay and XSLTResultsDisplay system preferences, and add OPACXSLTResultsDisplay\n";
    SetVersion ($DBversion);
}

$DBversion = '3.02.00.023';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    my $count_column1=count_column_from_table("itemstocknumberidx","items");
    if($count_column1>0)
    {
    $dbh->do(q{
	ALTER TABLE items 
		DROP KEY `itemstocknumberidx`;
    });
    }
    my $count_column2=count_column_from_table("itemsstocknumberidx","items");
    if($count_column2>0)
    {
    $dbh->do(q{
	ALTER TABLE items 
		DROP KEY `itemsstocknumberidx`;
    });
    }
    my $count_column3=count_column_from_table("delitemstocknumberidx","deleteditems");
    if($count_column3>0)
    {
    $dbh->do(q{
	ALTER TABLE deleteditems 
		DROP KEY `delitemstocknumberidx`;
    });
    }
    print "Upgrade to $DBversion done. — Add permission to batch modifications on records\n";
    SetVersion ($DBversion);
}

$DBversion = "3.02.00.024";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	$dbh->do(q{
    ALTER TABLE deletedborrowers ADD COLUMN gonenoaddresscomment VARCHAR(255) AFTER gonenoaddress, ADD COLUMN lostcomment VARCHAR(255) AFTER lost,ADD COLUMN debarredcomment VARCHAR(255) AFTER debarred;
    });
	$dbh->do(q{
    ALTER TABLE deletedborrowers CHANGE COLUMN debarred debarred DATE;
    });
    print "Upgrade to $DBversion done (Synching  deletedborrowers with borrowers)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.02.00.025";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.06.011") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("ALTER TABLE borrowers ADD KEY `guarantorid` (guarantorid);");
	    print "Upgrade to $DBversion done (Add index on guarantorid)\n";
	}
    SetVersion ($DBversion);
}

$DBversion = "3.02.00.026";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
      INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES('AllowMultipleHoldsPerBib','','','Enter here the different itemtypes separated by space you want to allow librarians or OPAC users (if OPACItemHolds is enabled) to set holds on multiple items','Free');
      });
    print "Upgrade to $DBversion done (Add index on guarantorid)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.02.00.027";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	$dbh->do(q{
		UPDATE `letter` set content='Dear <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nYou have a hold available for pickup as of <<reserves.waitingdate>>:\r\n\r\nTitle: <<biblio.title>>\r\nAuthor: <<biblio.author>>\r\nCopy: <<items.barcode>>\r\nLocation: <<branches.branchname>>\r\n<<branches.branchaddress1>>\r\n<<branches.branchaddress2>>\r\n<<branches.branchaddress3>>' where module='reserves' and code='HOLD'});
	print "Upgrade to $DBversion done\n";
	SetVersion ($DBversion);
}

$DBversion = "3.02.00.028";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	$dbh->do(q{
        ALTER TABLE issuingrules ADD COLUMN `holdspickupdelay` INT(11) NULL default NULL ;
    });
	print "Upgrade to $DBversion done\n";
	SetVersion ($DBversion);
}

$DBversion = "3.02.00.029";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	$dbh->do(q{
	ALTER TABLE `search_history` ADD `limit_desc` VARCHAR( 255 ) NULL DEFAULT NULL AFTER `query_cgi` ,
	ADD `limit_cgi` VARCHAR( 255 ) NULL DEFAULT NULL AFTER `limit_desc` 
    });
	print "Upgrade to $DBversion done\n";
	SetVersion ($DBversion);
}

$DBversion = "3.02.00.030";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES  
		('OpacAdvancedSearchContent','','Use HTML tabs to create your own advanced search menu in OPAC','70|10','Textarea'),
		('AdvancedSearchContent','','Use HTML tabs to create your own advanced search menu','70|10','Textarea')");
    print "Upgrade to $DBversion done (adding OpacAdvancedSearchContent and AdvancedSearchContent systempref, in 'Searching' tab)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.031";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
$dbh->do("
	INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('SpecifyDueDate',1,'Define whether to display \"Specify Due Date\" form in Circulation','','YesNo');
	");
    print "Upgrade to $DBversion done\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.033";
if ( C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.04.017") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("
		INSERT IGNORE INTO `permissions` (`module_bit`, `code`, `description`) VALUES
		(15, 'check_expiration', 'Check the expiration of a serial'),
		(15, 'claim_serials', 'Claim missing serials'),
		(15, 'create_subscription', 'Create a new subscription'),
		(15, 'delete_subscription', 'Delete an existing subscription'),
		(15, 'edit_subscription', 'Edit an existing subscription'),
		(15, 'receive_serials', 'Serials receiving'),
		(15, 'renew_subscription', 'Renew a subscription'),
		(15, 'routing', 'Routing');
		");
	    print "Upgrade to $DBversion done (adding more permissions)\n";
	}
    SetVersion($DBversion);
}

$DBversion = "3.02.00.034";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{
	CREATE TABLE IF NOT EXISTS pending_offline_operations (
	    operationid INT(11) NOT NULL AUTO_INCREMENT,
	    userid VARCHAR(30) NOT NULL,
	    branchcode VARCHAR(10) NOT NULL,
	    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    action VARCHAR(10) NOT NULL,
	    barcode VARCHAR(20) NOT NULL,
	    cardnumber VARCHAR(16) NULL,
	    PRIMARY KEY (operationid)
	);
	}
    );

    print "Upgrade to $DBversion done (adding one table : pending_offline_operations)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.035";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
	my $count_column=count_column_from_table("statisticvalue","items");
    if($count_column==0)
    {
    	$dbh->do("ALTER TABLE `items` ADD `statisticvalue` varchar(80) DEFAULT NULL");
    }
    print "Upgrade to $DBversion done (adding statisticvalue in 'items' tab)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.036";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.01.003") or $compare_version >TransformToNum("3.01.00.000"))
	{
		my $search=$dbh->selectall_arrayref("select * from systempreferences where variable='dontmerge'");
		if (@$search){
			my $search=$dbh->selectall_arrayref("select * from systempreferences where variable='MergeAuthoritiesOnUpdate'");
			if (@$search){
	    		$dbh->do("DELETE FROM systempreferences WHERE variable='dontmerge'");
			}
			else {
	    		$dbh->do("UPDATE systempreferences set variable='MergeAuthoritiesOnUpdate' ,value=1-value*1 WHERE variable='dontmerge'");
			}
		}
		else {
	    	$dbh->do("INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('MergeAuthoritiesOnUpdate', '1', 'if ON, Updating authorities will automatically updates biblios',NULL,'YesNo')");
		}
	    print "Upgrade to $DBversion done (add new syspref MergeAuthoritiesOnUpdate)\n";
	}
    SetVersion ($DBversion);
}

$DBversion = "3.02.00.037";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
if($compare_version < TransformToNum("3.00.01.004") or $compare_version >TransformToNum("3.01.00.000"))
{
  if (lc(C4::Context->preference('marcflavour')) eq "unimarc"){
    $dbh->do("INSERT IGNORE INTO `marc_tag_structure` (`tagfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `authorised_value`, `frameworkcode`) VALUES ('099', 'Informations locales', '', 0, 0, '', '');");
    $dbh->do("INSERT IGNORE INTO `marc_tag_structure` (`frameworkcode`,`tagfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `authorised_value`) SELECT DISTINCT(frameworkcode),'099', 'Informations locales', '', 0, 0, '' from biblio_framework");
    $dbh->do(<<ENDOFSQL);
INSERT IGNORE INTO marc_subfield_structure (`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value`, `authtypecode`, `value_builder`, `isurl`, `hidden`, `seealso`, `link`, `defaultvalue`,frameworkcode )
VALUES ('099', 'c', 'date creation notice (koha)', '', 0, 0, 'biblio.datecreated', -1, '', '', '', NULL, 0, '', '', NULL, ''),
('099', 'd', 'date modification notice (koha)', '', 0, 0, 'biblio.timestamp', -1, '', '', '', NULL, 0, '', '', NULL, ''),
('995', '2', 'Perdu', '', 0, 0, 'items.itemlost', 10, '', '', '', NULL, 1, '', NULL, NULL, '');
ENDOFSQL
    $dbh->do(<<ENDOFSQL1);
INSERT IGNORE INTO marc_subfield_structure (`frameworkcode`,`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value`, `authtypecode`, `value_builder`, `isurl`, `hidden`, seealso, link, defaultvalue )
SELECT DISTINCT(frameworkcode), '099', 'c', 'date creation notice (koha)', '', 0, 0, 'biblio.datecreated', -1, '', '', '', NULL, 0, '', '', NULL from biblio_framework;
ENDOFSQL1
    $dbh->do(<<ENDOFSQL2);
INSERT IGNORE INTO marc_subfield_structure (`frameworkcode`,`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value`, `authtypecode`, `value_builder`, `isurl`, `hidden`, seealso, link, defaultvalue )
SELECT DISTINCT(frameworkcode), '099', 'd', 'date modification notice (koha)', '', 0, 0, 'biblio.timestamp', -1, '', '', '', NULL, 0, '', '', NULL from biblio_framework;
ENDOFSQL2
    $dbh->do(<<ENDOFSQL3);
INSERT IGNORE INTO marc_subfield_structure (`frameworkcode`,`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value`, `authtypecode`, `value_builder`, `isurl`, `hidden`, seealso, link, defaultvalue )
SELECT DISTINCT(frameworkcode), '995', '2', 'Perdu', '', 0, 0, 'items.itemlost', 10, '', '', '', NULL, 1, '', NULL, NULL from biblio_framework;
ENDOFSQL3
      print "Upgrade to $DBversion done (updates MARC framework structure)\n";
    }
}
    SetVersion ($DBversion);
}


$DBversion = "3.02.00.038";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.04.019") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    my $authdisplayhierarchy = C4::Context->preference('AuthDisplayHierarchy');
	    if ($authdisplayhierarchy < 1){
	       $dbh->do("INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)VALUES('AuthDisplayHierarchy','0','To display authorities in a hierarchy way. Put ON only if you have a thesaurus. Default is OFF','','YesNo')");
	    };
	    print "Upgrade to $DBversion done (new AuthDisplayHierarchy, )\n";
	}
    SetVersion ($DBversion);
}  

$DBversion = "3.02.00.039";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
if($compare_version < TransformToNum("3.00.04.020")or $compare_version >TransformToNum("3.01.00.000"))
{
    if (lc(C4::Context->preference('marcflavour')) eq "unimarc"){
        $dbh->do(<<OPACISBD);
INSERT IGNORE INTO systempreferences (variable,explanation,options,type,value)
VALUES('OPACISBD','OPAC ISBD View','90|20', 'Textarea',
'#200|<h2>Titre : |{200a}{. 200c}{ : 200e}{200d}{. 200h}{. 200i}|</h2>\r\n#500|<label class="ipt">Autres titres : </label>|{500a}{. 500i}{. 500h}{. 500m}{. 500q}{. 500k}<br/>|\r\n#517|<label class="ipt"> </label>|{517a}{ : 517e}{. 517h}{, 517i}<br/>|\r\n#541|<label class="ipt"> </label>|{541a}{ : 541e}<br/>|\r\n#200||<label class="ipt">Auteurs : </label><br/>|\r\n#700||<a href="opac-search.pl?op=do_search&marclist=7009&operator==&type=intranet&value={7009}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Chercher sur l''auteur"></a>{700c}{ 700b}{ 700a}{ 700d}{ (700f)}{. 7004}<br/>|\r\n#701||<a href="opac-search.pl?op=do_search&marclist=7009&operator==&type=intranet&value={7019}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Chercher sur l''auteur"></a>{701c}{ 701b}{ 701a}{ 701d}{ (701f)}{. 7014}<br/>|\r\n#702||<a href="opac-search.pl?op=do_search&marclist=7009&operator==&type=intranet&value={7029}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Chercher sur l''auteur"></a>{702c}{ 702b}{ 702a}{ 702d}{ (702f)}{. 7024}<br/>|\r\n#710||<a href="opac-search.pl?op=do_search&marclist=7109&operator==&type=intranet&value={7109}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Chercher sur l''auteur"></a>{710a}{ (710c)}{. 710b}{ : 710d}{ ; 710f}{ ; 710e}<br/>|\r\n#711||<a href="opac-search.pl?op=do_search&marclist=7109&operator==&type=intranet&value={7119}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Chercher sur l''auteur"></a>{711a}{ (711c)}{. 711b}{ : 711d}{ ; 711f}{ ; 711e}<br/>|\r\n#712||<a href="opac-search.pl?op=do_search&marclist=7109&operator==&type=intranet&value={7129}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Chercher sur l''auteur"></a>{712a}{ (712c)}{. 712b}{ : 712d}{ ; 712f}{ ; 712e}<br/>|\r\n#210|<label class="ipt">Lieu d''édition : </label>|{ 210a}<br/>|\r\n#210|<label class="ipt">Editeur : </label>|{ 210c}<br/>|\r\n#210|<label class="ipt">Date d''édition : </label>|{ 210d}<br/>|\r\n#215|<label class="ipt">Description : </label>|{215a}{ : 215c}{ ; 215d}{ + 215e}|<br/>\r\n#225|<label class="ipt">Collection :</label>|<a href="opac-search.pl?op=do_search&marclist=225a&operator==&type=intranet&value={225a}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Chercher sur {225a}"></a>{ (225a}{ = 225d}{ : 225e}{. 225h}{. 225i}{ / 225f}{, 225x}{ ; 225v}|)<br/>\r\n#200||<label class="ipt">Sujets : </label><br/>|\r\n#600||<a href="opac-search.pl?op=do_search&marclist=6009&operator==&type=intranet&value={6009}"><img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Search on {6009}"></a>{ 600c}{ 600b}{ 600a}{ 600d}{ (600f)} {-- 600x }{-- 600z }{-- 600y}<br />|\r\n#604||<a href="opac-search.pl?op=do_search&marclist=6049&operator==&type=intranet&value={6049}"><img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Search on {6049}"></a>{ 604a}{. 604t}<br />|\r\n#601||<a href="opac-search.pl?op=do_search&marclist=6019&operator==&type=intranet&value={6019}"><img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Search on {6019}"></a>{ 601a}{ (601c)}{. 601b}{ : 601d} { ; 601f}{ ; 601e}{ -- 601x }{-- 601z }{-- 601y}<br />|\r\n#605||<a href="opac-search.pl?op=do_search&marclist=6059&operator==&type=intranet&value={6059}"><img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Search on {6059}"></a>{ 605a}{. 605i}{. 605h}{. 605k}{. 605m}{. 605q} {-- 605x }{-- 605z }{-- 605y }{-- 605l}<br />|\r\n#606||<a href="opac-search.pl?op=do_search&marclist=6069&operator==&type=intranet&value={6069}"><img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Search on {6069}">xx</a>{ 606a}{-- 606x }{-- 606z }{606y }<br />|\r\n#607||<a href="opac-search.pl?op=do_search&marclist=6079&operator==&type=intranet&value={6079}"><img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Search on {6079}"></a>{ 607a}{-- 607x}{-- 607z}{-- 607y}<br />|\r\n#010|<label class="ipt">ISBN : </label>|{010a}|<br/>\r\n#011|<label class="ipt">ISSN : </label>|{011a}|<br/>\r\n#200||<label class="ipt">Notes : </label>|<br/>\r\n#300||{300a}|<br/>\r\n#320||{320a}|<br/>\r\n#327||{327a}|<br/>\r\n#328||{328a}|<br/>\r\n#200||<br/><h2>Exemplaires</h2>|\r\n#200|<table>|<th>Localisation</th><th>Cote</th>|\r\n#995||<tr><td>{995e}&nbsp;&nbsp;</td><td> {995k}</td></tr>|\r\n#200|||</table>')
OPACISBD
    }else{
        $dbh->do(<<OPACISBDEN);
INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) 
VALUES('OPACISBD','#100||{ 100a }{ 100b }{ 100c }{ 100d }{ 110a }{ 110b }{ 110c }{ 110d }{ 110e }{ 110f }{ 110g }{ 130a }{ 130d }{ 130f }{ 130g }{ 130h }{ 130k }{ 130l }{ 130m }{ 130n }{ 130o }{ 130p }{ 130r }{ 130s }{ 130t }|<br/><br/>\r\n#245||{ 245a }{ 245b }{245f }{ 245g }{ 245k }{ 245n }{ 245p }{ 245s }{ 245h }|\r\n#246||{ : 246i }{ 246a }{ 246b }{ 246f }{ 246g }{ 246n }{ 246p }{ 246h }|\r\n#242||{ = 242a }{ 242b }{ 242n }{ 242p }{ 242h }|\r\n#245||{ 245c }|\r\n#242||{ = 242c }|\r\n#250| - |{ 250a }{ 250b }|\r\n#254|, |{ 254a }|\r\n#255|, |{ 255a }{ 255b }{ 255c }{ 255d }{ 255e }{ 255f }{ 255g }|\r\n#256|, |{ 256a }|\r\n#257|, |{ 257a }|\r\n#258|, |{ 258a }{ 258b }|\r\n#260| - |{ 260a }{ 260b }{ 260c }|\r\n#300| - |{ 300a }{ 300b }{ 300c }{ 300d }{ 300e }{ 300f }{ 300g }|\r\n#306| - |{ 306a }|\r\n#307| - |{ 307a }{ 307b }|\r\n#310| - |{ 310a }{ 310b }|\r\n#321| - |{ 321a }{ 321b }|\r\n#340| - |{ 3403 }{ 340a }{ 340b }{ 340c }{ 340d }{ 340e }{ 340f }{ 340h }{ 340i }|\r\n#342| - |{ 342a }{ 342b }{ 342c }{ 342d }{ 342e }{ 342f }{ 342g }{ 342h }{ 342i }{ 342j }{ 342k }{ 342l }{ 342m }{ 342n }{ 342o }{ 342p }{ 342q }{ 342r }{ 342s }{ 342t }{ 342u }{ 342v }{ 342w }|\r\n#343| - |{ 343a }{ 343b }{ 343c }{ 343d }{ 343e }{ 343f }{ 343g }{ 343h }{ 343i }|\r\n#351| - |{ 3513 }{ 351a }{ 351b }{ 351c }|\r\n#352| - |{ 352a }{ 352b }{ 352c }{ 352d }{ 352e }{ 352f }{ 352g }{ 352i }{ 352q }|\r\n#362| - |{ 362a }{ 351z }|\r\n#440| - |{ 440a }{ 440n }{ 440p }{ 440v }{ 440x }|.\r\n#490| - |{ 490a }{ 490v }{ 490x }|.\r\n#800| - |{ 800a }{ 800b }{ 800c }{ 800d }{ 800e }{ 800f }{ 800g }{ 800h }{ 800j }{ 800k }{ 800l }{ 800m }{ 800n }{ 800o }{ 800p }{ 800q }{ 800r }{ 800s }{ 800t }{ 800u }{ 800v }|.\r\n#810| - |{ 810a }{ 810b }{ 810c }{ 810d }{ 810e }{ 810f }{ 810g }{ 810h }{ 810k }{ 810l }{ 810m }{ 810n }{ 810o }{ 810p }{ 810r }{ 810s }{ 810t }{ 810u }{ 810v }|.\r\n#811| - |{ 811a }{ 811c }{ 811d }{ 811e }{ 811f }{ 811g }{ 811h }{ 811k }{ 811l }{ 811n }{ 811p }{ 811q }{ 811s }{ 811t }{ 811u }{ 811v }|.\r\n#830| - |{ 830a }{ 830d }{ 830f }{ 830g }{ 830h }{ 830k }{ 830l }{ 830m }{ 830n }{ 830o }{ 830p }{ 830r }{ 830s }{ 830t }{ 830v }|.\r\n#500|<br/><br/>|{ 5003 }{ 500a }|\r\n#501|<br/><br/>|{ 501a }|\r\n#502|<br/><br/>|{ 502a }|\r\n#504|<br/><br/>|{ 504a }|\r\n#505|<br/><br/>|{ 505a }{ 505t }{ 505r }{ 505g }{ 505u }|\r\n#506|<br/><br/>|{ 5063 }{ 506a }{ 506b }{ 506c }{ 506d }{ 506u }|\r\n#507|<br/><br/>|{ 507a }{ 507b }|\r\n#508|<br/><br/>|{ 508a }{ 508a }|\r\n#510|<br/><br/>|{ 5103 }{ 510a }{ 510x }{ 510c }{ 510b }|\r\n#511|<br/><br/>|{ 511a }|\r\n#513|<br/><br/>|{ 513a }{513b }|\r\n#514|<br/><br/>|{ 514z }{ 514a }{ 514b }{ 514c }{ 514d }{ 514e }{ 514f }{ 514g }{ 514h }{ 514i }{ 514j }{ 514k }{ 514m }{ 514u }|\r\n#515|<br/><br/>|{ 515a }|\r\n#516|<br/><br/>|{ 516a }|\r\n#518|<br/><br/>|{ 5183 }{ 518a }|\r\n#520|<br/><br/>|{ 5203 }{ 520a }{ 520b }{ 520u }|\r\n#521|<br/><br/>|{ 5213 }{ 521a }{ 521b }|\r\n#522|<br/><br/>|{ 522a }|\r\n#524|<br/><br/>|{ 524a }|\r\n#525|<br/><br/>|{ 525a }|\r\n#526|<br/><br/>|{\\n510i }{\\n510a }{ 510b }{ 510c }{ 510d }{\\n510x }|\r\n#530|<br/><br/>|{\\n5063 }{\\n506a }{ 506b }{ 506c }{ 506d }{\\n506u }|\r\n#533|<br/><br/>|{\\n5333 }{\\n533a }{\\n533b }{\\n533c }{\\n533d }{\\n533e }{\\n533f }{\\n533m }{\\n533n }|\r\n#534|<br/><br/>|{\\n533p }{\\n533a }{\\n533b }{\\n533c }{\\n533d }{\\n533e }{\\n533f }{\\n533m }{\\n533n }{\\n533t }{\\n533x }{\\n533z }|\r\n#535|<br/><br/>|{\\n5353 }{\\n535a }{\\n535b }{\\n535c }{\\n535d }|\r\n#538|<br/><br/>|{\\n5383 }{\\n538a }{\\n538i }{\\n538u }|\r\n#540|<br/><br/>|{\\n5403 }{\\n540a }{ 540b }{ 540c }{ 540d }{\\n520u }|\r\n#544|<br/><br/>|{\\n5443 }{\\n544a }{\\n544b }{\\n544c }{\\n544d }{\\n544e }{\\n544n }|\r\n#545|<br/><br/>|{\\n545a }{ 545b }{\\n545u }|\r\n#546|<br/><br/>|{\\n5463 }{\\n546a }{ 546b }|\r\n#547|<br/><br/>|{\\n547a }|\r\n#550|<br/><br/>|{ 550a }|\r\n#552|<br/><br/>|{ 552z }{ 552a }{ 552b }{ 552c }{ 552d }{ 552e }{ 552f }{ 552g }{ 552h }{ 552i }{ 552j }{ 552k }{ 552l }{ 552m }{ 552n }{ 562o }{ 552p }{ 552u }|\r\n#555|<br/><br/>|{ 5553 }{ 555a }{ 555b }{ 555c }{ 555d }{ 555u }|\r\n#556|<br/><br/>|{ 556a }{ 506z }|\r\n#563|<br/><br/>|{ 5633 }{ 563a }{ 563u }|\r\n#565|<br/><br/>|{ 5653 }{ 565a }{ 565b }{ 565c }{ 565d }{ 565e }|\r\n#567|<br/><br/>|{ 567a }|\r\n#580|<br/><br/>|{ 580a }|\r\n#581|<br/><br/>|{ 5633 }{ 581a }{ 581z }|\r\n#584|<br/><br/>|{ 5843 }{ 584a }{ 584b }|\r\n#585|<br/><br/>|{ 5853 }{ 585a }|\r\n#586|<br/><br/>|{ 5863 }{ 586a }|\r\n#020|<br/><br/><label>ISBN: </label>|{ 020a }{ 020c }|\r\n#022|<br/><br/><label>ISSN: </label>|{ 022a }|\r\n#222| = |{ 222a }{ 222b }|\r\n#210| = |{ 210a }{ 210b }|\r\n#024|<br/><br/><label>Standard No.: </label>|{ 024a }{ 024c }{ 024d }{ 0242 }|\r\n#027|<br/><br/><label>Standard Tech. Report. No.: </label>|{ 027a }|\r\n#028|<br/><br/><label>Publisher. No.: </label>|{ 028a }{ 028b }|\r\n#013|<br/><br/><label>Patent No.: </label>|{ 013a }{ 013b }{ 013c }{ 013d }{ 013e }{ 013f }|\r\n#030|<br/><br/><label>CODEN: </label>|{ 030a }|\r\n#037|<br/><br/><label>Source: </label>|{ 037a }{ 037b }{ 037c }{ 037f }{ 037g }{ 037n }|\r\n#010|<br/><br/><label>LCCN: </label>|{ 010a }|\r\n#015|<br/><br/><label>Nat. Bib. No.: </label>|{ 015a }{ 0152 }|\r\n#016|<br/><br/><label>Nat. Bib. Agency Control No.: </label>|{ 016a }{ 0162 }|\r\n#600|<br/><br/><label>Subjects--Personal Names: </label>|{\\n6003 }{\\n600a}{ 600b }{ 600c }{ 600d }{ 600e }{ 600f }{ 600g }{ 600h }{--600k}{ 600l }{ 600m }{ 600n }{ 600o }{--600p}{ 600r }{ 600s }{ 600t }{ 600u }{--600x}{--600z}{--600y}{--600v}|\r\n#610|<br/><br/><label>Subjects--Corporate Names: </label>|{\\n6103 }{\\n610a}{ 610b }{ 610c }{ 610d }{ 610e }{ 610f }{ 610g }{ 610h }{--610k}{ 610l }{ 610m }{ 610n }{ 610o }{--610p}{ 610r }{ 610s }{ 610t }{ 610u }{--610x}{--610z}{--610y}{--610v}|\r\n#611|<br/><br/><label>Subjects--Meeting Names: </label>|{\\n6113 }{\\n611a}{ 611b }{ 611c }{ 611d }{ 611e }{ 611f }{ 611g }{ 611h }{--611k}{ 611l }{ 611m }{ 611n }{ 611o }{--611p}{ 611r }{ 611s }{ 611t }{ 611u }{--611x}{--611z}{--611y}{--611v}|\r\n#630|<br/><br/><label>Subjects--Uniform Titles: </label>|{\\n630a}{ 630b }{ 630c }{ 630d }{ 630e }{ 630f }{ 630g }{ 630h }{--630k }{ 630l }{ 630m }{ 630n }{ 630o }{--630p}{ 630r }{ 630s }{ 630t }{--630x}{--630z}{--630y}{--630v}|\r\n#648|<br/><br/><label>Subjects--Chronological Terms: </label>|{\\n6483 }{\\n648a }{--648x}{--648z}{--648y}{--648v}|\r\n#650|<br/><br/><label>Subjects--Topical Terms: </label>|{\\n6503 }{\\n650a}{ 650b }{ 650c }{ 650d }{ 650e }{--650x}{--650z}{--650y}{--650v}|\r\n#651|<br/><br/><label>Subjects--Geographic Terms: </label>|{\\n6513 }{\\n651a}{ 651b }{ 651c }{ 651d }{ 651e }{--651x}{--651z}{--651y}{--651v}|\r\n#653|<br/><br/><label>Subjects--Index Terms: </label>|{ 653a }|\r\n#654|<br/><br/><label>Subjects--Facted Index Terms: </label>|{\\n6543 }{\\n654a}{--654b}{--654x}{--654z}{--654y}{--654v}|\r\n#655|<br/><br/><label>Index Terms--Genre/Form: </label>|{\\n6553 }{\\n655a}{--655b}{--655x }{--655z}{--655y}{--655v}|\r\n#656|<br/><br/><label>Index Terms--Occupation: </label>|{\\n6563 }{\\n656a}{--656k}{--656x}{--656z}{--656y}{--656v}|\r\n#657|<br/><br/><label>Index Terms--Function: </label>|{\\n6573 }{\\n657a}{--657x}{--657z}{--657y}{--657v}|\r\n#658|<br/><br/><label>Index Terms--Curriculum Objective: </label>|{\\n658a}{--658b}{--658c}{--658d}{--658v}|\r\n#050|<br/><br/><label>LC Class. No.: </label>|{ 050a }{ / 050b }|\r\n#082|<br/><br/><label>Dewey Class. No.: </label>|{ 082a }{ / 082b }|\r\n#080|<br/><br/><label>Universal Decimal Class. No.: </label>|{ 080a }{ 080x }{ / 080b }|\r\n#070|<br/><br/><label>National Agricultural Library Call No.: </label>|{ 070a }{ / 070b }|\r\n#060|<br/><br/><label>National Library of Medicine Call No.: </label>|{ 060a }{ / 060b }|\r\n#074|<br/><br/><label>GPO Item No.: </label>|{ 074a }|\r\n#086|<br/><br/><label>Gov. Doc. Class. No.: </label>|{ 086a }|\r\n#088|<br/><br/><label>Report. No.: </label>|{ 088a }|','ISBD','70|10','Textarea');
OPACISBDEN
    }
    print "Upgrade to $DBversion done (new OPACISBD syspref, )\n";
}
    SetVersion ($DBversion);
}

$DBversion = "3.02.00.040";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.06.001") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    my $value = $dbh->selectrow_array("SELECT value FROM systempreferences WHERE variable = 'HomeOrHoldingBranch'");
	    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('HomeOrHoldingBranchReturn','$value','Used by Circulation to determine which branch of an item to check checking-in items','holdingbranch|homebranch','Choice');");
	    print "Upgrade to $DBversion done (Add HomeOrHoldingBranchReturn system preference)\n";
	}
    SetVersion ($DBversion);
}

$DBversion = "3.02.00.041";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.06.002") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("ALTER TABLE issues CHANGE COLUMN `itemnumber` `itemnumber` int(11) UNIQUE DEFAULT NULL;");
	    $dbh->do("ALTER TABLE serialitems ADD CONSTRAINT `serialitems_sfk_2` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`) ON DELETE CASCADE ON UPDATE CASCADE;");
	    print "Upgrade to $DBversion done (Improve serialitems table security)\n";
	}
    SetVersion ($DBversion);
}

$DBversion = "3.02.00.042";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.06.003") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("UPDATE systempreferences set value='../koha-tmpl/opac-tmpl/prog/en/xslt/".C4::Context->preference('marcflavour')."slim2OPACDetail.xsl',type='Free' where variable='XSLTDetailsDisplay' AND value=1;");
	    $dbh->do("UPDATE systempreferences set value='../koha-tmpl/opac-tmpl/prog/en/xslt/".C4::Context->preference('marcflavour')."slim2OPACResults.xsl',type='Free' where variable='XSLTResultsDisplay' AND value=1;");
	    $dbh->do("UPDATE systempreferences set value='',type='Free' where variable='XSLTDetailsDisplay' AND value=0;");
	    $dbh->do("UPDATE systempreferences set value='',type='Free' where variable='XSLTResultsDisplay' AND value=0;");
	    print "Upgrade to $DBversion done (Improve XSLT)\n";
	}
    SetVersion ($DBversion);
}

$DBversion = '3.02.00.043';
if (C4::Context->preference('Version') < TransformToNum($DBversion)){
	if($compare_version < TransformToNum("3.00.06.006") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("
	        INSERT IGNORE INTO `letter` (module, code, name, title, content)         VALUES('reserves', 'STAFFHOLDPLACED', 'Hold Placed on Item (from staff)', 'Hold Placed on Item (from staff)','A hold has been placed on the following item from the intranet : <<title>> (<<biblionumber>>) for the user <<firstname>> <<surname>> (<<cardnumber>>).');
	    ");
	    print "Upgrade to $DBversion done (Added notice for hold from staff)\n";
	}
    SetVersion ($DBversion);
}

$DBversion = '3.02.00.044';
if (C4::Context->preference('Version') < TransformToNum($DBversion)){
	if($compare_version < TransformToNum("3.00.06.008") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("INSERT IGNORE INTO `user_permissions` (borrowernumber,`module_bit` , `code` ) (SELECT borrowernumber, '9', 'edit_items' FROM borrowers WHERE (flags<<9 && 00000001));");
	    print "Upgrade to $DBversion done (updating permissions for catalogers)\n";
	}
    SetVersion ($DBversion);
}

$DBversion = "3.02.00.045";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	if($compare_version < TransformToNum("3.00.06.010") or $compare_version >TransformToNum("3.01.00.000"))
	{
	    $dbh->do("INSERT systempreferences (value, variable) select value, 'XSLTDetailFilename' from systempreferences where variable='XSLTDetailsDisplay';");
	    $dbh->do("INSERT systempreferences (value, variable) select value, 'XSLTResultsFilename' from systempreferences where variable='XSLTResultsDisplay' ;");
	    $dbh->do("UPDATE systempreferences set value=(LENGTH(value)>0),type='YesNo' where variable='XSLTDetailsDisplay';");
	    $dbh->do("UPDATE systempreferences set value=(LENGTH(value)>0),type='YesNo' where variable='XSLTResultsDisplay';");
	    print "Upgrade to $DBversion done (Improvements to XSLT Support)\n";
	}
    SetVersion ($DBversion);
}


$DBversion = "3.02.00.046";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `auth_subfield_structure` ADD CONSTRAINT `auth_subfield_structure_ibfk_1` FOREIGN KEY (`authtypecode`, `tagfield`) REFERENCES `auth_tag_structure` (`authtypecode`, `tagfield`) ON DELETE CASCADE");
    print "Upgrade to $DBversion done (adding foreign key on auth_subfield_structure.authtypecode and auth_subfield_structure.tagfield for deleting on cascade)\n";
}

$DBversion = "3.02.00.047";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `accountlines` ADD `note` text NULL default NULL");
    print "Upgrade to $DBversion done (adding note field in accountlines table)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.048";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `accountlines` ADD `manager_id` int( 11 ) NULL ");
    print "Upgrade to $DBversion done (adding manager_id field in accountlines table)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.049";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(
        qq{
	ALTER TABLE `aqbasketgroups` ADD `freedeliveryplace` TEXT NULL AFTER `deliveryplace`;
	}
    );

    print "Upgrade to $DBversion done (adding freedeliveryplace to basketgroups)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.050";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `accountlines` ADD `meansofpayment` text NULL default NULL");
    print "Upgrade to $DBversion done (adding meansofpayment field in accountlines table)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.051";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `accountlines` ADD `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST");
    print "Upgrade to $DBversion done (adding id field in accountlines table)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.052";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("
	INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('MeansOfPayment','Undefined|Cash|Cheque|Bank card|Credit transfer|Direct debit','Define means of payment for borrowers payments','Undefined|Cash|Cheque|Bank card|Credit transfer|Direct debit','free');
	");
    print "Upgrade to $DBversion done (adding MeansOfPayment syspref)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.053";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `accountlines` ADD COLUMN `time` TIME  DEFAULT NULL AFTER `date`");
    print "Upgrade to $DBversion done (adding time field in accountlines table)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.054";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("
	INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacHiddenItems','','This syspref allows to define custom rules for hiding specific items at opac. See docs/opac/OpacHiddenItems.txt for more informations.','','Textarea');
	");
    print "Upgrade to $DBversion done (Adding OpacHiddenItems syspref)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.055";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("
	ALTER TABLE `items` DROP INDEX `itemsstocknumberidx`;
	");
	$dbh->do("
	ALTER TABLE items ADD INDEX itemsstocknumberidx (stocknumber);
	");
    print "Upgrade to $DBversion done (remove unicity from index itemsstocknumberidx)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.056";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("
	INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('PrefillItem','0','When a new item is added, should it be prefilled with last created item values?','','YesNo');
	");
    print "Upgrade to $DBversion done (Adding PrefillItem syspref)\n";
    SetVersion($DBversion);
}


$DBversion = "3.02.00.057";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("
	INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('uploadPath','','Sets the upload path for the upload.pl plugin','','');
	");

    $dbh->do("
	INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('uploadWebPath','','Set the upload path starting from document root for the upload.pl plugin','','');
	");
    print "Upgrade to $DBversion done (Adding upload plugin sysprefs)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.058";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("
	INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('uploadPath','','Sets the upload path for the upload.pl plugin','','');
	");

    $dbh->do("
	INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('uploadWebPath','','Set the upload path starting from document root for the upload.pl plugin','','');
	");
    print "Upgrade to $DBversion done (Adding upload plugin sysprefs)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.059";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE overduerules ALTER delay1 SET DEFAULT NULL, ALTER delay2 SET DEFAULT NULL, ALTER delay3 SET DEFAULT NULL");
    print "Upgrade to $DBversion done (Setting NULL default value for delayn columns in table overduerules)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.060";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(qq{
	INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('BlockRenewWhenOverdue','0','If Set, when item is overdue, renewals are blocked','','YesNo');
    });
    print "Upgrade to $DBversion done (Adds New System preference BlockRenewWhenOverdue)\n";
    SetVersion($DBversion);
}

$DBversion = "3.02.00.061";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(qq{
    	ALTER TABLE `deleteditems` ADD `statisticvalue` varchar(80) DEFAULT NULL
    });
    print "Upgrade to $DBversion done (Adds Column statisticvalue in table deleteditems)\n";
    SetVersion($DBversion);
}

$DBversion = "3.06.00.001";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	$dbh->do(q{
    DROP TABLE IF EXISTS `indexes`;
    });
	$dbh->do(q{
    CREATE TABLE `indexes` (
      `id` bigint unsigned NOT NULL auto_increment,
      `code` varchar(255) NOT NULL DEFAULT '',
      `label` varchar(255) DEFAULT NULL,
      `type` varchar(20) DEFAULT NULL,
      `faceted` tinyint(4) DEFAULT NULL,
      `ressource_type` varchar(255) DEFAULT NULL,
      `mandatory` tinyint(4) DEFAULT NULL,
      `sortable` tinyint(4) DEFAULT NULL,
      `plugin` varchar(255) DEFAULT NULL,
      `avlist` varchar(255) DEFAULT NULL,
      `rpn_index` INT  NOT NULL,
      `ccl_index_name` VARCHAR(255)  NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE (`code`,`type`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    });
	$dbh->do(q{
    DROP TABLE IF EXISTS `indexmappings`;
    });
	$dbh->do(q{
    CREATE TABLE `indexmappings` (
      `field` char(3) DEFAULT NULL,
      `subfield` char(1) DEFAULT NULL,
      `index` varchar(255) DEFAULT NULL,
      `ressource_type` varchar(20) DEFAULT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    });

    if ( C4::Context->preference("marcflavour") eq 'UNIMARC' ) {
        $dbh->do(q{
        LOCK TABLES `indexes` WRITE;
        });
        $dbh->do(q{
        INSERT INTO `indexes` (`code`,`label`,`type`,`faceted`,`ressource_type`,`mandatory`,`sortable`,`plugin`,`ccl_index_name`, `rpn_index`, `avlist`) VALUES 
                ('upc','UPC','str',0,'biblio',0,0,'','','',''),
                ('onloan','En prêt','int',0,'biblio',0,0,'','','',''),
                ('name','Auteur personne','ste',0,'biblio',0,0,'','','',''),
                ('music-source','Source éditoriale','str',0,'biblio',0,0,'','','',''),
                ('music-number','Référence éditoriale','int',0,'biblio',0,0,'','','',''),
                ('video-mt','video-mt','str',0,'biblio',0,0,'','','',''),
                ('graphics-types','graphics-types','str',0,'biblio',0,0,'','','',''),
                ('type-of-serial','Type de périodique','str',0,'biblio',0,0,'','','',''),
                ('illustration-code','Code d\'illustration','str',0,'biblio',0,0,'C4::Search::Plugins::Illustration','','',''),
                ('second-author-firstname','Prénom du second auteur','ste',0,'biblio',0,0,'','','',''),
                ('second-author-name','Nom du second auteur','ste',0,'biblio',0,0,'','','',''),
                ('author-name-personal','Nom de l\'auteur','ste',0,'biblio',0,0,'','','',''),
                ('author-firstname','Prénom de l\'auteur','ste',0,'biblio',0,0,'','','',''),
                ('rflag','Indicateur de vendange','int',0,'biblio',0,0,'','','',''),
                ('harvestdate','Date de dernière vendange','date',0,'biblio',0,0,'','harvestdate','',''),
                ('identifier','Identifiant notice','str',0,'biblio',0,0,'','','',''),
                ('status','Statut','str',0,'biblio',0,0,'','','','ETAT'),
                ('serialnote','Note sur le numéro','ste',0,'biblio',0,0,'','','',''),
                ('location','Localisation','str',0,'biblio',0,1,'','mc-loc','8013','LOC'),
                ('acqdate','Date d\'acquisition','date',0,'biblio',0,1,'','','',''),
                ('item','Exemplaire','str',0,'biblio',0,0,'','item','9520',''),
                ('lost','Exemplaire perdu','int',0,'biblio',0,0,'','','','LOST'),
                ('subject','Sujet','ste',1,'biblio',0,0,'','su','21',''),
                ('callnumber','Cote','ste',0,'biblio',0,1,'','cn','',''),
                ('availability','Disponibilité','int',0,'biblio',0,0,'C4::Search::Plugins::Availability','','',''),
                ('barcode','Code barre','str',0,'biblio',0,0,'','bc','8023',''),
                ('holdingbranch','Dépositaire','str',1,'biblio',0,0,'','','',''),
                ('abstract','Résumé','txt',0,'biblio',0,0,'','ab','62',''),
                ('dewey','Cote dewey','ste',0,'biblio',0,1,'','','',''),
                ('itype','Type de document','str',0,'biblio',0,0,'','mc-itype','8031',''),
                ('ccode','Code de collection','str',1,'biblio',0,1,'','mc-ccode','8009',''),
                ('authorities','Formes Rejetées','txt',0,'biblio',0,0,'C4::Search::Plugins::Authorities','','',''),
                ('lastmodified','Date de modification','date',0,'biblio',0,0,'','','',''),
                ('genre','Genre','str',0,'biblio',0,0,'','','',''),
                ('audience','Public','str',0,'biblio',0,0,'C4::Search::Plugins::Audience','','',''),
                ('authid','AuthId','int',0,'biblio',0,0,'','an','',''),
                ('title','Titre','ste',0,'biblio',1,1,'','ti','4',''),
                ('title-series','Collection','ste',1,'biblio',0,0,'','se','5',''),
                ('title-cover','Titre de couverture','ste',0,'biblio',0,0,'','','',''),
                ('author','Auteur','ste',1,'biblio',0,1,'C4::Search::Plugins::Author','au','1003',''),
                ('title-uniform','Titre uniforme','ste',0,'biblio',0,0,'','ut','6',''),
                ('isbn','ISBN','str',0,'biblio',0,0,'C4::Search::Plugins::DeleteDash','nb','7',''),
                ('entereddate','Date de saisie','date',0,'biblio',0,0,'','','',''),
                ('title-host','Document hôte','ste',0,'biblio',0,0,'','','',''),
                ('biblionumber','Biblionumber','int',0,'biblio',0,0,'','','',''),
                ('name-geographic','Sujet géographique','ste',0,'biblio',0,0,'','','',''),
                ('pubplace','Lieu de publication','ste',0,'biblio',0,0,'','','',''),
                ('lang','Langue','str',0,'biblio',0,0,'','','','LANG'),
                ('ppn','PPN','str',0,'biblio',0,0,'','','',''),
                ('personnal-name','Sujet nom de personne','ste',0,'biblio',0,0,'','','',''),
                ('note','Note','txt',0,'biblio',0,0,'','nt','63',''),
                ('issn','ISSN','str',0,'biblio',0,0,'C4::Search::Plugins::DeleteDash','ns','8',''),
                ('corporate-name','Auteur collectivité','ste',0,'biblio',0,0,'','cpn','2',''),
                ('size','Taille','str',0,'biblio',0,0,'','','',''),
                ('ean','EAN','str',0,'biblio',1,0,'','','',''),
                ('publisher','Éditeur','ste',0,'biblio',0,0,'','pb','1018',''),
                ('itemcallnumber','Cote exemplaire','ste',0,'biblio',0,0,'','','',''),
                ('pubdate','Date de publication','date',0,'biblio',0,1,'C4::Search::Plugins::Date','','',''),
                ('homebranch','Propriétaire','str',0,'biblio',0,0,'','branch','8011',''),
                ('serials','Ressources continues','ste',0,'biblio',0,0,'','','',''),
                ('printed-music','Musique imprimée','ste',0,'biblio',0,0,'','','',''),
                ('electronic-ressource','Ressource électronique','ste',0,'biblio',0,0,'','','',''),
                ('country-heading','Pays d\'édition','str',0,'biblio',0,0,'','','',''),
                ('auth-heading','heading','ste',0,'authority',1,1,'','he','',''),
                ('auth-heading-main','heading-main','ste',0,'authority',1,1,'','','',''),
                ('auth-local-number','local-number','str',0,'authority',0,0,'','','',''),
                ('auth-note','note','txt',0,'authority',0,0,'','','',''),
                ('auth-parallel','parallel','ste',0,'authority',0,0,'','','',''),
                ('auth-ppn','ppn','str',0,'authority',0,0,'','','',''),
                ('auth-see','see','ste',0,'authority',0,0,'','','',''),
                ('auth-see-also','see-also','ste',0,'authority',0,0,'','','',''),
                ('auth-type','type','str',0,'authority',0,0,'','at','',''),
                ('auth-summary','summary','ste',0,'authority',1,1,'C4::Search::Plugins::Summary','','',''),
                ('usedinxbiblios','Used in X biblios','int',0,'authority',1,1,'C4::Search::Plugins::UsedInXBiblios','','','');
        });
        $dbh->do(q{
        UNLOCK TABLES;
        });
        $dbh->do(q{
        LOCK TABLES `indexmappings` WRITE;
        });
        $dbh->do(q{
        INSERT INTO `indexmappings` VALUES 
        ('711','*','corporate-name','biblio'),
        ('710','*','corporate-name','biblio'),
        ('702','b','second-author-firstname','biblio'),
        ('702','a','second-author-name','biblio'),
        ('702','*','name','biblio'),
        ('701','*','name','biblio'),
        ('700','b','author-firstname','biblio'),
        ('700','a','author-name-personal','biblio'),
        ('700','*','name','biblio'),
        ('7..','9','authid','biblio'),
        ('7..','*','author','biblio'),
        ('225','g','author','biblio'),
        ('686','a','callnumber','biblio'),
        ('676','a','dewey','biblio'),
        ('676','a','callnumber','biblio'),
        ('610','*','subject','biblio'),
        ('608','a','genre','biblio'),
        ('607','*','name-geographic','biblio'),
        ('606','*','subject','biblio'),
        ('605','*','subject','biblio'),
        ('604','*','subject','biblio'),
        ('603','*','subject','biblio'),
        ('602','*','personnal-name','biblio'),
        ('602','*','subject','biblio'),
        ('601','*','subject','biblio'),
        ('600','*','subject','biblio'),
        ('600','*','personnal-name','biblio'),
        ('6..','9','authid','biblio'),
        ('5..','9','authid','biblio'),
        ('5..','*','title','biblio'),
        ('464','t','title-host','biblio'),
        ('461','t','title-host','biblio'),
        ('410','t','title-series','biblio'),
        ('403','t','title-uniform','biblio'),
        ('4..','t','title','biblio'),
        ('4..','d','pubdate','biblio'),
        ('4..','9','authid','biblio'),
        ('330','a','abstract','biblio'),
        ('3..','9','authid','biblio'),
        ('3..','*','note','biblio'),
        ('230','a','electronic-ressource','biblio'),
        ('225','x','issn','biblio'),
        ('225','v','title-series','biblio'),
        ('225','i','title-series','biblio'),
        ('225','h','title-series','biblio'),
        ('225','e','title-series','biblio'),
        ('225','d','title-series','biblio'),
        ('225','a','title-series','biblio'),
        ('210','d','pubdate','biblio'),
        ('210','c','publisher','biblio'),
        ('210','a','pubplace','biblio'),
        ('208','*','printed-music','biblio'),
        ('207','*','serials','biblio'),
        ('205','*','title','biblio'),
        ('202','a','country-heading','biblio'),
        ('200','i','title-cover','biblio'),
        ('200','i','title','biblio'),
        ('200','f','author','biblio'),
        ('200','g','author','biblio'),
        ('200','e','title','biblio'),
        ('200','e','title-cover','biblio'),
        ('200','d','title','biblio'),
        ('200','c','title','biblio'),
        ('200','b','itype','biblio'),
        ('200','a','title','biblio'),
        ('200','a','title-cover','biblio'),
        ('2..','9','authid','biblio'),
        ('116','a','graphics-types','biblio'),
        ('115','a','video-mt','biblio'),
        ('110','a','type-of-serial','biblio'),
        ('105','a','illustration-code','biblio'),
        ('101','a','lang','biblio'),
        ('1..','9','authid','biblio'),
        ('099','t','ccode','biblio'),
        ('099','d','lastmodified','biblio'),
        ('099','c','entereddate','biblio'),
        ('099','c','acqdate','biblio'),
        ('091','b','harvestdate','biblio'),
        ('091','a','rflag','biblio'),
        ('090','9','biblionumber','biblio'),
        ('073','a','ean','biblio'),
        ('073','*','identifier','biblio'),
        ('072','a','upc','biblio'),
        ('072','*','identifier','biblio'),
        ('071','b','music-source','biblio'),
        ('071','a','music-number','biblio'),
        ('071','*','identifier','biblio'),
        ('035','*','identifier','biblio'),
        ('011','a','issn','biblio'),
        ('011','*','identifier','biblio'),
        ('010','a','isbn','biblio'),
        ('010','*','identifier','biblio'),
        ('009','@','identifier','biblio'),
        ('009','@','ppn','biblio'),
        ('001','@','biblionumber','biblio'),
        ('001','@','identifier','biblio'),
        ('712','*','corporate-name','biblio'),
        ('8..','9','authid','biblio'),
        ('995','*','item','biblio'),
        ('995','2','lost','biblio'),
        ('995','6','acqdate','biblio'),
        ('995','a','homebranch','biblio'),
        ('995','b','homebranch','biblio'),
        ('995','c','holdingbranch','biblio'),
        ('995','d','holdingbranch','biblio'),
        ('995','e','location','biblio'),
        ('995','f','barcode','biblio'),
        ('995','h','ccode','biblio'),
        ('995','k','callnumber','biblio'),
        ('995','k','itemcallnumber','biblio'),
        ('995','n','onloan','biblio'),
        ('995','o','status','biblio'),
        ('995','r','itype','biblio'),
        ('995','u','note','biblio'),
        ('995','v','serialnote','biblio'),
        ('200','*','auth-heading','authority'),
        ('210','*','auth-heading','authority'),
        ('215','*','auth-heading','authority'),
        ('216','*','auth-heading','authority'),
        ('220','*','auth-heading','authority'),
        ('230','*','auth-heading','authority'),
        ('240','*','auth-heading','authority'),
        ('250','*','auth-heading','authority'),
        ('260','*','auth-heading','authority'),
        ('280','*','auth-heading','authority'),
        ('200','a','auth-heading-main','authority'),
        ('210','a','auth-heading-main','authority'),
        ('215','a','auth-heading-main','authority'),
        ('216','a','auth-heading-main','authority'),
        ('220','a','auth-heading-main','authority'),
        ('230','a','auth-heading-main','authority'),
        ('240','a','auth-heading-main','authority'),
        ('250','a','auth-heading-main','authority'),
        ('260','a','auth-heading-main','authority'),
        ('280','a','auth-heading-main','authority'),
        ('001','@','auth-local-number','authority'),
        ('3..','a','auth-note','authority'),
        ('700','*','auth-parallel','authority'),
        ('710','*','auth-parallel','authority'),
        ('715','*','auth-parallel','authority'),
        ('716','*','auth-parallel','authority'),
        ('720','*','auth-parallel','authority'),
        ('730','*','auth-parallel','authority'),
        ('740','*','auth-parallel','authority'),
        ('750','*','auth-parallel','authority'),
        ('760','*','auth-parallel','authority'),
        ('780','*','auth-parallel','authority'),
        ('009','@','auth-ppn','authority'),
        ('400','*','auth-see','authority'),
        ('410','*','auth-see','authority'),
        ('415','*','auth-see','authority'),
        ('416','*','auth-see','authority'),
        ('420','*','auth-see','authority'),
        ('430','*','auth-see','authority'),
        ('440','*','auth-see','authority'),
        ('450','*','auth-see','authority'),
        ('460','*','auth-see','authority'),
        ('480','*','auth-see','authority'),
        ('500','*','auth-see-also','authority'),
        ('510','*','auth-see-also','authority'),
        ('515','*','auth-see-also','authority'),
        ('516','*','auth-see-also','authority'),
        ('520','*','auth-see-also','authority'),
        ('530','*','auth-see-also','authority'),
        ('540','*','auth-see-also','authority'),
        ('550','*','auth-see-also','authority'),
        ('560','*','auth-see-also','authority'),
        ('580','*','auth-see-also','authority'),
        ('942','*','auth-type','authority'),
        ('152','b','auth-type','authority');
        });
        $dbh->do(q{
        UNLOCK TABLES;
        });
    }
    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('SolrAPI','http://localhost:8080/solr','Solr web service URL.','','Free');");
    $dbh->do("UPDATE `systempreferences` SET options='score|str_callnumber|date_pubdate|date_acqdate|txt_title|str_author' WHERE variable IN ('defaultSortField', 'OPACdefaultSortField')");
    $dbh->do("UPDATE `systempreferences` SET options='asc|desc' WHERE variable IN ('defaultSortOrder', 'OPACdefaultSortOrder')");
    $dbh->do("UPDATE `systempreferences` SET value='score' WHERE variable IN ('defaultSortField', 'OPACdefaultSortField')");
    $dbh->do("UPDATE `systempreferences` SET value='desc' WHERE variable IN ('defaultSortOrder', 'OPACdefaultSortOrder')");
    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES('SearchEngine','Solr','Solr|Zebra','Search Engine','Choice')");
    print "Upgrade to $DBversion done (Solr tables)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.06.00.013";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("UPDATE `systempreferences` SET options='acqdate|author|callnumber|ccode|dewey|location|pubdate|score|title' WHERE variable IN ('defaultSortField', 'OPACdefaultSortField')");
    $dbh->do("UPDATE `systempreferences` SET options='asc|desc' WHERE variable IN ('defaultSortOrder', 'OPACdefaultSortOrder')");
    $dbh->do("UPDATE `systempreferences` SET value='desc' WHERE variable IN ('defaultSortOrder', 'OPACdefaultSortOrder')");
    $dbh->do("UPDATE `systempreferences` SET value='score' WHERE variable IN ('defaultSortField', 'OPACdefaultSortField')");
    print "Upgrade to $DBversion done (Update System Preferences defaultSortField and OPACdefaultSortField and *SortOrder)\n";
    SetVersion($DBversion);
}

$DBversion = "3.06.00.040";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('numFacetsDisplay','100','Specify the maximum number of facets to display for an index','','Integer');");
    print "Upgrade to $DBversion done (Add System Preferences numFacetsDisplay)\n";
    SetVersion($DBversion);
}

$DBversion = "3.06.00.049";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('SearchOPACHides','','Construct the opac query with this string at the end.','','Free');");
    print "Upgrade to $DBversion done (Add System Preferences SearchOPACHides)\n";
    SetVersion($DBversion);
}

$DBversion = "3.06.00.050";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(qq{UPDATE `systempreferences` SET options=CONCAT(options,"|SolrIndexOff") WHERE variable ='SearchEngine'});
    print "Upgrade to $DBversion done (Update System Preferences SearchEngine with SolrIndexOff)\n";
    SetVersion($DBversion);
}

$DBversion = "3.06.00.052";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(qq{
    INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('numSearchRSSResults',50,'Specify the maximum number of results to display on a RSS page of results',NULL,'Integer');
    });
    print "Upgrade to $DBversion done (Adds New System preference numSearchRSSResults)\n";
    SetVersion($DBversion);
}

$DBversion = "3.06.00.053";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(qq{INSERT IGNORE INTO `systempreferences` (variable,value,explanation,options,type) VALUES('maxItemsInSearchResults',20,'Specify the maximum number of items to display in results',NULL,'Integer')});
    print "Upgrade to $DBversion done (Add System Preferences MaxItemsInSearchResults)\n";
    SetVersion($DBversion);
}

$DBversion = "3.06.00.059";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(qq{
        UPDATE `indexes` SET plugin='C4::Search::Plugins::Date' WHERE plugin='C4::Search::Plugins::PubDate'
    });
    print "Upgrade to $DBversion done (PubDate plugin name changed)\n";
    SetVersion($DBversion);
}

$DBversion = "3.06.00.073";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do(qq{
        ALTER TABLE `borrowers` ADD `lostcomment` VARCHAR(255) DEFAULT NULL AFTER `lost`
    });
    print "Upgrade to $DBversion done (Add missing field borrower.lostcomment)\n";
    SetVersion($DBversion);
}

$DBversion = "3.06.00.078";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `export_format` MODIFY `csv_separator` VARCHAR(4) NOT NULL, MODIFY `field_separator` VARCHAR(4) NOT NULL, MODIFY `subfield_separator` VARCHAR(4) NOT NULL");
    print "Upgrade to $DBversion done (Modify column type for export_format table)\n";
    SetVersion($DBversion);
}

$DBversion = "3.06.00.080";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("
        INSERT IGNORE INTO `systempreferences`
            (variable,value,explanation,options,type)
            VALUES('hidenoitems','0','This syspref allows to hide biblio if there is no items to show (see OpacHiddenItems)','','YesNo');
    ");
    print "Upgrade to $DBversion done (Adding hidenoitems syspref)\n";
    SetVersion($DBversion);
}

$DBversion = "3.06.00.081";
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {
    $dbh->do("
        INSERT IGNORE INTO `systempreferences`
            (variable,value,explanation,options,type)
            VALUES('AuthSubfieldsToCheck','a b x y z','Space-separated list of subfields to check to detect if two authorities are equivalent (only used with BiblioAddsAuthorities)','','Free')
    ");
    print "Upgrade to $DBversion done (Add new system preference AuthSubfieldsToCheck)\n";
    SetVersion($DBversion);
}

$DBversion = '3.06.00.082';
if (C4::Context->preference('Version') < TransformToNum($DBversion)){
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACNoResultsFound','','Display this HTML when no results are found for a search in the OPAC','70|10','Textarea')");
    print "Upgrade to $DBversion done (adding syspref OPACNoResultsFound to control what displays when no results are found for a search in the OPAC.)\n";
    SetVersion ($DBversion);
}

=item DropAllForeignKeys($table)

  Drop all foreign keys of the table $table

=cut

sub DropAllForeignKeys {
    my ($table) = @_;

    # get the table description
    my $sth = $dbh->prepare("SHOW CREATE TABLE $table");
    $sth->execute;
    my $vsc_structure = $sth->fetchrow;

    # split on CONSTRAINT keyword
    my @fks = split /CONSTRAINT /, $vsc_structure;

    # parse each entry
    foreach (@fks) {

        # isolate what is before FOREIGN KEY, if there is something, it's a foreign key to drop
        $_ = /(.*) FOREIGN KEY.*/;
        my $id = $1;
        if ($id) {

            # we have found 1 foreign, drop it
            $dbh->do("ALTER TABLE $table DROP FOREIGN KEY $id");
            $id = "";
        }
    }
}

=item TransformToNum

  Transform the Koha version from a 4 parts string
  to a number, with just 1 .

=cut

sub TransformToNum {
    my $version = shift;

    # remove the 3 last . to have a Perl number
    $version =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;
    return $version;
}

=item SetVersion

    set the DBversion in the systempreferences

=cut

sub SetVersion {
    my $kohaversion = TransformToNum(shift);
    if ( C4::Context->preference('Version') ) {
        my $finish = $dbh->prepare("UPDATE systempreferences SET value=? WHERE variable='Version'");
        $finish->execute($kohaversion);
    } else {
        my $finish = $dbh->prepare(
"INSERT IGNORE INTO systempreferences (variable,value,explanation) values ('Version',?,'The Koha database version. WARNING: Do not change this value manually, it is maintained by the webinstaller')"
        );
        $finish->execute($kohaversion);
    }
}

sub count_column_from_table{
	my $column=shift;
	my $tablename=shift;
	my $sthdb = $dbh->prepare("SELECT DATABASE()");
	$sthdb->execute;
	my ($actualdb) = $sthdb->fetchrow;
	my $sthcolumn = $dbh->prepare("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE COLUMN_NAME='$column' AND TABLE_NAME='$tablename' AND TABLE_SCHEMA='$actualdb'");
	$sthcolumn->execute();
	my ($resultcolumn) = $sthcolumn->fetchrow;
	return $resultcolumn || 0;
	}
exit;

