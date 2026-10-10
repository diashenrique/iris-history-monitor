/// Contract tests for GET /overview (task T011, user story 1, spec FR-002, data-model OverviewSnapshot).
/// Written before service.Overview (T012) and the route (T013).
///
/// service.Overview.Build takes the raw dashboard values as an array keyed by SYS.Stats.Dashboard property
/// name, so the unavailable and never-backed-up cases are tested without changing the instance.
/// Snapshot reads the live dashboard and must match the contract on any instance, including a fresh one.
Class diashenrique.historymonitor.test.api.OverviewTest Extends %UnitTest.TestCase
{

Parameter O = "diashenrique.historymonitor.service.Overview";

Parameter H = "diashenrique.historymonitor.test.api.ContractHelper";

Parameter D = "diashenrique.historymonitor.api.Dispatch";

/// The metric names of data-model.md, in the order the snapshot returns them.
ClassMethod Expected() As %List
{
	Quit $ListBuild("systemUpTime", "lastBackup", "lockTable", "journalSpace", "journalStatus", "ecpAppServer", "ecpDataServer", "writeDaemon", "licenseCurrent", "licenseCurrentPct", "licenseHigh", "licenseHighPct", "licenseLimit", "applicationErrors", "cspSessions", "cacheEfficiency", "processes", "seriousAlerts")
}

/// A healthy sample with the values a running instance reports.
ClassMethod Healthy(Output v)
{
	Kill v
	Set v("SystemUpTime") = "2d  4h 10m", v("LastBackup") = "2026-10-08 23:00:00"
	Set v("LockTable") = "Normal", v("JournalSpace") = "Normal", v("JournalStatus") = "Normal"
	Set v("ECPAppServer") = "OK", v("ECPDataServer") = "OK", v("WriteDaemon") = "Normal"
	Set v("LicenseCurrent") = 3, v("LicenseCurrentPct") = 37, v("LicenseHigh") = 4, v("LicenseHighPct") = 50, v("LicenseLimit") = 8
	Set v("ApplicationErrors") = 0, v("CSPSessions") = 2, v("CacheEfficiency") = 52.06, v("Processes") = 40, v("SeriousAlerts") = 0
}

/// The metric object with the given name, or "" when it is missing.
ClassMethod Find(snapshot As %DynamicObject, name As %String) As %DynamicObject
{
	Set it = snapshot.metrics.%GetIterator()
	While it.%GetNext(.k, .m) { If m.name = name Return m }
	Quit ""
}

ClassMethod Text(errs As %DynamicArray) As %String
{
	Quit ##class(diashenrique.historymonitor.test.api.ContractHelperTest).Text(errs)
}

Method TestLiveSnapshotMatchesContract()
{
	Set s = $ClassMethod(..#O, "Snapshot")
	Set errs = $ClassMethod(..#H, "Check", "OverviewSnapshot", s)
	Do $$$AssertEquals(errs.%Size(), 0, "live snapshot matches OverviewSnapshot: "_..Text(errs))
}

Method TestLiveSnapshotHasEveryMetricOnceInOrder()
{
	Set s = $ClassMethod(..#O, "Snapshot")
	Set names = ""
	Set it = s.metrics.%GetIterator()
	While it.%GetNext(.k, .m) { Set names = names_$ListBuild(m.name) }
	Do $$$AssertEquals($ListToString(names), $ListToString(..Expected()), "every data-model metric, once, in order")
}

Method TestLiveMetricsHaveUnitAndStatus()
{
	Set s = $ClassMethod(..#O, "Snapshot")
	Set it = s.metrics.%GetIterator()
	While it.%GetNext(.k, .m) {
		Do $$$AssertNotEquals(m.unit, "", m.name_" has a unit")
		Do $$$AssertTrue($ListFind($ListBuild("ok", "warning", "critical", "unavailable"), m.status), m.name_" has a known status")
	}
}

Method TestGeneratedAtIsUtc()
{
	Set s = $ClassMethod(..#O, "Snapshot")
	Do $$$AssertTrue($Match(s.generatedAt, "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"), "generatedAt is a UTC date-time: "_s.generatedAt)
}

/// $ZDateTime time format 7 converts local time to UTC, so applying it to a UTC value shifts it by the
/// server offset. This only shows on a server outside UTC (the CI runs in America/Sao_Paulo).
Method TestGeneratedAtIsTheCurrentUtcTime()
{
	Set s = $ClassMethod(..#O, "Snapshot")
	Set h = $ZDateTimeH($Translate($Extract(s.generatedAt, 1, 19), "T", " "), 3)
	Set now = $ZTimeStamp
	Set diff = ((+now - h) * 86400) + ($Piece(now, ",", 2) - $Piece(h, ",", 2))
	Do $$$AssertTrue($ZAbs(diff) < 120, "generatedAt "_s.generatedAt_" is within two minutes of UTC now (difference "_(diff \ 1)_" s)")
}

Method TestHealthySampleIsAllOk()
{
	Do ..Healthy(.v)
	Set s = $ClassMethod(..#O, "Build", .v)
	Set errs = $ClassMethod(..#H, "Check", "OverviewSnapshot", s)
	Do $$$AssertEquals(errs.%Size(), 0, "matches the contract: "_..Text(errs))
	Set it = s.metrics.%GetIterator()
	While it.%GetNext(.k, .m) { Do $$$AssertEquals(m.status, "ok", m.name_" is ok") }
}

Method TestNumbersAreJsonNumbers()
{
	Do ..Healthy(.v)
	Set v("LicenseCurrent") = "3"
	Set s = $ClassMethod(..#O, "Build", .v)
	Set m = ..Find(s, "licenseCurrent")
	Do $$$AssertEquals(m.%GetTypeOf("value"), "number", "a count leaves as a number even when the source gives text")
	Do $$$AssertEquals(m.value, 3, "value")
	Do $$$AssertEquals(m.unit, "count", "unit")
	Do $$$AssertEquals(..Find(s, "licenseCurrentPct").unit, "percent", "percent unit")
	Do $$$AssertEquals(..Find(s, "lockTable").%GetTypeOf("value"), "string", "a state stays text")
}

Method TestMissingSourceIsUnavailableNotOmitted()
{
	Do ..Healthy(.v)
	Kill v("LockTable")
	Set v("CSPSessions") = ""
	Set s = $ClassMethod(..#O, "Build", .v)
	Do $$$AssertEquals(s.metrics.%Size(), $ListLength(..Expected()), "no metric is omitted")
	For name = "lockTable", "cspSessions" {
		Set m = ..Find(s, name)
		Do $$$AssertEquals(m.status, "unavailable", name_" is unavailable")
		Do $$$AssertEquals(m.%GetTypeOf("value"), "null", name_" value is null")
		Do $$$AssertNotEquals(m.reason, "", name_" has a reason")
	}
	Do $$$AssertEquals(..Find(s, "journalSpace").status, "ok", "the other metrics are still returned")
	Set errs = $ClassMethod(..#H, "Check", "OverviewSnapshot", s)
	Do $$$AssertEquals(errs.%Size(), 0, "still matches the contract: "_..Text(errs))
}

Method TestSampleFailureMarksEveryMetricUnavailable()
{
	Kill v
	Set s = $ClassMethod(..#O, "Build", .v, "the dashboard sample could not be read")
	Do $$$AssertEquals(s.metrics.%Size(), $ListLength(..Expected()), "every metric is still listed")
	Set it = s.metrics.%GetIterator()
	While it.%GetNext(.k, .m) {
		Do $$$AssertEquals(m.status, "unavailable", m.name_" is unavailable")
		Do $$$AssertEquals(m.reason, "the dashboard sample could not be read", m.name_" carries the reason")
	}
	Set errs = $ClassMethod(..#H, "Check", "OverviewSnapshot", s)
	Do $$$AssertEquals(errs.%Size(), 0, "matches the contract: "_..Text(errs))
}

Method TestNeverBackedUpIsWarning()
{
	Do ..Healthy(.v)
	Set v("LastBackup") = ""
	Set m = ..Find($ClassMethod(..#O, "Build", .v), "lastBackup")
	Do $$$AssertEquals(m.status, "warning", "a backup that never ran is a warning")
	Do $$$AssertEquals(m.%GetTypeOf("value"), "null", "no backup date")
	Do $$$AssertEquals(m.%IsDefined("reason"), 0, "reason is only for unavailable metrics")
}

Method TestBackupThatRanIsOk()
{
	Do ..Healthy(.v)
	Set m = ..Find($ClassMethod(..#O, "Build", .v), "lastBackup")
	Do $$$AssertEquals(m.status, "ok", "status")
	Do $$$AssertEquals(m.value, "2026-10-08 23:00:00", "the date as the instance reports it")
}

Method TestStateValues()
{
	Do ..Healthy(.v)
	Set cases = $ListBuild($ListBuild("Normal", "ok"), $ListBuild("OK", "ok"), $ListBuild("Warning", "warning"), $ListBuild("Troubled", "critical"), $ListBuild("Something new", "warning"))
	For i = 1:1:$ListLength(cases) {
		Set raw = $List($List(cases, i), 1), want = $List($List(cases, i), 2)
		Set v("WriteDaemon") = raw, v("ECPAppServer") = raw
		Set s = $ClassMethod(..#O, "Build", .v)
		Do $$$AssertEquals(..Find(s, "writeDaemon").status, want, "writeDaemon "_raw)
		Do $$$AssertEquals(..Find(s, "ecpAppServer").status, want, "ecpAppServer "_raw)
		Do $$$AssertEquals(..Find(s, "writeDaemon").value, raw, "the state text is returned as reported")
	}
}

Method TestLicensePercentThresholds()
{
	Do ..Healthy(.v)
	For pair = "79:ok", "80:warning", "94:warning", "95:critical", "100:critical" {
		Set v("LicenseCurrentPct") = $Piece(pair, ":", 1), v("LicenseHighPct") = $Piece(pair, ":", 1)
		Set s = $ClassMethod(..#O, "Build", .v)
		Do $$$AssertEquals(..Find(s, "licenseCurrentPct").status, $Piece(pair, ":", 2), "licenseCurrentPct "_pair)
		Do $$$AssertEquals(..Find(s, "licenseHighPct").status, $Piece(pair, ":", 2), "licenseHighPct "_pair)
	}
}

Method TestSeriousAlertsAreAWarning()
{
	Do ..Healthy(.v)
	Set v("SeriousAlerts") = 2
	Set m = ..Find($ClassMethod(..#O, "Build", .v), "seriousAlerts")
	Do $$$AssertEquals(m.status, "warning", "serious alerts since startup")
	Do $$$AssertEquals(m.value, 2, "value")
}

Method TestNonNumericCountIsUnavailable()
{
	Do ..Healthy(.v)
	Set v("Processes") = "n/a"
	Set m = ..Find($ClassMethod(..#O, "Build", .v), "processes")
	Do $$$AssertEquals(m.status, "unavailable", "a count that is not a number is not passed through")
	Do $$$AssertEquals(m.%GetTypeOf("value"), "null", "value")
}

Method TestRouteIsMapped()
{
	Set xdata = ##class(%Dictionary.CompiledXData).%OpenId(..#D_"||UrlMap")
	Do $$$AssertTrue($IsObject(xdata), "UrlMap exists")
	Quit:'$IsObject(xdata)
	Set text = xdata.Data.Read(32000)
	Do $$$AssertTrue($ZStrip(text, "*WC") [ "<RouteUrl=""/overview""Method=""GET""Call=""Overview""/>", "GET /overview calls Overview")
}

}
