/// Tests for util.Security (task T003). Uses its own resource and role names so it never
/// touches the real ones on a developer instance.
/// The role also needs Read on the IRISSYS database: service.Overview switches to %SYS to read the
/// dashboard sample, and without it a real HTTP call returned every metric unavailable (task T012).
/// It also needs SELECT on the System Monitor history tables: without it a real HTTP call to
/// /history failed with SQLCODE -99 (task T016).
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

Method TestRoleCanReadTheSystemDatabase()
{
	Do ##class(diashenrique.historymonitor.util.Security).Setup(..#RES, ..#ROLE)
	New $Namespace
	Set $Namespace = "%SYS"
	Do ##class(Security.Roles).Get(..#ROLE, .props)
	Do $$$AssertEquals(..Holds($Get(props("Resources")), "%DB_IRISSYS", "R"), 1, "role holds Read on %DB_IRISSYS: "_$Get(props("Resources")))
}

Method TestSetupCompletesARoleFromAnOlderInstall()
{
	Do ##class(diashenrique.historymonitor.util.Security).Teardown(..#RES, ..#ROLE)
	Do ..CreateOldRole()
	Set sc = ##class(diashenrique.historymonitor.util.Security).Setup(..#RES, ..#ROLE)
	Do $$$AssertStatusOK(sc, "Setup on an existing role")
	Set res = ..RoleResources()
	Do $$$AssertEquals(..Holds(res, ..#RES, "U"), 1, "keeps Use on the resource: "_res)
	Do $$$AssertEquals(..Holds(res, "%DB_IRISSYS", "R"), 1, "adds Read on %DB_IRISSYS: "_res)
}

/// The resource and role as version 1.3.0 created them: Use on the resource only.
ClassMethod CreateOldRole()
{
	New $Namespace
	Set $Namespace = "%SYS"
	Do ##class(Security.Resources).Create(..#RES, "test", "")
	Do ##class(Security.Roles).Create(..#ROLE, "role as version 1.3.0 created it", ..#RES_":U")
}

ClassMethod RoleResources() As %String
{
	New $Namespace
	Set $Namespace = "%SYS"
	Do ##class(Security.Roles).Get(..#ROLE, .props)
	Quit $Get(props("Resources"))
}

/// True when the comma list of resource:permissions grants perm on name.
ClassMethod Holds(list As %String, name As %String, perm As %String) As %Boolean
{
	For i = 1:1:$Length(list, ",") {
		Set item = $Piece(list, ",", i)
		If ($Piece(item, ":", 1) = name) && ($Piece(item, ":", 2) [ perm) Return 1
	}
	Quit 0
}

Method TestRoleCanSelectTheHistoryTables()
{
	Do ##class(diashenrique.historymonitor.util.Security).Setup(..#RES, ..#ROLE)
	For t = "SysData", "SysData_DB", "Hourly", "Hourly_Sys", "Hourly_DB", "Daily", "Daily_Sys", "Daily_DB" {
		Do $$$AssertEquals(..Can(t, "s"), 1, "SELECT on SYS_History."_t)
		Do $$$AssertEquals(..Can(t, "i") + ..Can(t, "u") + ..Can(t, "d"), 0, "no INSERT, UPDATE or DELETE on SYS_History."_t)
	}
	Do $$$AssertEquals(..Can("PerfData", "s"), 0, "no SELECT on a history table the API does not read")
}

/// Whether the test role holds the SQL privilege (s, i, u, d) on SYS_History.<table>.
ClassMethod Can(table As %String, action As %String) As %Boolean
{
	New $Namespace
	Set $Namespace = "%SYS"
	Quit +$SYSTEM.SQL.Security.CheckPrivilege(..#ROLE, 1, "SYS_History."_table, action, "%SYS")
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
