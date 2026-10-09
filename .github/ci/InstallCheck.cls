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
	Do ..Check($Get(p("Resource")) = "HistoryMonitorRead", "requires the HistoryMonitorRead resource", .bad)
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
	Set $Namespace = "USER"
	For c = "api.Dispatch", "api.Problem", "service.Overview", "service.Validate", "util.Security" {
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
