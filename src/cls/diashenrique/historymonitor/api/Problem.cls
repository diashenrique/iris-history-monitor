/// Builds application/problem+json error responses (spec FR-007, contract schema Problem).
/// Body builds the object, Render also sets the HTTP status and content type when a %response exists.
Class diashenrique.historymonitor.api.Problem
{

Parameter MEDIATYPE = "application/problem+json";

ClassMethod ContentType() As %String
{
	Quit ..#MEDIATYPE
}

/// Reason phrase for the statuses the API uses.
ClassMethod Title(status As %Integer) As %String
{
	Quit $Case(status, 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed", 500: "Internal Server Error", : "Error")
}

/// "404 Not Found", the form %CSP.Response.Status expects.
ClassMethod StatusLine(status As %Integer) As %String
{
	Quit (+status)_" "_..Title(status)
}

/// slug becomes the stable relative type URI /problems/<slug>. errors is an optional
/// %DynamicArray of {parameter, message} and is left out when empty.
ClassMethod Body(status As %Integer, slug As %String, detail As %String = "", errors As %DynamicArray = "") As %DynamicObject
{
	Set body = {}
	Do body.%Set("type", "/problems/"_slug, "string")
	Do body.%Set("title", ..Title(status), "string")
	Do body.%Set("status", +status, "number")
	Do body.%Set("detail", detail, "string")
	If $IsObject(errors), errors.%Size() > 0 {
		Do body.%Set("errors", errors)
	}
	Quit body
}

/// Returns the JSON text. When a %response object is in scope (a REST request), sets its
/// status line and content type. The caller writes the returned text.
ClassMethod Render(status As %Integer, slug As %String, detail As %String = "", errors As %DynamicArray = "") As %String
{
	If $IsObject($Get(%response)) {
		Set %response.ContentType = ..ContentType()
		Set %response.Status = ..StatusLine(status)
	}
	Quit ..Body(status, slug, detail, errors).%ToJSON()
}

}
