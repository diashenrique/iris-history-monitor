/// REST dispatch class for the History Monitor API v1 (spec 001-api-v1).
/// Routes: GET /overview (T013), GET /history/:metric (T017), GET /processes (T020).
///
/// Access: the web application (module.xml) requires password authentication and allows no
/// unauthenticated access. A request without valid credentials is answered by %CSP.REST.Login with 401
/// and an empty body, not a problem: that code runs before login, with no roles, and cannot run code
/// from this namespace's database, so it is not overridden here (research.md R11).
/// OnPreDispatch then requires Use on the HistoryMonitorRead resource and answers 403 without it.
/// The web application itself requires no resource: when it did, CSP refused users without the role
/// before this class ran, with a 401 HTML page instead of a 403 problem (research.md R11).
/// Errors leave as problem+json and never carry internal error text.
Class diashenrique.historymonitor.api.Dispatch Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

Parameter CHARSET = "utf-8";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/overview" Method="GET" Call="Overview"/>
<Route Url="/history/:metric" Method="GET" Call="History"/>
<Route Url="/processes" Method="GET" Call="Processes"/>
</Routes>
}

/// GET /overview: the current snapshot (user story 1). An unavailable source is reported per metric,
/// so this route answers 200 even when the dashboard sample cannot be read.
ClassMethod Overview() As %Status
{
	Write ##class(diashenrique.historymonitor.service.Overview).Snapshot().%ToJSON()
	Quit $$$OK
}

/// Query parameters GET /history/:metric reads. Anything else in the query string is ignored.
Parameter HISTORYPARAMS = "granularity,from,to,database,limit,cursor";

/// GET /history/:metric: one metric over a range (user story 2). Invalid input is a 400 problem.
ClassMethod History(metric As %String) As %Status
{
	Set names = ..#HISTORYPARAMS
	For i = 1:1:$Length(names, ",") {
		Set p = $Piece(names, ",", i)
		If $Data(%request.Data(p, 1)) Set q(p) = %request.Data(p, 1)
	}
	Set body = ..HistoryResponse(metric, .q, .code)
	If code '= 200 {
		Set %response.ContentType = ##class(diashenrique.historymonitor.api.Problem).ContentType()
		Set %response.Status = ##class(diashenrique.historymonitor.api.Problem).StatusLine(code)
	}
	Write body.%ToJSON()
	Quit $$$OK
}

/// The body of GET /history/:metric without the HTTP write, so it can be tested. q is subscripted
/// by query parameter name; code receives 200 or 400.
ClassMethod HistoryResponse(metric As %String, ByRef q, Output code As %Integer) As %DynamicObject
{
	Set errs = ##class(diashenrique.historymonitor.service.Validate).History(metric, .q, .clean)
	If errs.%Size() > 0 {
		Set code = 400
		Quit ##class(diashenrique.historymonitor.api.Problem).Body(400, "invalid-parameter", "One or more parameters are not valid.", errs)
	}
	Set code = 200
	Quit ##class(diashenrique.historymonitor.service.History).Series(.clean)
}

/// Query parameters GET /processes reads.
Parameter PROCESSPARAMS = "namespace,user,state,q,sort,page,pageSize";

/// GET /processes: one page of the process list (user story 3). Invalid input is a 400 problem.
ClassMethod Processes() As %Status
{
	Set names = ..#PROCESSPARAMS
	For i = 1:1:$Length(names, ",") {
		Set p = $Piece(names, ",", i)
		If $Data(%request.Data(p, 1)) Set q(p) = %request.Data(p, 1)
	}
	Set body = ..ProcessesResponse(.q, .code)
	If code '= 200 {
		Set %response.ContentType = ##class(diashenrique.historymonitor.api.Problem).ContentType()
		Set %response.Status = ##class(diashenrique.historymonitor.api.Problem).StatusLine(code)
	}
	Write body.%ToJSON()
	Quit $$$OK
}

/// The body of GET /processes without the HTTP write. code receives 200 or 400.
ClassMethod ProcessesResponse(ByRef q, Output code As %Integer) As %DynamicObject
{
	Set errs = ##class(diashenrique.historymonitor.service.Validate).Processes(.q, .clean)
	If errs.%Size() > 0 {
		Set code = 400
		Quit ##class(diashenrique.historymonitor.api.Problem).Body(400, "invalid-parameter", "One or more parameters are not valid.", errs)
	}
	Set code = 200
	Quit ##class(diashenrique.historymonitor.service.Processes).Page(.clean)
}

/// The resource a caller must hold Use on. One definition, shared with util.Security.
ClassMethod Resource() As %String
{
	Quit ##class(diashenrique.historymonitor.util.Security).#RESOURCE
}

/// The access decision, kept free of the session so it can be tested.
/// 401: nobody is authenticated. 403: authenticated without Use on the resource. 200: allowed.
ClassMethod Authorize(username As %String, hasUse As %Boolean) As %Integer
{
	If ($Get(username) = "") || (username = "UnknownUser") Quit 401
	If '$Get(hasUse) Quit 403
	Quit 200
}

/// Runs before routing. Stops the request with a problem+json response when access is not allowed.
ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
	Set code = ..Authorize($Username, $SYSTEM.Security.Check(..Resource(), "USE"))
	If code '= 200 {
		Set pContinue = 0
		Do ..Fail(code)
	}
	Quit $$$OK
}

/// Replaces the default error page for 404, 405 and unhandled errors with problem+json.
ClassMethod ReportHttpStatusCode(pHttpStatus As %String, pSC As %Status = {$$$OK}) As %Status
{
	Do ..Fail(+pHttpStatus, pSC)
	Quit $$$OK
}

/// The problem object for a status. Unmapped statuses become a generic 500. The text of sc is never
/// copied into the response, because it can hold paths, globals or SQL.
ClassMethod ErrorBody(code As %Integer, sc As %Status = {$$$OK}) As %DynamicObject
{
	If '$ListFind($ListBuild(400, 401, 403, 404, 405, 500), code) Set code = 500
	Set slug = $Case(code, 400: "invalid-request", 401: "unauthorized", 403: "forbidden", 404: "not-found", 405: "method-not-allowed", : "internal-error")
	Set detail = $Case(code, 400: "The request is not valid.", 401: "Authentication is required.", 403: "The authenticated user is not allowed to use this API.", 404: "No such route.", 405: "This method is not allowed for this route.", : "An internal error occurred.")
	Quit ##class(diashenrique.historymonitor.api.Problem).Body(code, slug, detail)
}

/// Writes the problem+json response with the right status line and content type.
ClassMethod Fail(code As %Integer, sc As %Status = {$$$OK})
{
	Set body = ..ErrorBody(code, sc)
	If (body.status = 500) && $$$ISERR(sc) {
		Try {
			Do ##class(%SYS.System).WriteToConsoleLog("History Monitor API error: "_$SYSTEM.Status.GetOneStatusText(sc), 0, 1)
		} Catch {
		}
	}
	Set %response.ContentType = ##class(diashenrique.historymonitor.api.Problem).ContentType()
	Set %response.Status = ##class(diashenrique.historymonitor.api.Problem).StatusLine(body.status)
	Write body.%ToJSON()
}

}
