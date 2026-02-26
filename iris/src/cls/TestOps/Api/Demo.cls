Class TestOps.Api.Demo
{

/// Ensure demo user exists and return its id.
ClassMethod DemoUserId() As %Integer
{
    set email="demo@testops.local"
    set row=##class(TestOps.Util.DB).QueryOne("SELECT id FROM TestOps_User WHERE email=?", email)
    if row'="" quit +row.id

    // create with random password (unused)
    set salt=##class(TestOps.Util.DB).RandomHex(16)
    set pwd=##class(TestOps.Util.DB).RandomHex(16)
    set hash=##class(TestOps.Util.DB).HashPassword(pwd, salt)
    do ##class(TestOps.Util.DB).Exec(
        "INSERT INTO TestOps_User(email, role, passHash, passSalt) VALUES(?,?,?,?)",
        email, "admin", hash, salt
    )

    set row=##class(TestOps.Util.DB).QueryOne("SELECT id FROM TestOps_User WHERE email=?", email)
    quit +$get(row.id,0)
}

ClassMethod ProjectsList() As %Status
{
    set ownerId=..DemoUserId()
    set rows=##class(TestOps.Util.DB).Query(
        "SELECT id, name, ingestToken, createdAt FROM TestOps_Project WHERE ownerId=? ORDER BY id DESC",
        ownerId
    )
    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("projects", rows)
    do res.%Set("mode", "demo")
    do ##class(TestOps.Util.DB).WriteJSON(200, res)
    quit $$$OK
}

ClassMethod ProjectsCreate() As %Status
{
    set hasBody=0
    // Backward compatible with old ReadJSONBody(): accept empty and validate below
    set body=##class(TestOps.Util.DB).ReadJSONBody()
    if body="" {
        do ##class(TestOps.Util.DB).WriteJSON(400, ##class(TestOps.Util.DB).Error("bad_request","JSON body required"))
        quit $$$OK
    }

    set name=$get(body.name, "")
    set name=$zstrip(name, "<>W")
    if name="" {
        do ##class(TestOps.Util.DB).WriteJSON(400, ##class(TestOps.Util.DB).Error("bad_request","name required"))
        quit $$$OK
    }

    set ownerId=..DemoUserId()
    set token=##class(TestOps.Util.DB).RandomHex(32)

    do ##class(TestOps.Util.DB).Exec(
        "INSERT INTO TestOps_Project(ownerId, name, ingestToken) VALUES(?,?,?)",
        ownerId, name, token
    )

    set row=##class(TestOps.Util.DB).QueryOne(
        "SELECT TOP 1 id, name, ingestToken, createdAt FROM TestOps_Project WHERE ownerId=? ORDER BY id DESC",
        ownerId
    )

    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("project", row)
    do res.%Set("mode", "demo")
    do ##class(TestOps.Util.DB).WriteJSON(201, res)
    quit $$$OK
}

ClassMethod ProjectsDelete(id As %Integer) As %Status
{
    set ownerId=..DemoUserId()
    set row=##class(TestOps.Util.DB).QueryOne(
        "SELECT id FROM TestOps_Project WHERE id=? AND ownerId=?",
        id, ownerId
    )
    if row="" {
        do ##class(TestOps.Util.DB).WriteJSON(404, ##class(TestOps.Util.DB).Error("not_found","Project not found"))
        quit $$$OK
    }

    // cascade run data etc if needed in future; for demo delete only project row
    do ##class(TestOps.Util.DB).Exec("DELETE FROM TestOps_Project WHERE id=?", id)

    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("ok", 1)
    do ##class(TestOps.Util.DB).WriteJSON(200, res)
    quit $$$OK
}

}
