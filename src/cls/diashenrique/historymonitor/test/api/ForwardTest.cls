/// Forwarding of the old addresses (spec 003 US1, FR-002, SC-001; contracts/forwarding.md; research R1,
/// R2). Target() is checked for every row of the contract and for hostile input: the result is always one
/// of six fixed strings, which is also the regression test for the constitution rule "a request never
/// selects which code runs" (analysis C2). Over HTTP, a test copy of the forwarding application, built
/// from module.xml, must answer 302 to anyone, signed in or not, for any method.
Class diashenrique.historymonitor.test.api.ForwardTest Extends %UnitTest.TestCase
{

Parameter F = "diashenrique.historymonitor.web.Forward";

Parameter APP = "/csp/irismonitor-test";

Parameter OVERVIEW = "/historymonitor/index.html#/";

/// The contract: old address, target.
ClassMethod Rows() As %List
{
	Quit $ListBuild(
		$ListBuild("/dashboard.csp", "/historymonitor/index.html#/"),
		$ListBuild("/historylicense.csp", "/historymonitor/index.html#/history?metric=license"),
		$ListBuild("/historycspsessions.csp", "/historymonitor/index.html#/history?metric=csp-sessions"),
		$ListBuild("/historydatabase.csp", "/historymonitor/index.html#/history?metric=database-size"),
		$ListBuild("/systemprocesses.csp", "/historymonitor/index.html#/processes"))
}

ClassMethod Targets() As %List
{
	Set all = $ListBuild(..#OVERVIEW), rows = ..Rows(), ptr = 0
	While $ListNext(rows, ptr, row) { Set all = all_$ListBuild($List(row, 2)) }
	Quit all
}

Method OnBeforeAllTests() As %Status
{
	Set sc = ##class(diashenrique.historymonitor.test.api.HttpSessionTest).Attributes("/csp/irismonitor", .props)
	Quit:$$$ISERR(sc) sc
	Set ns = $Namespace
	Do ..Cleanup()
	New $Namespace
	Set $Namespace = "%SYS"
	Set p("NameSpace") = ns, p("Enabled") = 1
	For name = "DispatchClass", "AutheEnabled", "MatchRoles", "CookiePath", "UseCookies", "ServeFiles" {
		Set:$Data(props(name)) p(name) = $Replace($Replace(props(name), "${Namespace}", ns), "/csp/irismonitor", ..#APP)
	}
	Quit ##class(Security.Applications).Create(..#APP, .p)
}

Method OnAfterAllTests() As %Status
{
	Quit ..Cleanup()
}

ClassMethod Cleanup() As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"
	Do:##class(Security.Applications).Exists(..#APP) ##class(Security.Applications).Delete(..#APP)
	Quit $$$OK
}

Method TestEveryOldPageHasItsScreen()
{
	Set rows = ..Rows(), ptr = 0
	While $ListNext(rows, ptr, row) {
		Do $$$AssertEquals($ClassMethod(..#F, "Target", $List(row, 1)), $List(row, 2), $List(row, 1))
		Do $$$AssertEquals($ClassMethod(..#F, "Target", $ZConvert($List(row, 1), "U")), $List(row, 2), $List(row, 1)_" in capitals")
		Do $$$AssertEquals($ClassMethod(..#F, "Target", "/deep/path"_$List(row, 1)), $List(row, 2), $List(row, 1)_" below a folder")
	}
}

Method TestEverythingElseIsTheOverview()
{
	For path = "", "/", "/dashboardapi.csp", "/resources/plugins/x.css", "/diashenrique.historymonitor.dashboard.license.cls", "/unknown.csp", "/historylicense.csp.bak", "/historylicense" {
		Do $$$AssertEquals($ClassMethod(..#F, "Target", path), ..#OVERVIEW, "'"_path_"'")
	}
}

Method TestHostileInputOnlyGetsAFixedTarget()
{
	Set targets = ..Targets()
	For path = "/../../etc/passwd", "/x#javascript:alert(1)", "/a"_$Char(13,10)_"Location: http://evil", "//evil.example/", "/historylicense.csp?x=http://evil", "/%2e%2e/historylicense.csp", "/"_$Char(0), "/"_$Translate($Justify("", 5000), " ", "a") {
		Set t = $ClassMethod(..#F, "Target", path)
		Do $$$AssertTrue($ListFind(targets, t), "fixed target for hostile input ("_$Extract($ZConvert(path, "O", "JSON"), 1, 40)_"): "_t)
	}
}

Method TestOverHttpAnyoneIsForwarded()
{
	Set rows = ..Rows(), ptr = 0
	While $ListNext(rows, ptr, row) {
		For method = "GET", "HEAD", "POST" {
			Set r = ..Call($List(row, 1)_"?from=2001-01-01", method)
			Do $$$AssertEquals(r.HttpResponse.StatusCode, 302, method_" "_$List(row, 1)_": status")
			Do $$$AssertEquals(r.HttpResponse.GetHeader("LOCATION"), $List(row, 2), method_" "_$List(row, 1)_": Location")
			Do $$$AssertTrue(r.HttpResponse.GetHeader("CACHE-CONTROL") [ "no-store", method_" "_$List(row, 1)_": not cached")
		}
	}
	Set r = ..Call("/resources/plugins/extreme18.2.3/dx.all.js")
	Do $$$AssertEquals(r.HttpResponse.StatusCode, 302, "an old static file: status")
	Do $$$AssertEquals(r.HttpResponse.GetHeader("LOCATION"), ..#OVERVIEW, "an old static file goes to the Overview")
	Set cookie = r.HttpResponse.GetHeader("SET-COOKIE")
	Do $$$AssertNotTrue(cookie [ "/historymonitor", "no cookie for the new monitor's path is set here ("_cookie_")")
}

/// One request without credentials and without following redirects.
ClassMethod Call(path As %String, method As %String = "GET") As %Net.HttpRequest
{
	Set r = ##class(%Net.HttpRequest).%New()
	Set r.Server = "localhost", r.Timeout = 30, r.FollowRedirect = 0
	New $Namespace
	Set $Namespace = "%SYS"
	Do ##class(Config.Startup).Get(.startup)
	Set r.Port = $Get(startup("WebServerPort"), 52773)
	Do r.Send(method, ..#APP_path)
	Quit r
}

}
