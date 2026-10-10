/// util.Retire pointed at test-only names, so RetireTest never touches the real classes, files or
/// globals (spec 003 analysis F2). Same shape as the real targets: a package, single classes (including
/// page classes next to a class of the same package that must stay), a folder under the instance's csp
/// folder, and globals.
Class diashenrique.historymonitor.test.api.RetireFixture Extends diashenrique.historymonitor.util.Retire
{

Parameter PACKAGES = "diashenrique.historymonitor.test.retireold";

Parameter CLASSES = "diashenrique.historymonitor.test.retireutil.metrics,diashenrique.historymonitor.test.retireutil.Settings,diashenrique.historymonitor.test.retirecsp.dashboard,diashenrique.historymonitor.test.retirecsp.historylicense";

Parameter FOLDER = "hm-retire-test";

Parameter GLOBALS = "^HMRetireTestScratch,^HMRetireTestSettings";

}
