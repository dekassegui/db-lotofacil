<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="text" encoding="utf-8" indent="no" omit-xml-declaration="yes"/>

  <!-- separador de campos dos registros -->
  <xsl:param name="SEPARATOR"/>

  <!-- Lista concurso/cidade/estado de ganhadores da Lotofácil. -->

  <xsl:template name="LISTA_DADOS_GANHADORES_LOTO" match="/">

    <!-- percorre a lista de registros de concursos -->
    <xsl:for-each select="//table/tr">

      <xsl:choose>
        <xsl:when test="count(td)>2"><!-- registro básico -->
          <xsl:if test="td[19]>0"><!-- 1+ ganhadores -->
            <xsl:value-of select="td[1]"/><xsl:value-of select="$SEPARATOR"/><xsl:choose><xsl:when test="string-length(td[20])>0"><xsl:value-of select="td[20]"/></xsl:when><xsl:otherwise>NULL</xsl:otherwise></xsl:choose><xsl:value-of select="$SEPARATOR"/><xsl:choose><xsl:when test="string-length(td[21])>0"><xsl:value-of select="td[21]"/></xsl:when><xsl:otherwise>NULL</xsl:otherwise></xsl:choose><xsl:text>&#xA;</xsl:text>
          </xsl:if>
        </xsl:when>
        <xsl:otherwise><!-- registro complementar -->
          <xsl:value-of select="preceding-sibling::tr[count(td)>2][1]/td[1]"/><xsl:value-of select="$SEPARATOR"/><xsl:choose><xsl:when test="string-length(td[1])>0"><xsl:value-of select="td[1]"/></xsl:when><xsl:otherwise>NULL</xsl:otherwise></xsl:choose><xsl:value-of select="$SEPARATOR"/><xsl:choose><xsl:when test="string-length(td[2])>0"><xsl:value-of select="td[2]"/></xsl:when><xsl:otherwise>NULL</xsl:otherwise></xsl:choose><xsl:text>&#xA;</xsl:text>
        </xsl:otherwise>
      </xsl:choose>

    </xsl:for-each>

  </xsl:template>

</xsl:stylesheet>
