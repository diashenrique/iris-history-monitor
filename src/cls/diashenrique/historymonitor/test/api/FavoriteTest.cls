/// The Management Portal favourite created at install (spec 002 task T058, FR-024).
/// Version 1.x created it pointing to the old dashboard, and stored it as an object of util.Favorite,
/// a class that does not exist in %SYS, so the Management Portal could not open, change or delete it.
/// An install must leave one plain %SYS.Portal.Users favourite per user, pointing to the new interface.
/// Uses its own page name and removes it afterwards, so real favourites are untouched.
Class diashenrique.historymonitor.test.api.FavoriteTest Extends %UnitTest.TestCase
{

Parameter PAGE = "HMTestFavorite";

Method OnBeforeAllTests() As %Status
{
	Quit ..Remove()
}

Method OnAfterAllTests() As %Status
{
	Quit ..Remove()
}

/// Deletes the test favourites from this namespace, where both the plain class and util.Favorite exist
/// (the data lives in the system database, the same for every namespace).
ClassMethod Remove() As %Status
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT %ID AS id FROM %SYS_Portal.Users WHERE Page = ?", ..#PAGE)
	While rs.%Next() { Do ##class(%SYS.Portal.Users).%DeleteId(rs.id) }
	Quit $$$OK
}

/// The link stored for the current user, or "".
ClassMethod Link() As %String
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Data FROM %SYS_Portal.Users WHERE Page = ? AND Username = ?", ..#PAGE, $ZConvert($Username, "L"))
	Quit $Select(rs.%Next(): rs.Data, 1: "")
}

/// Whether the Management Portal, which runs in %SYS, can open the current user's favourite.
ClassMethod PortalCanOpen() As %Boolean
{
	Set id = $ZConvert($Username, "L")_"||"_..#PAGE
	New $Namespace
	Set $Namespace = "%SYS"
	Quit $IsObject(##class(%SYS.Portal.Users).%OpenId(id))
}

/// A favourite as version 1.x stored it: an object of util.Favorite.
ClassMethod CreateOldStyle(url As %String)
{
	Set o = ##class(diashenrique.historymonitor.util.Favorite).%New()
	Set o.Username = $ZConvert($Username, "L"), o.Page = ..#PAGE, o.Data = url
	Do o.%Save()
}

Method TestCreatesAFavouriteThePortalCanOpen()
{
	Do ..Remove()
	Set sc = ##class(diashenrique.historymonitor.util.Favorite).%AddFavorite(..#PAGE, "/historymonitor/index.html")
	Do $$$AssertStatusOK(sc, "added")
	Do $$$AssertEquals(..Link(), "/historymonitor/index.html", "points to the new interface")
	Do $$$AssertTrue(..PortalCanOpen(), "the Management Portal can open it")
}

Method TestUpgradeMovesAnOldFavourite()
{
	Do ..Remove()
	Do ..CreateOldStyle("/csp/irismonitor/dashboard.csp")
	Do $$$AssertEquals(..Link(), "/csp/irismonitor/dashboard.csp", "the favourite of version 1.x")
	Do $$$AssertEquals(..PortalCanOpen(), 0, "which the Management Portal cannot open")
	Set sc = ##class(diashenrique.historymonitor.util.Favorite).%AddFavorite(..#PAGE, "/historymonitor/index.html")
	Do $$$AssertStatusOK(sc, "installed again")
	Do $$$AssertEquals(..Link(), "/historymonitor/index.html", "now points to the new interface")
	Do $$$AssertTrue(..PortalCanOpen(), "and the Management Portal can open it")
}

Method TestInstallingTwiceKeepsOneFavourite()
{
	Do ..Remove()
	Do ##class(diashenrique.historymonitor.util.Favorite).%AddFavorite(..#PAGE, "/historymonitor/index.html")
	Do ##class(diashenrique.historymonitor.util.Favorite).%AddFavorite(..#PAGE, "/historymonitor/index.html")
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS n FROM %SYS_Portal.Users WHERE Page = ? AND Username = ?", ..#PAGE, $ZConvert($Username, "L"))
	Do rs.%Next()
	Do $$$AssertEquals(rs.n, 1, "one favourite per user")
}

}
