<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:marc="http://www.loc.gov/MARC21/slim"
  xmlns:items="http://www.koha.org/items"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  exclude-result-prefixes="marc items">

<xsl:import href="UNIMARCslimUtils.xsl"/>
<xsl:output method = "xml" indent="yes" omit-xml-declaration = "yes" />
<xsl:template match="/">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="marc:record">
  <xsl:variable name="leader" select="marc:leader"/>
  <xsl:variable name="leader6" select="substring($leader,7,1)"/>
  <xsl:variable name="leader7" select="substring($leader,8,1)"/>
  <xsl:variable name="biblionumber" select="marc:datafield[@tag=999]/marc:subfield[@code='9']"/>
  

  <xsl:if test="marc:datafield[@tag=200]">
    <xsl:for-each select="marc:datafield[@tag=200]">
      <h1>
        <xsl:call-template name="addClassRtl" />
        <xsl:variable name="title" select="marc:subfield[@code='a']"/>
        <xsl:variable name="ntitle"
         select="translate($title, '&#x0098;&#x009C;&#xC29C;&#xC29B;&#xC298;&#xC288;&#xC289;','')"/>
        <!--<xsl:value-of select="$ntitle" />-->
 <xsl:value-of select="marc:subfield[@code='a'][1]" />
<xsl:if test="marc:subfield[@code='a'][2]"><xsl:text>. </xsl:text><xsl:value-of select="marc:subfield[@code='a'][2]" /></xsl:if>
<xsl:if test="marc:subfield[@code='a'][3]"><xsl:text>. </xsl:text><xsl:value-of select="marc:subfield[@code='a'][3]" /></xsl:if>

        <xsl:if test="marc:subfield[@code='e']">
          <xsl:text> ; </xsl:text>
          <xsl:for-each select="marc:subfield[@code='e']">
            <xsl:value-of select="."/>
	      <xsl:if test="position()!=last()">
        		<xsl:text>, </xsl:text>
	      </xsl:if>
          </xsl:for-each>
        </xsl:if>
        <xsl:if test="marc:subfield[@code='d']">
          <xsl:text> =</xsl:text>
          <xsl:value-of select="marc:subfield[@code='d']"/>
        </xsl:if>
        <xsl:if test="marc:subfield[@code='b']">
          <xsl:text> [</xsl:text>
          <xsl:value-of select="marc:subfield[@code='b']"/>
          <xsl:text>]</xsl:text>
        </xsl:if>
          <xsl:if test="marc:subfield[@code='h']">
            <xsl:text> ; </xsl:text>
            <xsl:value-of select="marc:subfield[@code='h']"/>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='i']">
            <xsl:text> : </xsl:text>
            <xsl:value-of select="marc:subfield[@code='i']"/>
          </xsl:if>
        <xsl:if test="marc:subfield[@code='f']">
          <xsl:text> / </xsl:text>
          <xsl:value-of select="marc:subfield[@code='f']"/>
        </xsl:if>
        <xsl:if test="marc:subfield[@code='g']">
          <xsl:text> ; </xsl:text>
          <xsl:value-of select="marc:subfield[@code='g']"/>
        </xsl:if>
      </h1>
    </xsl:for-each>
  </xsl:if>
  
   <xsl:call-template name="tag_413" />
   <xsl:call-template name="tag_421" />
   <xsl:call-template name="tag_422" />
   <xsl:call-template name="tag_423" />
   <xsl:call-template name="tag_424" />
   <xsl:call-template name="tag_425" />
   <xsl:call-template name="tag_430" />
   <xsl:call-template name="tag_431" />
   <xsl:call-template name="tag_432" />
   <xsl:call-template name="tag_433" />
   <xsl:call-template name="tag_434" />
   <xsl:call-template name="tag_435" />
   <xsl:call-template name="tag_436" />
   <xsl:call-template name="tag_437" />
   <xsl:call-template name="tag_440" />
   <xsl:call-template name="tag_441" />
   <xsl:call-template name="tag_442" />
   <xsl:call-template name="tag_443" />
   <xsl:call-template name="tag_444" />
   <xsl:call-template name="tag_445" />
   <xsl:call-template name="tag_446" />
   <xsl:call-template name="tag_447" />
   <xsl:call-template name="tag_448" />
   <xsl:call-template name="tag_451" />
   <xsl:call-template name="tag_452" />
   <xsl:call-template name="tag_453" />
   <xsl:call-template name="tag_454" />
   <xsl:call-template name="tag_455" />
   <xsl:call-template name="tag_456" />
   <xsl:call-template name="tag_462" />
   <xsl:call-template name="tag_463" />
   <xsl:call-template name="tag_4xx" />

  <xsl:call-template name="tag_7xx">
    <xsl:with-param name="tag">700</xsl:with-param>
    <xsl:with-param name="label">Auteur principal</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_7xx">
    <xsl:with-param name="tag">710</xsl:with-param>
    <xsl:with-param name="label">Collectivité principale</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_7xx">
    <xsl:with-param name="tag">701</xsl:with-param>
    <xsl:with-param name="label">Co-auteur</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_7xx">
    <xsl:with-param name="tag">702</xsl:with-param>
    <xsl:with-param name="label">Auteur</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_7xx">
    <xsl:with-param name="tag">711</xsl:with-param>
    <xsl:with-param name="label">Collectivité co-auteur</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_7xx">
    <xsl:with-param name="tag">712</xsl:with-param>
    <xsl:with-param name="label">Collectivité secondaire</xsl:with-param>
  </xsl:call-template>

  <xsl:if test="marc:datafield[@tag=101]">
    <li>
      <strong>Langue: </strong>
      <xsl:for-each select="marc:datafield[@tag=101]">
        <xsl:for-each select="marc:subfield">
          <xsl:choose>
            <xsl:when test="@code='b'">de la trad. intermédiaire, </xsl:when>
            <xsl:when test="@code='c'">de l'œuvre originale, </xsl:when>
            <xsl:when test="@code='d'">du résumé, </xsl:when>
            <xsl:when test="@code='e'">de la table des matières, </xsl:when>
            <xsl:when test="@code='f'">de la page de titre, </xsl:when>
            <xsl:when test="@code='g'">du titre propre, </xsl:when>
            <xsl:when test="@code='h'">d'un livret, </xsl:when>
            <xsl:when test="@code='i'">des textes d'accompagnement, </xsl:when>
            <xsl:when test="@code='j'">des sous-titres, </xsl:when>
          </xsl:choose>
          <xsl:value-of select="text()"/>
          <xsl:choose>
            <xsl:when test="position()=last()">
              <xsl:text>.</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text> ; </xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
      </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=102]">
    <li>
      <strong>Pays: </strong>
      <xsl:for-each select="marc:datafield[@tag=102]">
        <xsl:for-each select="marc:subfield">
          <xsl:value-of select="text()"/>
          <xsl:choose>
            <xsl:when test="position()=last()">
              <xsl:text>.</xsl:text>
            </xsl:when>
              <xsl:otherwise><xsl:text>, </xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
      </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:call-template name="tag_210" />

  <xsl:call-template name="tag_215" />

  <abbr class="unapi-id" title="koha:biblionumber:{marc:datafield[@tag=999]/marc:subfield[@code='9']}"><!-- unAPI --></abbr>

