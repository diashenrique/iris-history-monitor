/// The old prefix /csp/irismonitor after the old pages were removed (spec 003 US1, FR-002; research R1, R2).
/// Every request, whatever its method or path, gets 302 to the matching screen of the new monitor
/// (specs/003-retire-old-pages/contracts/forwarding.md). The target is always one of six fixed strings,
/// chosen by the last path segment; nothing from the request is copied into it, no data is read and no
/// other host is called. The application allows unauthenticated access: the new monitor asks for sign-in
/// itself and returns to the target screen. Stays for all of 2.x (FR-003).
Class diashenrique.historymonitor.web.Forward Extends %CSP.REST
{

Parameter OVERVIEW = "/historymonitor/index.html#/";

/// No routes: OnPreDispatch answers every request itself.
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
</Routes>
}

/// The new address for an old path (the part of the URL after /csp/irismonitor, query string ignored).
ClassMethod Target(path As %String) As %String
{
	Set path = $Piece($Get(path), "?", 1)
	Set page = $ZConvert($Piece(path, "/", $Length(path, "/")), "L")
	Quit $Case(page,
		"dashboard.csp": ..#OVERVIEW,
		"historylicense.csp": "/historymonitor/index.html#/history?metric=license",
		"historycspsessions.csp": "/historymonitor/index.html#/history?metric=csp-sessions",
		"historydatabase.csp": "/historymonitor/index.html#/history?metric=database-size",
		"systemprocesses.csp": "/historymonitor/index.html#/processes",
		: ..#OVERVIEW)
}

/// Every method and path: 302 to Target(url), not cached, no body. OnPreDispatch runs before any route
/// is looked up, and stopping there answers every request (DispatchRequest is final in %CSP.REST).
ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
	Set pContinue = 0
	Set %response.Status = "302 Found"
	Set %response.ContentType = "text/plain"
	Do %response.SetHeader("Location", ..Target(pUrl))
	Do %response.SetHeader("Cache-Control", "no-store")
	Quit $$$OK
}

}
