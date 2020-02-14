Class diashenrique.historymonitor.dashboard.database Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

ClassMethod OnPage() As %Status
{
	#dim %request As %CSP.Request
	#dim %response As %CSP.Response

	Set Method = $Get(%request.Data("method",1))

	Xecute "do .."_Method_"()"

	Quit $$$OK
}

/// do ##class(diashenrique.historymonitor.dashboard.database).getDatabaseDailySize()
ClassMethod getDatabaseDailySize() As %Status
{
	Kill ^IRISMonitor("Database","Daily")

	Set (dtFrom,dtTo)=""

    Set dtFrom = $Get(%request.Data("dayFrom",1))
    Set dtTo = $Get(%request.Data("dayTo",1))

    If (dtTo = "") {
	    Set dtTo = +$Horolog
    }
    Else {
	 	Set dtTo = $ZDateh(dtTo,4)
    }

    If (dtFrom = "") {
    	Set dtFrom = dtTo - 6
    }
    Else {
	    Set dtFrom = $ZDateh(dtFrom,4)
    }

    New $Namespace
	Set $Namespace = "%SYS"

    Set tSC = $System.Status.OK()

    Try {
	    Set oRS = ##class(%SQL.Statement).%New()

		Set sql = "SELECT Daily, element_key as Metrica, DB_FileSize as FileSize FROM SYS_History.Daily_DB WHERE Daily->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        Set tSC = oRS.%Prepare(sql)

        Quit:$System.Status.IsError(tSC)

        Set result = oRS.%Execute()

        If (result.%SQLCODE '< 0) {

            While result.%Next() {

	            If ($Piece(result.Metrica,"_",2) '= "Max") {
		         	Continue   
	            }

				Set dbBlacklist = $Listbuild("IRISTEMP","USER")

				If ($Listfind(dbBlacklist,$Piece(result.Metrica,"_",1)) > 0) {
					Continue
				}

	            Set data = $Piece(result.Daily,"||",1)
				Set hora = $Piece(result.Daily,"||",2)
				Set datetimeUTC = $System.SQL.DATEDIFF("s","1970-01-01 00:00:00",$ZDatetime(data_","_hora,3)) * 1000
				Set dbName = $Piece(result.Metrica,"_",1)
				Set dbMetrica = $Piece(result.Metrica,"_",2)
				Set dbSize = result.FileSize  / 1024	;Convert from Mb to Gigabyte

				Set ^["IRISMONITOR"]IRISMonitor("Database","Daily",dbName,dbMetrica,data,hora) = datetimeUTC_"^"_dbSize
            }

        }
        Else {
            Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }

        Set $Namespace = "IRISMONITOR"

		Set arrDBDia = []

		// Database
		Set idDBName = ""
		For {
			Set idDBName = $Order(^IRISMonitor("Database","Daily",idDBName))
			Quit:idDBName=""

			// Métrica (Max, Avg, StDev)
			Set idMetrica = ""
			For {
				Set idMetrica = $Order(^IRISMonitor("Database","Daily",idDBName,idMetrica))
				Quit:idMetrica=""

				Set arrMetrica = [] 
				// Data 
				Set dtData = ""
				For {
					Set dtData = $Order(^IRISMonitor("Database","Daily",idDBName,idMetrica, dtData))
					Quit:dtData=""

					// Horario 
					Set inthora = ""
					For {
						Set inthora = $Order(^IRISMonitor("Database","Daily",idDBName,idMetrica, dtData,inthora))
						Quit:inthora=""

						Set arrDados = []

						Set obj = $Get(^IRISMonitor("Database","Daily",idDBName,idMetrica,dtData,inthora))

						Set arrDados."0" = $Number($Piece(obj,"^",1))		;DateTime UTC Format 
						Set arrDados."1" = $Normalize($Piece(obj,"^",2),2)	;Database File Size

						Do arrMetrica.%Push(arrDados)
					}
				}
			}
			Set json = { }
			Do json.%Set("name",idDBName)
			Do json.%Set("data",arrMetrica)
			Do json.%Set("lineWidth",$Normalize("0.5",1))
			Do arrDBDia.%Push(json)
		}
    }
    Catch (oException) {
        Set tSC = oException.AsStatus()
    }

    Write arrDBDia.%ToJSON() 

    Quit tSC
}

