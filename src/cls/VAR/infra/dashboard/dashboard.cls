Class VAR.infra.dashboard.dashboard Extends %CSP.Page
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

ClassMethod getMetrics() As %Status
{
	
	DO ..getDashboardSample(.dashboard)
	DO ..getClassProperties(dashboard.%ClassName(1), .propList, .descrList)
	
	SET arrayMetrics = []
	SET jsonMetrics  = {}
	
	FOR i=1:1:$listlength(propList) {
		SET descr = $listget(descrList,i)
		SET propertyName = $listget(propList,i)
		SET propertyValue = $property(dashboard, propertyName)
		
		DO jsonMetrics.%Set(propertyName, propertyValue)
		
	}
	
	WRITE $replace($replace(jsonMetrics.%ToJSON(),"""'",""),"'""","")
	
	QUIT $$$OK
}

ClassMethod getDashboardSample(Output dashboard)
{
	NEW $namespace
	SET $namespace = "%SYS"
	SET dashboard = ##class(SYS.Stats.Dashboard).Sample()
}
	
ClassMethod getClassProperties(className As %String, Output propList As %List, Output descrList As %List)
{
	NEW $namespace
	SET $namespace = "%SYS"
	
	SET propList = "", descrList = ""
	SET properties = ##class(%Dictionary.ClassDefinition).%OpenId(className).Properties
	
	FOR i=1:1:properties.Count() {
		SET property = properties.GetAt(i)
		SET propList = propList_$listbuild(property.Name)
		SET descrList = descrList_$listbuild(property.Description)
	}
}

}
