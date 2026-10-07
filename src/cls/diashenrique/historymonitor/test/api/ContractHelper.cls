/// Compares a response object with a schema of the API contract (task T010, spec FR-010).
/// The contract is specs/001-api-v1/contracts/openapi.json, generated from the YAML by
/// scripts/openapi_to_json.py (CI fails when the two differ).
///
/// Check returns a %DynamicArray of mismatch messages; empty means the shape matches. It is strict on
/// purpose: a missing required field, a wrong type, a value outside an enum, a badly formatted date-time
/// and any property the schema does not list are all mismatches, because an extra field is shape drift.
/// A schema with additionalProperties: true accepts any extra field.
///
/// Supported keywords: $ref (#/components/schemas/X), type, nullable, oneOf, enum, format date-time,
/// pattern, maxLength, minimum, maximum, required, properties, additionalProperties, items.
Class diashenrique.historymonitor.test.api.ContractHelper
{

Parameter CONTRACT = "specs/001-api-v1/contracts/openapi.json";

/// Path of the contract file. ^UnitTestRoot is <repo>/src/cls, set by test.Runner.
ClassMethod Path() As %String
{
	Set root = ##class(%File).NormalizeDirectory($Get(^UnitTestRoot, "/home/irisowner/repo/src/cls"))
	Set repo = ##class(%File).ParentDirectoryName(##class(%File).ParentDirectoryName(root))
	Quit repo_..#CONTRACT
}

ClassMethod Contract() As %DynamicObject
{
	Set stream = ##class(%Stream.FileCharacter).%New()
	Set stream.TranslateTable = "UTF8"
	Set sc = stream.LinkToFile(..Path())
	If $$$ISERR(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
	Quit {}.%FromJSON(stream)
}

/// schemaName is a key of components.schemas, for example "Problem".
ClassMethod Check(schemaName As %String, value As %DynamicAbstractObject) As %DynamicArray
{
	Set errs = []
	Try {
		Set root = ..Contract()
		Set schema = root.components.schemas.%Get(schemaName)
		If '$IsObject(schema) {
			Do errs.%Push("unknown schema '"_schemaName_"'")
		} Else {
			// The holder lets Walk read the type of the root value the same way it reads any member.
			Set holder = []
			Do holder.%Push(value)
			Do ..Walk(root, schema, holder, 0, "$", errs)
		}
	} Catch ex {
		Do errs.%Push("contract helper error: "_ex.DisplayString())
	}
	Quit errs
}

ClassMethod Walk(root As %DynamicObject, schema As %DynamicObject, parent As %DynamicAbstractObject, key, path As %String, errs As %DynamicArray) [ Private ]
{
	Set ref = schema.%Get("$ref")
	If ref '= "" {
		Set schema = root.components.schemas.%Get($Piece(ref, "/", $Length(ref, "/")))
		If '$IsObject(schema) {
			Do errs.%Push(path_": unresolved reference "_ref)
			Quit
		}
	}
	Set t = parent.%GetTypeOf(key)
	Set value = parent.%Get(key)
	If (t = "null") && schema.%Get("nullable") Quit

	If schema.%IsDefined("oneOf") {
		Set ok = 0
		Set it = schema.oneOf.%GetIterator()
		While it.%GetNext(.ai, .alt) {
			Set tmp = []
			Do ..Walk(root, alt, parent, key, path, tmp)
			If tmp.%Size() = 0 {
				Set ok = 1
				Quit
			}
		}
		If 'ok Do errs.%Push(path_": matches none of the allowed alternatives (got "_t_")")
		Quit
	}

	Set expected = schema.%Get("type")
	If (expected '= "") && '..TypeOk(expected, t, value) {
		Do errs.%Push(path_": expected "_expected_" but got "_t)
		Quit
	}

	If expected = "string" {
		If schema.%IsDefined("enum") {
			Set found = 0
			Set it = schema.enum.%GetIterator()
			While it.%GetNext(.ei, .ev) { If ev = value Set found = 1 }
			If 'found Do errs.%Push(path_": '"_value_"' is not one of the allowed values")
		}
		If (schema.%Get("format") = "date-time") && '$Match(value, "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z") {
			Do errs.%Push(path_": '"_value_"' is not a UTC date-time")
		}
		If schema.%IsDefined("pattern") && '$Match(value, schema.%Get("pattern")) {
			Do errs.%Push(path_": '"_value_"' does not match the pattern")
		}
		If schema.%IsDefined("maxLength") && ($Length(value) > schema.%Get("maxLength")) {
			Do errs.%Push(path_": longer than "_schema.%Get("maxLength"))
		}
	} ElseIf (expected = "number") || (expected = "integer") {
		If schema.%IsDefined("minimum") && (value < schema.%Get("minimum")) Do errs.%Push(path_": below the minimum")
		If schema.%IsDefined("maximum") && (value > schema.%Get("maximum")) Do errs.%Push(path_": above the maximum")
	} ElseIf expected = "object" {
		Set props = schema.%Get("properties")
		Set req = schema.%Get("required")
		If $IsObject(req) {
			Set it = req.%GetIterator()
			While it.%GetNext(.ri, .rname) {
				If 'value.%IsDefined(rname) Do errs.%Push(path_": missing required property '"_rname_"'")
			}
		}
		Set it = value.%GetIterator()
		While it.%GetNext(.k, .v) {
			If $IsObject(props) && props.%IsDefined(k) {
				Do ..Walk(root, props.%Get(k), value, k, path_"."_k, errs)
			} ElseIf schema.%Get("additionalProperties") '= 1 {
				Do errs.%Push(path_": unexpected property '"_k_"'")
			}
		}
	} ElseIf expected = "array" {
		Set items = schema.%Get("items")
		If $IsObject(items) {
			Set it = value.%GetIterator()
			While it.%GetNext(.i, .v) {
				Do ..Walk(root, items, value, i, path_"["_i_"]", errs)
			}
		}
	}
}

ClassMethod TypeOk(expected As %String, actual As %String, value) As %Boolean [ Private ]
{
	If expected = "integer" Quit (actual = "number") && (value = (value \ 1))
	Quit $Case(expected, "string": (actual = "string"), "number": (actual = "number"), "boolean": (actual = "boolean"), "object": (actual = "object"), "array": (actual = "array"), : 1)
}

}
