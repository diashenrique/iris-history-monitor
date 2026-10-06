/// Regression tests for the Phase 1 security fixes.
/// Run: do ##class(%UnitTest.Manager).RunTest("diashenrique/historymonitor/test", "/nodelete")
Class diashenrique.historymonitor.test.SecurityTest Extends %UnitTest.TestCase
{

Method TestSsrfRejectsBadPorts()
{
	Set cls = "diashenrique.historymonitor.util.metrics"
	Do $$$AssertEquals($ClassMethod(cls, "IsAllowedTarget", "localhost", "0"), 0, "port 0 rejected")
	Do $$$AssertEquals($ClassMethod(cls, "IsAllowedTarget", "localhost", "70000"), 0, "port above 65535 rejected")
	Do $$$AssertEquals($ClassMethod(cls, "IsAllowedTarget", "localhost", "80a"), 0, "non numeric port rejected")
	Do $$$AssertEquals($ClassMethod(cls, "IsAllowedTarget", "localhost", ""), 0, "empty port rejected")
}

Method TestSsrfRejectsForeignHosts()
{
	Set cls = "diashenrique.historymonitor.util.metrics"
	Do $$$AssertEquals($ClassMethod(cls, "IsAllowedTarget", "169.254.169.254", "80"), 0, "metadata address rejected")
	Do $$$AssertEquals($ClassMethod(cls, "IsAllowedTarget", "evil.example.com", "443"), 0, "unlisted host rejected")
	Do $$$AssertEquals($ClassMethod(cls, "IsAllowedTarget", "localhost@evil.com", "80"), 0, "userinfo trick rejected")
	Do $$$AssertEquals($ClassMethod(cls, "IsAllowedTarget", "", "80"), 0, "empty host rejected")
}

Method TestSsrfAcceptsLocalAndListedHosts()
{
	Set cls = "diashenrique.historymonitor.util.metrics"
	Do $$$AssertEquals($ClassMethod(cls, "IsAllowedTarget", "localhost", "52773"), 1, "localhost accepted")
	Do $$$AssertEquals($ClassMethod(cls, "IsAllowedTarget", "127.0.0.1", "52773"), 1, "loopback accepted")
	Set ^IRISMonitor("AllowedHosts", "monitor.test") = 1
	Do $$$AssertEquals($ClassMethod(cls, "IsAllowedTarget", "Monitor.Test", "443"), 1, "listed host accepted, case-insensitive")
	Kill ^IRISMonitor("AllowedHosts", "monitor.test")
}

Method TestDispatcherRejectsUnlistedMethod()
{
	// Dispatcher writes to %response; give it one so the test does not touch a real request
	New %response
	Set %response = ##class(%CSP.Response).%New()
	Set sc = ##class(diashenrique.historymonitor.util.Dispatcher).Run("diashenrique.historymonitor.util.metrics", "$ZUtil(5)", "readMetrics")
	Do $$$AssertStatusOK(sc, "returns OK without executing")
	Do $$$AssertEquals(%response.Status, "400 Bad Request", "status is 400")
}

Method TestDispatcherRejectsInjection()
{
	New %response
	Set %response = ##class(%CSP.Response).%New()
	Set ^IRISMonitor("TestCanary") = 0
	Set sc = ##class(diashenrique.historymonitor.util.Dispatcher).Run("diashenrique.historymonitor.util.metrics", "readMetrics() set ^IRISMonitor(""TestCanary"")=1 do x", "readMetrics")
	Do $$$AssertEquals($Get(^IRISMonitor("TestCanary")), 0, "injected code did not run")
	Kill ^IRISMonitor("TestCanary")
}

}
