/// Contract tests for GET /processes (task T018, user story 3, spec FR-005, data-model ProcessPage).
/// Written before service.Processes (T019) and the route (T020).
///
/// service.Processes.Build is the pure part (items in, page out), so filters, sorting and paging are
/// tested on fixed items; Page reads the live CONTROLPANEL query and must match the contract.
/// api.Dispatch.ProcessesResponse is the route body without the HTTP write.
Class diashenrique.historymonitor.test.api.ProcessesTest Extends %UnitTest.TestCase
{

Parameter S = "diashenrique.historymonitor.service.Processes";

Parameter D = "diashenrique.historymonitor.api.Dispatch";

Parameter H = "diashenrique.historymonitor.test.api.ContractHelper";

ClassMethod Text(errs As %DynamicArray) As %String
{
	Quit ##class(diashenrique.historymonitor.test.api.ContractHelperTest).Text(errs)
}

/// Five fixed processes, as Page would have built them.
ClassMethod Items(Output items)
{
	Kill items
	Set items(1) = {"job": 1, "pid": 101, "routine": "CONTROL", "state": "RUN", "cpuTime": 50}
	Set items(2) = {"job": 2, "pid": 102, "username": "alice", "namespace": "USER", "routine": "MyApp.Orders", "state": "READ", "cpuTime": 900, "clientName": "WS-ALICE"}
	Set items(3) = {"job": 3, "pid": 103, "username": "bob", "namespace": "USER", "routine": "%CSP.Broker", "state": "RUNW", "cpuTime": 10}
	Set items(4) = {"job": 4, "pid": 104, "username": "alice", "namespace": "%SYS", "routine": "WRTDMN", "state": "HANG", "cpuTime": 300}
	Set items(5) = {"job": 5, "pid": 105, "username": "carol", "namespace": "APP", "routine": "Report.Monthly", "state": "READ", "cpuTime": 900}
}

/// Runs a request through the route body.
ClassMethod Get(ByRef q, Output code) As %DynamicObject
{
	Quit $ClassMethod(..#D, "ProcessesResponse", .q, .code)
}

/// A page of the fixed items for the given request values (already valid).
ClassMethod Fixed(ByRef q) As %DynamicObject
{
	Do ##class(diashenrique.historymonitor.service.Validate).Processes(.q, .clean)
	Do ..Items(.items)
	Quit $ClassMethod(..#S, "Build", .clean, .items)
}

/// The values of one field over the items of a page, joined by commas.
ClassMethod Values(page As %DynamicObject, field As %String) As %String
{
	Set out = ""
	Set it = page.items.%GetIterator()
	While it.%GetNext(.k, .p) { Set out = out_$Select(out = "": "", 1: ",")_p.%Get(field) }
	Quit out
}

Method TestLivePageMatchesContract()
{
	Set page = ..Get(.q, .code)
	Do $$$AssertEquals(code, 200, "status")
	Set errs = $ClassMethod(..#H, "Check", "ProcessPage", page)
	Do $$$AssertEquals(errs.%Size(), 0, "matches ProcessPage: "_..Text(errs))
	Do $$$AssertTrue(page.total > 0, "at least this process is listed")
	Do $$$AssertEquals(page.page, 1, "default page")
	Do $$$AssertEquals(page.pageSize, 100, "default page size")
}

Method TestLiveItemsUseTheDocumentedFieldsOnly()
{
	Set allowed = $ClassMethod(..#S, "Fields")
	Set page = ..Get(.q, .code)
	Set it = page.items.%GetIterator()
	While it.%GetNext(.k, .p) {
		Set fit = p.%GetIterator()
		While fit.%GetNext(.name, .value) {
			Do $$$AssertTrue($ListFind(allowed, name), "documented field: "_name)
			Do $$$AssertNotEquals(value, "", name_" is omitted when empty, not sent as """"")
		}
	}
}

Method TestLiveListShowsThisProcess()
{
	// While the snapshot is read this process is in %SYS, so it is found by pid, not by namespace.
	Set q("q") = $Job
	Set page = ..Get(.q, .code)
	Do $$$AssertTrue(","_..Values(page, "pid")_"," [ (","_$Job_","), "this process ("_$Job_") is listed")
}

Method TestLiveNamespaceFilterKeepsOnlyThatNamespace()
{
	Set all = ..Get(.q, .code)
	Set ns = ""
	Set it = all.items.%GetIterator()
	While it.%GetNext(.k, .p) { If p.namespace '= "" Set ns = p.namespace Quit }
	Do $$$AssertNotEquals(ns, "", "some live process has a namespace")
	Quit:ns=""
	Set q("namespace") = ns
	Set page = ..Get(.q, .code)
	Do $$$AssertTrue(page.total > 0, "the namespace "_ns_" matches at least one process")
	Do $$$AssertTrue(page.total <= all.total, "a filter never adds processes")
	Set it = page.items.%GetIterator()
	While it.%GetNext(.k, .p) { Do $$$AssertEquals(p.namespace, ns, "only "_ns_" processes") }
}

Method TestLiveDaemonHasNoPlaceholders()
{
	Set q("q") = "CONTROL"
	Set page = ..Get(.q, .code)
	Set found = 0
	Set it = page.items.%GetIterator()
	While it.%GetNext(.k, .p) {
		Continue:p.routine'="CONTROL"
		Set found = 1
		Do $$$AssertEquals(p.%IsDefined("username"), 0, "the control daemon has no username field")
		Do $$$AssertEquals(p.%IsDefined("device"), 0, "nor a device field")
		Do $$$AssertEquals(p.%GetTypeOf("pid"), "number", "pid is a number")
	}
	Do $$$AssertTrue(found, "the CONTROL daemon is listed")
}

/// The service does not call CONTROLPANEL (it needs %Admin_Manage, research.md R10) but must give the
/// same values. The tests run as a superuser, so CONTROLPANEL can be read here for comparison.
/// Long-lived system daemons are compared, because their counters do not move between the two reads.
Method TestLiveValuesMatchControlPanel()
{
	Do ..ControlPanel(.cp)
	Do $$$AssertTrue($Data(cp) > 0, "CONTROLPANEL rows read")
	Set q("pageSize") = 500
	Set page = ..Get(.q, .code)
	Set compared = 0
	Set it = page.items.%GetIterator()
	While it.%GetNext(.k, .p) {
		Continue:'$Data(cp(p.pid))
		Continue:'$ListFind($ListBuild("CONTROL", "WRTDMN", "GARCOL", "JRNDMN", "EXPDMN"), p.routine)
		Set compared = compared + 1
		For field = "job", "displayPid", "username", "device", "namespace", "routine", "state", "clientName", "exeName", "ipAddress", "osUsername", "parentPid" {
			Do $$$AssertEquals(p.%Get(field), $Get(cp(p.pid, field)), p.routine_" "_field)
		}
	}
	Do $$$AssertTrue(compared >= 2, "compared "_compared_" daemons")
}

/// CONTROLPANEL rows by pid: cp(pid, field) = value, using the API field names.
ClassMethod ControlPanel(Output cp)
{
	Kill cp
	Set names = $ListBuild("job", "pid", "displayPid", "username", "device", "namespace", "routine", "commands", "globals", "state", "clientName", "exeName", "ipAddress", "", "", "", "", "privateGlobalBlocks", "osUsername", "cpuTime", "parentPid", "elapsedTime")
	New $Namespace
	Set $Namespace = "%SYS"
	Set stmt = ##class(%SQL.Statement).%New()
	Quit:$$$ISERR(stmt.%PrepareClassQuery("%SYS.ProcessQuery", "CONTROLPANEL"))
	Set rs = stmt.%Execute()
	While rs.%Next() {
		Set pid = rs.%GetData(2)
		For i = 1:1:$ListLength(names) {
			Set name = $List(names, i)
			If (name '= "") && (rs.%GetData(i) '= "") Set cp(pid, name) = rs.%GetData(i)
		}
	}
}

Method TestFilters()
{
	Set q("namespace") = "USER"
	Do $$$AssertEquals(..Values(..Fixed(.q), "job"), "2,3", "namespace")
	Kill q
	Set q("user") = "alice"
	Do $$$AssertEquals(..Values(..Fixed(.q), "job"), "2,4", "user")
	Kill q
	Set q("state") = "READ"
	Do $$$AssertEquals(..Values(..Fixed(.q), "job"), "2,5", "state")
	Kill q
	Set q("user") = "alice", q("namespace") = "USER"
	Do $$$AssertEquals(..Values(..Fixed(.q), "job"), "2", "filters combine")
	Kill q
	Set q("namespace") = "NOSUCH"
	Set page = ..Fixed(.q)
	Do $$$AssertEquals(page.total, 0, "an unknown value matches nothing")
	Do $$$AssertEquals(page.items.%Size(), 0, "no items")
}

Method TestTextSearchIsCaseInsensitiveOverTextFields()
{
	Set q("q") = "orders"
	Do $$$AssertEquals(..Values(..Fixed(.q), "job"), "2", "matches the routine, any case")
	Set q("q") = "ws-alice"
	Do $$$AssertEquals(..Values(..Fixed(.q), "job"), "2", "matches the client name")
	Set q("q") = "105"
	Do $$$AssertEquals(..Values(..Fixed(.q), "job"), "5", "matches the pid")
}

Method TestSorting()
{
	Set q("sort") = "routine"
	Do $$$AssertEquals(..Values(..Fixed(.q), "routine"), "%CSP.Broker,CONTROL,MyApp.Orders,Report.Monthly,WRTDMN", "text ascending")
	Set q("sort") = "-cpuTime"
	Do $$$AssertEquals(..Values(..Fixed(.q), "job"), "2,5,4,1,3", "numbers descending, ties by job")
	Set q("sort") = "cpuTime"
	Do $$$AssertEquals(..Values(..Fixed(.q), "job"), "3,1,4,2,5", "numbers ascending, ties by job")
	Set q("sort") = "username"
	Do $$$AssertEquals(..Values(..Fixed(.q), "job"), "2,4,3,5,1", "a process without the field sorts last")
	Kill q
	Do $$$AssertEquals(..Values(..Fixed(.q), "job"), "1,2,3,4,5", "default order is the job number")
}

Method TestPaging()
{
	Set q("pageSize") = 2, q("page") = 1
	Set page = ..Fixed(.q)
	Do $$$AssertEquals(..Values(page, "job"), "1,2", "first page")
	Do $$$AssertEquals(page.total, 5, "total counts every match")
	Do $$$AssertEquals(page.next, "2", "next names the following page")
	Set q("page") = 3
	Set page = ..Fixed(.q)
	Do $$$AssertEquals(..Values(page, "job"), "5", "last page")
	Do $$$AssertEquals(page.%IsDefined("next"), 0, "no next on the last page")
	Set errs = $ClassMethod(..#H, "Check", "ProcessPage", page)
	Do $$$AssertEquals(errs.%Size(), 0, "matches the contract: "_..Text(errs))
}

Method TestPageAfterTheEndIsEmptyNotAnError()
{
	// A process that ends between two requests can leave the next page short or empty.
	Set q("pageSize") = 2, q("page") = 9
	Set page = ..Fixed(.q)
	Do $$$AssertEquals(page.items.%Size(), 0, "no items")
	Do $$$AssertEquals(page.total, 5, "total still reported")
	Do $$$AssertEquals(page.%IsDefined("next"), 0, "no next")
	Set errs = $ClassMethod(..#H, "Check", "ProcessPage", page)
	Do $$$AssertEquals(errs.%Size(), 0, "matches the contract: "_..Text(errs))
}

Method TestBadRequestsAreProblems()
{
	Set cases = ""
	Set cases = cases_$ListBuild($ListBuild("sort", "password"))
	Set cases = cases_$ListBuild($ListBuild("sort", "-"))
	Set cases = cases_$ListBuild($ListBuild("sort", "routine;DROP"))
	Set cases = cases_$ListBuild($ListBuild("page", "0"))
	Set cases = cases_$ListBuild($ListBuild("page", "1.5"))
	Set cases = cases_$ListBuild($ListBuild("pageSize", "501"))
	Set cases = cases_$ListBuild($ListBuild("pageSize", "abc"))
	Set cases = cases_$ListBuild($ListBuild("q", $Translate($Justify("", 101), " ", "x")))
	Set cases = cases_$ListBuild($ListBuild("namespace", "USER"_$Char(10)_"X"))
	Set cases = cases_$ListBuild($ListBuild("user", $Translate($Justify("", 200), " ", "u")))
	For i = 1:1:$ListLength(cases) {
		Set c = $List(cases, i)
		Kill q
		Set q($List(c, 1)) = $List(c, 2)
		Set body = ..Get(.q, .code)
		Do $$$AssertEquals(code, 400, $List(c, 1)_" case "_i_" is a 400")
		Set errs = $ClassMethod(..#H, "Check", "Problem", body)
		Do $$$AssertEquals(errs.%Size(), 0, "case "_i_" is a Problem: "_..Text(errs))
		Do $$$AssertEquals(body.type, "/problems/invalid-parameter", "case "_i_" type")
		Do $$$AssertEquals(body.errors.%Get(0).parameter, $List(c, 1), "case "_i_" names the parameter")
	}
}

Method TestRouteIsMapped()
{
	Set xdata = ##class(%Dictionary.CompiledXData).%OpenId(..#D_"||UrlMap")
	Quit:'$IsObject(xdata)
	Set text = $ZStrip(xdata.Data.Read(32000), "*WC")
	Do $$$AssertTrue(text [ "<RouteUrl=""/processes""Method=""GET""Call=""Processes""/>", "GET /processes calls Processes")
}

}
