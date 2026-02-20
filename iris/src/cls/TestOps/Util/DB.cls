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
ClassMethod Obj() As %DynamicObject [ ProcedureBlock = 1 ]
{
    quit ##class(%DynamicObject).%New()
}

/// Convenience: create a standard {"error":{code,message}} JSON object.
ClassMethod Error(code As %String, message As %String) As %DynamicObject [ ProcedureBlock = 1 ]
{
    set root=##class(%DynamicObject).%New()
    set err=##class(%DynamicObject).%New()
    do err.%Set("code", code)
    do err.%Set("message", message)
    do root.%Set("error", err)
    quit root
}

/// Reads request body as JSON DynamicObject.
/// Returns "" when body is empty or invalid JSON.
ClassMethod ReadJSONBody() As %DynamicObject [ ProcedureBlock = 1 ]
{
    set raw=%request.Content.Read()
    if raw="" {
        quit ""
    }
    try {
        quit ##class(%DynamicObject).%FromJSON(raw)
    } catch ex {
        quit ""
    }
}

/// Generates random hex string of specified length.
ClassMethod RandomHex(len As %Integer = 32) As %String [ ProcedureBlock = 1 ]
{
    set s=""
    for i=1:1:(len\2) {
        set b=$zhex($random(256))
        if $length(b)=1 set b="0"_b
        set s=s_b
    }
    quit s
}

/// Password hashing (demo): SHA256(salt||pwd)
ClassMethod HashPassword(pwd As %String, salt As %String = "") As %String [ ProcedureBlock = 1 ]
{
    quit $system.Encryption.SHAHash(salt_pwd, "SHA256")
}

ClassMethod VerifyPassword(pwd As %String, salt As %String, hash As %String) As %Boolean [ ProcedureBlock = 1 ]
{
    quit (..HashPassword(pwd, salt)=hash)
}

/// Simple auth token generator.
ClassMethod NewToken() As %String [ ProcedureBlock = 1 ]
{
    quit ..RandomHex(64)
}

/// Creates a session token for userId and stores it.
ClassMethod CreateSession(userId As %Integer) As %String [ ProcedureBlock = 1 ]
{
    set token=..NewToken()
    do ..Exec("INSERT INTO TestOps_Session(userId, token) VALUES(?,?)", userId, token)
    quit token
}

/// Ensures DB schema exists (runs sql file via %SQL.Statement).
ClassMethod ApplySchema(path As %String) As %Status [ ProcedureBlock = 1 ]
{
    set stream=##class(%Stream.FileCharacter).%New()
    set stream.Filename=path

    if 'stream.%Open() {
        quit $$$ERROR($$$GeneralError, "Cannot open schema file: "_path)
    }

    // Read whole file
    set sql=""
    while 'stream.AtEnd {
        set sql = sql _ stream.Read(32000)
    }
    do stream.%Close()

    // Split by ';' and execute non-empty statements
    set i=1
    for  {
        set stmt=$piece(sql,";",i)
        quit:stmt=""
        set s=$zstrip(stmt,"<>W")
        if s'="" {
            do ..Exec(s)
        }
        set i=i+1
    }

    quit $$$OK
}

/// Ensures initial admin user exists.
ClassMethod EnsureAdmin() As %Status [ ProcedureBlock = 1 ]
{
    // Read admin creds from environment variables, with defaults
    set email=$ZTRNLNM("TESTOPS_ADMIN_EMAIL")
    if email="" set email="admin@testops.local"

    set pwd=$ZTRNLNM("TESTOPS_ADMIN_PASSWORD")
    if pwd="" set pwd="admin123"

    // If user exists, do nothing
    set row=..QueryOne("SELECT id FROM TestOps_User WHERE email=?", email)
    if row'="" {
        if row.%IsDefined("id") {
            quit $$$OK
        }
    }

    // Create admin user
    set salt=..RandomHex(16)
    set hash=..HashPassword(pwd, salt)

    // IMPORTANT: columns must match schema.sql (passHash/passSalt)
    do ..Exec("INSERT INTO TestOps_User(email, role, passHash, passSalt) VALUES(?,?,?,?)", email, "admin", hash, salt)

    quit $$$OK
}

/// Executes a SELECT query and returns first row as DynamicObject or "".
ClassMethod QueryOne(sql As %String, p1 As %String = "", p2 As %String = "", p3 As %String = "") As %DynamicObject [ ProcedureBlock = 1 ]
{
    set arr=..Query(sql, p1, p2, p3)
    if arr.%Size()<1 {
        quit ""
    }
    quit arr.%Get(0)
}

/// Executes a SELECT query and returns rows as DynamicArray of DynamicObject.
ClassMethod Query(sql As %String, p1 As %String = "", p2 As %String = "", p3 As %String = "") As %DynamicArray [ ProcedureBlock = 1 ]
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

/// Validates a session token and returns userId or 0.
ClassMethod ValidateSession(token As %String) As %Integer [ ProcedureBlock = 1 ]
{
    if token="" {
        quit 0
    }
    set row=..QueryOne("SELECT userId FROM TestOps_Session WHERE token=?", token)
    if row="" {
        quit 0
    }
    quit +row.userId
}

}