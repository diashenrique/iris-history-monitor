Class diashenrique.historymonitor.dashboard.license Extends %CSP.Page
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

/// do ##class(diashenrique.historymonitor.dashboard.license).getLicenseLiveHistory()
ClassMethod getLicenseLiveHistory() As %Status
{
    Set (dtFrom,dtTo)=""

    Set dtFrom = $Get(%request.Data("fiveMinFrom",1))
    Set dtTo = $Get(%request.Data("fiveMinTo",1))

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
    Set arrayLicenseLive = []

    Try {

	    Set sql = "SELECT top 1000 DateTime, Sys_LicUsedLocal as LicUsedLocal FROM SYS_History.SysData WHERE ZDATE BETWEEN "_dtFrom_" AND "_dtTo

	    Set oRS = ##class(%SQL.Statement).%New()

        Set tSC = oRS.%Prepare(sql)

        Quit:$System.Status.IsError(tSC)

        Set result = oRS.%Execute()

        If (result.%SQLCODE '< 0) {
	        While result.%Next() {
	            Set arrayDados = [] 
				Set arrayDados."0" = ..DateTimeToISO8601(result.DateTime)
				Set arrayDados."1" = result.LicUsedLocal
				Do arrayLicenseLive.%Push(arrayDados)
            }

        }
        Else {
            Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
    }
    Catch (oException) {
        Set tSC = oException.AsStatus()
    }

    Write arrayLicenseLive.%ToJSON() 

    Quit tSC
}

/// do ##class(diashenrique.historymonitor.dashboard.license).getLicenseEveryFiveMinutesDataTable()
ClassMethod getLicenseEveryFiveMinutesDataTable() As %Status
{
    Set (dtFrom,dtTo)=""

    Set dtFrom = $Get(%request.Data("fiveFrom",1))
    Set dtTo = $Get(%request.Data("fiveTo",1))

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
    Set arrayFiveMin = []

    Try {

	    Set sql = "SELECT top 1000 DateTime, Sys_LicUsedLocal as LicUsedLocal FROM SYS_History.SysData WHERE ZDATE BETWEEN "_dtFrom_" AND "_dtTo

	    Set oRS = ##class(%SQL.Statement).%New()

        Set tSC = oRS.%Prepare(sql)

        Quit:$System.Status.IsError(tSC)

        Set result = oRS.%Execute()

        If (result.%SQLCODE '< 0) {
	        While result.%Next() {
	            Set json = { } 
	            Set dia = $Piece(result.DateTime," ",1)
	            Set hora = $Piece(result.DateTime," ",2)
				Do json.%Set("date",$ZDate($ZDateh(dia,3),4))
				Do json.%Set("time",hora)
				Do json.%Set("licQty",result.LicUsedLocal)
				Do arrayFiveMin.%Push(json)
            }

        }
        Else {
            Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
    }
    Catch (oException) {
        Set tSC = oException.AsStatus()
    }

    Write arrayFiveMin.%ToJSON() 

    Quit tSC
}

/// do ##class(diashenrique.historymonitor.dashboard.license).getLicenseHourlyHistory()
ClassMethod getLicenseHourlyHistory() As %Status
{
	Kill ^IRISMonitor("License","Hourly")

	Set (dtFrom,dtTo)=""

    Set dtFrom = $Get(%request.Data("hourFrom",1))
    Set dtTo = $Get(%request.Data("hourTo",1))

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

        Set sql = "SELECT Hourly, element_key as Metrica, Sys_LicUsedLocal as LicUsedLocal FROM SYS_History.Hourly_Sys WHERE Hourly->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        Set tSC = oRS.%Prepare(sql)

        Quit:$System.Status.IsError(tSC)

        Set result = oRS.%Execute()

        If (result.%SQLCODE '< 0) {

            While result.%Next() {
	            Set data = $Piece(result.Hourly,"||",1)
	            Set hora = $Piece(result.Hourly,"||",2)
	            Set metrica = result.Metrica
	            Set licenca = result.LicUsedLocal

				;Skipping Standard Deviation, just keeping Average and Maximum Values 
	            Continue:(metrica="StDev")

	            Set datetimeUTC = $System.SQL.DATEDIFF("s","1970-01-01 00:00:00",$ZDatetime(data_","_hora,3)) * 1000

	            Set ^["IRISMONITOR"]IRISMonitor("License","Hourly",metrica,data,hora) = datetimeUTC_"^"_licenca
            }

        }
        Else {
            Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }

        Set $Namespace = "IRISMONITOR"
        Set arrHourly = []

        // Métrica (Max, Avg, StDev)
		Set idMetrica = ""
		For {
			Set idMetrica = $Order(^IRISMonitor("License","Hourly",idMetrica))
			Quit:idMetrica=""

			Set arrMetrica = [] 

			// Data  
			Set dtData = ""
			For {
				Set dtData = $Order(^IRISMonitor("License","Hourly",idMetrica,dtData))
				Quit:dtData=""

				// Horario 
				Set inthora = ""
				For {
					Set inthora = $Order(^IRISMonitor("License","Hourly",idMetrica,dtData,inthora))
					Quit:inthora=""

					Set arrDados = []

					Set obj = $Get(^IRISMonitor("License","Hourly",idMetrica,dtData,inthora))

					Set arrDados."0" = $Number($Piece(obj,"^",1))		;DateTime UTC Format 
					Set arrDados."1" = $Normalize($Piece(obj,"^",2),2)	;License Qty

					Do arrMetrica.%Push(arrDados)
				}

			}

			Set json = { } , jsonMarker = { } , jsonfillColor = { } , jsonlinearGradient = { } , arrStops = [], arrAllStops = []

			Set colorCode = $Select(idMetrica="Max":"#107595",idMetrica="Avg":"#fcf594",1:"#f2efb6")

			Do json.%Set("name",idMetrica)
			Do json.%Set("data",arrMetrica)
			Do json.%Set("color",colorCode)
			Do json.%Set("lineColor",colorCode)

			Do jsonMarker.%Set("enabled",0)
			Do jsonMarker.%Set("symbol","circle")
			Do jsonMarker.%Set("radius",2)
			Do jsonMarker.%Set("lineWidth",1)
			Do jsonMarker.%Set("lineColor",colorCode)
			Do jsonMarker.%Set("fillColor","#ffffff") 
			Do json.%Set("marker",jsonMarker)

			Do jsonlinearGradient.%Set("x1",0)
			Do jsonlinearGradient.%Set("x2",0)
			Do jsonlinearGradient.%Set("y1",0)
			Do jsonlinearGradient.%Set("y2",1)

			Set arrStops = [].%Push(0).%Push(colorCode)
            Do arrAllStops.%Push(arrStops)
            Set arrStops = [].%Push(1).%Push("#ffffff")
            Do arrAllStops.%Push(arrStops)

			Do jsonfillColor.%Set("linearGradient",jsonlinearGradient)
			Do jsonfillColor.%Set("stops",arrAllStops)
			Do json.%Set("fillColor",jsonfillColor)

			Do arrHourly.%Push(json)
		}

    }
    Catch (oException) {
        Set tSC = oException.AsStatus()
    }

    Write arrHourly.%ToJSON() 

    Quit tSC
}

/// do ##class(diashenrique.historymonitor.dashboard.license).getLicenseHourlyDataTable()
ClassMethod getLicenseHourlyDataTable() As %Status
{
	Kill ^IRISMonitor("Hourly","DataTable")

	Set (dtFrom,dtTo, obj)=""

    Set dtFrom = $Get(%request.Data("hourFrom",1))
    Set dtTo = $Get(%request.Data("hourTo",1))

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

        Set sql = "SELECT Hourly, element_key as Metrica, Sys_LicUsedLocal as LicUsedLocal FROM SYS_History.Hourly_Sys WHERE Hourly->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        Set tSC = oRS.%Prepare(sql)

        Quit:$System.Status.IsError(tSC)

        Set result = oRS.%Execute()

        If (result.%SQLCODE '< 0) {

            While result.%Next() {
	            Set data = $Piece(result.Hourly,"||",1)
	            Set hora = $Piece(result.Hourly,"||",2)
	            Set metrica = result.Metrica
	            Set licenca = result.LicUsedLocal

				;Skipping Standard Deviation, just keeping Average and Maximum Values 
	            Continue:(metrica="StDev")

	            Set obj = $Get(^["IRISMONITOR"]IRISMonitor("Hourly","DataTable",data,hora))
	            Set $Piece(obj,"^",1) = $ZDate(data,4)
	            Set $Piece(obj,"^",2) = $ZTime(hora,2)
	            If (metrica="Avg") {
		            Set $Piece(obj,"^",3) = licenca
	            }
                Else {
		            Set $Piece(obj,"^",4) = licenca
	            }

	            Set ^["IRISMONITOR"]IRISMonitor("Hourly","DataTable",data,hora) = obj
            }

        }
        Else {
            Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }

        Set $Namespace = "IRISMONITOR"

        Set arrHourlyDataTable = []

		Set dia = ""
		For {
			Set dia = $Order(^IRISMonitor("Hourly","DataTable",dia))
			Quit:dia=""

			Set horario = ""
			For {
				Set horario = $Order(^IRISMonitor("Hourly","DataTable",dia,horario))
				Quit:horario=""

				Set oHourly = $Get(^IRISMonitor("Hourly","DataTable",dia,horario))

				Set json = { } 
				Do json.%Set("date",$Piece(oHourly,"^",1))
				Do json.%Set("time",$Piece(oHourly,"^",2))
				Do json.%Set("avg",$Normalize($Piece(oHourly,"^",3),2))
				Do json.%Set("max",$Normalize($Piece(oHourly,"^",4),2))
				Do arrHourlyDataTable.%Push(json)	
			}

		}

    }
    Catch (oException) {
        Set tSC = oException.AsStatus()
    }

    Write arrHourlyDataTable.%ToJSON() 

    Quit tSC
}

