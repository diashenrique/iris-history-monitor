/// Concurrency test for the history service (task T015, spec FR-009, SC-004).
/// The legacy pages Kill and rewrite ^IRISMonitor per request, so two users could overwrite each other.
/// Here two background processes read overlapping ranges at the same time, many times, and each must
/// always get exactly the result a lone serial call gets. The workers report through ^UnitTest.HMConc,
/// a test-only global; the service itself writes no global.
Class diashenrique.historymonitor.test.api.ConcurrencyTest Extends %UnitTest.TestCase
{

Parameter F = "diashenrique.historymonitor.test.api.HistoryFixture";

Parameter ROUNDS = 25;

Method OnBeforeAllTests() As %Status
{
	Kill ^UnitTest.HMConc
	Quit $ClassMethod(..#F, "Create")
}

Method OnAfterAllTests() As %Status
{
	Kill ^UnitTest.HMConc
	Quit $ClassMethod(..#F, "Remove")
}

/// The JSON of one request, without generatedAt-like fields (the history response has none).
ClassMethod Read(from As %String, to As %String) As %String
{
	Set q("granularity") = "5min", q("from") = from, q("to") = to
	Quit ##class(diashenrique.historymonitor.api.Dispatch).HistoryResponse("license", .q, .code).%ToJSON()
}

/// Background worker: reads its range ROUNDS times and records how many results differed from the first.
ClassMethod Worker(name As %String, from As %String, to As %String)
{
	Set first = "", diff = 0
	Try {
		For i = 1:1:..#ROUNDS {
			Set json = ..Read(from, to)
			If first = "" Set first = json
			If json '= first Set diff = diff + 1
		}
	} Catch ex {
		Set ^UnitTest.HMConc(name, "error") = ex.DisplayString()
	}
	Set ^UnitTest.HMConc(name, "json") = first
	Set ^UnitTest.HMConc(name, "diff") = diff
	Set ^UnitTest.HMConc(name, "done") = 1
}

Method TestOverlappingRequestsKeepTheirOwnData()
{
	Set a("from") = "2001-02-03T10:00:00Z", a("to") = "2001-02-03T10:25:00Z"
	Set b("from") = "2001-02-03T10:20:00Z", b("to") = "2001-02-03T10:55:00Z"
	Set expectA = ..Read(a("from"), a("to")), expectB = ..Read(b("from"), b("to"))
	Do $$$AssertNotEquals(expectA, expectB, "the two ranges give different data")

	Kill ^UnitTest.HMConc
	Job ##class(diashenrique.historymonitor.test.api.ConcurrencyTest).Worker("a", a("from"), a("to"))::10
	Do $$$AssertTrue($Test, "worker a started")
	Job ##class(diashenrique.historymonitor.test.api.ConcurrencyTest).Worker("b", b("from"), b("to"))::10
	Do $$$AssertTrue($Test, "worker b started")
	// Read the same ranges here too while the workers run.
	For i = 1:1:..#ROUNDS {
		If ..Read(a("from"), a("to")) '= expectA Set ^UnitTest.HMConc("main", "diff") = $Get(^UnitTest.HMConc("main", "diff")) + 1
		If ..Read(b("from"), b("to")) '= expectB Set ^UnitTest.HMConc("main", "diff") = $Get(^UnitTest.HMConc("main", "diff")) + 1
	}
	For wait = 1:1:120 {
		Quit:$Get(^UnitTest.HMConc("a", "done"))&&$Get(^UnitTest.HMConc("b", "done"))
		Hang 0.25
	}
	For name = "a", "b" {
		Do $$$AssertEquals($Get(^UnitTest.HMConc(name, "done")), 1, "worker "_name_" finished")
		Do $$$AssertEquals($Get(^UnitTest.HMConc(name, "error")), "", "worker "_name_" had no error")
		Do $$$AssertEquals($Get(^UnitTest.HMConc(name, "diff")), 0, "worker "_name_" always got the same result")
	}
	Do $$$AssertEquals($Get(^UnitTest.HMConc("a", "json")), expectA, "worker a got only its own range")
	Do $$$AssertEquals($Get(^UnitTest.HMConc("b", "json")), expectB, "worker b got only its own range")
	Do $$$AssertEquals($Get(^UnitTest.HMConc("main", "diff"), 0), 0, "the main process was not disturbed either")
}

}
