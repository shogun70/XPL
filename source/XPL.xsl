<?xml version="1.0" encoding="UTF-8"?>
<!--
EXBL to XBL transform
Copyright 2007, Sean Hogan (http://www.meekostuff.net/)
All rights reserved
-->

<xsl:stylesheet
	exclude-result-prefixes="xsl xbl xpl"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
	xmlns:xbl="http://www.w3.org/ns/xbl"
	xmlns:xpl="http://www.meekostuff.net/ns/xpl"
	xmlns="http://www.w3.org/ns/xbl">

<xsl:output method="text" />


<xsl:template match="/">
Meeko.stuff.xplSystem.createContext('/** $uri **/');
	<xsl:apply-templates/>
Meeko.stuff.xplSystem.init();
</xsl:template>

<xsl:template match="processing-instruction()">
	<xsl:variable name="piType" select="match(name(), /xpl-(.*)/)"/>
	<xsl:variable name="href" select="match(value(), /href='(.*)'/)"/>
	<xsl:choose>
		<xsl:when test="$piType = 'prefetch'">
Meeko.stuff.xplSystem.prefetch['/** $uri **/'] = '/** $text **/';
		</xsl:when>
		<xsl:when test="$piType = 'param'">
Meeko.stuff.xplSystem.contexts['/** $uri **/'].params['/** $pi->attributes->{name} **/'] = '/** $self->expandParams($pi->attributes->{value}) **/';
		</xsl:when>
		<xsl:when test="$piType = 'require'">
Meeko.stuff.xplSystem.contexts['/** $uri **/'].requiredContexts.push('/** $requireUri **/');
		</xsl:when>
	</xsl:choose>
</xsl:template>

<xsl:template match="script">
Meeko.stuff.xplSystem.contexts['/** $uri **/'].wrappedScript = function() {
	var xplSystem = Meeko.stuff.xplSystem;
	var xplContext = xplSystem.contexts['/** $uri **/'];
	var logger = xplContext.logger;
	/** $scriptText **/;
}
</xsl:template>

</xsl:stylesheet>