/// do ##class(diashenrique.historymonitor.dashboard.license).getLicenseDailyHistory()
ClassMethod getLicenseDailyHistory() As %Status
{
	Kill ^IRISMonitor("Daily")	

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

        Set sql = "SELECT Daily, element_key as Metrica, Sys_LicUsedLocal as LicUsedLocal FROM SYS_History.Daily_Sys WHERE Daily->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        Set tSC = oRS.%Prepare(sql)

        Quit:$System.Status.IsError(tSC)

        Set result = oRS.%Execute()

        If (result.%SQLCODE '< 0) {

            While result.%Next() {
	            Set data = $Piece(result.Daily,"||",1)
	            Set hora = $Piece(result.Daily,"||",2)
	            Set metrica = result.Metrica
	            Set licenca = result.LicUsedLocal

				;Skipping Standard Deviation, just keeping Average and Maximum Values 
	            Continue:(metrica="StDev")

	            Set datetimeUTC = $System.SQL.DATEDIFF("s","1970-01-01 00:00:00",$ZDatetime(data_","_hora,3)) * 1000

	            Set ^["IRISMONITOR"]IRISMonitor("Daily",metrica,data,hora) = datetimeUTC_"^"_licenca
            }

        }
        Else {
            Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }

        Set $Namespace = "IRISMONITOR"
        Set arrDaily = []

        // Métrica (Max, Avg, StDev)
		Set idMetrica = ""
		For {
			Set idMetrica = $Order(^IRISMonitor("Daily",idMetrica))
			Quit:idMetrica=""

			Set arrMetrica = [] 

			// Data  
			Set dtData = ""
			For {
				Set dtData = $Order(^IRISMonitor("Daily",idMetrica,dtData))
				Quit:dtData=""

				// Horario 
				Set inthora = ""
				For {
					Set inthora = $Order(^IRISMonitor("Daily",idMetrica,dtData,inthora))
					Quit:inthora=""

					Set arrDados = []

					Set obj = $Get(^IRISMonitor("Daily",idMetrica,dtData,inthora))

					Set arrDados."0" = $Number($Piece(obj,"^",1))		;DateTime UTC Format 
					Set arrDados."1" = $Normalize($Piece(obj,"^",2),2)	;Nº Licença

					Do arrMetrica.%Push(arrDados)
				}

			}

			Set json = { } , jsonMarker = { } , jsonfillColor = { } , jsonlinearGradient = { } , arrStops = [], arrAllStops = []

			Set colorCode = $Select(idMetrica="Max":"#22b2da",idMetrica="Avg":"#f0d43a",1:"#f2efb6")

			Do json.%Set("name",idMetrica)
			Do json.%Set("data",arrMetrica)
			Do json.%Set("color",colorCode)
			Do json.%Set("lineColor",colorCode)

			Do jsonMarker.%Set("enabled",0)
			Do jsonMarker.%Set("symbol","circle")
			Do jsonMarker.%Set("radius",2)
			Do jsonMarker.%Set("lineWidth",1)
			Do jsonMarker.%Set("lineColor",colorCode)
			Do jsonMarker.%Set("fillColor","#ffffff") 
			Do json.%Set("marker",jsonMarker)

			Do jsonlinearGradient.%Set("x1",0)
			Do jsonlinearGradient.%Set("x2",0)
			Do jsonlinearGradient.%Set("y1",0)
			Do jsonlinearGradient.%Set("y2",1)

			Set arrStops = [].%Push(0).%Push(colorCode)
            Do arrAllStops.%Push(arrStops)
            Set arrStops = [].%Push(1).%Push("#ffffff")
            Do arrAllStops.%Push(arrStops)

			Do jsonfillColor.%Set("linearGradient",jsonlinearGradient)
			Do jsonfillColor.%Set("stops",arrAllStops)
			Do json.%Set("fillColor",jsonfillColor)

			Do arrDaily.%Push(json)
		}

    }
    Catch (oException) {
        Set tSC = oException.AsStatus()
    }

    Write arrDaily.%ToJSON() 

    Quit tSC
}

