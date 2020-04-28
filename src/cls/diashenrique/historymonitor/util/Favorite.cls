Class diashenrique.historymonitor.util.Favorite Extends %SYS.Portal.Users
{

ClassMethod %AddFavorite(pPageName As %String, pURLData As %List) As %Status [ Internal ]
{
    New $Namespace
    Set $Namespace = "%SYS"
    Set tSC = $$$OK

    Try {

        Set sql = "SELECT ID FROM Security.Users"

        Set oRS = ##class(%SQL.Statement).%New()

        Set tSC = oRS.%Prepare(sql)

        Quit:$System.Status.IsError(tSC)

        Set result = oRS.%Execute()

        If (result.%SQLCODE '< 0) {
            While result.%Next() {
                Set userID = result.ID

                Set existentId = ""
                &SQL(SELECT ID INTO :existentId FROM %SYS_Portal.Users WHERE Page = :pPageName AND Username = :userID)

                If (existentId="") {
                    Set Obj = ..%New()
                    If $IsObject(Obj) {
                        Set Obj.Username = userID
                        Set Obj.Page = pPageName
                        Set Obj.Data = pURLData
                        Set Status = Obj.%Save()
                    }
                }
            }
        }
        Else {
            Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
    }
    Catch (oException) {
        Set tSC = oException.AsStatus()
    }

    Quit tSC
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
