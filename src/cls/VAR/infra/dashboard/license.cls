Class VAR.infra.dashboard.license Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

ClassMethod OnPage() As %Status
{
	#dim %request As %CSP.Request
	#dim %response As %CSP.Response
	
	SET Method 	= $Get(%request.Data("method",1))

	XECUTE "do .."_Method_"()"
	
	QUIT $$$OK
}

/// do ##class(VAR.infra.dashboard.license).getLicenseLiveHistory()
ClassMethod getLicenseLiveHistory() As %Status
{
    SET (dtFrom,dtTo)=""
    
    SET dtFrom = $get(%request.Data("fiveMinFrom",1))
    SET dtTo   = $get(%request.Data("fiveMinTo",1))
    
    IF (dtTo = "") {
	    SET dtTo = +$horolog
    } ELSE {
	 	SET dtTo = $zdateh(dtTo,4)
    }
    
    IF (dtFrom = "") {
    	SET dtFrom = dtTo - 6
    } ELSE {
	    SET dtFrom = $zdateh(dtFrom,4)
    }
    
    NEW $namespace
	SET $namespace = "%SYS"

	SET tSC = $System.Status.OK()
    SET arrayLicenseLive = []

    TRY {
	    
	    SET sql = "SELECT top 1000 DateTime, Sys_LicUsedLocal as LicUsedLocal FROM SYS_History.SysData WHERE ZDATE BETWEEN "_dtFrom_" AND "_dtTo
	
	    SET oRS = ##class(%SQL.Statement).%New()
        
        SET tSC = oRS.%Prepare(sql)
       
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        WHILE result.%Next() {
	            SET arrayDados = [] 
				SET arrayDados."0" = ..DateTimeToISO8601(result.DateTime)
				SET arrayDados."1" = result.LicUsedLocal
				DO arrayLicenseLive.%Push(arrayDados)
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrayLicenseLive.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.license).getLicenseEveryFiveMinutesDataTable()
ClassMethod getLicenseEveryFiveMinutesDataTable() As %Status
{
    SET (dtFrom,dtTo)=""
    
    SET dtFrom = $get(%request.Data("fiveFrom",1))
    SET dtTo   = $get(%request.Data("fiveTo",1))
    
    IF (dtTo = "") {
	    SET dtTo = +$horolog
    } ELSE {
	 	SET dtTo = $zdateh(dtTo,4)
    }
    
    IF (dtFrom = "") {
    	SET dtFrom = dtTo - 6
    } ELSE {
	    SET dtFrom = $zdateh(dtFrom,4)
    }
    
    NEW $namespace
	SET $namespace = "%SYS"

	SET tSC = $System.Status.OK()
    SET arrayFiveMin = []

    TRY {
	    
	    SET sql = "SELECT top 1000 DateTime, Sys_LicUsedLocal as LicUsedLocal FROM SYS_History.SysData WHERE ZDATE BETWEEN "_dtFrom_" AND "_dtTo
	
	    SET oRS = ##class(%SQL.Statement).%New()
        
        SET tSC = oRS.%Prepare(sql)
       
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        WHILE result.%Next() {
	            SET json = {} 
	            SET dia  = $piece(result.DateTime," ",1)
	            SET hora = $piece(result.DateTime," ",2)
				DO json.%Set("date",$zdate($zdateh(dia,3),4))
				DO json.%Set("time",hora)
				DO json.%Set("licQty",result.LicUsedLocal)
				DO arrayFiveMin.%Push(json)
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrayFiveMin.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.license).getLicenseHourlyHistory()
ClassMethod getLicenseHourlyHistory() As %Status
{
	KILL ^IRISMonitor("License","Hourly")
	
	SET (dtFrom,dtTo)=""
    
    SET dtFrom = $get(%request.Data("hourFrom",1))
    SET dtTo   = $get(%request.Data("hourTo",1))
    
    IF (dtTo = "") {
	    SET dtTo = +$horolog
    } ELSE {
	 	SET dtTo = $zdateh(dtTo,4)
    }
    
    IF (dtFrom = "") {
    	SET dtFrom = dtTo - 6
    } ELSE {
	    SET dtFrom = $zdateh(dtFrom,4)
    }	
	
	NEW $namespace
	SET $namespace = "%SYS"
	
    SET tSC = $System.Status.OK()

    TRY {
	    SET oRS = ##class(%SQL.Statement).%New()
        
        SET sql = "SELECT Hourly, element_key as Metrica, Sys_LicUsedLocal as LicUsedLocal FROM SYS_History.Hourly_Sys WHERE Hourly->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        SET tSC = oRS.%Prepare(sql)
        
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        
            WHILE result.%Next() {
	            SET data = $piece(result.Hourly,"||",1)
	            SET hora = $piece(result.Hourly,"||",2)
	            SET metrica = result.Metrica
	            SET licenca = result.LicUsedLocal
				
				;Skipping Standard Deviation, just keeping Average and Maximum Values 
	            CONTINUE:(metrica="StDev")
	            
	            SET datetimeUTC = $SYSTEM.SQL.DATEDIFF("s","1970-01-01 00:00:00",$zdatetime(data_","_hora,3)) * 1000
	            
	            SET ^["IRISMONITOR"]IRISMonitor("License","Hourly",metrica,data,hora) = datetimeUTC_"^"_licenca
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
        
        SET $namespace = "IRISMONITOR"
        SET arrHourly = []

        // Métrica (Max, Avg, StDev)
		SET idMetrica = ""
		FOR {
			SET idMetrica=$order(^IRISMonitor("License","Hourly",idMetrica))
			QUIT:idMetrica=""
			
			SET arrMetrica = [] 
			
			// Data  
			SET dtData = ""
			FOR {
				SET dtData=$order(^IRISMonitor("License","Hourly",idMetrica,dtData))
				QUIT:dtData=""

				// Horario 
				SET inthora = ""
				FOR {
					SET inthora=$order(^IRISMonitor("License","Hourly",idMetrica,dtData,inthora))
					QUIT:inthora=""
					
					SET arrDados = []
					
					SET obj = $get(^IRISMonitor("License","Hourly",idMetrica,dtData,inthora))
					
					SET arrDados."0" = $number($piece(obj,"^",1))		;DateTime UTC Format 
					SET arrDados."1" = $normalize($piece(obj,"^",2),2)	;License Qty
					
					DO arrMetrica.%Push(arrDados)
				}
				
			}
			
			SET json = {}, jsonMarker ={}, jsonfillColor = {}, jsonlinearGradient = {}, arrStops = [], arrAllStops = []

			SET colorCode = $select(idMetrica="Max":"#107595",idMetrica="Avg":"#fcf594",1:"#f2efb6")
			
			DO json.%Set("name",idMetrica)
			DO json.%Set("data",arrMetrica)
			DO json.%Set("color",colorCode)
			DO json.%Set("lineColor",colorCode)
			
			DO jsonMarker.%Set("enabled",0)
			DO jsonMarker.%Set("symbol","circle")
			DO jsonMarker.%Set("radius",2)
			DO jsonMarker.%Set("lineWidth",1)
			DO jsonMarker.%Set("lineColor",colorCode)
			DO jsonMarker.%Set("fillColor","#ffffff") 
			DO json.%Set("marker",jsonMarker)
			
			DO jsonlinearGradient.%Set("x1",0)
			DO jsonlinearGradient.%Set("x2",0)
			DO jsonlinearGradient.%Set("y1",0)
			DO jsonlinearGradient.%Set("y2",1)
			
			SET arrStops=[].%Push(0).%Push(colorCode)
            DO arrAllStops.%Push(arrStops)
            SET arrStops=[].%Push(1).%Push("#ffffff")
            DO arrAllStops.%Push(arrStops)
			
			DO jsonfillColor.%Set("linearGradient",jsonlinearGradient)
			DO jsonfillColor.%Set("stops",arrAllStops)
			DO json.%Set("fillColor",jsonfillColor)
			
			DO arrHourly.%Push(json)
		}
        
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrHourly.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.license).getLicenseHourlyDataTable()
ClassMethod getLicenseHourlyDataTable() As %Status
{
	KILL ^IRISMonitor("Hourly","DataTable")
	
	SET (dtFrom,dtTo, obj)=""
    
    SET dtFrom = $get(%request.Data("hourFrom",1))
    SET dtTo   = $get(%request.Data("hourTo",1))
    
    IF (dtTo = "") {
	    SET dtTo = +$horolog
    } ELSE {
	 	SET dtTo = $zdateh(dtTo,4)
    }
    
    IF (dtFrom = "") {
    	SET dtFrom = dtTo - 6
    } ELSE {
	    SET dtFrom = $zdateh(dtFrom,4)
    }
	
	NEW $namespace
	SET $namespace = "%SYS"
	
    SET tSC = $System.Status.OK()

    TRY {
	    SET oRS = ##class(%SQL.Statement).%New()
        
        SET sql = "SELECT Hourly, element_key as Metrica, Sys_LicUsedLocal as LicUsedLocal FROM SYS_History.Hourly_Sys WHERE Hourly->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        SET tSC = oRS.%Prepare(sql)
        
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        
            WHILE result.%Next() {
	            SET data = $piece(result.Hourly,"||",1)
	            SET hora = $piece(result.Hourly,"||",2)
	            SET metrica = result.Metrica
	            SET licenca = result.LicUsedLocal
				
				;Skipping Standard Deviation, just keeping Average and Maximum Values 
	            CONTINUE:(metrica="StDev")
	            
	            SET obj = $get(^["IRISMONITOR"]IRISMonitor("Hourly","DataTable",data,hora))
	            SET $piece(obj,"^",1) = $zdate(data,4)
	            SET $piece(obj,"^",2) = $ztime(hora,2)
	            IF (metrica="Avg") {
		            SET $piece(obj,"^",3) = licenca
	            } ELSE {
		            SET $piece(obj,"^",4) = licenca
	            }
	            	            
	            SET ^["IRISMONITOR"]IRISMonitor("Hourly","DataTable",data,hora) = obj
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
        
        SET $namespace = "IRISMONITOR"
        
        SET arrHourlyDataTable = []

		SET dia = ""
		FOR {
			SET dia=$order(^IRISMonitor("Hourly","DataTable",dia))
			QUIT:dia=""
			
			SET horario = ""
			FOR {
				SET horario=$order(^IRISMonitor("Hourly","DataTable",dia,horario))
				QUIT:horario=""
				
				SET oHourly = $get(^IRISMonitor("Hourly","DataTable",dia,horario))

				SET json = {} 
				DO json.%Set("date",$piece(oHourly,"^",1))
				DO json.%Set("time",$piece(oHourly,"^",2))
				DO json.%Set("avg",$normalize($piece(oHourly,"^",3),2))
				DO json.%Set("max",$normalize($piece(oHourly,"^",4),2))
				DO arrHourlyDataTable.%Push(json)	
			}
			
		}
        
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrHourlyDataTable.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.license).getLicenseDailyHistory()
ClassMethod getLicenseDailyHistory() As %Status
{
	KILL ^IRISMonitor("Daily")	
	
	SET (dtFrom,dtTo)=""
    
    SET dtFrom = $get(%request.Data("dayFrom",1))
    SET dtTo   = $get(%request.Data("dayTo",1))
    
    IF (dtTo = "") {
	    SET dtTo = +$horolog
    } ELSE {
	 	SET dtTo = $zdateh(dtTo,4)
    }
    
    IF (dtFrom = "") {
    	SET dtFrom = dtTo - 6
    } ELSE {
	    SET dtFrom = $zdateh(dtFrom,4)
    }	
	
	NEW $namespace
	SET $namespace = "%SYS"
	
    SET tSC = $System.Status.OK()

    TRY {
	    SET oRS = ##class(%SQL.Statement).%New()
        
        SET sql = "SELECT Daily, element_key as Metrica, Sys_LicUsedLocal as LicUsedLocal FROM SYS_History.Daily_Sys WHERE Daily->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        SET tSC = oRS.%Prepare(sql)
        
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        
            WHILE result.%Next() {
	            SET data = $piece(result.Daily,"||",1)
	            SET hora = $piece(result.Daily,"||",2)
	            SET metrica = result.Metrica
	            SET licenca = result.LicUsedLocal
				
				;Skipping Standard Deviation, just keeping Average and Maximum Values 
	            CONTINUE:(metrica="StDev")
	            
	            SET datetimeUTC = $SYSTEM.SQL.DATEDIFF("s","1970-01-01 00:00:00",$zdatetime(data_","_hora,3)) * 1000
	            
	            SET ^["IRISMONITOR"]IRISMonitor("Daily",metrica,data,hora) = datetimeUTC_"^"_licenca
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
        
        SET $namespace = "IRISMONITOR"
        SET arrDaily = []

        // Métrica (Max, Avg, StDev)
		SET idMetrica = ""
		FOR {
			SET idMetrica=$order(^IRISMonitor("Daily",idMetrica))
			QUIT:idMetrica=""
			
			SET arrMetrica = [] 
			
			// Data  
			SET dtData = ""
			FOR {
				SET dtData=$order(^IRISMonitor("Daily",idMetrica,dtData))
				QUIT:dtData=""

				// Horario 
				SET inthora = ""
				FOR {
					SET inthora=$order(^IRISMonitor("Daily",idMetrica,dtData,inthora))
					QUIT:inthora=""
					
					SET arrDados = []
					
					SET obj = $get(^IRISMonitor("Daily",idMetrica,dtData,inthora))
					
					SET arrDados."0" = $number($piece(obj,"^",1))		;DateTime UTC Format 
					SET arrDados."1" = $normalize($piece(obj,"^",2),2)	;Nº Licença
					
					DO arrMetrica.%Push(arrDados)
				}
				
			}
			
			SET json = {}, jsonMarker ={}, jsonfillColor = {}, jsonlinearGradient = {}, arrStops = [], arrAllStops = []

			SET colorCode = $select(idMetrica="Max":"#22b2da",idMetrica="Avg":"#f0d43a",1:"#f2efb6")
			
			DO json.%Set("name",idMetrica)
			DO json.%Set("data",arrMetrica)
			DO json.%Set("color",colorCode)
			DO json.%Set("lineColor",colorCode)
			
			DO jsonMarker.%Set("enabled",0)
			DO jsonMarker.%Set("symbol","circle")
			DO jsonMarker.%Set("radius",2)
			DO jsonMarker.%Set("lineWidth",1)
			DO jsonMarker.%Set("lineColor",colorCode)
			DO jsonMarker.%Set("fillColor","#ffffff") 
			DO json.%Set("marker",jsonMarker)
			
			DO jsonlinearGradient.%Set("x1",0)
			DO jsonlinearGradient.%Set("x2",0)
			DO jsonlinearGradient.%Set("y1",0)
			DO jsonlinearGradient.%Set("y2",1)
			
			SET arrStops=[].%Push(0).%Push(colorCode)
            DO arrAllStops.%Push(arrStops)
            SET arrStops=[].%Push(1).%Push("#ffffff")
            DO arrAllStops.%Push(arrStops)
			
			DO jsonfillColor.%Set("linearGradient",jsonlinearGradient)
			DO jsonfillColor.%Set("stops",arrAllStops)
			DO json.%Set("fillColor",jsonfillColor)
			
			DO arrDaily.%Push(json)
		}
        
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrDaily.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.license).getLicenseDailyDataTable()
ClassMethod getLicenseDailyDataTable() As %Status
{
	KILL IRISMonitor("Daily","DataTable")
	
	SET (dtFrom,dtTo)=""
    
    SET dtFrom = $get(%request.Data("dayFrom",1))
    SET dtTo   = $get(%request.Data("dayTo",1))
    
    IF (dtTo = "") {
	    SET dtTo = +$horolog
    } ELSE {
	 	SET dtTo = $zdateh(dtTo,4)
    }
    
    IF (dtFrom = "") {
    	SET dtFrom = dtTo - 6
    } ELSE {
	    SET dtFrom = $zdateh(dtFrom,4)
    }
	
	NEW $namespace
	SET $namespace = "%SYS"
	
    SET tSC = $System.Status.OK()

    TRY {
	    SET oRS = ##class(%SQL.Statement).%New()
        
        SET sql = "SELECT Daily, element_key as Metrica, Sys_LicUsedLocal as LicUsedLocal FROM SYS_History.Daily_Sys WHERE Daily->ZDATE BETWEEN "_dtFrom_" AND "_dtTo
        
        SET tSC = oRS.%Prepare(sql)
        
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        
            WHILE result.%Next() {
	            SET data = $piece(result.Daily,"||",1)
	            SET hora = $piece(result.Daily,"||",2)
	            SET metrica = result.Metrica
	            SET licenca = result.LicUsedLocal
				
				;Skipping Standard Deviation, just keeping Average and Maximum Values 
	            CONTINUE:(metrica="StDev")
	            
	            SET obj = $get(^["IRISMONITOR"]IRISMonitor("Daily","DataTable",data,hora))
	            SET $piece(obj,"^",1) = $zdate(data,4)
	            SET $piece(obj,"^",2) = $ztime(hora,2)
	            IF (metrica="Avg") {
		            SET $piece(obj,"^",3) = licenca
	            } ELSE {
		            SET $piece(obj,"^",4) = licenca
	            }
	            	            
	            SET ^["IRISMONITOR"]IRISMonitor("Daily","DataTable",data,hora) = obj
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
        
        SET $namespace = "IRISMONITOR"
        
        SET arrDailyDataTable = []

		SET dia = ""
		FOR {
			SET dia=$order(^IRISMonitor("Daily","DataTable",dia))
			QUIT:dia=""
			
			SET horario = ""
			FOR {
				SET horario=$order(^IRISMonitor("Daily","DataTable",dia,horario))
				QUIT:horario=""
				
				SET oDaily = $get(^IRISMonitor("Daily","DataTable",dia,horario))

				SET json = {} 
				DO json.%Set("date",$piece(oDaily,"^",1))
				DO json.%Set("time",$piece(oDaily,"^",2))
				DO json.%Set("avg",$normalize($piece(oDaily,"^",3),2))
				DO json.%Set("max",$normalize($piece(oDaily,"^",4),2))
				DO arrDailyDataTable.%Push(json)	
			}
			
		}
        
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrDailyDataTable.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.license).DateTimeToISO8601("2019-03-22 08:58:06")
ClassMethod DateTimeToISO8601(pDateTime As %DateTime) As %String
{
	QUIT:(pDateTime="") ""
	
	SET ret = $case(pDateTime,"":"",:$replace(pDateTime," ","T")_"Z")
	
	QUIT ret
}

}
