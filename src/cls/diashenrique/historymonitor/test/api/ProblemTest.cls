/// Tests for api.Problem (task T004, spec FR-007). Written before the implementation (T007).
/// Contract: contracts/openapi.yaml, schema Problem.
Class diashenrique.historymonitor.test.api.ProblemTest Extends %UnitTest.TestCase
{

Method TestBodyHasRequiredFields()
{
	Set body = ##class(diashenrique.historymonitor.api.Problem).Body(400, "invalid-parameter", "from must be before to")
	Do $$$AssertEquals(body.%IsDefined("type"), 1, "type present")
	Do $$$AssertEquals(body.%IsDefined("title"), 1, "title present")
	Do $$$AssertEquals(body.%IsDefined("status"), 1, "status present")
	Do $$$AssertEquals(body.%IsDefined("detail"), 1, "detail present")
	Do $$$AssertEquals(body.detail, "from must be before to", "detail is the message given")
}

Method TestTypeIsStableRelativeUri()
{
	Set body = ##class(diashenrique.historymonitor.api.Problem).Body(404, "not-found", "no such metric")
	Do $$$AssertEquals(body.type, "/problems/not-found", "type is /problems/<slug>")
}

Method TestStatusIsAnInteger()
{
	Set body = ##class(diashenrique.historymonitor.api.Problem).Body(403, "forbidden", "role required")
	Do $$$AssertEquals(body.status, 403, "status value")
	Do $$$AssertEquals(body.%GetTypeOf("status"), "number", "status is a JSON number, not a string")
}

Method TestTitleComesFromStatus()
{
	Do $$$AssertEquals(##class(diashenrique.historymonitor.api.Problem).Body(400, "invalid-parameter", "x").title, "Bad Request", "400")
	Do $$$AssertEquals(##class(diashenrique.historymonitor.api.Problem).Body(401, "unauthorized", "x").title, "Unauthorized", "401")
	Do $$$AssertEquals(##class(diashenrique.historymonitor.api.Problem).Body(403, "forbidden", "x").title, "Forbidden", "403")
	Do $$$AssertEquals(##class(diashenrique.historymonitor.api.Problem).Body(404, "not-found", "x").title, "Not Found", "404")
	Do $$$AssertEquals(##class(diashenrique.historymonitor.api.Problem).Body(500, "internal-error", "x").title, "Internal Server Error", "500")
}

Method TestErrorsOmittedWhenNone()
{
	Set body = ##class(diashenrique.historymonitor.api.Problem).Body(400, "invalid-parameter", "bad input")
	Do $$$AssertEquals(body.%IsDefined("errors"), 0, "no errors key without validation failures")
}

Method TestErrorsListedWhenGiven()
{
	Set errs = [{"parameter":"from","message":"not an ISO 8601 date"},{"parameter":"limit","message":"must be 1..1000"}]
	Set body = ##class(diashenrique.historymonitor.api.Problem).Body(400, "invalid-parameter", "bad input", errs)
	Do $$$AssertEquals(body.errors.%Size(), 2, "two errors")
	Do $$$AssertEquals(body.errors.%Get(0).parameter, "from", "first parameter")
	Do $$$AssertEquals(body.errors.%Get(1).message, "must be 1..1000", "second message")
}

Method TestContentType()
{
	Do $$$AssertEquals(##class(diashenrique.historymonitor.api.Problem).ContentType(), "application/problem+json", "media type")
}

Method TestRenderSetsStatusAndContentType()
{
	New %response
	Set %response = ##class(%CSP.Response).%New()
	Set json = ##class(diashenrique.historymonitor.api.Problem).Render(404, "not-found", "no such metric")
	Do $$$AssertEquals(%response.ContentType, "application/problem+json", "response content type")
	Do $$$AssertEquals(%response.Status, "404 Not Found", "response status line")
	Set back = {}.%FromJSON(json)
	Do $$$AssertEquals(back.status, 404, "body status matches")
}

Method TestRenderEscapesHostileDetail()
{
	New %response
	Set %response = ##class(%CSP.Response).%New()
	Set hostile = "x"" ,""status"":200, <script>alert(1)</script>"_$Char(10)_"end"
	Set json = ##class(diashenrique.historymonitor.api.Problem).Render(400, "invalid-parameter", hostile)
	Set back = {}.%FromJSON(json)
	Do $$$AssertEquals(back.detail, hostile, "detail round-trips as data")
	Do $$$AssertEquals(back.status, 400, "injected status did not override the real one")
}

}
