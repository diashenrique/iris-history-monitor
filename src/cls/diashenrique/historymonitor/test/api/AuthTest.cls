/// Tests for the access decision and error mapping of api.Dispatch (tasks T008 and T009, spec FR-008, FR-007).
/// The decision is a pure method so it can be tested without a web server:
///   no authenticated user -> 401, authenticated without Use on the resource -> 403, with it -> 200.
/// The web application setting (password auth, no unauthenticated access, resource) is checked
/// by hand on a real instance; see the pull request.
Class diashenrique.historymonitor.test.api.AuthTest Extends %UnitTest.TestCase
{

Parameter D = "diashenrique.historymonitor.api.Dispatch";

Method TestNoUserIs401()
{
	Do $$$AssertEquals($ClassMethod(..#D, "Authorize", "", 0), 401, "empty user name")
	Do $$$AssertEquals($ClassMethod(..#D, "Authorize", "UnknownUser", 0), 401, "UnknownUser is the unauthenticated user")
}

Method TestNoUserIs401EvenIfResourceCheckSaysYes()
{
	Do $$$AssertEquals($ClassMethod(..#D, "Authorize", "UnknownUser", 1), 401, "an unauthenticated user never passes")
	Do $$$AssertEquals($ClassMethod(..#D, "Authorize", "", 1), 401, "empty user never passes")
}

Method TestUserWithoutRoleIs403()
{
	Do $$$AssertEquals($ClassMethod(..#D, "Authorize", "alice", 0), 403, "authenticated but no Use on the resource")
}

Method TestUserWithRoleIs200()
{
	Do $$$AssertEquals($ClassMethod(..#D, "Authorize", "alice", 1), 200, "authenticated and holds Use")
}

Method TestDispatchUsesTheResourceCreatedBySecurity()
{
	Do $$$AssertEquals($ClassMethod(..#D, "Resource"), ##class(diashenrique.historymonitor.util.Security).#RESOURCE, "one resource name for both classes")
}

Method TestErrorBodyForUnknownRoute()
{
	Set body = $ClassMethod(..#D, "ErrorBody", 404, $$$OK)
	Do $$$AssertEquals(body.status, 404, "status")
	Do $$$AssertEquals(body.type, "/problems/not-found", "type")
	Do $$$AssertNotEquals(body.detail, "", "detail present")
}

Method TestErrorBodyForMethodNotAllowed()
{
	Set body = $ClassMethod(..#D, "ErrorBody", 405, $$$OK)
	Do $$$AssertEquals(body.type, "/problems/method-not-allowed", "type")
	Do $$$AssertEquals(body.title, "Method Not Allowed", "title")
}

Method TestErrorBodyForServerErrorDoesNotLeakInternals()
{
	Set sc = $$$ERROR($$$GeneralError, "secret path /usr/irissys/mgr/user and ^IRISMonitor(""x"")")
	Set body = $ClassMethod(..#D, "ErrorBody", 500, sc)
	Do $$$AssertEquals(body.status, 500, "status")
	Do $$$AssertEquals(body.type, "/problems/internal-error", "type")
	Do $$$AssertEquals(body.detail [ "secret", 0, "internal text is not copied into the response")
	Do $$$AssertEquals(body.detail [ "irissys", 0, "paths are not exposed")
}

Method TestUnexpectedStatusMapsToInternalError()
{
	Set body = $ClassMethod(..#D, "ErrorBody", 418, $$$OK)
	Do $$$AssertEquals(body.type, "/problems/internal-error", "anything unmapped is a generic problem")
}

}
