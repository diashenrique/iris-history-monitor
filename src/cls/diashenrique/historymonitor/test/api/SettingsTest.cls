/// Tests for the interface switch (spec 002 task T009, FR-002, research R4).
/// The switch starts off, any viewer can read it through GET /settings, and only an administrator
/// (%Admin_Manage:USE) can change it. The suite runs as a superuser, so the refusal is tested on the pure
/// decision Settings.CanChange, the way Dispatch.Authorize is tested in spec 001.
Class diashenrique.historymonitor.test.api.SettingsTest Extends %UnitTest.TestCase
{

Parameter S = "diashenrique.historymonitor.util.Settings";

Parameter D = "diashenrique.historymonitor.api.Dispatch";

/// The stored value before the tests, restored afterwards.
Property Saved As %String;

Method OnBeforeAllTests() As %Status
{
	Set ..Saved = $ClassMethod(..#S, "Stored")
	Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
	Quit $ClassMethod(..#S, "Restore", ..Saved)
}

Method TestSwitchStartsOff()
{
	Do $ClassMethod(..#S, "Restore", "")
	Do $$$AssertEquals($ClassMethod(..#S, "InterfaceEnabled"), 0, "nothing stored means off")
}

Method TestAdministratorCanTurnItOnAndOff()
{
	Set sc = $ClassMethod(..#S, "SetInterfaceEnabled", 1)
	Do $$$AssertStatusOK(sc, "the superuser running the tests holds %Admin_Manage")
	Do $$$AssertEquals($ClassMethod(..#S, "InterfaceEnabled"), 1, "on")
	Do $$$AssertStatusOK($ClassMethod(..#S, "SetInterfaceEnabled", 0), "off again")
	Do $$$AssertEquals($ClassMethod(..#S, "InterfaceEnabled"), 0, "off")
}

Method TestAnyTrueValueMeansOn()
{
	Do $ClassMethod(..#S, "SetInterfaceEnabled", 7)
	Do $$$AssertEquals($ClassMethod(..#S, "InterfaceEnabled"), 1, "stored as a boolean")
}

Method TestOnlyAnAdministratorMayChangeIt()
{
	Do $$$AssertEquals($ClassMethod(..#S, "CanChange", 1), 1, "with %Admin_Manage:USE")
	Do $$$AssertEquals($ClassMethod(..#S, "CanChange", 0), 0, "without it")
	Do $$$AssertEquals($ClassMethod(..#S, "CanChange", ""), 0, "no answer means no")
}

Method TestSettingsBodyMatchesTheContract()
{
	Do $ClassMethod(..#S, "SetInterfaceEnabled", 1)
	Set body = $ClassMethod(..#D, "SettingsResponse")
	Set errs = ##class(diashenrique.historymonitor.test.api.ContractHelper).Check("Settings", body)
	Do $$$AssertEquals(errs.%Size(), 0, "matches Settings: "_##class(diashenrique.historymonitor.test.api.ContractHelperTest).Text(errs))
	Do $$$AssertEquals(body.%GetTypeOf("interfaceEnabled"), "boolean", "a JSON boolean")
	Do $$$AssertEquals(body.interfaceEnabled, 1, "reports the stored value")
}

Method TestRouteIsMapped()
{
	Set xdata = ##class(%Dictionary.CompiledXData).%OpenId(..#D_"||UrlMap")
	Quit:'$IsObject(xdata)
	Set text = $ZStrip(xdata.Data.Read(32000), "*WC")
	Do $$$AssertTrue(text [ "<RouteUrl=""/settings""Method=""GET""Call=""Settings""/>", "GET /settings calls Settings")
}

}
