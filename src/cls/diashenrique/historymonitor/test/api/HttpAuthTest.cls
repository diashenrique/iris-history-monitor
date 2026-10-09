/// Authorization and error shape over real HTTP for every route (task T021, user story 4, spec FR-007,
/// FR-008, SC-003). AuthTest checks the decision method; this class checks what a client receives.
///
/// The web application is created from the <WebApplication> element of module.xml (same dispatch class,
/// authentication, resource and match roles) under a test URL, with two temporary users: one holding
/// HistoryMonitorViewer and one without it. Requests go to the instance web server on localhost.
/// Everything is removed afterwards.
Class diashenrique.historymonitor.test.api.HttpAuthTest Extends %UnitTest.TestCase
{

Parameter APP = "/api/historymonitor-test/v1";

Parameter VIEWER = "HMTestViewer";

Parameter NOROLE = "HMTestNoRole";

Parameter H = "diashenrique.historymonitor.test.api.ContractHelper";

/// Passwords are made per run and never stored.
Property Password As %String;

/// The routes, each with valid query values.
ClassMethod Routes() As %List
{
	Quit $ListBuild("/overview", "/history/license?granularity=daily&from=2001-02-01&to=2001-02-02", "/processes?pageSize=1")
}

Method OnBeforeAllTests() As %Status
{
	Set ..Password = "Hm-"_$Translate($System.Util.CreateGUID(), "-")
	Set sc = ##class(diashenrique.historymonitor.util.Security).Setup()
	Quit:$$$ISERR(sc) sc
	Set sc = ..ReadWebApplication(.props)
	Quit:$$$ISERR(sc) sc
	Quit ..CreateAppAndUsers(.props, ..Password)
}

Method OnAfterAllTests() As %Status
{
	Quit ..Cleanup()
}

/// The attributes of <WebApplication> in module.xml, with ${Namespace} resolved to this namespace.
ClassMethod ReadWebApplication(Output props) As %Status
{
	Kill props
	Set root = ##class(%File).NormalizeDirectory($Get(^UnitTestRoot, "/home/irisowner/repo/src/cls"))
	Set file = ##class(%File).ParentDirectoryName(##class(%File).ParentDirectoryName(root))_"module.xml"
	Set sc = ##class(%XML.TextReader).ParseFile(file, .reader)
	Quit:$$$ISERR(sc) sc
	While reader.Read() {
		Continue:(reader.NodeType'="element")||(reader.LocalName'="WebApplication")
		For i = 1:1:reader.AttributeCount {
			Do reader.MoveToAttributeIndex(i)
			Set props(reader.LocalName) = $Replace(reader.Value, "${Namespace}", $Namespace)
		}
		Quit
	}
	Quit $Select($Data(props("DispatchClass")): $$$OK, 1: $$$ERROR($$$GeneralError, "no WebApplication in "_file))
}

ClassMethod CreateAppAndUsers(ByRef props, password As %String) As %Status
{
	Set ns = $Namespace, role = ##class(diashenrique.historymonitor.util.Security).#ROLE
	Do ..Cleanup()
	New $Namespace
	Set $Namespace = "%SYS"
	Set p("DispatchClass") = props("DispatchClass"), p("NameSpace") = ns, p("Enabled") = 1
	For name = "AutheEnabled", "Resource", "MatchRoles", "UseCookies" {
		Set:$Data(props(name)) p(name) = props(name)
	}
	Set sc = ##class(Security.Applications).Create(..#APP, .p)
	Quit:$$$ISERR(sc) sc
	Set sc = ##class(Security.Users).Create(..#VIEWER, role, password)
	Quit:$$$ISERR(sc) sc
	Quit ##class(Security.Users).Create(..#NOROLE, "", password)
}

ClassMethod Cleanup() As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"
	Do:##class(Security.Applications).Exists(..#APP) ##class(Security.Applications).Delete(..#APP)
	For user = ..#VIEWER, ..#NOROLE {
		Do:##class(Security.Users).Exists(user) ##class(Security.Users).Delete(user)
	}
	Quit $$$OK
}