/// do ##class(diashenrique.historymonitor.dashboard.license).getLicenseDailyDataTable()
ClassMethod getLicenseDailyDataTable() As %Status
{
	Kill IRISMonitor("Daily","DataTable")

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

        Set sql = "SELECT Daily, element_key as Metrica, Sys_LicUsedLocal as LicUsedLocal FROM SYS_History.Daily_Sys WHERE Daily->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        Set tSC = oRS.%Prepare(sql)

        Quit:$System.Status.IsError(tSC)

        Set result = oRS.%Execute()

        If (result.%SQLCODE '< 0) {

            While result.%Next() {
	            Set data = $Piece(result.Daily,"||",1)
	            Set hora = $Piece(result.Daily,"||",2)
	            Set metrica = result.Metrica
	            Set licenca = result.LicUsedLocal

				;Skipping Standard Deviation, just keeping Average and Maximum Values 
	            Continue:(metrica="StDev")

	            Set obj = $Get(^["IRISMONITOR"]IRISMonitor("Daily","DataTable",data,hora))
	            Set $Piece(obj,"^",1) = $ZDate(data,4)
	            Set $Piece(obj,"^",2) = $ZTime(hora,2)
	            If (metrica="Avg") {
		            Set $Piece(obj,"^",3) = licenca
	            }
                Else {
		            Set $Piece(obj,"^",4) = licenca
	            }

	            Set ^["IRISMONITOR"]IRISMonitor("Daily","DataTable",data,hora) = obj
            }

        }
        Else {
            Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }

        Set $Namespace = "IRISMONITOR"

        Set arrDailyDataTable = []

		Set dia = ""
		For {
			Set dia = $Order(^IRISMonitor("Daily","DataTable",dia))
			Quit:dia=""

			Set horario = ""
			For {
				Set horario = $Order(^IRISMonitor("Daily","DataTable",dia,horario))
				Quit:horario=""

				Set oDaily = $Get(^IRISMonitor("Daily","DataTable",dia,horario))

				Set json = { } 
				Do json.%Set("date",$Piece(oDaily,"^",1))
				Do json.%Set("time",$Piece(oDaily,"^",2))
				Do json.%Set("avg",$Normalize($Piece(oDaily,"^",3),2))
				Do json.%Set("max",$Normalize($Piece(oDaily,"^",4),2))
				Do arrDailyDataTable.%Push(json)	
			}

		}

    }
    Catch (oException) {
        Set tSC = oException.AsStatus()
    }

    Write arrDailyDataTable.%ToJSON() 

    Quit tSC
}

/// do ##class(diashenrique.historymonitor.dashboard.license).DateTimeToISO8601("2019-03-22 08:58:06")
ClassMethod DateTimeToISO8601(pDateTime As %DateTime) As %String
{
	Quit:(pDateTime="") ""

	Set ret = $Case(pDateTime,"":"",:$Replace(pDateTime," ","T")_"Z")

	Quit ret
}

}
