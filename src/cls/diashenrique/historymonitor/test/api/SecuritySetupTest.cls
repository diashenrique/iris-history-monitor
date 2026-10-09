/// Tests for util.Security (task T003). Uses its own resource and role names so it never
/// touches the real ones on a developer instance.
Class diashenrique.historymonitor.test.api.SecuritySetupTest Extends %UnitTest.TestCase
{

Parameter RES = "HMTestResource";

Parameter ROLE = "HMTestRole";

Method OnBeforeAllTests() As %Status
{
	Quit ##class(diashenrique.historymonitor.util.Security).Teardown(..#RES, ..#ROLE)
}

Method OnAfterAllTests() As %Status
{
	Quit ##class(diashenrique.historymonitor.util.Security).Teardown(..#RES, ..#ROLE)
}

Method TestSetupCreatesResourceAndRole()
{
	Set sc = ##class(diashenrique.historymonitor.util.Security).Setup(..#RES, ..#ROLE)
	Do $$$AssertStatusOK(sc, "Setup returns OK")
	New $Namespace
	Set $Namespace = "%SYS"
	Do $$$AssertEquals(##class(Security.Resources).Exists(..#RES), 1, "resource exists")
	Do $$$AssertEquals(##class(Security.Roles).Exists(..#ROLE), 1, "role exists")
}

Method TestRoleHoldsUsePermissionOnResource()
{
	Do ##class(diashenrique.historymonitor.util.Security).Setup(..#RES, ..#ROLE)
	New $Namespace
	Set $Namespace = "%SYS"
	Set sc = ##class(Security.Roles).Get(..#ROLE, .props)
	Do $$$AssertStatusOK(sc, "role can be read")
	Do $$$AssertEquals($Find($Get(props("Resources")), ..#RES_":U") > 0, 1, "role holds Use on the resource")
}

Method TestSetupIsIdempotent()
{
	Set sc1 = ##class(diashenrique.historymonitor.util.Security).Setup(..#RES, ..#ROLE)
	Set sc2 = ##class(diashenrique.historymonitor.util.Security).Setup(..#RES, ..#ROLE)
	Do $$$AssertStatusOK(sc1, "first call OK")
	Do $$$AssertStatusOK(sc2, "second call OK, nothing duplicated or failing")
}

Method TestTeardownRemovesBoth()
{
	Do ##class(diashenrique.historymonitor.util.Security).Setup(..#RES, ..#ROLE)
	Set sc = ##class(diashenrique.historymonitor.util.Security).Teardown(..#RES, ..#ROLE)
	Do $$$AssertStatusOK(sc, "Teardown returns OK")
	New $Namespace
	Set $Namespace = "%SYS"
	Do $$$AssertEquals(##class(Security.Roles).Exists(..#ROLE), 0, "role removed")
	Do $$$AssertEquals(##class(Security.Resources).Exists(..#RES), 0, "resource removed")
}

}
