Class diashenrique.historymonitor.dashboard.dashboard Extends %CSP.Page
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

ClassMethod getMetrics() As %Status
{

	Do ..getDashboardSample(.dashboard)
	Do ..getClassProperties(dashboard.%ClassName(1), .propList, .descrList)

	Set arrayMetrics = []
	Set jsonMetrics = { }

	For i=1:1:$Listlength(propList) {
		Set descr = $Listget(descrList,i)
		Set propertyName = $Listget(propList,i)
		Set propertyValue = $Property(dashboard, propertyName)

		Do jsonMetrics.%Set(propertyName, propertyValue)

	}

	Write $Replace($Replace(jsonMetrics.%ToJSON(),"""'",""),"'""","")

	Quit $$$OK
}

ClassMethod getDashboardSample(Output dashboard)
{
	New $Namespace
	Set $Namespace = "%SYS"
	Set dashboard = ##class(SYS.Stats.Dashboard).Sample()
}

ClassMethod getClassProperties(className As %String, Output propList As %List, Output descrList As %List)
{
	New $Namespace
	Set $Namespace = "%SYS"

	Set propList = "", descrList = ""
	Set properties = ##class(%Dictionary.ClassDefinition).%OpenId(className).Properties

	For i=1:1:properties.Count() {
		Set property = properties.GetAt(i)
		Set propList = propList_$Listbuild(property.Name)
		Set descrList = descrList_$Listbuild(property.Description)
	}
}

}
