/// Adds the History Monitor to the Management Portal favourites of every user (module.xml invoke).
///
/// Favourites are %SYS.Portal.Users rows, stored in the system database and therefore the same in every
/// namespace. Version 1.x saved them as objects of this class, which does not exist in %SYS, so the
/// Management Portal could not open, change or delete them. This class still extends %SYS.Portal.Users
/// so those old rows stay readable here; %AddFavorite replaces them with plain %SYS.Portal.Users rows
/// and points them to the given address (spec 002 FR-024).
Class diashenrique.historymonitor.util.Favorite Extends %SYS.Portal.Users
{

ClassMethod %AddFavorite(pPageName As %String, pURLData As %List) As %Status [ Internal ]
{
	Set tSC = $$$OK
	Try {
		Do ..Users(.users)
		Set user = ""
		For {
			Set user = $Order(users(user))
			Quit:user=""
			Set id = user_"||"_pPageName
			Set existing = ##class(%SYS.Portal.Users).%OpenId(id)
			If $IsObject(existing) && ($ClassName(existing) = "%SYS.Portal.Users") {
				If existing.Data '= pURLData {
					Set existing.Data = pURLData
					$$$ThrowOnError(existing.%Save())
				}
				Continue
			}
			// A 1.x row (an object of this class) or none: replace it with a plain row the Portal can open.
			Kill existing
			If ##class(%SYS.Portal.Users).%ExistsId(id) $$$ThrowOnError(##class(%SYS.Portal.Users).%DeleteId(id))
			Set row = ##class(%SYS.Portal.Users).%New()
			Set row.Username = user, row.Page = pPageName, row.Data = pURLData
			$$$ThrowOnError(row.%Save())
		}
	}
	Catch (oException) {
		Set tSC = oException.AsStatus()
	}
	Quit tSC
}

/// users(name) for every user of the instance, read in %SYS.
ClassMethod Users(Output users) [ Private ]
{
	Kill users
	New $Namespace
	Set $Namespace = "%SYS"
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM Security.Users")
	While rs.%Next() { Set users(rs.ID) = "" }
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
