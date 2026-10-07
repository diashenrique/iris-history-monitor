/// Tests for test.api.ContractHelper (task T010, spec FR-010, constitution III).
/// The helper compares a response object with a schema of contracts/openapi.json (generated from the YAML).
/// It must be strict: a missing required field, a wrong type, an enum miss and an UNLISTED property all fail,
/// because an extra field is exactly the shape drift the contract tests exist to catch.
Class diashenrique.historymonitor.test.api.ContractHelperTest Extends %UnitTest.TestCase
{

Parameter H = "diashenrique.historymonitor.test.api.ContractHelper";

/// Joins the messages of an error list so a test can look for a field name in them.
ClassMethod Text(errs As %DynamicArray) As %String
{
	Set text = ""
	Set it = errs.%GetIterator()
	While it.%GetNext(.k, .v) { Set text = text_v_"|" }
	Quit text
}

Method TestContractFileLoads()
{
	Set c = $ClassMethod(..#H, "Contract")
	Do $$$AssertEquals($IsObject(c), 1, "contract is an object")
	Do $$$AssertEquals(c.paths.%IsDefined("/overview"), 1, "has /overview")
	Do $$$AssertEquals(c.components.schemas.%IsDefined("Problem"), 1, "has the Problem schema")
}

Method TestValidProblemPasses()
{
	Set v = {}.%FromJSON("{""type"":""/problems/x"",""title"":""Bad Request"",""status"":400,""detail"":""d""}")
	Set errs = $ClassMethod(..#H, "Check", "Problem", v)
	Do $$$AssertEquals(errs.%Size(), 0, "no mismatches: "_..Text(errs))
}

Method TestNestedErrorsListPasses()
{
	Set v = {}.%FromJSON("{""type"":""/problems/x"",""title"":""t"",""status"":400,""detail"":""d"",""errors"":[{""parameter"":""from"",""message"":""m""}]}")
	Set errs = $ClassMethod(..#H, "Check", "Problem", v)
	Do $$$AssertEquals(errs.%Size(), 0, "nested array of objects: "_..Text(errs))
}

Method TestMissingRequiredIsReported()
{
	Set v = {}.%FromJSON("{""type"":""/problems/x"",""title"":""t"",""status"":400}")
	Set errs = $ClassMethod(..#H, "Check", "Problem", v)
	Do $$$AssertEquals(errs.%Size(), 1, "one mismatch")
	Do $$$AssertEquals(..Text(errs) [ "detail", 1, "names the missing field")
}

Method TestWrongTypeIsReported()
{
	Set v = {}.%FromJSON("{""type"":""/problems/x"",""title"":""t"",""status"":""400"",""detail"":""d""}")
	Set errs = $ClassMethod(..#H, "Check", "Problem", v)
	Do $$$AssertEquals(errs.%Size(), 1, "one mismatch")
	Do $$$AssertEquals(..Text(errs) [ "status", 1, "names the field")
}

Method TestIntegerRejectsFraction()
{
	Set v = {}.%FromJSON("{""type"":""/problems/x"",""title"":""t"",""status"":400.5,""detail"":""d""}")
	Set errs = $ClassMethod(..#H, "Check", "Problem", v)
	Do $$$AssertEquals(errs.%Size(), 1, "a fraction is not an integer")
}

Method TestUnlistedPropertyIsDrift()
{
	Set v = {}.%FromJSON("{""type"":""/problems/x"",""title"":""t"",""status"":400,""detail"":""d"",""trace"":""secret""}")
	Set errs = $ClassMethod(..#H, "Check", "Problem", v)
	Do $$$AssertEquals(errs.%Size(), 1, "one mismatch")
	Do $$$AssertEquals(..Text(errs) [ "trace", 1, "names the unexpected field")
}

Method TestEnumViolation()
{
	Set v = {}.%FromJSON("{""name"":""cspSessions"",""value"":3,""unit"":""count"",""status"":""fine""}")
	Set errs = $ClassMethod(..#H, "Check", "Metric", v)
	Do $$$AssertEquals(errs.%Size(), 1, "status outside the enum")
	Do $$$AssertEquals(..Text(errs) [ "status", 1, "names the field")
}

Method TestNullableOneOfValue()
{
	Set h = ..#H
	Set base = "{""name"":""n"",""unit"":""u"",""status"":""ok"",""value"":"
	For json = "null", "12.5", """text""" {
		Set errs = $ClassMethod(h, "Check", "Metric", {}.%FromJSON(base_json_"}"))
		Do $$$AssertEquals(errs.%Size(), 0, "value "_json_" is allowed: "_..Text(errs))
	}
	Set errs = $ClassMethod(h, "Check", "Metric", {}.%FromJSON(base_"true}"))
	Do $$$AssertEquals(errs.%Size(), 1, "a boolean value matches no oneOf branch")
}

Method TestArrayItemsResolveRefsAndShowIndex()
{
	Set json = "{""generatedAt"":""2026-03-01T10:00:00Z"",""metrics"":[{""name"":""a"",""value"":1,""unit"":""u"",""status"":""ok""},{""name"":""b"",""unit"":""u"",""status"":""ok""}]}"
	Set errs = $ClassMethod(..#H, "Check", "OverviewSnapshot", {}.%FromJSON(json))
	Do $$$AssertEquals(errs.%Size(), 1, "second metric lacks value")
	Do $$$AssertEquals(..Text(errs) [ "metrics[1]", 1, "the path shows which element")
}

Method TestDateTimeFormat()
{
	Set h = ..#H
	Set errs = $ClassMethod(h, "Check", "Point", {}.%FromJSON("{""t"":""2026-03-01T10:00:00Z"",""v"":1}"))
	Do $$$AssertEquals(errs.%Size(), 0, "a UTC date-time is valid")
	Set errs = $ClassMethod(h, "Check", "Point", {}.%FromJSON("{""t"":""yesterday"",""v"":1}"))
	Do $$$AssertEquals(errs.%Size(), 1, "free text is not a date-time")
}

Method TestAdditionalPropertiesTrueAllowsAnyField()
{
	Set errs = $ClassMethod(..#H, "Check", "Process", {}.%FromJSON("{""Pid"":12,""Namespace"":""USER"",""anything"":true}"))
	Do $$$AssertEquals(errs.%Size(), 0, "Process allows additional properties: "_..Text(errs))
}

Method TestNullableObject()
{
	Set json = "{""metric"":""license"",""granularity"":""daily"",""from"":""2026-01-01T00:00:00Z"",""to"":""2026-02-01T00:00:00Z"",""coverage"":null,""partial"":true,""truncated"":false,""series"":[]}"
	Set errs = $ClassMethod(..#H, "Check", "HistorySeries", {}.%FromJSON(json))
	Do $$$AssertEquals(errs.%Size(), 0, "coverage may be null: "_..Text(errs))
}

Method TestUnknownSchemaIsAnError()
{
	Set errs = $ClassMethod(..#H, "Check", "NoSuchSchema", {})
	Do $$$AssertEquals(errs.%Size(), 1, "a typo in a test must not pass silently")
}

/// First real contract checks: what the implemented classes produce must match the YAML.
Method TestProblemBodyFromTheImplementationMatchesTheContract()
{
	Set e = [{"parameter":"from","message":"bad"}]
	Set body = ##class(diashenrique.historymonitor.api.Problem).Body(400, "invalid-parameter", "bad input", e)
	Set errs = $ClassMethod(..#H, "Check", "Problem", body)
	Do $$$AssertEquals(errs.%Size(), 0, "Problem.Body with errors: "_..Text(errs))
}

Method TestDispatchErrorBodiesMatchTheContract()
{
	For code = 400, 401, 403, 404, 405, 500 {
		Set body = ##class(diashenrique.historymonitor.api.Dispatch).ErrorBody(code)
		Set errs = $ClassMethod(..#H, "Check", "Problem", body)
		Do $$$AssertEquals(errs.%Size(), 0, "Dispatch.ErrorBody("_code_"): "_..Text(errs))
	}
}

}
