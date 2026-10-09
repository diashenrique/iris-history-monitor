/// Tests for service.Validate (task T005, spec FR-006). Written before the implementation (T007).
/// Every validator returns "" when the value is valid, otherwise a short message.
/// Normalized values come back through an Output argument and stay empty on failure.
/// Limits come from specs/001-api-v1/data-model.md (limit 1..5000, database pattern).
Class diashenrique.historymonitor.test.api.ValidateTest Extends %UnitTest.TestCase
{

Parameter V = "diashenrique.historymonitor.service.Validate";

/// Values that must be rejected by every validator below: code, SQL and path tricks.
ClassMethod Hostile() As %List
{
	Quit $ListBuild("license' OR '1'='1", "license;DROP TABLE x", "$ZF(-1,""id"")", "1; Kill ^IRISMonitor", "../../etc/passwd", "a"_$Char(10)_"b", "<script>alert(1)</script>", "x"" ,""y"":1")
}

Method TestDateAcceptsDateAndDatetime()
{
	Set err = $ClassMethod(..#V, "Date", "2026-03-01", .out)
	Do $$$AssertEquals(err, "", "date only is valid")
	Do $$$AssertEquals(out, "2026-03-01 00:00:00", "date only means midnight UTC")
	Set err = $ClassMethod(..#V, "Date", "2026-03-01T10:15:30Z", .out)
	Do $$$AssertEquals(err, "", "UTC datetime is valid")
	Do $$$AssertEquals(out, "2026-03-01 10:15:30", "normalized to a space separated UTC timestamp")
	Set err = $ClassMethod(..#V, "Date", "2026-03-01T10:15", .out)
	Do $$$AssertEquals(err, "", "datetime without seconds is valid")
	Do $$$AssertEquals(out, "2026-03-01 10:15:00", "seconds default to zero")
}

Method TestDateRejectsBadValues()
{
	Set bad = $ListBuild("", "yesterday", "2026-13-01", "2026-02-30", "2026-03-01T25:00:00Z", "01/03/2026", "2026-3-1", "20260301", "2026-03-01T10:15:30Z; DROP TABLE x")
	For i = 1:1:$ListLength(bad) {
		Set out = "stale"
		Set err = $ClassMethod(..#V, "Date", $List(bad, i), .out)
		Do $$$AssertNotEquals(err, "", "rejected: "_$List(bad, i))
		Do $$$AssertEquals(out, "", "no normalized value on failure: "_$List(bad, i))
	}
}

Method TestRangeOrder()
{
	Set err = $ClassMethod(..#V, "Range", "2026-01-01 00:00:00", "2026-01-02 00:00:00")
	Do $$$AssertEquals(err, "", "from before to")
	Set err = $ClassMethod(..#V, "Range", "2026-01-01 00:00:00", "2026-01-01 00:00:00")
	Do $$$AssertEquals(err, "", "from equal to is allowed")
	Set err = $ClassMethod(..#V, "Range", "2026-01-02 00:00:00", "2026-01-01 00:00:00")
	Do $$$AssertNotEquals(err, "", "from after to is rejected")
}

Method TestRangeLongerThanRetentionWindowIsAllowed()
{
	// FR-013: windows up to 90 days must be accepted; coverage reporting handles missing data later.
	Set err = $ClassMethod(..#V, "Range", "2026-01-01 00:00:00", "2026-03-31 00:00:00")
	Do $$$AssertEquals(err, "", "89 day window accepted")
}

Method TestMetricEnum()
{
	For m = "license", "csp-sessions", "database-size" {
		Do $$$AssertEquals($ClassMethod(..#V, "Metric", m), "", "valid metric "_m)
	}
	Do $$$AssertNotEquals($ClassMethod(..#V, "Metric", "License"), "", "case sensitive")
	Do $$$AssertNotEquals($ClassMethod(..#V, "Metric", ""), "", "empty rejected")
	Do $$$AssertNotEquals($ClassMethod(..#V, "Metric", "processes"), "", "unknown metric rejected")
}

Method TestGranularityEnum()
{
	For g = "5min", "hourly", "daily" {
		Do $$$AssertEquals($ClassMethod(..#V, "Granularity", g), "", "valid granularity "_g)
	}
	Do $$$AssertNotEquals($ClassMethod(..#V, "Granularity", "weekly"), "", "unknown granularity rejected")
	Do $$$AssertNotEquals($ClassMethod(..#V, "Granularity", "5 min"), "", "near miss rejected")
	Do $$$AssertNotEquals($ClassMethod(..#V, "Granularity", ""), "", "empty rejected")
}

Method TestLimitBounds()
{
	Set err = $ClassMethod(..#V, "Limit", "", .out)
	Do $$$AssertEquals(err, "", "absent limit is valid")
	Do $$$AssertEquals(out, 1000, "default is 1000")
	Set err = $ClassMethod(..#V, "Limit", "1", .out)
	Do $$$AssertEquals(out, 1, "lower bound")
	Set err = $ClassMethod(..#V, "Limit", "5000", .out)
	Do $$$AssertEquals(err, "", "upper bound valid")
	Do $$$AssertEquals(out, 5000, "upper bound value")
}

Method TestLimitRejectsOutOfRangeAndNonIntegers()
{
	Set bad = $ListBuild("0", "-1", "5001", "1.5", "1e3", "abc", "10abc", " 5", "5 ", "+5", "1; Kill ^x", "99999999999999999999")
	For i = 1:1:$ListLength(bad) {
		Set out = "stale"
		Set err = $ClassMethod(..#V, "Limit", $List(bad, i), .out)
		Do $$$AssertNotEquals(err, "", "rejected: '"_$List(bad, i)_"'")
		Do $$$AssertEquals(out, "", "no value on failure: '"_$List(bad, i)_"'")
	}
}

Method TestDatabaseNamePattern()
{
	For d = "USER", "ENSLIB", "my-db_1.x", "%SYS", "a" {
		Do $$$AssertEquals($ClassMethod(..#V, "Database", d), "", "valid database name "_d)
	}
	Do $$$AssertEquals($ClassMethod(..#V, "Database", $Translate($Justify("", 64), " ", "a")), "", "64 characters is the maximum")
	Do $$$AssertNotEquals($ClassMethod(..#V, "Database", $Translate($Justify("", 65), " ", "a")), "", "65 characters rejected")
	Do $$$AssertNotEquals($ClassMethod(..#V, "Database", ""), "", "empty rejected")
	Do $$$AssertNotEquals($ClassMethod(..#V, "Database", "a b"), "", "space rejected")
	Do $$$AssertNotEquals($ClassMethod(..#V, "Database", "a;b"), "", "semicolon rejected")
	Do $$$AssertNotEquals($ClassMethod(..#V, "Database", "x' OR 1=1--"), "", "SQL tail rejected")
}

Method TestHostileStringsRejectedEverywhere()
{
	Set hostile = ..Hostile()
	For i = 1:1:$ListLength(hostile) {
		Set h = $List(hostile, i)
		Do $$$AssertNotEquals($ClassMethod(..#V, "Metric", h), "", "metric rejects hostile #"_i)
		Do $$$AssertNotEquals($ClassMethod(..#V, "Granularity", h), "", "granularity rejects hostile #"_i)
		Do $$$AssertNotEquals($ClassMethod(..#V, "Database", h), "", "database rejects hostile #"_i)
		Set err = $ClassMethod(..#V, "Date", h, .out)
		Do $$$AssertNotEquals(err, "", "date rejects hostile #"_i)
		Set err = $ClassMethod(..#V, "Limit", h, .out)
		Do $$$AssertNotEquals(err, "", "limit rejects hostile #"_i)
	}
}

/// The aggregate check used by the History route: collects every problem at once.
Method TestHistoryAcceptsAValidRequest()
{
	Set q("granularity") = "daily", q("from") = "2026-01-01", q("to") = "2026-03-01", q("limit") = "500"
	Set errs = $ClassMethod(..#V, "History", "license", .q, .clean)
	Do $$$AssertEquals(errs.%Size(), 0, "no errors")
	Do $$$AssertEquals(clean("from"), "2026-01-01 00:00:00", "from normalized")
	Do $$$AssertEquals(clean("to"), "2026-03-01 00:00:00", "to normalized")
	Do $$$AssertEquals(clean("limit"), 500, "limit normalized")
	Do $$$AssertEquals(clean("granularity"), "daily", "granularity kept")
}

Method TestHistoryReportsEveryErrorWithParameterName()
{
	Set q("granularity") = "weekly", q("from") = "nope", q("to") = "2026-03-01", q("limit") = "0"
	Set errs = $ClassMethod(..#V, "History", "license", .q, .clean)
	Set names = ""
	Set it = errs.%GetIterator()
	While it.%GetNext(.k, .e) {
		Set names = names_","_e.parameter
		Do $$$AssertNotEquals(e.message, "", "message present for "_e.parameter)
	}
	Do $$$AssertEquals(names, ",granularity,from,limit", "one error per bad parameter, in a stable order")
}

Method TestHistoryRejectsUnknownMetric()
{
	Set q("granularity") = "daily", q("from") = "2026-01-01", q("to") = "2026-03-01"
	Set errs = $ClassMethod(..#V, "History", "processes", .q, .clean)
	Do $$$AssertEquals(errs.%Size(), 1, "one error")
	Do $$$AssertEquals(errs.%Get(0).parameter, "metric", "names the metric parameter")
}

Method TestHistoryRejectsReversedRange()
{
	Set q("granularity") = "daily", q("from") = "2026-03-01", q("to") = "2026-01-01"
	Set errs = $ClassMethod(..#V, "History", "license", .q, .clean)
	Do $$$AssertEquals(errs.%Size(), 1, "one error")
	Do $$$AssertEquals(errs.%Get(0).parameter, "from", "reversed range is reported on from")
}

Method TestDatabaseOnlyValidForDatabaseSize()
{
	Set q("granularity") = "daily", q("from") = "2026-01-01", q("to") = "2026-03-01", q("database") = "USER"
	Set errs = $ClassMethod(..#V, "History", "license", .q, .clean)
	Do $$$AssertEquals(errs.%Size(), 1, "database not allowed for license")
	Do $$$AssertEquals(errs.%Get(0).parameter, "database", "names the database parameter")
	Set errs = $ClassMethod(..#V, "History", "database-size", .q, .clean)
	Do $$$AssertEquals(errs.%Size(), 0, "database allowed for database-size")
	Do $$$AssertEquals(clean("database"), "USER", "database passed through")
}

}