/// do ##class(diashenrique.historymonitor.dashboard.database).getDatabaseDailySizeDataGrid()
ClassMethod getDatabaseDailySizeDataGrid() As %Status
{
	Kill ^IRISMonitor("Database","DailyDataGrid")

	Set (dtFrom,dtTo)=""

    Set dtFrom = $Get(%request.Data("dayFrom",1))
    Set dtTo = $Get(%request.Data("dayTo",1))

    If (dtTo = "") {
	    Set dtTo = +$Horolog
    }
    Else {
	 	Set dtTo = $ZDateh(dtTo,4)
    }

    If (dtFrom = "") {
    	Set dtFrom = dtTo - 6
    }
    Else {
	    Set dtFrom = $ZDateh(dtFrom,4)
    }

    New $Namespace
	Set $Namespace = "%SYS"

    Set tSC = $System.Status.OK()

    Try {
	    Set oRS = ##class(%SQL.Statement).%New()

        Set sql = "SELECT Daily, element_key as Metrica, DB_FileSize as FileSize FROM SYS_History.Daily_DB WHERE Daily->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        Set tSC = oRS.%Prepare(sql)

        Quit:$System.Status.IsError(tSC)

        Set result = oRS.%Execute()

        If (result.%SQLCODE '< 0) {

            While result.%Next() {

	            If ($Piece(result.Metrica,"_",2) '= "Max") {
		         	Continue   
	            }

	            Set dbBlacklist = $Listbuild("IRISSYS","IRISLIB","IRISTEMP","IRISAUDIT","ENSLIB")

				If ($Listfind(dbBlacklist,$Piece(result.Metrica,"_",1)) > 0) {
					Continue
				}

	            Set data = $Piece(result.Daily,"||",1)
				Set hora = $Piece(result.Daily,"||",2)
				Set dbName = $Piece(result.Metrica,"_",1)
				Set dbSize = result.FileSize  / 1024 	;Convert from Mb to Gigabyte

				Set obj = $Get(^["IRISMONITOR"]IRISMonitor("Database","DailyDataGrid",dbName,data,hora))
	            Set $Piece(obj,"^",1) = $ZDate(data,4)
	            Set $Piece(obj,"^",2) = $ZTime(hora,2)
	            Set $Piece(obj,"^",3) = dbSize

	            Set ^["IRISMONITOR"]IRISMonitor("Database","DailyDataGrid",dbName,data,hora) = obj

            }

        }
        Else {
            Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }

        Set $Namespace = "IRISMONITOR"

		Set arrDBDiaDataGrid = []

		// Database
		Set idDBName = ""
		For {
			Set idDBName = $Order(^IRISMonitor("Database","DailyDataGrid",idDBName))
			Quit:idDBName=""

			// Data 
			Set dtData = ""
			For {
				Set dtData = $Order(^IRISMonitor("Database","DailyDataGrid",idDBName, dtData))
				Quit:dtData=""

				// Horario 
				Set inthora = ""
				For {
					Set inthora = $Order(^IRISMonitor("Database","DailyDataGrid",idDBName, dtData,inthora))
					Quit:inthora=""

					Set oDBDay = $Get(^IRISMonitor("Database","DailyDataGrid",idDBName, dtData,inthora))

					Set json = { } 
					Do json.%Set("dbName",idDBName)
					Do json.%Set("date",$Piece(oDBDay,"^",1))
					Do json.%Set("time",$Piece(oDBDay,"^",2))
					Do json.%Set("sizeGb",$Normalize($Piece(oDBDay,"^",3),2))
					Do arrDBDiaDataGrid.%Push(json)	
				}
			}
		}
    }
    Catch (oException) {
        Set tSC = oException.AsStatus()
    }

    Write arrDBDiaDataGrid.%ToJSON() 

    Quit tSC
}

/// do ##class(diashenrique.historymonitor.dashboard.license).DateTimeToISO8601("2019-03-22 08:58:06")
ClassMethod DateTimeToISO8601(pDateTime As %DateTime) As %String
{
	Quit:(pDateTime="") ""

	Set ret = $Case(pDateTime,"":"",:$Replace(pDateTime," ","T")_"Z")

	Quit ret
}

/// do ##class(diashenrique.historymonitor.dashboard.database).GetDatabases()
ClassMethod GetDatabasesList()
{
	New $Namespace
	Set $Namespace = "%SYS"

	Set statement = ##class(%SQL.Statement).%New()   
	Set status = statement.%PrepareClassQuery("Config.Databases","List")   

	If $$$ISERR(status) {
		Do $System.OBJ.DisplayError(status) 
	}   

	Set resultset = statement.%Execute()

	While resultset.%Next() {
	    Write resultset.%Get("Name")_" - "_resultset.%Get("Directory"),!
	}

	Quit
}

}
