/// GET /settings after the monitor switch was removed (spec 003 FR-007, research R5). The route stays in
/// API v1 for compatibility and always reports the monitor as on, even when an old 1.x switch value is
/// still stored (the upgrade cleanup removes it, but the answer must not depend on that).
Class diashenrique.historymonitor.test.api.SettingsTest Extends %UnitTest.TestCase
{

Parameter D = "diashenrique.historymonitor.api.Dispatch";

Method TestSettingsBodyMatchesTheContract()
{
	Set body = $ClassMethod(..#D, "SettingsResponse")
	Set errs = ##class(diashenrique.historymonitor.test.api.ContractHelper).Check("Settings", body)
	Do $$$AssertEquals(errs.%Size(), 0, "matches Settings: "_##class(diashenrique.historymonitor.test.api.ContractHelperTest).Text(errs))
	Do $$$AssertEquals(body.%GetTypeOf("interfaceEnabled"), "boolean", "a JSON boolean")
	Do $$$AssertEquals(body.interfaceEnabled, 1, "always on")
}

Method TestAnOldSwitchValueIsIgnored()
{
	Set saved = $Get(^diashenrique.historymonitor.Settings("interfaceEnabled"), "<none>")
	Set ^diashenrique.historymonitor.Settings("interfaceEnabled") = 0
	Set body = $ClassMethod(..#D, "SettingsResponse")
	If saved = "<none>" { Kill ^diashenrique.historymonitor.Settings } Else { Set ^diashenrique.historymonitor.Settings("interfaceEnabled") = saved }
	Do $$$AssertEquals(body.interfaceEnabled, 1, "a 1.x 'off' value left behind does not turn the monitor off")
}

Method TestRouteIsMapped()
{
	Set xdata = ##class(%Dictionary.CompiledXData).%OpenId(..#D_"||UrlMap")
	Quit:'$IsObject(xdata)
	Set text = $ZStrip(xdata.Data.Read(32000), "*WC")
	Do $$$AssertTrue(text [ "<RouteUrl=""/settings""Method=""GET""Call=""Settings""/>", "GET /settings calls Settings")
}

}
