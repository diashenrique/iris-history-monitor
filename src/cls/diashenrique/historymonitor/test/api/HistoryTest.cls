/// Contract tests for GET /history/{metric} (task T014, user story 2, spec FR-003, FR-004, data-model
/// HistorySeries). Written before service.History (T016) and the route (T017).
///
/// The data comes from HistoryFixture: real SYS.History rows in February 2001, keyed in UTC.
/// service.History.Series takes the values normalized by service.Validate.History; Build is the pure
/// part (rows in, response out) and takes "now" so the partial rule can be tested at any date.
/// api.Dispatch.HistoryResponse is the route body without the HTTP write, so 400 cases are tested here.
Class diashenrique.historymonitor.test.api.HistoryTest Extends %UnitTest.TestCase
{

Parameter S = "diashenrique.historymonitor.service.History";

Parameter D = "diashenrique.historymonitor.api.Dispatch";

Parameter H = "diashenrique.historymonitor.test.api.ContractHelper";

Parameter F = "diashenrique.historymonitor.test.api.HistoryFixture";

Method OnBeforeAllTests() As %Status
{
	Quit $ClassMethod(..#F, "Create")
}

Method OnAfterAllTests() As %Status
{
	Quit $ClassMethod(..#F, "Remove")
}

/// Runs a request through validation and the service, the way the route does.
ClassMethod Get(metric As %String, granularity As %String, from As %String, to As %String, limit As %String = "", database As %String = "", cursor As %String = "") As %DynamicObject
{
	Set q("granularity") = granularity, q("from") = from, q("to") = to
	Set:limit'="" q("limit") = limit
	Set:database'="" q("database") = database
	Set:cursor'="" q("cursor") = cursor
	Quit $ClassMethod(..#D, "HistoryResponse", metric, .q, .code)
}

ClassMethod Text(errs As %DynamicArray) As %String
{
	Quit ##class(diashenrique.historymonitor.test.api.ContractHelperTest).Text(errs)
}

/// The series with the given name, or "".
ClassMethod Series(body As %DynamicObject, name As %String) As %DynamicObject
{
	Set it = body.series.%GetIterator()
	While it.%GetNext(.k, .s) { If s.name = name Return s }
	Quit ""
}

/// Series names joined by commas, in response order.
ClassMethod Names(body As %DynamicObject) As %String
{
	Set out = ""
	Set it = body.series.%GetIterator()
	While it.%GetNext(.k, .s) { Set out = out_$Select(out = "": "", 1: ",")_s.name }
	Quit out
}

/// The t of every point of a series joined by commas.
ClassMethod Times(series As %DynamicObject) As %String
{
	Set out = ""
	Set it = series.points.%GetIterator()
	While it.%GetNext(.k, .p) { Set out = out_$Select(out = "": "", 1: ",")_p.t }
	Quit out
}

Method TestEveryMetricAndGranularityMatchesContract()
{
	For metric = "license", "csp-sessions", "database-size" {
		For grain = "5min", "hourly", "daily" {
			Set body = ..Get(metric, grain, "2001-02-01", "2001-02-06")
			Set errs = $ClassMethod(..#H, "Check", "HistorySeries", body)
			Do $$$AssertEquals(errs.%Size(), 0, metric_" "_grain_" matches HistorySeries: "_..Text(errs))
			Do $$$AssertTrue(body.series.%Size() > 0, metric_" "_grain_" has series")
			Do $$$AssertEquals(body.metric, metric, "metric echoed")
			Do $$$AssertEquals(body.granularity, grain, "granularity echoed")
		}
	}
}

Method TestFiveMinuteLicenseValuesInUtc()
{
	Set body = ..Get("license", "5min", "2001-02-03T10:00:00Z", "2001-02-03T10:10:00Z")
	Do $$$AssertEquals(..Names(body), "value", "one series for 5-minute samples")
	Set s = ..Series(body, "value")
	Do $$$AssertEquals(..Times(s), "2001-02-03T10:00:00Z,2001-02-03T10:05:00Z,2001-02-03T10:10:00Z", "UTC keys, from and to inclusive")
	Do $$$AssertEquals(s.points.%Get(1).v, 1, "value of the second sample")
	Do $$$AssertEquals(s.points.%Get(1).%GetTypeOf("v"), "number", "v is a number")
	Do $$$AssertEquals(body.from, "2001-02-03T10:00:00Z", "from echoed as UTC date-time")
	Do $$$AssertEquals(body.to, "2001-02-03T10:10:00Z", "to echoed as UTC date-time")
}

Method TestPointsAreAscending()
{
	For grain = "5min", "hourly", "daily" {
		Set body = ..Get("license", grain, "2001-02-01", "2001-02-06")
		Set it = body.series.%GetIterator()
		While it.%GetNext(.k, .s) {
			Set prev = "", ok = 1
			Set pit = s.points.%GetIterator()
			While pit.%GetNext(.pk, .p) {
				If (prev '= "") && (p.t ']] prev) Set ok = 0
				Set prev = p.t
			}
			Do $$$AssertTrue(ok, grain_" "_s.name_" points are oldest first")
		}
	}
}

Method TestHourlyHasAvgAndMaxButNotStDev()
{
	Set body = ..Get("license", "hourly", "2001-02-03", "2001-02-04")
	Do $$$AssertEquals(..Names(body), "Avg,Max", "the statistics the pages show")
	Set avg = ..Series(body, "Avg")
	Do $$$AssertEquals(avg.points.%Size(), 6, "six hourly rows")
	Do $$$AssertEquals(avg.points.%Get(0).t, "2001-02-03T08:00:00Z", "first hour")
	Do $$$AssertEquals(avg.points.%Get(0).v, 8, "Avg value")
	Do $$$AssertEquals(..Series(body, "Max").points.%Get(0).v, 8.5, "Max value")
}

Method TestCspSessionsSkipsEmptyValues()
{
	Set body = ..Get("csp-sessions", "5min", "2001-02-03T10:00:00Z", "2001-02-03T10:55:00Z")
	Set s = ..Series(body, "value")
	Do $$$AssertEquals(s.points.%Size(), 11, "the sample with no CSP session value is left out, not sent as 0")
	Do $$$AssertEquals(..Times(s) [ "10:30:00Z", 0, "the empty 10:30 sample is not a point")
	Do $$$AssertEquals(s.points.%Get(1).v, 2, "CSP sessions value")
}

Method TestDatabaseSizeHasOneSeriesPerDatabase()
{
	Set body = ..Get("database-size", "daily", "2001-02-01", "2001-02-06")
	Do $$$AssertTrue(..Names(body) [ "HMOTHERDB", "other database present: "_..Names(body))
	Do $$$AssertTrue(..Names(body) [ "HMTESTDB", "test database present")
	Set s = ..Series(body, "HMTESTDB")
	Do $$$AssertEquals(s.points.%Size(), 5, "five days")
	Do $$$AssertEquals(s.points.%Get(0).v, 301, "the Max file size of the day")
	Set hourly = ..Get("database-size", "hourly", "2001-02-03", "2001-02-04")
	Do $$$AssertEquals(..Series(hourly, "HMTESTDB").points.%Get(0).v, 218, "hourly uses the Max statistic, not Avg or StDev")
	Set five = ..Get("database-size", "5min", "2001-02-03T10:00:00Z", "2001-02-03T10:05:00Z")
	Do $$$AssertEquals(..Series(five, "HMTESTDB").points.%Get(1).v, 101, "5-minute database size")
}

Method TestDatabaseFilter()
{
	For grain = "5min", "hourly", "daily" {
		Set body = ..Get("database-size", grain, "2001-02-01", "2001-02-06", , "HMTESTDB")
		Do $$$AssertEquals(..Names(body), "HMTESTDB", grain_": only the requested database")
	}
	Set body = ..Get("database-size", "daily", "2001-02-01", "2001-02-06", , "NOSUCHDB")
	Do $$$AssertEquals(body.series.%Size(), 0, "an unknown database gives no series, not an error")
}

Method TestEmptyRangeHasNoCoverage()
{
	Set body = ..Get("license", "hourly", "2001-01-10", "2001-01-11")
	Set errs = $ClassMethod(..#H, "Check", "HistorySeries", body)
	Do $$$AssertEquals(errs.%Size(), 0, "still matches the contract: "_..Text(errs))
	Do $$$AssertEquals(body.series.%Size(), 0, "no series")
	Do $$$AssertEquals(body.%GetTypeOf("coverage"), "null", "coverage is null")
	Do $$$AssertEquals(body.partial, 1, "an empty range is partial")
	Do $$$AssertEquals(body.truncated, 0, "not truncated")
	Do $$$AssertEquals(body.%IsDefined("next"), 0, "no cursor")
}

Method TestCoverageAndPartial()
{
	Set body = ..Get("license", "hourly", "2001-02-03T08:00:00Z", "2001-02-03T13:00:00Z")
	Do $$$AssertEquals(body.coverage.first, "2001-02-03T08:00:00Z", "first timestamp present")
	Do $$$AssertEquals(body.coverage.last, "2001-02-03T13:00:00Z", "last timestamp present")
	Do $$$AssertEquals(body.partial, 0, "data spans the whole range")
	Set wide = ..Get("license", "hourly", "2001-02-02", "2001-02-04")
	Do $$$AssertEquals(wide.coverage.first, "2001-02-03T08:00:00Z", "coverage is what exists, not what was asked")
	Do $$$AssertEquals(wide.partial, 1, "a range wider than the data is partial")
}

Method TestTruncationAndCursorWalkTheWholeRange()
{
	Set all = "", pages = 0, cursor = ""
	For {
		Set body = ..Get("license", "5min", "2001-02-03T10:00:00Z", "2001-02-03T10:55:00Z", 5, , cursor)
		Set errs = $ClassMethod(..#H, "Check", "HistorySeries", body)
		Do $$$AssertEquals(errs.%Size(), 0, "page matches the contract: "_..Text(errs))
		Set pages = pages + 1
		Set times = ..Times(..Series(body, "value"))
		Set all = all_$Select(all = "": "", 1: ",")_times
		If pages < 3 {
			Do $$$AssertEquals($Length(times, ","), 5, "page "_pages_" holds limit timestamps")
			Do $$$AssertEquals(body.truncated, 1, "page "_pages_" is truncated")
			Do $$$AssertEquals(body.next, $Piece(times, ",", 5), "next is the last timestamp of the page")
		}
		Quit:'body.truncated
		Quit:pages>5
		Set cursor = body.next
	}
	Do $$$AssertEquals(pages, 3, "12 samples at limit 5 take three pages")
	Do $$$AssertEquals(body.%IsDefined("next"), 0, "the last page has no cursor")
	Do $$$AssertEquals($Length(all, ","), 12, "every sample once, none repeated or lost")
	Do $$$AssertEquals($Piece(all, ",", 12), "2001-02-03T10:55:00Z", "ends with the last sample")
}

Method TestTruncationCountsTimestampsNotPoints()
{
	Set body = ..Get("license", "hourly", "2001-02-03", "2001-02-04", 2)
	Do $$$AssertEquals(..Series(body, "Avg").points.%Size(), 2, "Avg has two hours")
	Do $$$AssertEquals(..Series(body, "Max").points.%Size(), 2, "Max has the same two hours")
	Do $$$AssertEquals(body.next, "2001-02-03T09:00:00Z", "cursor after the second hour")
}

Method TestFutureEndIsNotPartialWhenDataIsCurrent()
{
	// Build is the pure part: rows(n) = $ListBuild(UTC key in seconds, series name, value).
	Set now = $ZDateTimeH("2026-10-09 12:00:00", 3), nowKey = (+now * 86400) + $Piece(now, ",", 2)
	Set clean("metric") = "license", clean("granularity") = "hourly", clean("limit") = 1000
	Set clean("from") = "2026-10-09 10:00:00", clean("to") = "2026-10-10 00:00:00"
	Set rows(1) = $ListBuild(nowKey - 7200, "Avg", 1), rows(2) = $ListBuild(nowKey - 3600, "Avg", 2)
	Set body = $ClassMethod(..#S, "Build", .clean, .rows, nowKey - 7200, nowKey - 3600, nowKey)
	Do $$$AssertEquals(body.partial, 0, "the part of the range still in the future does not make it partial")
	Set clean("from") = "2026-10-08 00:00:00"
	Set body = $ClassMethod(..#S, "Build", .clean, .rows, nowKey - 7200, nowKey - 3600, nowKey)
	Do $$$AssertEquals(body.partial, 1, "missing past hours make it partial")
}

Method TestBadRequestsAreProblems()
{
	Set cases = ""
	Set cases = cases_$ListBuild($ListBuild("license", "daily", "2001-02-06", "2001-02-01", "", "from"))
	Set cases = cases_$ListBuild($ListBuild("license", "daily", "yesterday", "2001-02-01", "", "from"))
	Set cases = cases_$ListBuild($ListBuild("cpu", "daily", "2001-02-01", "2001-02-06", "", "metric"))
	Set cases = cases_$ListBuild($ListBuild("license", "weekly", "2001-02-01", "2001-02-06", "", "granularity"))
	Set cases = cases_$ListBuild($ListBuild("license", "daily", "2001-02-01", "2001-02-06", "HMTESTDB", "database"))
	For i = 1:1:$ListLength(cases) {
		Set c = $List(cases, i)
		Kill q
		Set q("granularity") = $List(c, 2), q("from") = $List(c, 3), q("to") = $List(c, 4)
		Set:$List(c, 5)'="" q("database") = $List(c, 5)
		Set body = $ClassMethod(..#D, "HistoryResponse", $List(c, 1), .q, .code)
		Do $$$AssertEquals(code, 400, "case "_i_" is a 400")
		Set errs = $ClassMethod(..#H, "Check", "Problem", body)
		Do $$$AssertEquals(errs.%Size(), 0, "case "_i_" is a Problem: "_..Text(errs))
		Do $$$AssertEquals(body.type, "/problems/invalid-parameter", "case "_i_" type")
		Do $$$AssertEquals(body.errors.%Get(0).parameter, $List(c, 6), "case "_i_" names the parameter")
	}
}

Method TestUnknownMetricIsNotEchoedUnescaped()
{
	Set q("granularity") = "daily", q("from") = "2001-02-01", q("to") = "2001-02-06"
	Set body = $ClassMethod(..#D, "HistoryResponse", "<script>alert(1)</script>", .q, .code)
	Do $$$AssertEquals(code, 400, "rejected")
	Do $$$AssertEquals(body.%ToJSON() [ "<script>", 0, "the bad value is not copied into the response")
}

Method TestValidRequestIs200()
{
	Set q("granularity") = "daily", q("from") = "2001-02-01", q("to") = "2001-02-06"
	Set body = $ClassMethod(..#D, "HistoryResponse", "license", .q, .code)
	Do $$$AssertEquals(code, 200, "status")
}

Method TestRouteIsMapped()
{
	Set xdata = ##class(%Dictionary.CompiledXData).%OpenId(..#D_"||UrlMap")
	Quit:'$IsObject(xdata)
	Set text = $ZStrip(xdata.Data.Read(32000), "*WC")
	Do $$$AssertTrue(text [ "<RouteUrl=""/history/:metric""Method=""GET""Call=""History""/>", "GET /history/:metric calls History")
}

}