/// $ListBuild(HTTP status, content type, body) of one request. user "" sends no credentials.
ClassMethod Call(path As %String, user As %String = "", password As %String = "", method As %String = "GET") As %List
{
	Set r = ##class(%Net.HttpRequest).%New()
	Set r.Server = "localhost", r.Timeout = 30
	New $Namespace
	Set $Namespace = "%SYS"
	Do ##class(Config.Startup).Get(.startup)
	Set r.Port = $Get(startup("WebServerPort"), 52773)
	If user '= "" Set r.Username = user, r.Password = password
	Set sc = r.Send(method, ..#APP_path)
	Quit:$$$ISERR(sc) $ListBuild(0, "", $System.Status.GetErrorText(sc))
	Set body = $Select($IsObject(r.HttpResponse.Data): r.HttpResponse.Data.Read(1000000), 1: r.HttpResponse.Data)
	Quit $ListBuild(r.HttpResponse.StatusCode, r.HttpResponse.ContentType, body)
}

/// Asserts a problem+json response with the given status.
Method AssertProblem(response As %List, status As %Integer, what As %String)
{
	Do $$$AssertEquals($List(response, 1), status, what_": status")
	Do $$$AssertTrue($ZConvert($List(response, 2), "L") [ "application/problem+json", what_": content type is problem+json (got "_$List(response, 2)_")")
	Set body = ""
	Try { Set body = {}.%FromJSON($List(response, 3)) } Catch {}
	Do $$$AssertTrue($IsObject(body), what_": body is JSON ("_$Extract($List(response, 3), 1, 80)_")")
	Quit:'$IsObject(body)
	Set errs = $ClassMethod(..#H, "Check", "Problem", body)
	Do $$$AssertEquals(errs.%Size(), 0, what_": body is a Problem")
	Do $$$AssertEquals(body.status, status, what_": status in the body")
}

/// 401 comes from %CSP.REST.Login before any API code runs (research.md R11): the status and an
/// empty body. Observed on IRIS 2026.1 behind Apache: no WWW-Authenticate header either.
Method AssertUnauthorized(response As %List, what As %String)
{
	Do $$$AssertEquals($List(response, 1), 401, what_": status")
	Do $$$AssertEquals($List(response, 3), "", what_": empty body, no API data")
}

Method TestWebServerAnswers()
{
	Set response = ..Call("/overview", ..#VIEWER, ..Password)
	Do $$$AssertNotEquals($List(response, 1), 0, "the web server answered: "_$List(response, 3))
}

Method TestNoCredentialsIs401()
{
	Set routes = ..Routes()
	For i = 1:1:$ListLength(routes) {
		Do ..AssertUnauthorized(..Call($List(routes, i)), "no credentials "_$List(routes, i))
	}
}

Method TestWrongPasswordIs401()
{
	Set routes = ..Routes()
	For i = 1:1:$ListLength(routes) {
		Do ..AssertUnauthorized(..Call($List(routes, i), ..#VIEWER, "wrong-"_..Password), "wrong password "_$List(routes, i))
	}
}

Method TestUserWithoutRoleIs403Problem()
{
	Set routes = ..Routes()
	For i = 1:1:$ListLength(routes) {
		Do ..AssertProblem(..Call($List(routes, i), ..#NOROLE, ..Password), 403, "no role "_$List(routes, i))
	}
}

Method TestViewerGetsJson()
{
	Set routes = ..Routes()
	For i = 1:1:$ListLength(routes) {
		Set response = ..Call($List(routes, i), ..#VIEWER, ..Password)
		Do $$$AssertEquals($List(response, 1), 200, "viewer "_$List(routes, i)_": status ("_$Extract($List(response, 3), 1, 120)_")")
		Do $$$AssertTrue($ZConvert($List(response, 2), "L") [ "application/json", "viewer "_$List(routes, i)_": content type")
	}
}

Method TestViewerResponsesMatchTheContract()
{
	For pair = "/overview:OverviewSnapshot", "/history/license?granularity=daily&from=2001-02-01&to=2001-02-02:HistorySeries", "/processes?pageSize=5:ProcessPage" {
		Set path = $Piece(pair, ":", 1), schema = $Piece(pair, ":", 2)
		Set body = ""
		Try { Set body = {}.%FromJSON($List(..Call(path, ..#VIEWER, ..Password), 3)) } Catch {}
		Do $$$AssertTrue($IsObject(body), path_" is JSON")
		Continue:'$IsObject(body)
		Set errs = $ClassMethod(..#H, "Check", schema, body)
		Do $$$AssertEquals(errs.%Size(), 0, path_" matches "_schema_" over HTTP")
	}
}

Method TestBadInputIs400Problem()
{
	Do ..AssertProblem(..Call("/history/license?granularity=daily&from=2001-02-02&to=2001-02-01", ..#VIEWER, ..Password), 400, "reversed range")
	Do ..AssertProblem(..Call("/processes?sort=password", ..#VIEWER, ..Password), 400, "bad sort")
}

Method TestUnknownRouteIs404Problem()
{
	Do ..AssertProblem(..Call("/nope", ..#VIEWER, ..Password), 404, "unknown route")
}

Method TestWrongMethodIs405Problem()
{
	Do ..AssertProblem(..Call("/overview", ..#VIEWER, ..Password, "POST"), 405, "POST /overview")
}

}
