Class TestOps.Api.Projects
{

ClassMethod List(userId As %Integer) As %Status
{
    set rows=##class(TestOps.Util.DB).Query("SELECT id, name, ingestToken, createdAt FROM TestOps_Project WHERE ownerId=? ORDER BY createdAt DESC", userId)
    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("projects", rows)
    do ##class(TestOps.Util.DB).WriteJSON(200, res)
    quit $$$OK
}

ClassMethod Create(userId As %Integer) As %Status
{
    set body=##class(TestOps.Util.DB).ReadJSONBody()
    if body="" { quit $$$OK }
    set name=$get(body.name,"")
    if name="" {
        do ##class(TestOps.Util.DB).WriteJSON(400, ##class(TestOps.Util.DB).Error("bad_request","name required"))
        quit $$$OK
    }

    set token=##class(TestOps.Util.DB).RandomHex(24)
    do ##class(TestOps.Util.DB).Exec("INSERT INTO TestOps_Project(name, ownerId, ingestToken) VALUES(?,?,?)", name, userId, token)
    set row=##class(TestOps.Util.DB).QueryOne("SELECT id, name, ingestToken, createdAt FROM TestOps_Project WHERE ingestToken=?", token)
    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("project", row)
    do ##class(TestOps.Util.DB).WriteJSON(201, res)
    quit $$$OK
}

ClassMethod Update(userId As %Integer, id As %Integer) As %Status
{
    set body=##class(TestOps.Util.DB).ReadJSONBody()
    if body="" { quit $$$OK }
    set name=$get(body.name,"")

    set owner=##class(TestOps.Util.DB).QueryOne("SELECT ownerId FROM TestOps_Project WHERE id=?", id)
    if owner="" {
        do ##class(TestOps.Util.DB).WriteJSON(404, ##class(TestOps.Util.DB).Error("not_found","Project not found"))
        quit $$$OK
    }
    if owner.ownerId'=userId {
        do ##class(TestOps.Util.DB).WriteJSON(403, ##class(TestOps.Util.DB).Error("forbidden","Not allowed"))
        quit $$$OK
    }

    if name'="" {
        do ##class(TestOps.Util.DB).Exec("UPDATE TestOps_Project SET name=? WHERE id=?", name, id)
    }
    set row=##class(TestOps.Util.DB).QueryOne("SELECT id, name, ingestToken, createdAt FROM TestOps_Project WHERE id=?", id)
    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("project", row)
    do ##class(TestOps.Util.DB).WriteJSON(200, res)
    quit $$$OK
}

ClassMethod Delete(userId As %Integer, id As %Integer) As %Status
{
    set owner=##class(TestOps.Util.DB).QueryOne("SELECT ownerId FROM TestOps_Project WHERE id=?", id)
    if owner="" {
        do ##class(TestOps.Util.DB).WriteJSON(404, ##class(TestOps.Util.DB).Error("not_found","Project not found"))
        quit $$$OK
    }
    if owner.ownerId'=userId {
        do ##class(TestOps.Util.DB).WriteJSON(403, ##class(TestOps.Util.DB).Error("forbidden","Not allowed"))
        quit $$$OK
    }

    // cascade delete runs/tests/errors
    set runs=##class(TestOps.Util.DB).Query("SELECT id FROM TestOps_Run WHERE projectId=?", id)
    for i=1:1:runs.%Size() {
        set rid=runs.%Get(i).id
        do ##class(TestOps.Util.DB).Exec("DELETE FROM TestOps_TestCase WHERE runId=?", rid)
        do ##class(TestOps.Util.DB).Exec("DELETE FROM TestOps_ErrorEvent WHERE runId=?", rid)
        do ##class(TestOps.Util.DB).Exec("DELETE FROM TestOps_Run WHERE id=?", rid)
    }
    do ##class(TestOps.Util.DB).Exec("DELETE FROM TestOps_Project WHERE id=?", id)

    set res=##class(TestOps.Util.DB).Obj()
    do ##class(TestOps.Util.DB).WriteJSON(204, res)
    quit $$$OK
}

ClassMethod RotateToken(userId As %Integer, id As %Integer) As %Status
{
    set owner=##class(TestOps.Util.DB).QueryOne("SELECT ownerId FROM TestOps_Project WHERE id=?", id)
    if owner="" {
        do ##class(TestOps.Util.DB).WriteJSON(404, ##class(TestOps.Util.DB).Error("not_found","Project not found"))
        quit $$$OK
    }
    if owner.ownerId'=userId {
        do ##class(TestOps.Util.DB).WriteJSON(403, ##class(TestOps.Util.DB).Error("forbidden","Not allowed"))
        quit $$$OK
    }

    set token=##class(TestOps.Util.DB).RandomHex(24)
    do ##class(TestOps.Util.DB).Exec("UPDATE TestOps_Project SET ingestToken=? WHERE id=?", token, id)
    set row=##class(TestOps.Util.DB).QueryOne("SELECT id, name, ingestToken, createdAt FROM TestOps_Project WHERE id=?", id)
    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("project", row)
    do ##class(TestOps.Util.DB).WriteJSON(200, res)
    quit $$$OK
}

}
