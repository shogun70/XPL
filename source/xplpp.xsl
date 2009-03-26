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
<xsl:apply-templates select="xpl:package"/>
</xsl:template>

<xsl:template match="/xpl:package">
Meeko.stuff.xplSystem.createNamespace("<xsl:value-of select="@namespace" />");
<xsl:value-of select="@namespace" /> = (function() {
	<xsl:apply-templates />
return {
	<xsl:for-each select="xpl:class[@visibility='public' or not(@visibility)]">
	<xsl:value-of select="@name"/>: <xsl:value-of select="@name"/><xsl:if test="position()!=last()">, </xsl:if><xsl:text>
	</xsl:text>
	</xsl:for-each>
}
})();
</xsl:template>

<xsl:template match="xpl:script">
<xsl:value-of select="string()"/><xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="xpl:package/xpl:class">
var <xsl:value-of select="@name"/> = (function() {
var <xsl:value-of select="@name"/> = function() {
	<xsl:apply-templates select="xpl:instance/xpl:script"/>
};
	<xsl:if test="@extends">
<xsl:value-of select="@name"/>.prototype = new <xsl:value-of select="@extends"/>;
	</xsl:if>
	
	<xsl:apply-templates select="xpl:script | xpl:property | xpl:method">
		<xsl:with-param name="object"><xsl:value-of select="@name"/></xsl:with-param>
	</xsl:apply-templates>
	<xsl:apply-templates select="xpl:instance/xpl:property | xpl:instance/xpl:method">
		<xsl:with-param name="object"><xsl:value-of select="@name"/>.prototype</xsl:with-param>
	</xsl:apply-templates>

if (<xsl:value-of select="@name"/>.prototype.__defineGetter__) {
	<xsl:apply-templates select="xpl:instance/xpl:property" mode="js2">
		<xsl:with-param name="object"><xsl:value-of select="@name"/>.prototype</xsl:with-param>
	</xsl:apply-templates>
}

	<xsl:if test="(xpl:instance/xpl:property | xpl:instance/xpl:method)[@visibility='protected' or @visibility='private']">
<xsl:value-of select="@name"/>.prototype.xblPublic = [
		<xsl:for-each select="(xpl:instance/xpl:property | xpl:instance/xpl:method)[@visibility='public' or not(@visibility)]">
	"<xsl:value-of select="@name"/>"<xsl:if test="position()!=last()">, </xsl:if>
		</xsl:for-each>
]
	</xsl:if>

return <xsl:value-of select="@name"/>;
})();
</xsl:template>

<xsl:template>

</xsl:template>

<xsl:template match="xpl:class/xpl:property" mode="specific">
	<xsl:apply-templates select=".">
		<xsl:with-param name="object"><xsl:value-of select="@name"/></xsl:with-param>
	</xsl:apply-templates>
</xsl:template>	
	
<xsl:template match="xpl:class/xpl:method" mode="specific">
	<xsl:apply-templates select=".">
		<xsl:with-param name="object"><xsl:value-of select="@name"/></xsl:with-param>
	</xsl:apply-templates>
</xsl:template>
	
<xsl:template match="xpl:instance/xpl:property" mode="specific">
	<xsl:apply-templates select="xpl:property">
		<xsl:with-param name="object"><xsl:value-of select="@name"/>.prototype</xsl:with-param>
	</xsl:apply-templates>
</xsl:template>

<xsl:template match="xpl:instance/xpl:method" mode="specific">
	<xsl:apply-templates select="xpl:method">
		<xsl:with-param name="object"><xsl:value-of select="@name"/>.prototype</xsl:with-param>
	</xsl:apply-templates>
</xsl:template>

<xsl:template match="xpl:method">
	<xsl:param name="$object">this</xsl:param>
<xsl:value-of select="$object"/>.<xsl:value-of select="@name"/> = function(<xsl:for-each select="xpl:parameter">
			<xsl:value-of select="@name"/><xsl:if test="position()!=last()">, </xsl:if>
		</xsl:for-each>) {
	<xsl:value-of select="string(xpl:body)"/>
}
</xsl:template>

<xsl:template match="xpl:property">
	<xsl:param name="object">this</xsl:param>
	<xsl:variable name="Name"><xsl:call-template name="ucFirst"><xsl:with-param name="text" select="@name"/></xsl:call-template></xsl:variable>
	<xsl:if test="xpl:getter">
<xsl:value-of select="$object"/>.<xsl:value-of select="concat('get', $Name)"/> = function() {
	<xsl:value-of select="string(xpl:getter)"/>
}
	</xsl:if>
	<xsl:if test="xpl:setter">
<xsl:value-of select="$object"/>.<xsl:value-of select="concat('set', $Name)"/> = function(val) {
	<xsl:value-of select="string(xpl:setter)"/>
}
	</xsl:if>	
	<xsl:if test="not(xpl:setter or xpl:getter)">
<xsl:value-of select="$object"/>.<xsl:value-of select="@name"/> = <xsl:value-of select="string()"/>;
	</xsl:if>
</xsl:template>

<xsl:template match="xpl:instance/xpl:property" mode="js2">
	<xsl:param name="object">this</xsl:param>
	<xsl:variable name="Name"><xsl:call-template name="ucFirst"><xsl:with-param name="text" select="@name"/></xsl:call-template></xsl:variable>
	<xsl:if test="xpl:getter">
<xsl:value-of select="$object"/>.__defineGetter__("<xsl:value-of select="@name"/>", <xsl:value-of select="$object"/>.<xsl:value-of select="concat('get', $Name)"/>);
	</xsl:if>
	<xsl:if test="xpl:setter">
<xsl:value-of select="$object"/>.__defineSetter__("<xsl:value-of select="@name"/>", <xsl:value-of select="$object"/>.<xsl:value-of select="concat('set', $Name)"/>);
	</xsl:if>
</xsl:template>


<xsl:template name="ucFirst">
<xsl:param name="text"/>
<xsl:value-of select="translate(substring($text,1,1),'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/><xsl:value-of select="substring($text,2)"/>
</xsl:template>

</xsl:stylesheet>