/// Sign-in entry of the new interface (spec 002 FR-014, FR-015, research R3, R5).
/// Lives in the /historymonitor web application, which requires password authentication: IRIS shows its
/// login form before this page runs, and the successful sign-in opens the session whose cookie
/// (path /historymonitor/) the API also accepts. Static files do not open a CSP session, so the
/// interface sends the browser here whenever the API answers 401.
///
/// The only input is "return", the interface route to go back to. It is never executed or echoed into
/// markup: Target keeps it only when it is a plain interface route, otherwise it goes to the Overview.
Class diashenrique.historymonitor.web.Login Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

/// Longest route kept; longer values go to the Overview.
Parameter MAXRETURN = 2000;

ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
	Set %response.Redirect = ..Target($Get(%request.Data("return", 1)))
	Quit 1
}

ClassMethod OnPage() As %Status [ ServerOnly = 1 ]
{
	Quit $$$OK
}

/// "./index.html" plus the requested route when it is a hash route of the interface made of URL-safe
/// characters; "./index.html#/" otherwise. Never an absolute or protocol-relative address.
ClassMethod Target(return As %String) As %String
{
	Set r = $Get(return)
	If ($Length(r) > ..#MAXRETURN) || '$Match(r, "#/[A-Za-z0-9/_?=&%.,:+~-]*") Set r = "#/"
	Quit "./index.html"_r
}

}