<xsl:if test="marc:controlfield[@tag=009]">
    <li><strong>PPN: </strong>
      <xsl:value-of select="marc:controlfield[@tag=009]"/>
    </li>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=010]/marc:subfield[@code='a']">
    <li><strong>ISBN: </strong>
    <xsl:for-each select="marc:datafield[@tag=010]">
      <xsl:variable name="isbn" select="marc:subfield[@code='a']"/>
      <xsl:value-of select="marc:subfield[@code='a']"/>
      <xsl:choose>
        <xsl:when test="position()=last()">
          <xsl:text>.</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text> ; </xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=011]">
    <li>
      <strong>ISSN: </strong>
      <xsl:for-each select="marc:datafield[@tag=011]">
        <xsl:value-of select="marc:subfield[@code='a']"/>
        <xsl:choose>
          <xsl:when test="position()=last()">
            <xsl:text>.</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>; </xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:call-template name="tag_title">
    <xsl:with-param name="tag">225</xsl:with-param>
    <xsl:with-param name="label">Collection</xsl:with-param>
  </xsl:call-template>

  <xsl:if test="marc:datafield[@tag=676]">
    <li>
    <strong>Dewey: </strong>
      <xsl:for-each select="marc:datafield[@tag=676]">
        <xsl:value-of select="marc:subfield[@code='a']"/>
        <xsl:if test="marc:subfield[@code='v']">
          <xsl:text>, </xsl:text>
          <xsl:value-of select="marc:subfield[@code='v']"/>
        </xsl:if>
        <xsl:if test="marc:subfield[@code='z']">
          <xsl:text>, </xsl:text>
          <xsl:value-of select="marc:subfield[@code='z']"/>
        </xsl:if>
        <xsl:if test="not (position()=last())">
          <xsl:text> ; </xsl:text>
        </xsl:if>
      </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=686]">
    <li>
    <strong>Classification: </strong>
      <xsl:for-each select="marc:datafield[@tag=686]">
        <xsl:value-of select="marc:subfield[@code='a']"/>
        <xsl:if test="marc:subfield[@code='b']">
          <xsl:text>, </xsl:text>
          <xsl:value-of select="marc:subfield[@code='b']"/>
        </xsl:if>
        <xsl:if test="marc:subfield[@code='c']">
          <xsl:text>, </xsl:text>
          <xsl:value-of select="marc:subfield[@code='c']"/>
        </xsl:if>
        <xsl:if test="not (position()=last())"><xsl:text> ; </xsl:text></xsl:if>
      </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=327]">
    <li>
      <strong>Note de contenu: </strong>
      <xsl:for-each select="marc:datafield[@tag=327]">
        <xsl:call-template name="chopPunctuation">
          <xsl:with-param name="chopString">
            <xsl:call-template name="subfieldSelect">
                <xsl:with-param name="codes">abcdjpvxyz</xsl:with-param>
                <xsl:with-param name="subdivCodes">jpxyz</xsl:with-param>
                <xsl:with-param name="subdivDelimiter">-- </xsl:with-param>
            </xsl:call-template>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=330]">
    <li>
      <strong>Résumé: </strong>
      <xsl:for-each select="marc:datafield[@tag=330]">
        <xsl:value-of select="marc:subfield[@code='a']"/>
        <xsl:choose>
          <xsl:when test="position()=last()">
            <xsl:text>.</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>; </xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=317]">
    <li>
      <strong>Note sur la provenance: </strong>
      <xsl:for-each select="marc:datafield[@tag=317]">
          <xsl:value-of select="marc:subfield[@code='a']"/>      
      </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=320]">
    <li>
      <strong>Bibliographie: </strong>
      <xsl:for-each select="marc:datafield[@tag=320]">
        <xsl:value-of select="marc:subfield[@code='a']"/>
        <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
      </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=328]">
    <li>
      <strong>Thèse: </strong>
      <xsl:for-each select="marc:datafield[@tag=328]">
	<xsl:for-each select="marc:subfield">
          <xsl:value-of select="text()"/>
          <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
	</xsl:for-each>
      </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=333]">
    <li>
      <strong>Public: </strong>
      <xsl:for-each select="marc:datafield[@tag=333]">
        <xsl:value-of select="marc:subfield[@code='a']"/>
        <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
      </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=955]">
    <li>
      <strong>Etat de collection SUDOC: </strong>
      <xsl:for-each select="marc:datafield[@tag=955]">
        <xsl:choose>
          <xsl:when test="marc:subfield[@code='9']">
            <xsl:value-of select="marc:subfield[@code='9']"/>:
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="RCR">
      		  <xsl:with-param name="code" select="substring-before(marc:subfield[@code='5'], ':')"/>
      		</xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:value-of select="marc:subfield[@code='r']"/>
        <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
      </xsl:for-each>
    </li>
  </xsl:if>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">600</xsl:with-param>
    <xsl:with-param name="label">Sujet - Nom de personne</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">601</xsl:with-param>
    <xsl:with-param name="label">Sujet - Collectivité</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">602</xsl:with-param>
    <xsl:with-param name="label">Sujet - Famille</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">604</xsl:with-param>
    <xsl:with-param name="label">Sujet - Auteur/titre</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">606</xsl:with-param>
    <xsl:with-param name="label">Sujet - Nom commun</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">607</xsl:with-param>
    <xsl:with-param name="label">Sujet - Nom géographique</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">608</xsl:with-param>
    <xsl:with-param name="label">Sujet - Forme</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">610</xsl:with-param>
    <xsl:with-param name="label">Sujet</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">615</xsl:with-param>
    <xsl:with-param name="label">Catégorie sujet</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">616</xsl:with-param>
    <xsl:with-param name="label">Marque déposée</xsl:with-param>
  </xsl:call-template>

  <xsl:if test="marc:datafield[@tag=856]">
      <span class="results_summary">
        <span class="label"><strong>URL: </strong></span>
        <xsl:for-each select="marc:datafield[@tag=856]">
          <a>
            <xsl:attribute name="href">
             <!--BIBLIBRE AJOUT http:// pour le lien--> http://<xsl:value-of select="marc:subfield[@code='u']"/>
            </xsl:attribute>
            <xsl:choose>
              <xsl:when test="marc:subfield[@code='y' or @code='3' or @code='z']">
                <xsl:call-template name="subfieldSelect">
                  <xsl:with-param name="codes">y3z</xsl:with-param>
                </xsl:call-template>
              </xsl:when>
              <xsl:when test="not(marc:subfield[@code='y']) and not(marc:subfield[@code='3']) and not(marc:subfield[@code='z'])">
        <li> <xsl:value-of select="marc:subfield[@code='u']"/></li> <!-- BIBLIBRE -->
            </xsl:when>
            </xsl:choose>
          </a>
          <xsl:choose>
            <xsl:when test="position()=last()"/>
            <xsl:otherwise>  </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
      </span>
    </xsl:if>

        <!-- 780 -->
        <xsl:if test="marc:datafield[@tag=780]">
        <xsl:for-each select="marc:datafield[@tag=780]">
        <li><strong>
        <xsl:choose>
        <xsl:when test="@ind2=0">
            Continues:
        </xsl:when>
        <xsl:when test="@ind2=1">
            Continues in part:
        </xsl:when>
        <xsl:when test="@ind2=2">
            Supersedes:
        </xsl:when>
        <xsl:when test="@ind2=3">
            Supersedes in part:
        </xsl:when>
        <xsl:when test="@ind2=4">
            Formed by the union: ... and: ...
        </xsl:when>
        <xsl:when test="@ind2=5">
            Absorbed:
        </xsl:when>
        <xsl:when test="@ind2=6">
            Absorbed in part:
        </xsl:when>
        <xsl:when test="@ind2=7">
            Separated from:
        </xsl:when>
        </xsl:choose>
        </strong>
                <xsl:variable name="f780">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">at</xsl:with-param>
                    </xsl:call-template>
                </xsl:variable>
             <a><xsl:attribute name="href">/cgi-bin/koha/catalogue/search.pl?q=<xsl:value-of select="translate($f780, '()', '')"/></xsl:attribute>
                <xsl:value-of select="translate($f780, '()', '')"/>
            </a>
        </li>
 
        <xsl:choose>
        <xsl:when test="@ind1=0">
            <li><xsl:value-of select="marc:subfield[@code='n']"/></li>
        </xsl:when>
        </xsl:choose>

        </xsl:for-each>
        </xsl:if>

        <!-- 785 -->
        <xsl:if test="marc:datafield[@tag=785]">
        <xsl:for-each select="marc:datafield[@tag=785]">
        <li><strong>
        <xsl:choose>
        <xsl:when test="@ind2=0">
            Continued by:
        </xsl:when>
        <xsl:when test="@ind2=1">
            Continued in part by:
        </xsl:when>
        <xsl:when test="@ind2=2">
            Superseded by:
        </xsl:when>
        <xsl:when test="@ind2=3">
            Superseded in part by:
        </xsl:when>
        <xsl:when test="@ind2=4">
            Absorbed by:
        </xsl:when>
        <xsl:when test="@ind2=5">
            Absorbed in part by:
        </xsl:when>
        <xsl:when test="@ind2=6">
            Split into .. and ...:
        </xsl:when>
        <xsl:when test="@ind2=7">
            Merged with ... to form ...
        </xsl:when>
        <xsl:when test="@ind2=8">
            Changed back to:
        </xsl:when>

        </xsl:choose>
        </strong>
                   <xsl:variable name="f785">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">at</xsl:with-param>
                    </xsl:call-template>
                </xsl:variable>

                <a><xsl:attribute name="href">/cgi-bin/koha/catalogue/search.pl?q=<xsl:value-of select="translate($f785, '()', '')"/></xsl:attribute>
                <xsl:value-of select="translate($f785, '()', '')"/>
            </a>

        </li>
        </xsl:for-each>
        </xsl:if>
        
		  <xsl:if test="marc:datafield[@tag=923]">
			  <strong>Collections disponibles : </strong>
			  <ul>
	        <xsl:for-each select="marc:datafield[@tag=923]">
	        	<li>
			      	<span class="label">Pour 
			      	    <strong>
			          		<xsl:call-template name="RCR">
			          		  <xsl:with-param name="code" select="marc:subfield[@code='c']"/>
			          		</xsl:call-template>
			      		</strong>
			      		<xsl:if test="marc:subfield[@code='b']">
			      		, Cote <xsl:value-of select="marc:subfield[@code='b']"/>
			      		</xsl:if>
			      		:
			          </span>
			        <ul>
			        	<xsl:if test="marc:subfield[@code='d']">
			        		<li><span class="label">Etat de collection : </span><xsl:value-of select="marc:subfield[@code='d']"/></li>
			        	</xsl:if>
			        	<xsl:if test="marc:subfield[@code='e']">
			        		<li><span class="label">Index : </span><xsl:value-of select="marc:subfield[@code='e']"/></li>
			        	</xsl:if>
			        	<xsl:if test="marc:subfield[@code='a']">
			        		<li><span class="label">Lacunes : </span><xsl:value-of select="marc:subfield[@code='a']"/></li>
			        	</xsl:if>
			        	<xsl:if test="marc:subfield[@code='g']">
				      		<li><span class="label">Sous-localisation : </span><xsl:value-of select="marc:subfield[@code='g']"/></li>
				      	</xsl:if>
				      	<xsl:if test="marc:subfield[@code='m']">
				      		<li><span class="label">Suppléments : </span><xsl:value-of select="marc:subfield[@code='g']"/></li>
				      	</xsl:if>
			        </ul>
	          </li>
	        </xsl:for-each>
        </ul>
		  </xsl:if>

    </xsl:template>

    <xsl:template name="RCR">
        <xsl:param name="code"/>
        <xsl:choose>
            <!-- Définir ici l'équivalence des RCRs <=> nom de la bibliothèque -->
            <xsl:when test="$code='130015206'">Muséothèque AGCCPF-PACA</xsl:when>
            <xsl:otherwise><xsl:value-of select="$code"/></xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="nameABCDQ">
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">aq</xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
                <xsl:with-param name="punctuation">
                    <xsl:text>:,;/ </xsl:text>
                </xsl:with-param>
            </xsl:call-template>
        <xsl:call-template name="termsOfAddress"/>
    </xsl:template>

    <xsl:template name="nameABCDN">
        <xsl:for-each select="marc:subfield[@code='a']">
                <xsl:call-template name="chopPunctuation">
                    <xsl:with-param name="chopString" select="."/>
                </xsl:call-template>
        </xsl:for-each>
        <xsl:for-each select="marc:subfield[@code='b']">
                <xsl:value-of select="."/>
        </xsl:for-each>
        <xsl:if test="marc:subfield[@code='c'] or marc:subfield[@code='d'] or marc:subfield[@code='n']">
                <xsl:call-template name="subfieldSelect">
                    <xsl:with-param name="codes">cdn</xsl:with-param>
                </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template name="nameACDEQ">
            <xsl:call-template name="subfieldSelect">
                <xsl:with-param name="codes">acdeq</xsl:with-param>
            </xsl:call-template>
    </xsl:template>
    <xsl:template name="termsOfAddress">
        <xsl:if test="marc:subfield[@code='b' or @code='c']">
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">bc</xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template name="part">
        <xsl:variable name="partNumber">
            <xsl:call-template name="specialSubfieldSelect">
                <xsl:with-param name="axis">n</xsl:with-param>
                <xsl:with-param name="anyCodes">n</xsl:with-param>
                <xsl:with-param name="afterCodes">fghkdlmor</xsl:with-param>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="partName">
            <xsl:call-template name="specialSubfieldSelect">
                <xsl:with-param name="axis">p</xsl:with-param>
                <xsl:with-param name="anyCodes">p</xsl:with-param>
                <xsl:with-param name="afterCodes">fghkdlmor</xsl:with-param>
            </xsl:call-template>
        </xsl:variable>
        <xsl:if test="string-length(normalize-space($partNumber))">
                <xsl:call-template name="chopPunctuation">
                    <xsl:with-param name="chopString" select="$partNumber"/>
                </xsl:call-template>
        </xsl:if>
        <xsl:if test="string-length(normalize-space($partName))">
                <xsl:call-template name="chopPunctuation">
                    <xsl:with-param name="chopString" select="$partName"/>
                </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template name="specialSubfieldSelect">
        <xsl:param name="anyCodes"/>
        <xsl:param name="axis"/>
        <xsl:param name="beforeCodes"/>
        <xsl:param name="afterCodes"/>
        <xsl:variable name="str">
            <xsl:for-each select="marc:subfield">
                <xsl:if test="contains($anyCodes, @code)      or (contains($beforeCodes,@code) and following-sibling::marc:subfield[@code=$axis])      or (contains($afterCodes,@code) and preceding-sibling::marc:subfield[@code=$axis])">
                    <xsl:value-of select="text()"/>
                    <xsl:text> </xsl:text>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        <xsl:value-of select="substring($str,1,string-length($str)-1)"/>
    </xsl:template>

</xsl:stylesheet>
