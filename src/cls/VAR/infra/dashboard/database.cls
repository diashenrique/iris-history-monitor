Class VAR.infra.dashboard.database Extends %CSP.Page
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

/// do ##class(VAR.infra.dashboard.database).getDatabaseDailySize()
ClassMethod getDatabaseDailySize() As %Status
{
	KILL ^IRISMonitor("Database","Daily")
	 
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
        
		SET sql = "SELECT Daily, element_key as Metrica, DB_FileSize as FileSize FROM SYS_History.Daily_DB WHERE Daily->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        SET tSC = oRS.%Prepare(sql)
        
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        
            WHILE result.%Next() {
	            
	            IF ($piece(result.Metrica,"_",2) '= "Max") {
		         	CONTINUE   
	            }
	            
	            SET dbBlacklist = $listbuild("CACHE","CACHEAUDIT","CACHELIB","CACHESYS","CACHETEMP","DOCBOOK","ENSDEMO","ENSEMBLE","ENSLIB","ENSEMBLEENSTEMP","ENSEMBLESECONDARY","SAMPLES","USER")
				
				IF ($listfind(dbBlacklist,$piece(result.Metrica,"_",1)) > 0){
					CONTINUE
				}
				
	            SET data = $piece(result.Daily,"||",1)
				SET hora = $piece(result.Daily,"||",2)
				SET datetimeUTC = $SYSTEM.SQL.DATEDIFF("s","1970-01-01 00:00:00",$zdatetime(data_","_hora,3)) * 1000
				SET dbName 	  = $piece(result.Metrica,"_",1)
				SET dbMetrica = $piece(result.Metrica,"_",2)
				SET dbSize = result.FileSize  / 1024	;Convert from Mb to Gigabyte
			
				SET ^["IRISMONITOR"]IRISMonitor("Database","Daily",dbName,dbMetrica,data,hora) = datetimeUTC_"^"_dbSize
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
        
        SET $namespace = "IRISMONITOR"
		
		SET arrDBDia = []
		
		// Database
		SET idDBName = ""
		FOR {
			SET idDBName=$order(^IRISMonitor("Database","Daily",idDBName))
			QUIT:idDBName=""
			
			// Métrica (Max, Avg, StDev)
			SET idMetrica = ""
			FOR {
				SET idMetrica=$order(^IRISMonitor("Database","Daily",idDBName,idMetrica))
				QUIT:idMetrica=""

				SET arrMetrica = [] 
				// Data 
				SET dtData = ""
				FOR {
					SET dtData=$order(^IRISMonitor("Database","Daily",idDBName,idMetrica, dtData))
					QUIT:dtData=""

					// Horario 
					SET inthora = ""
					FOR {
						SET inthora=$order(^IRISMonitor("Database","Daily",idDBName,idMetrica, dtData,inthora))
						QUIT:inthora=""

						SET arrDados = []

						SET obj = $get(^IRISMonitor("Database","Daily",idDBName,idMetrica,dtData,inthora))

						SET arrDados."0" = $number($piece(obj,"^",1))		;DateTime UTC Format 
						SET arrDados."1" = $normalize($piece(obj,"^",2),2)	;Database File Size

						DO arrMetrica.%Push(arrDados)
					}
				}
			}
			SET json = {}
			DO json.%Set("name",idDBName)
			DO json.%Set("data",arrMetrica)
			DO json.%Set("lineWidth",$normalize("0.5",1))
			DO arrDBDia.%Push(json)
		}
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrDBDia.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.database).getDatabaseDailySizeDataGrid()
ClassMethod getDatabaseDailySizeDataGrid() As %Status
{
	KILL ^IRISMonitor("Database","DailyDataGrid")
	 
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
        
        SET sql = "SELECT Daily, element_key as Metrica, DB_FileSize as FileSize FROM SYS_History.Daily_DB WHERE Daily->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        SET tSC = oRS.%Prepare(sql)
        
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        
            WHILE result.%Next() {
	            
	            IF ($piece(result.Metrica,"_",2) '= "Max") {
		         	CONTINUE   
	            }
	            
	            SET dbBlacklist = $listbuild("IRISSYS","IRISLIB","IRISTEMP","IRISAUDIT","ENSLIB")
				
				IF ($listfind(dbBlacklist,$piece(result.Metrica,"_",1)) > 0){
					CONTINUE
				}
				
	            SET data = $piece(result.Daily,"||",1)
				SET hora = $piece(result.Daily,"||",2)
				SET dbName = $piece(result.Metrica,"_",1)
				SET dbSize = result.FileSize  / 1024 	;Convert from Mb to Gigabyte
			
				SET obj = $get(^["IRISMONITOR"]IRISMonitor("Database","DailyDataGrid",dbName,data,hora))
	            SET $piece(obj,"^",1) = $zdate(data,4)
	            SET $piece(obj,"^",2) = $ztime(hora,2)
	            SET $piece(obj,"^",3) = dbSize
	            	            
	            SET ^["IRISMONITOR"]IRISMonitor("Database","DailyDataGrid",dbName,data,hora) = obj
	            
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
        
        SET $namespace = "IRISMONITOR"
		
		SET arrDBDiaDataGrid = []
		
		// Database
		SET idDBName = ""
		FOR {
			SET idDBName=$order(^IRISMonitor("Database","DailyDataGrid",idDBName))
			QUIT:idDBName=""
			
			// Data 
			SET dtData = ""
			FOR {
				SET dtData=$order(^IRISMonitor("Database","DailyDataGrid",idDBName, dtData))
				QUIT:dtData=""

				// Horario 
				SET inthora = ""
				FOR {
					SET inthora=$order(^IRISMonitor("Database","DailyDataGrid",idDBName, dtData,inthora))
					QUIT:inthora=""

					SET oDBDay = $get(^IRISMonitor("Database","DailyDataGrid",idDBName, dtData,inthora))

					SET json = {} 
					DO json.%Set("dbName",idDBName)
					DO json.%Set("date",$piece(oDBDay,"^",1))
					DO json.%Set("time",$piece(oDBDay,"^",2))
					DO json.%Set("sizeGb",$normalize($piece(oDBDay,"^",3),2))
					DO arrDBDiaDataGrid.%Push(json)	
				}
			}
		}
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrDBDiaDataGrid.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.license).DateTimeToISO8601("2019-03-22 08:58:06")
ClassMethod DateTimeToISO8601(pDateTime As %DateTime) As %String
{
	QUIT:(pDateTime="") ""
	
	SET ret = $case(pDateTime,"":"",:$replace(pDateTime," ","T")_"Z")
	
	QUIT ret
}

/// do ##class(VAR.infra.dashboard.database).GetDatabases()
ClassMethod GetDatabasesList()
{
	NEW $namespace
	SET $namespace = "%SYS"
	
	SET statement=##class(%SQL.Statement).%New()   
	SET status=statement.%PrepareClassQuery("Config.Databases","List")   
	
	IF $$$ISERR(status) {
		DO $system.OBJ.DisplayError(status) 
	}   
	
	SET resultset=statement.%Execute()
	
	WHILE resultset.%Next() {
	    WRITE resultset.%Get("Name")_" - "_resultset.%Get("Directory"),!
	}
	
	QUIT
}

}
