<!---
  ColdFusion Airbrake notifier, using V2 of the Airbrake API
  [http://help.airbrakeapp.com/kb/api-2/notifier-api-version-21]

  Date: July 28, 2011
  Version: 1.0.1
  Authors: 
    Original: Tim Blair (https://github.com/timblair/coldfusion-hoptoad-notifier)
    Editor: Ryan Johnson (rhino.citguy@gmail.com)
  License: See LICENSE.txt
  Requirements:
    ColdFusion 8+
  Description:
    This CFC is designed to use the Airbrake notification service to notify
    users about errors pertaining to ColdFusion applications. Simply put,
    call this component in the Application.cfc#onError() method.
--->
<cfcomponent output="false">
  <cfscript>
    // Notifier meta data
    variables.meta = {
      name    = "CF Airbrake Notifier",
      version = "1.0.1",
      url     = "http://airbrake_notifier.riaforge.org"
    };

    // Secured and unsecured notifier endpoints
    variables.airbrake_endpoint = {
      "default" = "http://airbrakeapp.com/notifier_api/v2/notices/",
      "secure"  = "https://airbrakeapp.com/notifier_api/v2/notices/"
    };
  </cfscript>

	<cffunction name="init" access="public" returntype="any" output="no"
    hint="Initialize the instance with the appropriate API key"
  >
		<cfargument name="api_key" type="string" required="yes" hint="The Hoptoad API key for the account to submit errors to">
		<cfargument name="environment" type="string" required="no" default="production" hint="The enviroment name to report to Hoptoad">
		<cfargument name="use_ssl" type="boolean" required="no" default="FALSE" hint="Should we use SSL when submitting to Hoptoad?">
    <cfscript>
      setApiKey(arguments.api_key);
      setEnvironment(arguments.environment);
      setUseSSL(arguments.use_ssl);
      return this;
    </cfscript>
	</cffunction>

<!--- getters/setters --->
	<cffunction name="setApiKey" access="public" returntype="void" output="no"
    hint="Set the project API key to use when POSTing data to Hoptoad"
  >
		<cfargument name="api_key" type="string" required="yes" hint="The Hoptoad project's API key">
		<cfset variables.instance.api_key = arguments.api_key>
	</cffunction>
  
	<cffunction name="getApiKey" access="public" returntype="string" output="no"
    hint="The configured project API key"
  >
		<cfreturn variables.instance.api_key>
	</cffunction>

	<cffunction name="setEnvironment" access="public" returntype="void" output="no"
    hint="Set the name of the environment we're running in"
  >
		<cfargument name="environment" type="string" required="yes" hint="The environment name">
		<cfset variables.instance.environment = arguments.environment>
	</cffunction>
  
	<cffunction name="getEnvironment" access="public" returntype="string" output="no"
    hint="The name of the configured environment"
  >
		<cfreturn variables.instance.environment>
	</cffunction>

	<cffunction name="setUseSSL" access="public" returntype="void" output="no"
    hint="Should we use SSL encryption when POSTing to Hoptoad?"
  >
		<cfargument name="use_ssl" type="boolean" required="yes" hint="">
		<cfset variables.instance.use_ssl = arguments.use_ssl>
	</cffunction>
  
	<cffunction name="getUseSSL" access="public" returntype="boolean" output="no"
    hint="The SSL encryption status"
  >
		<cfreturn variables.instance.use_ssl>
	</cffunction>
<!--- end:getters/setters --->
  

	<cffunction name="getEndpointURL"
    access="public" returntype="string" output="no"
    hint="Get the endpoint URL to POST to"
  >
		<cfreturn (getUseSSL() ? variables.hoptoad_endpoint.secure : variables.hoptoad_endpoint.default)>
	</cffunction>


  <cffunction name="send"
    access="public" returntype="struct" output="No"
    hint="Send an error notification to Hoptoad"
  >
		<cfargument name="error" type="any" required="yes" hint="The error structure to notify Hoptoad about">
		<cfargument name="session" type="struct" required="no" hint="Any additional session variables to report">
		<cfargument name="params" type="struct" required="no" hint="Any additional request params to report">
    
    <cfscript>
      var local = {};
      
      // We want to be dealing with a plain old structure here
      if (NOT isStruct(arguments.error)) { arguments.error = errorToStruct(arguments.error); }
      
      // Make sure we're looking at the error root
      if (StructKeyExists(error, 'RootCause')) { arguments.error = error["RootCause"]; }
      
      // Create the backtrace
      local.backtrace = [];
      if (StructKeyExists(arguments.error, 'tagcontext') AND isArray(arguments.error['tagcontext']) ) {
        local.backtrace = build_backtrace(arguments.error['tagcontext']);
      }
      
      // Default any messages we don't actually have but should do
      if (NOT StructKeyExists(arguments.error, 'type')) { arguments.error.type = "Unknown"; }
      if (NOT StructKeyExists(arguments.error, 'message')) { arguments.error.message = ""; }
    </cfscript>

    <cfsavecontent variable="local.xml"><?xml version="1.0" encoding="UTF-8"?>
      <cfoutput>
        <notice version="2.0">
          <api-key>#xmlformat(getApiKey())#</api-key>
          <notifier>
            <name>#xmlformat(variables.meta.name)#</name>
            <version>#xmlformat(variables.meta.version)#</version>
            <url>#xmlformat(variables.meta.url)#</url>
          </notifier>
          <server-environment>
            <project-root>#xmlformat(expandpath("."))#</project-root>
            <environment-name>#xmlformat(getEnvironment())#</environment-name>
          </server-environment>
          
          <!--- Error info and backtrace --->
          <error>
            <class>#xmlformat(arguments.error.type)#</class>
            <message>#xmlformat(arguments.error.type)#: #xmlformat(arguments.error.message)#</message>
            <cfif arraylen(local.backtrace)>
              <backtrace>
                <cfloop array="#local.backtrace#" index="local.line">
                  <line
                    file="#xmlformat(local.line.file)#"
                    number="#xmlformat(local.line.line)#"
                    method="#(len(local.line.method) ? xmlformat(local.line.method) : '')#"
                  />
                </cfloop>
              </backtrace>
            </cfif>
          </error>
          <request>
            <url>#getPageContext().getRequest().getRequestUrl()##(len(cgi.query_string) ? '?#cgi.query_string#' : '')#</url>
            <cfif arraylen(local.backtrace) AND listlast(local.backtrace[1].file, ".") EQ "cfc">
              <cfset local.component = reverse(listfirst(reverse(local.backtrace[1].file), "/"))>
              <component>#xmlformat(local.component)#</component>
              <cfif len(local.backtrace[1].method)>
                <action>#xmlformat(local.backtrace[1].method)#</action>
              <cfelse>
                <action />
              </cfif>
            <cfelse>
              <component />
              <action />
            </cfif>
            <!--- CGI and environment variables --->
            <cgi-data>
              <cfloop collection="#cgi#" item="local.key">
                <cfif len(cgi[local.key])>
                  <var key="#xmlformat(ucase(local.key))#">#xmlformat(cgi[local.key])#</var>
                </cfif>
              </cfloop>
              <!--- we'll also include any simple value fields from the error struct --->
              <var key="CF_HOST">#xmlformat(createObject("java", "java.net.InetAddress").getLocalHost().getHostName())#</var>
              <cfloop collection="#arguments.error#" item="local.key">
                <cfif issimplevalue(arguments.error[local.key]) AND len(arguments.error[local.key])>
                  <var key="CF_#xmlformat(ucase(local.key))#">#xmlformat(arguments.error[local.key])#</var>
                </cfif>
              </cfloop>
            </cgi-data>
            <!--- session data --->
            <cfif structkeyexists(arguments, "session")>
              <session>
                <cfloop collection="#arguments.session#" item="local.key">
                  <cfif issimplevalue(arguments.session[local.key])>
                    <var key="#xmlformat(ucase(local.key))#">#xmlformat(arguments.session[local.key])#</var>
                  </cfif>
                </cfloop>
              </session>
            </cfif>
            <!--- arbitrary call params --->
            <cfif structkeyexists(arguments, "params")>
              <params>
                <cfloop collection="#arguments.params#" item="local.key">
                  <cfif issimplevalue(arguments.params[local.key])>
                    <var key="#xmlformat(ucase(local.key))#">#xmlformat(arguments.params[local.key])#</var>
                  </cfif>
                </cfloop>
              </params>
            </cfif>
          </request>
        </notice>
      </cfoutput>
    </cfsavecontent>

		<!--- send the XML to Hoptoad --->
		<cfhttp method="post" url="#getEndpointURL()#" timeout="0" result="local.http">
			<cfhttpparam type="header" name="Accept" value="text/xml, application/xml">
			<cfhttpparam type="header" name="Content-type" value="text/xml">
			<cfhttpparam type="body" value='#local.xml#'>
		</cfhttp>

		<!--- parse the returned XML back to a structure --->
    <cfscript>
      local.ret = {
        endpoint = getEndpointURL(),
        request = local.xml.toString(),
        response = local.http,
        status = local.http.statusCode,
        id = 0,
        url = ""
      };
      if (isXML(local.http.filecontent)) {
        local.ret_xml = xmlparse(local.http.filecontent);
        if (StructKeyExists(local.ret_xml, 'notice')) {
          local.ret.id = local.ret_xml.notice.id.XmlText;
          local.ret.url = local.ret_xml.notice.url.XmlText;
        }
      }
      return local.ret;
    </cfscript>
	</cffunction>


  <cffunction name="exceptionHandler"
    access="public" returntype="void" output="no"
    hint="Backwards compatible facade for original CF notifier"
  >
		<cfargument name="exception" type="any" required="yes" hint="The exception to handle and send to Hoptoad">
		<cfargument name="action" type="string" required="no" default="" hint="The action to report">
		<cfargument name="controller" type="string" required="no" default="" hint="The controller to report">
    <cfscript>
      var error = errorToStruct(arguments.exception);
      var params = {};
      if ( len(arguments.action) ) { params.action = arguments.action; }
      if ( len(arguments.controller) ) { params.controller = arguments.controller; }
      this.send(error=error, params=params);
    </cfscript>
	</cffunction><!--- end:exceptionHandler() --->


<!--- PRIVATE --->
	<cffunction name="build_backtrace"
    access="private" returntype="array" output="no"
    hint="Cleans up the context array and pulls out the information required for the backtrace"
  >
		<cfargument name="context" type="array" required="yes" hint="The context element of the error structure">
		<cfset var lines = []>
		<cfset var line = {}>
		<cfset var item = {}>
		<cfloop array="#arguments.context#" index="item">
			<cfset line = { line = 0, file = "", method = "" }>
			<cfif structkeyexists(item, "line")><cfset line.line = item.line></cfif>
			<cfif structkeyexists(item, "template")><cfset line.file = item.template></cfif>
			<cfif structkeyexists(item, "raw_trace") AND refind("at cf.*?\$func([A-Z_-]+)\.runFunction", item.raw_trace)>
				<cfset line.method = lcase(trim(rereplace(item.raw_trace, "at cf.*?\$func([A-Z_-]+)\.runFunction.*", "\1")))>
			</cfif>
			<cfset arrayappend(lines, line)>
		</cfloop>
		<cfreturn lines>
	</cffunction>

	<cffunction name="errorToStruct"
    access="private" returntype="struct" output="no"
    hint="Converts a CFCATCH to a proper structure (or just shallow-copies if it's already a structure)"
  >
		<cfargument name="catch" type="any" required="yes" hint="The CFCATCH to convert">
		<cfset var error = {}>
		<cfset var key = "">
		<cfloop collection="#arguments.catch#" item="key">
			<cfset error[key] = arguments.catch[key]>
		</cfloop>
		<cfreturn error>
	</cffunction><!--- end:errorToStruct() --->

</cfcomponent>
