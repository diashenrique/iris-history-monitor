/// CI-only check of what IPM created from module.xml. Not part of the product package.
/// Prints one line per check and INSTALL_CHECK=OK or INSTALL_CHECK=FAILED n.
Class ci.InstallCheck
{

ClassMethod Run()
{
	New $Namespace
	Set $Namespace = "%SYS"
	Set bad = 0
	Set sc = ##class(Security.Applications).Get("/api/historymonitor/v1", .p)
	Do ..Check(sc, "API web application exists", .bad)
	Do ..Check($Get(p("DispatchClass")) = "diashenrique.historymonitor.api.Dispatch", "dispatch class", .bad)
	// The resource is checked by Dispatch.OnPreDispatch (403 problem+json); a web application resource
	// would make CSP answer 401 HTML instead (research.md R11).
	Do ..Check($Get(p("Resource")) = "", "no web application resource; the role is checked in OnPreDispatch", .bad)
	// 32 = password only. Any other value (64 = unauthenticated) would open the API.
	Do ..Check($Get(p("AutheEnabled")) = 32, "authentication is password only (AutheEnabled="_$Get(p("AutheEnabled"))_")", .bad)
	Do ..Check($Get(p("Enabled")) = 1, "enabled", .bad)
	Set sc2 = ##class(Security.Applications).Get("/csp/irismonitor", .q)
	Do ..Check(sc2, "dashboard web application exists", .bad)
	Do ..Check($Get(q("AutheEnabled")) = 32, "dashboard authentication unchanged (AutheEnabled="_$Get(q("AutheEnabled"))_")", .bad)
	Do ..Check(##class(Security.Resources).Exists("HistoryMonitorRead"), "resource created", .bad)
	Do ..Check(##class(Security.Roles).Exists("HistoryMonitorViewer"), "role created", .bad)
	Set sc3 = ##class(Security.Roles).Get("HistoryMonitorViewer", .r)
	Do ..Check($Get(r("Resources")) [ "HistoryMonitorRead:U", "role holds Use on the resource", .bad)
	Do ..Check($Get(r("Resources")) [ "%DB_IRISSYS:R", "role holds Read on %DB_IRISSYS (needed to read the dashboard sample)", .bad)
	Set n = 0
	For t = "SysData", "SysData_DB", "Hourly", "Hourly_Sys", "Hourly_DB", "Daily", "Daily_Sys", "Daily_DB" {
		Set n = n + $SYSTEM.SQL.Security.CheckPrivilege("HistoryMonitorViewer", 1, "SYS_History."_t, "s", "%SYS")
	}
	Do ..Check(n = 8, "role may SELECT the 8 history tables (got "_n_")", .bad)
	Set $Namespace = "USER"
	For c = "api.Dispatch", "api.Problem", "service.History", "service.Overview", "service.Validate", "util.Security" {
		Do ..Check(##class(%Dictionary.CompiledClass).%ExistsId("diashenrique.historymonitor."_c), "class "_c_" compiled", .bad)
	}
	Write $Select(bad = 0: "INSTALL_CHECK=OK", 1: "INSTALL_CHECK=FAILED "_bad), !
}

ClassMethod Check(ok As %Boolean, what As %String, ByRef bad As %Integer) [ Private ]
{
	Write $Select(ok: "PASS ", 1: "FAIL "), what, !
	If 'ok Set bad = bad + 1
}

}
