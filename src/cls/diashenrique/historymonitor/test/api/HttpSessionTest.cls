/// One sign-in covers the interface and the API (spec 002 task T014, FR-014, FR-025, research R3, R5).
/// Creates the two web applications of module.xml under a test prefix and signs in once through the
/// login page of the interface (web.Login). Static files do not open a CSP session, so the login page is
/// where the session starts. Then the API is called with only the session cookie. A client without the
/// cookie must still get 401, and the session cookie must be scoped to the prefix, not to "/".
Class diashenrique.historymonitor.test.api.HttpSessionTest Extends %UnitTest.TestCase
{

Parameter PREFIX = "/historymonitor-session-test/";

Parameter VIEWER = "HMSessionViewer";

Property Password As %String;

Method OnBeforeAllTests() As %Status
{
	Set ..Password = "Hm-"_$Translate($System.Util.CreateGUID(), "-")
	Set sc = ##class(diashenrique.historymonitor.util.Security).Setup()
	Quit:$$$ISERR(sc) sc
	Quit ..CreateAppsAndUser(..Password)
}

Method OnAfterAllTests() As %Status
{
	Quit ..Cleanup()
}

/// The attributes of the module.xml element whose Url is url.
ClassMethod Attributes(url As %String, Output props) As %Status
{
	Kill props
	Set root = ##class(%File).NormalizeDirectory($Get(^UnitTestRoot, "/home/irisowner/repo/src/cls"))
	Set repo = ##class(%File).ParentDirectoryName(##class(%File).ParentDirectoryName(root))
	Set sc = ##class(%XML.TextReader).ParseFile(repo_"module.xml", .reader)
	Quit:$$$ISERR(sc) sc
	While reader.Read() {
		Continue:reader.NodeType'="element"
		Kill attrs
		For i = 1:1:reader.AttributeCount {
			Do reader.MoveToAttributeIndex(i)
			Set attrs(reader.LocalName) = reader.Value
		}
		If $Get(attrs("Url")) = url Merge props = attrs Quit
	}
	Set props("Repo") = repo
	Quit $Select($Data(props("Url")): $$$OK, 1: $$$ERROR($$$GeneralError, "no element with Url "_url_" in module.xml"))
}

ClassMethod CreateAppsAndUser(password As %String) As %Status
{
	Set ns = $Namespace, role = ##class(diashenrique.historymonitor.util.Security).#ROLE
	Set sc = ..Attributes("/historymonitor", .ui)
	Quit:$$$ISERR(sc) sc
	Set sc = ..Attributes("/historymonitor/api/v1", .api)
	Quit:$$$ISERR(sc) sc
	Do ..Cleanup()
	New $Namespace
	Set $Namespace = "%SYS"
	// Interface: serve the files straight from the repository build folder.
	Kill p
	Set p("NameSpace") = ns, p("Enabled") = 1, p("ServeFiles") = 1, p("Recurse") = 1
	Set p("Path") = ##class(%File).NormalizeDirectory(ui("Repo")_$Extract(ui("Path"), 2, *))
	Set p("AutheEnabled") = $Select($Get(ui("PasswordAuthEnabled")) && '$Get(ui("UnauthenticatedEnabled")): 32, 1: 96)
	For name = "MatchRoles", "UseCookies", "CookiePath" {
		Set:$Data(ui(name)) p(name) = $Replace($Replace(ui(name), "${Namespace}", ns), "/historymonitor/", ..#PREFIX)
	}
	Set sc = ##class(Security.Applications).Create($Extract(..#PREFIX, 1, *-1), .p)
	Quit:$$$ISERR(sc) sc
	// API.
	Kill p
	Set p("NameSpace") = ns, p("Enabled") = 1, p("DispatchClass") = api("DispatchClass")
	For name = "AutheEnabled", "MatchRoles", "UseCookies", "CookiePath" {
		Set:$Data(api(name)) p(name) = $Replace($Replace(api(name), "${Namespace}", ns), "/historymonitor/", ..#PREFIX)
	}
	Set sc = ##class(Security.Applications).Create(..#PREFIX_"api/v1", .p)
	Quit:$$$ISERR(sc) sc
	Quit ##class(Security.Users).Create(..#VIEWER, role, password)
}

ClassMethod Cleanup() As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"
	For app = ..#PREFIX_"api/v1", $Extract(..#PREFIX, 1, *-1) {
		Do:##class(Security.Applications).Exists(app) ##class(Security.Applications).Delete(app)
	}
	Do:##class(Security.Users).Exists(..#VIEWER) ##class(Security.Users).Delete(..#VIEWER)
	Quit $$$OK
}

ClassMethod Client() As %Net.HttpRequest
{
	Set r = ##class(%Net.HttpRequest).%New()
	Set r.Server = "localhost", r.Timeout = 30
	New $Namespace
	Set $Namespace = "%SYS"
	Do ##class(Config.Startup).Get(.startup)
	Set r.Port = $Get(startup("WebServerPort"), 52773)
	Quit r
}

/// The Set-Cookie value of the CSP session cookie in the last response, or "".
ClassMethod SessionCookie(r As %Net.HttpRequest) As %String
{
	Set all = $Get(r.HttpResponse.Headers("SET-COOKIE"))
	For i = 1:1:$Length(all, ",") {
		Set c = $ZStrip($Piece(all, ",", i), "<>W")
		If $Extract(c, 1, 12) = "CSPSESSIONID" Return c
	}
	Quit ""
}

Method TestOneSignInCoversTheApi()
{
	Set r = ..Client()
	Set r.FollowRedirect = 0
	Set r.Username = ..#VIEWER, r.Password = ..Password
	Do r.Get(..#PREFIX_"diashenrique.historymonitor.web.Login.cls?return="_$ZConvert("#/history?metric=license", "O", "URL"))
	Do $$$AssertEquals(r.HttpResponse.StatusCode, 302, "the login page redirects after sign-in")
	Set location = r.HttpResponse.GetHeader("LOCATION")
	Do $$$AssertTrue($Extract(location, *-34, *) = "/index.html#/history?metric=license", "back to the requested view: "_location)
	Do $$$AssertTrue(location [ (..#PREFIX_"index.html"), "inside the interface application: "_location)
	Set cookie = ..SessionCookie(r)
	Do $$$AssertNotEquals(cookie, "", "the sign-in creates a session cookie")
	Do $$$AssertTrue($ZConvert(cookie, "L") [ ("path="_..#PREFIX), "the session is scoped to the prefix: "_$Extract(cookie, 1, 160))
	Do $$$AssertEquals($ZConvert(cookie, "L") [ "path=/;", 0, "the session is not sent to every application")

	// Same client, no credentials: only the cookie it received.
	Set r.Username = "", r.Password = ""
	Do r.Get(..#PREFIX_"api/v1/settings")
	Do $$$AssertEquals(r.HttpResponse.StatusCode, 200, "the API accepts the interface session")
	Set json = r.HttpResponse.Data.Read(10000)
	Do $$$AssertTrue(json [ "interfaceEnabled", "the API answered with settings: "_$Extract(json, 1, 80))
	Do r.Get(..#PREFIX_"index.html")
	Do $$$AssertEquals(r.HttpResponse.StatusCode, 200, "the interface page is served")
	Do $$$AssertTrue(r.HttpResponse.Data.Read(100000) [ "<div id=""root"">", "it is the built interface")
}

Method TestLoginPageAsksForCredentials()
{
	Set r = ..Client()
	Do r.Get(..#PREFIX_"diashenrique.historymonitor.web.Login.cls")
	Set body = r.HttpResponse.Data.Read(100000)
	Do $$$AssertNotEquals(r.HttpResponse.StatusCode, 302, "no redirect before sign-in")
	Do $$$AssertTrue($ZConvert(body, "L") [ "password", "the IRIS login form is shown")
}

Method TestReturnIsLimitedToInterfaceRoutes()
{
	Set L = "diashenrique.historymonitor.web.Login"
	Do $$$AssertEquals($ClassMethod(L, "Target", "#/processes?q=abc&page=2"), "./index.html#/processes?q=abc&page=2", "an interface route is kept")
	Do $$$AssertEquals($ClassMethod(L, "Target", ""), "./index.html#/", "nothing means the Overview")
	For bad = "https://evil.example/", "//evil.example", "#/x"_$Char(10)_"Location: x", "javascript:alert(1)", "#/<script>", "/csp/sys/UtilHome.csp" {
		Do $$$AssertEquals($ClassMethod(L, "Target", bad), "./index.html#/", "rejected: "_$ZConvert(bad, "O", "JS"))
	}
	Do $$$AssertEquals($ClassMethod(L, "Target", "#/"_$Translate($Justify("", 3000), " ", "a")), "./index.html#/", "too long")
}

Method TestNoSessionMeansNoData()
{
	Set r = ..Client()
	Do r.Get(..#PREFIX_"api/v1/overview")
	Do $$$AssertEquals(r.HttpResponse.StatusCode, 401, "a client without the cookie is refused")
	Do $$$AssertEquals(r.HttpResponse.Data.Read(1000) [ "metrics", 0, "and gets no data")
}

}
