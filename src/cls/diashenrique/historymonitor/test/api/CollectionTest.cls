/// History collection health (spec 004 FR-001, FR-002, FR-006, SC-002; research R2). The state decision is
/// tested as a pure function; the response against the contract and against the instance's own settings;
/// and reading it must leave the collector and retention settings exactly as they were (option A).
Class diashenrique.historymonitor.test.api.CollectionTest Extends %UnitTest.TestCase
{

Parameter C = "diashenrique.historymonitor.service.Collection";

Parameter D = "diashenrique.historymonitor.api.Dispatch";

Method TestDecideOffWhenNotConfigured()
{
	Do $$$AssertEquals($ClassMethod(..#C, "Decide", 0, 1000, 1000, 300), "off", "not configured, even with a fresh sample")
	Do $$$AssertEquals($ClassMethod(..#C, "Decide", 0, "", 1000, 300), "off", "not configured, no sample")
}

Method TestDecideStale()
{
	Do $$$AssertEquals($ClassMethod(..#C, "Decide", 1, "", 100000, 300), "stale", "configured, never recorded")
	Do $$$AssertEquals($ClassMethod(..#C, "Decide", 1, 100000 - 901, 100000, 300), "stale", "last sample older than three intervals")
	Do $$$AssertEquals($ClassMethod(..#C, "Decide", 1, 100000 - 91, 100000, 30), "stale", "three intervals of a shorter interval")
}

Method TestDecideRecording()
{
	Do $$$AssertEquals($ClassMethod(..#C, "Decide", 1, 100000 - 900, 100000, 300), "recording", "exactly three intervals")
	Do $$$AssertEquals($ClassMethod(..#C, "Decide", 1, 100000 - 10, 100000, 300), "recording", "recent sample")
	Do $$$AssertEquals($ClassMethod(..#C, "Decide", 1, 100000 - 900, 100000, ""), "recording", "unknown interval falls back to 300 s")
}

Method TestResponseMatchesTheContract()
{
	Set body = $ClassMethod(..#C, "Response")
	Set errs = ##class(diashenrique.historymonitor.test.api.ContractHelper).Check("HistoryCollection", body)
	Do $$$AssertEquals(errs.%Size(), 0, "matches HistoryCollection: "_##class(diashenrique.historymonitor.test.api.ContractHelperTest).Text(errs))
	Do $$$AssertEquals(body.retention.daily.kind, "indefinite", "daily summaries are never purged automatically")
	Do $$$AssertEquals(body.retention.daily.%GetTypeOf("days"), "null", "no day count for indefinite")
	// Every state is valid in the contract (an unquoted off in YAML once became the boolean false).
	For state = "recording", "stale", "off" {
		Set copy = {}.%FromJSON(body.%ToJSON())
		Set copy.state = state
		Set errs = ##class(diashenrique.historymonitor.test.api.ContractHelper).Check("HistoryCollection", copy)
		Do $$$AssertEquals(errs.%Size(), 0, "state "_state_" is in the contract: "_##class(diashenrique.historymonitor.test.api.ContractHelperTest).Text(errs))
	}
}

Method TestRetentionIsTheInstanceSetting()
{
	New $Namespace
	Set $Namespace = "%SYS"
	Set detail = ##class(SYS.History.PerfData).SetPurge(""), hourly = ##class(SYS.History.Hourly).SetPurge("")
	Set $Namespace = "USER"
	Set body = $ClassMethod(..#C, "Response")
	Do $$$AssertEquals(body.retention."5min".days, detail, "5-minute detail days")
	Do $$$AssertEquals(body.retention.hourly.days, hourly, "hourly days")
	// An administrator's change shows up (SC-002); the old value is put back whatever happens.
	Try {
		Set $Namespace = "%SYS"
		Do ##class(SYS.History.Hourly).SetPurge(90)
		Set $Namespace = "USER"
		Set changed = $ClassMethod(..#C, "Response")
		Do $$$AssertEquals(changed.retention.hourly.days, 90, "hourly after an administrator sets 90")
	} Catch e {
		Do $$$AssertStatusOK(e.AsStatus(), "changing retention for the test")
	}
	Set $Namespace = "%SYS"
	Do ##class(SYS.History.Hourly).SetPurge(hourly)
}

Method TestReadingChangesNothing()
{
	Do ..Snapshot(.before)
	Do $ClassMethod(..#C, "Response")
	Do $ClassMethod(..#C, "Response")
	Do ..Snapshot(.after)
	Set key = ""
	For {
		Set key = $Order(before(key))
		Quit:key=""
		Do $$$AssertEquals($Get(after(key)), before(key), "unchanged: "_key)
	}
}

Method TestRouteIsMapped()
{
	Set xdata = ##class(%Dictionary.CompiledXData).%OpenId(..#D_"||UrlMap")
	Quit:'$IsObject(xdata)
	Set text = $ZStrip(xdata.Data.Read(32000), "*WC")
	Do $$$AssertTrue(text [ "<RouteUrl=""/history-collection""Method=""GET""Call=""HistoryCollection""/>", "GET /history-collection calls HistoryCollection")
}

/// The collector and retention settings the module must never change (FR-006).
ClassMethod Snapshot(Output s)
{
	Kill s
	New $Namespace
	Set $Namespace = "%SYS"
	For c = "%Monitor.System.HistorySys", "%Monitor.System.HistoryPerf" {
		Set g = ##class(%Monitor.ItemGroup).%OpenId("%Monitor||"_c)
		Set s(c_" Activated") = $Select($IsObject(g): g.Activated, 1: "<none>")
		Set s(c_" SampInterval") = $Select($IsObject(g): g.SampInterval, 1: "<none>")
	}
	Set s("detail purge") = ##class(SYS.History.PerfData).SetPurge("")
	Set s("hourly purge") = ##class(SYS.History.Hourly).SetPurge("")
}

}
