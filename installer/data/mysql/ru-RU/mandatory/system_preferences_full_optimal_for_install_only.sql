TRUNCATE systempreferences;

-- Admin — Управление
-- Acquisitions — Поступления
-- EnhancedContent — Расширенное содержимое
-- Authorities — Авторитетные источники
-- Cataloguing — Каталогизация
-- Circulation — Оборот
-- I18N/L10N
-- Logs — Протоколы
-- OAI-PMH
-- OPAC — Электронный каталог
-- Patrons — Посетители
-- Searching — Искание
-- StaffClient — Клиент для библиотекарей
-- Local Use — Местное использование

INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('acquisitions','normal','Choose Normal, budget-based acquisitions, or Simple bibliographic-data acquisitions','simple|normal','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('advancedMARCeditor',0,'If ON, the MARC editor won\'t display field/subfield descriptions','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AmazonEnabled',0,'Turn ON Amazon Content - You MUST set AWSAccessKeyID, AWSPrivateKey, and AmazonAssocTag if enabled','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AmazonReviews',0,'Display Amazon review on staff interface - You MUST set AWSAccessKeyID, AWSPrivateKey, and AmazonAssocTag if enabled','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AmazonSimilarItems',0,'Turn ON Amazon Similar Items feature  - You MUST set AWSAccessKeyID, AWSPrivateKey, and AmazonAssocTag if enabled','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACAmazonEnabled',0,'Turn ON Amazon Content in the OPAC - You MUST set AWSAccessKeyID, AWSPrivateKey, and AmazonAssocTag if enabled','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACAmazonSimilarItems',0,'Turn ON Amazon Similar Items feature  - You MUST set AWSAccessKeyID, AWSPrivateKey, and AmazonAssocTag if enabled','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AmazonLocale','US','Use to set the Locale of your Amazon.com Web Services','US|CA|DE|FR|JP|UK','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AWSAccessKeyID','','See:  http://aws.amazon.com','','free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AmazonAssocTag','','See:  http://aws.amazon.com','','free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AnonSuggestions',0,'Set to anonymous borrowernumber to enable Anonymous suggestions',NULL,'free');


INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('authoritysep','--','Used to separate a list of authorities in a display. Usually --',10,'free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('autoBarcode','incremental','Used to autogenerate a barcode: incremental will be of the form 1, 2, 3; annual of the form 2007-0001, 2007-0002; hbyymmincr of the form HB08010001 where HB=Home Branch','incremental|annual|hbyymmincr|OFF','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AutoLocation',0,'If ON, IP authentication is enabled, blocking access to the staff client from unauthorized IP addresses',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AutomaticItemReturn',1,'If ON, Koha will automatically set up a transfer of this item to its homebranch',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('autoMemberNum',1,'If ON, patron number is auto-calculated','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('BiblioDefaultView','normal','Choose the default detail view in the catalog; choose between normal, marc or isbd','normal|marc|isbd','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('BorrowerMandatoryField','surname|cardnumber','Choose the mandatory fields for a patron\'s account',NULL,'free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('borrowerRelationship','father|mother','Define valid relationships between a guarantor & a guarantee (separated by | or ,)','','free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('BorrowersLog',1,'If ON, log edit/create/delete actions on patron data',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('CataloguingLog',1,'If ON, log edit/create/delete actions on bibliographic data. WARNING: this feature is very resource consuming.',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('checkdigit','none','If ON, enable checks on patron cardnumber: none or \"Katipo\" style checks','none|katipo','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('delimiter',';','Define the default separator character for exporting reports',';|tabulation|,|/|\\|#|\|','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('EnhancedMessagingPreferences',0,'If ON, allows patrons to select to receive additional messages about items due or nearly due.','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('expandedSearchOption',0,'If ON, set advanced search to be expanded by default',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('FinesLog',1,'If ON, log fines',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('hidelostitems',0,'If ON, disables display of\"lost\" items in OPAC.','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('hide_marc',0,'If ON, disables display of MARC fields, subfield codes & indicators (still shows data)',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('IndependantBranches',0,'If ON, increases security between libraries',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('insecure',0,'If ON, bypasses all authentication. Be careful!',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('IntranetBiblioDefaultView','normal','IntranetBiblioDefaultView','normal|marc|isbd|labeled_marc','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('intranetcolorstylesheet','','Define the color stylesheet to use in the Staff Client','','free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('IntranetmainUserblock','','Add a block of HTML that will display on the intranet home page','50|20','Textarea');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('IntranetNav','','Use HTML tabs to add navigational links to the left-hand navigational bar in the Staff Client','70|10','Textarea');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('intranetreadinghistory',1,'If ON, Reading History is enabled for all patrons','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('intranetstylesheet','','Enter a complete URL to use an alternate layout stylesheet in Intranet',NULL,'free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('intranetuserjs','','Custom javascript for inclusion in Intranet','50|10','Textarea');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('intranet_includes','includes','The includes directory you want for specific look of Koha (includes or includes_npl for example)',NULL,'Free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ISBD','#942|<code><b>|{942j}|</b></code><br/>
#700|<i>|{700a }{ 700g, }|; </i>
#701|<i>|{701a }{ 701g, }|; </i>
#702|<i>|{702a }{ 702g, }|; </i>
#200||<b>{200a}</b>{ [200b] }{. 200c}{: 200e}{. 200h}{. 200i}{ / 200f}{; 200g}|
#230||{; 230a}|
#205||{; 205a}{, 205b}{ = 205d}{ / 205f}{; 205g}|
#210|<br/>|{; 210a}{ (210b) }{: 210c}{, 210d}|. - 
#210|(|{ 210e}{(210f)}{: 210g}{, 210h}|)
#215|<quantitative>|{; 215a}{: 215c}{; 215d}{ + 215e}|</quantitative>
#225|<br/><description>(|{ 225a}{ = 225d}{: 225e}{. 225h}{. 225i}{ / 225f}{, I225x}{; 225v}|)</description>
#010|<br/>&nbsp;&nbsp;&nbsp;<ISBN>ISBN |{010a}{: 010d}|</ISBN>
#606|<br/>&nbsp;&nbsp;&nbsp;<thematic>|{- 606a }|</thematic>
#686|<br/>&nbsp;&nbsp;&nbsp;ББК |{686a   }|
#675|<br/>&nbsp;&nbsp;&nbsp;УДК |{675a   }|
#676|<br/>&nbsp;&nbsp;&nbsp;ДКД |{676a   }|
#952|<br><block952><div align="right">|{\n952b}{ - 952o}{ [952p]}|</block952></div>
#300|<br/>&nbsp;&nbsp;&nbsp;<i>Примечания:</i><br/> |{300a   }|
#327|<br/>&nbsp;&nbsp;&nbsp;<i>Содержание:</i><br/> |{327a   }|
#330|<br/>&nbsp;&nbsp;&nbsp;<i>Аннотация:</i><br/> |{330a   }|','ISBD','80|20','Textarea');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('IssueLog',1,'If ON, log checkout activity',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('IssuingInProcess',0,'If ON, disables fines if the patron is issuing item that accumulate debt',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('item-level_itypes',1,'If ON, enables Item-level Itemtype / Issuing Rules','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('itemcallnumber','942hv','The MARC field/subfield that is used to calculate the itemcallnumber (Dewey would be 082ab or 092ab; LOC would be 050ab or 090ab) could be 852hi from an item record',NULL,'free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('DefaultClassificationSource','udc','Default classification scheme used by the collection. E.g., Dewey, LCC, etc.', NULL,'ClassSources');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('KohaAdminEmailAddress','root@localhost','Define the email address where patron modification requests are sent','','free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('kohaspsuggest','','Track search queries, turn on by defining host:dbname:user:pass','','');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('LabelMARCView','standard','Define how a MARC record will display','standard|economical','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('LetterLog',1,'If ON, log all notices sent',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('LibraryName','','Define the library name as displayed on the OPAC','','');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('marc',1,'Turn on MARC support',NULL,'YesNo');

-- this is selected by the web installer now
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('marcflavour','UNIMARC','Define global MARC flavor (MARC21 or UNIMARC) used for character encoding','MARC21|UNIMARC','Choice');
-- OEGO: фактически не было добавлено установщиком

INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('MARCOrgCode','OSt','Define MARC Organization Code - http://www.loc.gov/marc/organizations/orgshome.html','','free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('MaxFine',9999,'Maximum fine a patron can have for a single late return','','Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('maxoutstanding',5,'maximum amount withstanding to be able make holds','','Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('memberofinstitution',0,'If ON, patrons can be linked to institutions',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('MIME','OPENOFFICE.ORG','Define the default application for exporting report data','EXCEL|OPENOFFICE.ORG','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('noissuescharge',5,'Define maximum amount withstanding before check outs are blocked','','Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('NotifyBorrowerDeparture',30,'Define number of days before expiry where circulation is warned about patron account expiry',NULL,'Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacAuthorities',1,'If ON, enables the search authorities link on OPAC',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opacbookbag',1,'If ON, enables display of Cart feature','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacBrowser',0,'If ON, enables subject authorities browser on OPAC (needs to set misc/cronjob/sbuild_browser_and_cloud.pl)',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacCloud',0,'If ON, enables subject cloud on OPAC',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opaccolorstylesheet','colors.css','Define the color stylesheet to use in the OPAC','','free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opaccredits','','Define HTML Credits at the bottom of the OPAC page','70|10','Textarea');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opacheader','','Add HTML to be included as a custom header in the OPAC','30|10','Textarea');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opaclayoutstylesheet','opac.css','Enter the name of the layout CSS stylesheet to use in the OPAC','','free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacMaintenance',0,'If ON, enables maintenance warning in OPAC','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacMainUserBlock','Добро пожаловать в АБИС Koha...\r\n<hr>','A user-defined block of HTML  in the main content area of the opac main page','50|20','Textarea');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacNav','Здесь будут важные ссылки.','Use HTML tags to add navigational links to the left-hand navigational bar in OPAC','70|10','Textarea');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacPasswordChange',1,'If ON, enables patron-initiated password change in OPAC (disable it when using LDAP auth)',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opacreadinghistory',1,'If ON, enables display of Patron Circulation History in OPAC','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opacsmallimage','','Enter a complete URL to an image to replace the default Koha logo','','free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opacstylesheet','','Enter a complete URL to use an alternate layout stylesheet in OPAC','','free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opacthemes','prog','Define the current theme for the OPAC interface.','','Themes');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacTopissue',0,'If ON, enables the \'most popular items\' link on OPAC. Warning, this is an EXPERIMENTAL feature, turning ON may overload your server',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opacuserjs','','Define custom javascript for inclusion in OPAC','50|20','Textarea');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opacuserlogin',1,'Enable or disable display of user login features',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('patronimages',1,'Enable patron images for the Staff Client',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('printcirculationslips',1,'If ON, enable printing circulation receipts','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('RequestOnOpac',1,'If ON, globally enables patron holds on OPAC',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ReservesMaxPickUpDelay',7,'Define the Maximum delay to pick up an item on hold','','Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ReturnBeforeExpiry',0,'If ON, checkout will be prevented if returndate is after patron card expiry',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ReturnLog',1,'If ON, enables the circulation (returns) log',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('reviewson',1,'If ON, enables patron reviews of bibliographic records in the OPAC','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('sortbynonfiling',0,'Sort search results by MARC nonfiling characters (deprecated)',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('SpecifyDueDate',1,'Define whether to display \"Specify Due Date\" form in Circulation','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('SubscriptionHistory',';','Define the display preference for serials issue history in OPAC','simplified|full','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('SubscriptionLog',1,'If ON, enables subscriptions log',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('suggestion',1,'If ON, enables patron suggestions feature in OPAC','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('template','prog','Define the preferred staff interface template','','Themes');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('TemplateEncoding','utf-8','Globally define the default character encoding','iso-8859-1|utf-8','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('timeout',12000000,'Inactivity timeout for cookies authentication (in seconds)',NULL,'Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('TransfersMaxDaysWarning',3,'Define the days before a transfer is suspected of having a problem',NULL,'Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('useDaysMode','Calendar','Choose the method for calculating due date: select Calendar to use the holidays module, and Days to ignore the holidays module','Calendar|Days|Datedue','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('virtualshelves',1,'If ON, enables Lists management','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('z3950AuthorAuthFields','701,702,700','Define the MARC biblio fields for Personal Name Authorities to fill biblio.author',NULL,'free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('z3950NormalizeAuthor',0,'If ON, Personal Name Authorities will replace authors in biblio.author','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ReservesNeedReturns',1,'If ON, a hold placed on an item available in this library must be checked-in, otherwise, a hold on a specific item, that is in the library & available is considered available','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type)  VALUES ('DebugLevel',2,'Define the level of debugging information sent to the browser when errors are encountered (set to 0 in production). 0=none, 1=some, 2=most','0|1|2','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('SessionStorage','mysql','Use database or a temporary file for storing session data','mysql|Pg|tmp','Choice');  
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('CircAutocompl',1,'If ON, autocompletion is enabled for the Circulation input',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('RoutingSerials',1,'If ON, serials routing is enabled',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('SearchMyLibraryFirst',0,'If ON, OPAC searches return results limited by the user\'s library by default if they are logged in',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('dontmerge',1,'If ON, modifying an authority record will not update all associated bibliographic records immediately, ask your system administrator to enable the merge_authorities.pl cron job',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('BiblioAddsAuthorities',0,'If ON, adding a new biblio will check for an existing authority record and create one on the fly if one doesn\'t exist',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('QueryStemming',1,'If ON, enables query stemming',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('QueryFuzzy',1,'If ON, enables fuzzy option for searches',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('QueryWeightFields',1,'If ON, enables field weighting',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('yuipath','local','Insert the path to YUI libraries, choose local if you use koha offline',"local|http://yui.yahooapis.com/2.5.1/build",'Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('canreservefromotherbranches',1,'With Independent branches on, can a user from one library place a hold on an item from another library','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('FRBRizeEditions',0,'If ON, Koha will query one or more ISBN web services for associated ISBNs and display an Editions tab on the details pages','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('OPACFRBRizeEditions',0,'If ON, the OPAC will query one or more ISBN web services for associated ISBNs and display an Editions tab on the details pages','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('XISBN',0,'Use with FRBRizeEditions. If ON, Koha will use the OCLC xISBN web service in the Editions tab on the detail pages. See: http://www.worldcat.org/affiliate/webservices/xisbn/app.jsp','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('OCLCAffiliateID','','Use with FRBRizeEditions and XISBN. You can sign up for an AffiliateID here: http://www.worldcat.org/wcpa/do/AffiliateUserServices?method=initSelfRegister','','free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('XISBNDailyLimit',499,'The xISBN Web service is free for non-commercial use when usage does not exceed 500 requests per day','','Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('PINESISBN',0,'Use with FRBRizeEditions. If ON, Koha will use PINES OISBN web service in the Editions tab on the detail pages.','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('ThingISBN',0,'Use with FRBRizeEditions. If ON, Koha will use the ThingISBN web service in the Editions tab on the detail pages.','','YesNo');

-- I18N/L10N
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('dateformat','metric','Define global date format (us mm/dd/yyyy, metric dd/mm/yyy, ISO yyyy/mm/dd)','metric|us|iso','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opaclanguages','ru-RU,uk-UA,en,fr-FR,de-DE','Set the default language in the OPAC.',NULL,'Languages');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('opaclanguagesdisplay',0,'If ON, enables display of Change Language feature on OPAC','','YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('BorrowersTitles','Господин|Госпожа|Мистер|Миссис|Уважаемый|Уважаемая|Товарищ|Добродий|Добродийка','Define appropriate Titles for patrons',NULL,'free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('gist',0.20 ,'Default Goods and Services tax rate NOT in %, but in numeric form (0.12 for 12%), set to 0 to disable GST','','Integer');
-- need AddressType to distinguish between US and other, telephone numbers, maori stuff, sex, nationality, etc.
-- LDAP ? required fields?
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('WebBasedSelfCheck',0,'If ON, enables the web-based self-check system',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('numSearchResults',20,'Specify the maximum number of results to display on a page of results',NULL,'Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACnumSearchResults',20,'Specify the maximum number of results to display on a page of results',NULL,'Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('defaultSortField',NULL,'Specify the default field used for sorting','relevance|popularity|call_number|pubdate|acqdate|title|author','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('defaultSortOrder',NULL,'Specify the default sort order','asc|dsc|az|za','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACdefaultSortField',NULL,'Specify the default field used for sorting','relevance|popularity|call_number|pubdate|acqdate|title|author','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACdefaultSortOrder',NULL,'Specify the default sort order','asc|dsc|za|az','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('staffClientBaseURL','','Specify the base URL of the staff client',NULL,'free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('minPasswordLength',3,'Specify the minimum length of a patron/staff password',NULL,'free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('noItemTypeImages',0,'If ON, disables item-type images',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('emailLibrarianWhenHoldIsPlaced',0,'If ON, emails the librarian whenever a hold is placed',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('holdCancelLength','','Specify how many days before a hold is canceled',NULL,'Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('libraryAddress','','The address to use for printing receipts, overdues, etc. if different than physical address',NULL,'free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('finesMode','test','Choose the fines mode, \'off\', \'test\' (emails admin report) or \'production\' (accrue overdue fines).  Requires accruefines cronjob.','off|test|production','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('globalDueDate','','If set, allows a global static due date for all checkouts','10','free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('itemBarcodeInputFilter','','If set, allows specification of a item barcode input filter','whitespace|T-prefix|cuecat','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('singleBranchMode',0,'Operate in Single-branch mode, hide branch selection in the OPAC',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('URLLinkText','','Text to display as the link anchor in the OPAC',NULL,'free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACSubscriptionDisplay','economical','Specify how to display subscription information in the OPAC','economical|off|full','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACDisplayExtendedSubInfo',1,'If ON, extended subscription information is displayed in the OPAC',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACViewOthersSuggestions',0,'If ON, allows all suggestions to be displayed in the OPAC',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACURLOpenInNewWindow',0,'If ON, URLs in the OPAC open in a new window',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACUserCSS','','Add CSS to be included in the OPAC in an embedded <style> tag.',NULL,'free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACItemsResultsDisplay',"statuses",'statuses : show only the status of items in result list. itemdisplay : show full location of items (branch+location+callnumber) as in staff interface',"statuses|itemdetails",'Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('uppercasesurnames',0,'If ON, surnames are converted to upper case in patron entry form',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('CircControl',"ItemHomeLibrary",'Specify the agency that controls the circulation and fines policy',"PickupLibrary|PatronLibrary|ItemHomeLibrary",'Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('finesCalendar',"noFinesWhenClosed",'Specify whether to use the Calendar in calculating duedates and fines',"ignoreCalendar|noFinesWhenClosed",'Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('previousIssuesDefaultSortOrder',"asc",'Specify the sort order of Previous Issues on the circulation page',"asc|desc",'Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('todaysIssuesDefaultSortOrder',"desc",'Specify the sort order of Todays Issues on the circulation page',"asc|desc",'Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACBaseURL',NULL,'Specify the Base URL of the OPAC, e.g., opac.mylibrary.com, the http:// will be added automatically by Koha.',NULL,'Free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('language','ru-RU,uk-UA,en,fr-FR,de-DE','Set the default language in the staff client.',NULL,'Languages');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('QueryAutoTruncate',1,'If ON, query truncation is enabled by default',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('QueryRemoveStopwords',0,'If ON, stopwords listed in the Administration area will be removed from queries',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacRenewalAllowed',0,'If ON, users can renew their issues directly from their OPAC account',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('PatronsPerPage','20','Number of Patrons Per Page displayed by default','20','Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('HomeOrHoldingBranch','holdingbranch','Used by Circulation to determine which branch of an item to check with independent branches on, and by search to determine which branch to choose for availability ','holdingbranch|homebranch','Choice');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacHighlightedWords','1','If Set, then queried words are higlighted in OPAC','','YesNo');

INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH','0','if ON, OAI-PMH server is enabled',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH:archiveID','KOHA-OAI-TEST','OAI-PMH archive identification',NULL,'Free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH:MaxCount','50','OAI-PMH maximum number of records by answer to ListRecords and ListIdentifiers queries',NULL,'Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH:Set','SET,Experimental set\r\nSET:SUBSET,Experimental subset','OAI-PMH exported set, the set name is followed by a comma and a short description, one set by line','30|10','Textarea');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH:Subset','itemtype=\'BOOK\'','Restrict answer to matching raws of the biblioitems table EXPERIMENTAL',NULL,'Free');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACItemHolds','1','Allow OPAC users to place hold on specific items. If OFF, users can only request next available copy.','','YesNo');

INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('GranularPermissions','0','Use detailed staff user permissions',NULL,'YesNo');
INSERT INTO `systempreferences` (variable, value,options,type, explanation) VALUES ('AddPatronLists','categorycode','categorycode|category_type','Choice','Allow user to choose what list to pick up from when adding patrons');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ExtendedPatronAttributes','1','Use extended patron IDs and attributes',NULL,'YesNo');

INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('RenewSerialAddsSuggestion','0','If ON, adds a new suggestion at serial subscription renewal',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('GoogleJackets','0','if ON, displays jacket covers from Google Books API',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('RandomizeHoldsQueueWeight','0','if ON, the holds queue in circulation will be randomized, either based on all location codes, or by the location codes specified in StaticHoldsQueueWeight',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('StaticHoldsQueueWeight','0','Specify a list of library location codes separated by commas -- the list of codes will be traversed and weighted with first values given higher weight for holds fulfillment -- alternatively, if RandomizeHoldsQueueWeight is set, the list will be randomly selective',NULL,'Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AutoEmailOpacUser','0','Sends notification emails containing new account details to patrons - when account is created.',NULL,'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AutoEmailPrimaryAddress','0','Defines the default email address where \'Account Details\' emails are sent.','email|emailpro|B_email|cardnumber|OFF','Choice');

-- Tags and BakerTaylor (note field order differs from above)
INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES
	('BakerTaylorBookstoreURL','','','URL template for \"My Libary Bookstore\" links, to which the \"key\" value is appended, and \"https://\" is prepended.  It should include your hostname and \"Parent Number\".  Make this variable empty to turn MLB links off.  Example: ocls.mylibrarybookstore.com/MLB/actions/searchHandler.do?nextPage=bookDetails&parentNum=10923&key=',''),
	('BakerTaylorEnabled','0','','Enable or disable all Baker & Taylor features.','YesNo'),
	('BakerTaylorPassword','','','Baker & Taylor Password for Content Cafe (external content)','Free'),
	('BakerTaylorUsername','','','Baker & Taylor Username for Content Cafe (external content)','Free'),
	('TagsEnabled','1','','Enables or disables all tagging features.  This is the main switch for tags.','YesNo'),
	('TagsExternalDictionary',NULL,'','Path on server to local ispell executable, used to set $Lingua::Ispell::path  This dictionary is used as a \"whitelist\" of pre-allowed tags.',''),
	('TagsInputOnDetail','1','','Allow users to input tags from the detail page.',         'YesNo'),
	('TagsInputOnList',  '0','','Allow users to input tags from the search results list.', 'YesNo'),
	('TagsModeration',  NULL,'','Require tags from patrons to be approved before becoming visible.','YesNo'),
	('TagsShowOnDetail','10','','Number of tags to display on detail page.  0 is off.',        'Integer'),
	('TagsShowOnList',   '6','','Number of tags to display on search results list.  0 is off.','Integer');

INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES('OPACShelfBrowser','1','','Enable/disable Shelf Browser on item details page. WARNING: this feature is very resource consuming on collections with large numbers of items.','YesNo');
INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES
('XSLTDetailsDisplay','0','','Enable XSL stylesheet control over details page display on OPAC exemple : ../koha-tmpl/opac-tmpl/prog/en/xslt/MARC21slim2OPACDetail.xsl','Textarea'),
('XSLTResultsDisplay','0','','Enable XSL stylesheet control over results page display on OPAC exemple : ../koha-tmpl/opac-tmpl/prog/en/xslt/MARC21slim2OPACResults.xsl','Textarea');
INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES('AdvancedSearchTypes','itemtypes','itemtypes|ccode','Select which set of fields comprise the Type limit in the advanced search','Choice');
INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES('AllowOnShelfHolds', '0', '', 'Allow hold requests to be placed on items that are not on loan', 'YesNo');
INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES('AllowHoldsOnDamagedItems', '1', '', 'Allow hold requests to be placed on damaged items', 'YesNo');
-- FIXME: add FrameworksLoaded, noOPACUserLogin?
INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('SMSSendDriver','','','Sets which SMS::Send driver is used to send SMS messages.','free');
INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('AllowRenewalLimitOverride', '0', 'if ON, allows renewal limits to be overridden on the circulation screen',NULL,'YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('MergeAuthoritiesOnUpdate', '1', 'if ON, Updating authorities will automatically updates biblios',NULL,'YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('RenewalPeriodBase', 'date_due', 'Set whether the renewal date should be counted from the date_due or from the moment the Patron asks for renewal ','date_due|now','Choice');
INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'AllowNotForLoanOverride', '0', '', 'If ON, Koha will allow the librarian to loan a not for loan item.', 'YesNo');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AWSPrivateKey','','See:  http://aws.amazon.com.  Note that this is required after 2009/08/15 in order to retrieve any enhanced content other than book covers from Amazon.','','free');
INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('viewISBD','1','Allow display of ISBD view of bibiographic records','','YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('viewLabeledMARC','0','Allow display of labeled MARC view of bibiographic records','','YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('viewMARC','1','Allow display of MARC view of bibiographic records','','YesNo');

INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('OPACDisplayRequestPriority','0','','Show patrons the priority level on holds in the OPAC','YesNo');

--INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('maxItemsInSearchResults',20,'Specify the maximum number of items to display for each result on a page of results',NULL,'free');
-- fix to 2142: maxItemsInSearchResults No longer used

INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AuthDisplayHierarchy',0,'Allow the display of hierarchy in Authority details',NULL,'YesNo');
-- from 3.00.04.019

INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('AmazonCoverImages', '0', 'Display Cover Images in Staff Client from Amazon Web Services','','YesNo');
-- from 3.00.02.007

INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACAmazonCoverImages', '0', 'Display cover images on OPAC from Amazon Web Services','','YesNo');
--from 3.00.02.007

INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ReceiveBackIssues', '5', 'Number of Previous journals to display when on subscription detail', '', '');

INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('AllowHoldPolicyOverride', '0', 'Allow staff to override hold policies when placing holds',NULL,'YesNo');
-- from 3.00.05.001

INSERT IGNORE INTO systempreferences (variable,explanation,options,type,value)
VALUES('OPACISBD','OPAC ISBD View','90|20', 'Textarea',
'#200|<h2>Заглавие: |{200a}{. 200c}{ : 200e}{200d}{. 200h}{. 200i}|</h2>\r\n#500|<label class="ipt">Унифицированое заглавие: </label>|{500a}{. 500i}{. 500h}{. 500m}{. 500q}{. 500k}<br/>|\r\n#517|<label class="ipt"> </label>|{517a}{ : 517e}{. 517h}{, 517i}<br/>|\r\n#541|<label class="ipt"> </label>|{541a}{ : 541e}<br/>|\r\n#200||<label class="ipt">Автора: </label><br/>|\r\n#700||<a href="opac-search.pl?op=do_search&marclist=7009&operator==&type=intranet&value={7009}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по автору"></a>{700c}{ 700b}{ 700a}{ 700d}{ (700f)}{. 7004}<br/>|\r\n#701||<a href="opac-search.pl?op=do_search&marclist=7009&operator==&type=intranet&value={7019}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по автору"></a>{701c}{ 701b}{ 701a}{ 701d}{ (701f)}{. 7014}<br/>|\r\n#702||<a href="opac-search.pl?op=do_search&marclist=7009&operator==&type=intranet&value={7029}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по автору"></a>{702c}{ 702b}{ 702a}{ 702d}{ (702f)}{. 7024}<br/>|\r\n#710||<a href="opac-search.pl?op=do_search&marclist=7109&operator==&type=intranet&value={7109}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по автору"></a>{710a}{ (710c)}{. 710b}{ : 710d}{ ; 710f}{ ; 710e}<br/>|\r\n#711||<a href="opac-search.pl?op=do_search&marclist=7109&operator==&type=intranet&value={7119}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по автору"></a>{711a}{ (711c)}{. 711b}{ : 711d}{ ; 711f}{ ; 711e}<br/>|\r\n#712||<a href="opac-search.pl?op=do_search&marclist=7109&operator==&type=intranet&value={7129}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по автору"></a>{712a}{ (712c)}{. 712b}{ : 712d}{ ; 712f}{ ; 712e}<br/>|\r\n#210|<label class="ipt">Унифицированная форма заглавия: </label>|{ 210a}<br/>|\r\n#210|<label class="ipt">Издатель: </label>|{ 210c}<br/>|\r\n#210|<label class="ipt">Дата публикации: </label>|{ 210d}<br/>|\r\n#215|<label class="ipt">Физическое описание: </label>|{215a}{ : 215c}{ ; 215d}{ + 215e}|<br/>\r\n#225|<label class="ipt">Серія:</label>|<a href="opac-search.pl?op=do_search&marclist=225a&operator==&type=intranet&value={225a}"> <img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по {225a}"></a>{ (225a}{ = 225d}{ : 225e}{. 225h}{. 225i}{ / 225f}{, 225x}{ ; 225v}|)<br/>\r\n#200||<label class="ipt">Тематические рубрики: </label><br/>|\r\n#600||<a href="opac-search.pl?op=do_search&marclist=6009&operator==&type=intranet&value={6009}"><img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по {6009}"></a>{ 600c}{ 600b}{ 600a}{ 600d}{ (600f)} {-- 600x }{-- 600z }{-- 600y}<br />|\r\n#604||<a href="opac-search.pl?op=do_search&marclist=6049&operator==&type=intranet&value={6049}"><img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по {6049}"></a>{ 604a}{. 604t}<br />|\r\n#601||<a href="opac-search.pl?op=do_search&marclist=6019&operator==&type=intranet&value={6019}"><img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по {6019}"></a>{ 601a}{ (601c)}{. 601b}{ : 601d} { ; 601f}{ ; 601e}{ -- 601x }{-- 601z }{-- 601y}<br />|\r\n#605||<a href="opac-search.pl?op=do_search&marclist=6059&operator==&type=intranet&value={6059}"><img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по {6059}"></a>{ 605a}{. 605i}{. 605h}{. 605k}{. 605m}{. 605q} {-- 605x }{-- 605z }{-- 605y }{-- 605l}<br />|\r\n#606||<a href="opac-search.pl?op=do_search&marclist=6069&operator==&type=intranet&value={6069}"><img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по {6069}">xx</a>{ 606a}{-- 606x }{-- 606z }{606y }<br />|\r\n#607||<a href="opac-search.pl?op=do_search&marclist=6079&operator==&type=intranet&value={6079}"><img border="0" src="/opac-tmpl/css/en/images/filefind.png" height="15" title="Поиск по {6079}"></a>{ 607a}{-- 607x}{-- 607z}{-- 607y}<br />|\r\n#010|<label class="ipt">ISBN: </label>|{010a}|<br/>\r\n#011|<label class="ipt">ISSN: </label>|{011a}|<br/>\r\n#200||<label class="ipt">Заметки: </label>|<br/>\r\n#300||{300a}|<br/>\r\n#320||{320a}|<br/>\r\n#327||{327a}|<br/>\r\n#328||{328a}|<br/>\r\n#200||<br/><h2>Экземпляры</h2>|\r\n#200|<table>|<th>Расположение</th><th>Cote</th>|\r\n#995||<tr><td>{995e}&nbsp;&nbsp;</td><td> {995k}</td></tr>|\r\n#200|||</table>');
-- from 3.00.04.020

INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('HomeOrHoldingBranchReturn','homebranch','Used by Circulation to determine which branch of an item to check checking-in items','holdingbranch|homebranch','Choice');
-- from 3.00.06.001

INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('IndependentBranchPatron',0,'If ON, librarian patron search can only be done on patron of same library as librarian',NULL,'YesNo');
-- from 3.00.06.004

INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACviewISBD','1','Allow display of ISBD view of bibiographic records in OPAC','','YesNo');
-- from 3.00.06.005

INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACviewMARC','1','Allow display of MARC view of bibiographic records in OPAC','','YesNo');
-- from 3.00.06.005

INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES('SolrAPI','http://localhost:8080/solr','','Solr web service URL.','Free');
INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES('SearchEngine','Solr','Solr|Zebra','Search Engine','Choice');
