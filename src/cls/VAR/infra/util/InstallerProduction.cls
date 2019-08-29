Class  VAR.infra.util.InstallerProduction [ Abstract ]
{

/// Namespace 
Parameter NAMESPACE = "MSGVIEWER";

/// Production name
Parameter PRODUCTION = "Demo.IRIS.Production";

/// Number of messages to be generated per service
Parameter LIMIT = 1000;

/// Helper to install a new namespace and production to display capabilities of the enhanced viewer
ClassMethod Install() As %Status
{
	SET sc = $$$OK
	TRY {
		SET sc = $$$ADDSC(sc,..InstallProduction()) quit:$$$ISERR(sc)
		SET sc = $$$ADDSC(sc,..GenerateMessages()) quit:$$$ISERR(sc)
	} CATCH (err) {
		SET sc = $$$ADDSC(sc,err.AsStatus())
	}
	RETURN sc
}

/// Helper to install a production
ClassMethod InstallProduction() As %Status [ Private ]
{
	SET sc = $$$OK
	TRY {
		SET sc = $$$ADDSC(sc,..CreateRequest("Demo.Message.SimpleRequest","Message")) quit:$$$ISERR(sc)
		SET sc = $$$ADDSC(sc,..CreateRequest("Demo.Message.AnotherRequest","Something")) quit:$$$ISERR(sc)
		SET sc = $$$ADDSC(sc,..CreateOperation()) quit:$$$ISERR(sc)
		SET sc = $$$ADDSC(sc,..CreateRESTService()) quit:$$$ISERR(sc)
		SET sc = $$$ADDSC(sc,..CreateProduction()) quit:$$$ISERR(sc)
		NEW $namespace
		SET $namespace = ..#NAMESPACE
		SET sc = $$$ADDSC(sc,##class(Ens.Director).StartProduction(..#PRODUCTION))
	} CATCH (err) {
		SET sc = $$$ADDSC(sc,err.AsStatus())
	}
	RETURN sc
}

/// Create new Ensemble production
ClassMethod CreateProduction(purge As %Boolean = 0) As %Status [ Private ]
{
	NEW $namespace
	SET $namespace = ..#NAMESPACE
	SET sc = $$$OK
	TRY {
		
		#; create new production
		SET class = ##class(%Dictionary.ClassDefinition).%New(..#PRODUCTION)
		SET class.ProcedureBlock = 1
		SET class.Super = "Ens.Production"
		SET class.GeneratedBy = $classname()
		SET xdata = ##class(%Dictionary.XDataDefinition).%New()
		SET xdata.Name = "ProductionDefinition"
		DO xdata.Data.Write("<Production Name="""_..#PRODUCTION_""" LogGeneralTraceEvents=""true""></Production>")	
		DO class.XDatas.Insert(xdata)
		SET sc = $$$ADDSC(sc,class.%Save())
		SET sc = $$$ADDSC(sc,$system.OBJ.Compile(..#PRODUCTION,"fck-dv"))
		
		SET production = ##class(Ens.Config.Production).%OpenId(..#PRODUCTION)
		SET item = ##class(Ens.Config.Item).%New()
		SET item.ClassName = "Demo.Service.REST"
		DO production.Items.Insert(item)
		SET sc = $$$ADDSC(sc,production.%Save())
		
		SET item = ##class(Ens.Config.Item).%New()
		SET item.ClassName = "Demo.Operation.Consumer"
		DO production.Items.Insert(item)
		SET sc = $$$ADDSC(sc,production.%Save())	
	} CATCH (err) {
		SET sc = $$$ADDSC(sc,err.AsStatus())
	}
	RETURN sc
}

/// Create a dummy REST service to populate messages
ClassMethod CreateRequest(classname As %String, prop As %String) As %Status [ Private ]
{
	NEW $namespace
	SET $namespace = ..#NAMESPACE
	SET sc = $$$OK
	TRY {
		SET class = ##class(%Dictionary.ClassDefinition).%New(classname)
		SET class.GeneratedBy = $classname()
		SET class.Super = "Ens.Request"
		SET class.ProcedureBlock = 1
		SET class.Inheritance = "left"
		SET sc = $$$ADDSC(sc,class.%Save())
		
		#; create adapter
		SET property = ##class(%Dictionary.PropertyDefinition).%New(classname)
		SET property.Name = prop
		SET property.Type = "%String"
		SET sc = $$$ADDSC(sc,property.%Save())
		SET sc = $$$ADDSC(sc,$system.OBJ.Compile(classname,"fck-dv"))
	} CATCH (err) {
		SET sc = $$$ADDSC(sc,err.AsStatus())
	}
	RETURN sc
}

/// Create a dummy operation to populate messages
ClassMethod CreateOperation() As %Status [ Private ]
{
	NEW $namespace
	SET $namespace = ..#NAMESPACE
	SET sc = $$$OK
	TRY {
		SET classname = "Demo.Operation.Consumer"
		SET class = ##class(%Dictionary.ClassDefinition).%New(classname)
		SET class.GeneratedBy = $classname()
		SET class.Super = "Ens.BusinessOperation"
		SET class.ProcedureBlock = 1
		SET class.Inheritance = "left"
		
		SET xdata = ##class(%Dictionary.XDataDefinition).%New()
		SET xdata.Name = "MessageMap"
		SET xdata.XMLNamespace = "http://www.intersystems.com/urlmap"
		DO xdata.Data.WriteLine("<MapItems>")
		DO xdata.Data.WriteLine("<MapItem MessageType=""Demo.Message.SimpleRequest"">")
		DO xdata.Data.WriteLine("<Method>Consume</Method>")
		DO xdata.Data.WriteLine("</MapItem>")
		DO xdata.Data.WriteLine("<MapItem MessageType=""Demo.Message.AnotherRequest"">")
		DO xdata.Data.WriteLine("<Method>Consume</Method>")
		DO xdata.Data.WriteLine("</MapItem>")
		DO xdata.Data.WriteLine("</MapItems>")		
		DO class.XDatas.Insert(xdata)
		SET sc = $$$ADDSC(sc,class.%Save())
		
		SET method = ##class(%Dictionary.MethodDefinition).%New(classname)
		SET method.Name = "Consume"
		SET method.ClassMethod = 0
		SET method.ReturnType = "%Status"
		SET method.FormalSpec = "input:Demo.Message.SimpleRequest,&output:Ens.Response"
		SET stream = ##class(%Stream.TmpCharacter).%New()
		DO stream.WriteLine("	set sc = $$$OK")
		DO stream.WriteLine("	$$$TRACE(input.Message)")
		DO stream.WriteLine("	return sc")
		SET method.Implementation = stream
		SET sc = $$$ADDSC(sc,method.%Save())
		
		SET sc = $$$ADDSC(sc,$system.OBJ.Compile(classname,"fck-dv"))
	} CATCH (err) {
		SET sc = $$$ADDSC(sc,err.AsStatus())
	}
	RETURN sc
}

/// Create a dummy REST service to populate messages
ClassMethod CreateRESTService() As %Status [ Private ]
{
	NEW $namespace
	SET $namespace = ..#NAMESPACE
	SET sc = $$$OK
	TRY {
		SET classname = "Demo.Service.REST"
		SET class = ##class(%Dictionary.ClassDefinition).%New(classname)
		SET class.GeneratedBy = $classname()
		SET class.Super = "EnsLib.REST.Service, Ens.BusinessService"
		SET class.ProcedureBlock = 1
		SET class.Inheritance = "left"
		
		SET xdata = ##class(%Dictionary.XDataDefinition).%New()
		SET xdata.Name = "UrlMap"
		SET xdata.XMLNamespace = "http://www.intersystems.com/urlmap"
		DO xdata.Data.WriteLine("<Routes>")
		DO xdata.Data.WriteLine("<Route Url=""/send/message"" Method=""POST"" Call=""SendMessage""/>")
		DO xdata.Data.WriteLine("<Route Url=""/send/something"" Method=""POST"" Call=""SendSomething""/>")
		DO xdata.Data.WriteLine("</Routes>")
		DO class.XDatas.Insert(xdata)
		SET sc = $$$ADDSC(sc,class.%Save())
		
		#; create adapter
		SET adapter = ##class(%Dictionary.ParameterDefinition).%New(classname)
		SET class.GeneratedBy = $classname()
		SET adapter.Name = "ADAPTER"
		SET adapter.SequenceNumber = 1
		SET adapter.Default = "EnsLib.HTTP.InboundAdapter"
		SET sc = $$$ADDSC(sc,adapter.%Save())
		
		#; add prefix
		SET prefix = ##class(%Dictionary.ParameterDefinition).%New(classname)
		SET prefix.Name = "EnsServicePrefix"
		SET prefix.SequenceNumber = 2
		SET prefix.Default = "|demoiris"
		SET sc = $$$ADDSC(sc,prefix.%Save())
		
		SET method = ##class(%Dictionary.MethodDefinition).%New(classname)
		SET method.Name = "SendMessage"
		SET method.ClassMethod = 0
		SET method.ReturnType = "%Status"
		SET method.FormalSpec = "input:%Library.AbstractStream,&output:%Stream.Object"
		SET stream = ##class(%Stream.TmpCharacter).%New()
		DO stream.WriteLine("	set sc = $$$OK")
		DO stream.WriteLine("	set request = ##class(Demo.Message.SimpleRequest).%New()")
		DO stream.WriteLine("	set data = {}.%FromJSON(input)")
		DO stream.WriteLine("	set request.Message = data.Message")
		DO stream.WriteLine("	set sc = $$$ADDSC(sc,..SendRequestSync(""Demo.Operation.Consumer"",request,.response))")
		DO stream.WriteLine("	return sc")
		SET method.Implementation = stream
		SET sc = $$$ADDSC(sc,method.%Save())
		
		SET method = ##class(%Dictionary.MethodDefinition).%New(classname)
		SET method.Name = "SendSomething"
		SET method.ClassMethod = 0
		SET method.ReturnType = "%Status"
		SET method.FormalSpec = "input:%Library.AbstractStream,&output:%Stream.Object"
		SET stream = ##class(%Stream.TmpCharacter).%New()
		DO stream.WriteLine("	set sc = $$$OK")
		DO stream.WriteLine("	set request = ##class(Demo.Message.AnotherRequest).%New()")
		DO stream.WriteLine("	set data = {}.%FromJSON(input)")
		DO stream.WriteLine("	set request.Something = data.Something")
		DO stream.WriteLine("	set sc = $$$ADDSC(sc,..SendRequestSync(""Demo.Operation.Consumer"",request,.response))")
		DO stream.WriteLine("	return sc")
		SET method.Implementation = stream
		SET sc = $$$ADDSC(sc,method.%Save())
		
		SET sc = $$$ADDSC(sc,$system.OBJ.Compile(classname,"fck-dv"))
	} CATCH (err) {
		SET sc = $$$ADDSC(sc,err.AsStatus())
	}
	RETURN sc
}

/// Generates load of messages
ClassMethod GenerateMessages() As %Status [ Private ]
{
	NEW $namespace
	SET $namespace = ..#NAMESPACE
	SET sc = $$$OK
	TRY {
		SET action(0) = "/demoiris/send/message"
		SET action(1) = "/demoiris/send/something"
		FOR i=1:1:..#LIMIT {
			SET content = {}
			SET content.Message = "Hi, I'm just a random message named "_$random(30000)
			SET content.Something = "Hi, I'm just a random something named "_$random(30000)
			SET httprequest = ##class(%Net.HttpRequest).%New()
		    SET httprequest.SSLCheckServerIdentity = 0
		    SET httprequest.SSLConfiguration = ""
		    SET httprequest.Https = 0
		    SET httprequest.Server = "localhost"
		    SET httprequest.Port = 9980
			SET serverUrl = action($random(2))
			DO httprequest.EntityBody.Write(content.%ToJSON())
			SET sc = httprequest.Post(serverUrl) 
			QUIT:$$$ISERR(sc)
		}
	} CATCH (err) {
		SET sc = $$$ADDSC(sc,err.AsStatus())
	}
	RETURN sc
}

}
