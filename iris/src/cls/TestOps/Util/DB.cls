Class TestOps.Util.DB Extends %RegisteredObject
{

/// Writes JSON response and terminates request.
ClassMethod WriteJSON(status As %Integer, obj As %DynamicAbstractObject) [ ProcedureBlock = 1 ]
{
    do %response.SetHeader("Content-Type","application/json")
    set %response.Status = status
    do %response.Write(obj.%ToJSON())
    quit
}

/// Convenience: create an empty JSON object.
ClassMethod Obj() As %DynamicObject
{
    quit ##class(%DynamicObject).%New()
}

/// Convenience: create a standard {"error":{code,message}} JSON object.
ClassMethod Error(code As %String, message As %String) As %DynamicObject
{
    set root=##class(%DynamicObject).%New()
    set err=##class(%DynamicObject).%New()
    do err.%Set("code", code)
    do err.%Set("message", message)
    do root.%Set("error", err)
    quit root
}

/// Reads request body as JSON DynamicObject.
/// Returns an empty object when body is empty or invalid JSON.
/// hasBody=1 only when valid JSON was parsed.
ClassMethod ReadJSONBody(ByRef hasBody As %Boolean) As %DynamicObject
{
    set hasBody=0
    set raw=%request.Content.Read()
    if raw="" quit ..Obj()

    try {
        set obj=##class(%DynamicObject).%FromJSON(raw)
        set hasBody=1
        quit obj
    } catch ex {
        quit ..Obj()
    }
}

/// Generates random hex string of specified length.
ClassMethod RandomHex(len As %Integer = 32) As %String
{
    set s=""
    for i=1:1:(len\2) {
        set b=$zhex($random(256))
        if $length(b)=1 set b="0"_b
        set s=s_b
    }
    quit s
}

ClassMethod HashPassword(pwd As %String, salt As %String = "") As %String
{
    // demo: SHA256(salt||pwd)
    quit $system.Encryption.SHAHash(salt_pwd, "SHA256")
}

ClassMethod VerifyPassword(pwd As %String, salt As %String, hash As %String) As %Boolean
{
    quit (..HashPassword(pwd, salt)=hash)
}

ClassMethod NewToken() As %String
{
    quit ..RandomHex(64)
}

/// Executes a SELECT query and returns first row as DynamicObject or "".
ClassMethod QueryOne(sql As %String, p1 As %String = "", p2 As %String = "", p3 As %String = "") As %DynamicObject
{
    set arr=..Query(sql, p1, p2, p3)
    if arr.%Size()<1 quit ""
    quit arr.%Get(0)
}

/// Executes a SELECT query and returns rows as DynamicArray of DynamicObject.
ClassMethod Query(sql As %String, p1 As %String = "", p2 As %String = "", p3 As %String = "") As %DynamicArray
{
    set out=##class(%DynamicArray).%New()
    set stmt=##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rset=stmt.%Execute(p1, p2, p3)
    set md=rset.%GetMetadata()
    while rset.%Next() {
        set row=##class(%DynamicObject).%New()
        for i=1:1:md.columnCount {
            do row.%Set(md.columns(i).colName, rset.%Get(i))
        }
        do out.%Push(row)
    }
    quit out
}

/// Executes INSERT/UPDATE/DELETE.
ClassMethod Exec(sql As %String, p1 As %String = "", p2 As %String = "", p3 As %String = "", p4 As %String = "", p5 As %String = "") [ ProcedureBlock = 1 ]
{
    set stmt=##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    do stmt.%Execute(p1, p2, p3, p4, p5)
    quit
}

/// Ensures DB schema exists (runs sql file via $system.SQL).
ClassMethod ApplySchema(path As %String) As %Status [ ProcedureBlock = 1 ]
{
    set stream=##class(%Stream.FileCharacter).%New()
    set stream.Filename=path
    if 'stream.%Open() {
        quit $$$ERROR($$$GeneralError, "Cannot open schema file: "_path)
    }

    set sql=stream.Read(stream.Size)
    do stream.%Close()

    set i=1
    for  {
        set stmt=$piece(sql,";",i)  quit:stmt=""
        set s=$zstrip(stmt,"<>W")
        if s'="" { do ..Exec(s) }
        set i=i+1
    }
    quit $$$OK
}

/// Ensures initial admin user exists.
ClassMethod EnsureAdmin() As %Status [ ProcedureBlock = 1 ]
{
    set email=$ZTRNLNM("TESTOPS_ADMIN_EMAIL")
    if email="" set email="admin@testops.local"

    set pwd=$ZTRNLNM("TESTOPS_ADMIN_PASSWORD")
    if pwd="" set pwd="admin123"

    set row=..QueryOne("SELECT id FROM TestOps_User WHERE email=?", email)
    if row'="" quit $$$OK

    set salt=..RandomHex(16)
    set hash=..HashPassword(pwd, salt)
    do ..Exec("INSERT INTO TestOps_User(email, role, passHash, passSalt) VALUES(?,?,?,?)", email, "admin", hash, salt)
    quit $$$OK
}

ClassMethod CreateSession(userId As %Integer) As %String
{
    set token=..NewToken()
    do ..Exec("INSERT INTO TestOps_Session(userId, token) VALUES(?,?)", userId, token)
    quit token
}

/// Validates a session token and returns userId or 0.
ClassMethod ValidateSession(token As %String) As %Integer
{
    if token="" quit 0
    set row=..QueryOne("SELECT userId FROM TestOps_Session WHERE token=?", token)
    if row="" quit 0
    quit +row.userId
}

}