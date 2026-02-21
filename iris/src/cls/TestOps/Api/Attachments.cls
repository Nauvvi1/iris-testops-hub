Class TestOps.Api.Attachments
{

ClassMethod BasePath() As %String
{
    quit "/opt/testops/attachments"
}

ClassMethod EnsureRunAccess(userId As %Integer, runId As %Integer) As %Boolean
{
    set row=##class(TestOps.Util.DB).QueryOne(
        "SELECT p.ownerId FROM TestOps_Run r JOIN TestOps_Project p ON p.id=r.projectId WHERE r.id=?",
        runId
    )

    if row="" {
        do ##class(TestOps.Util.DB).WriteJSON(404, ##class(TestOps.Util.DB).Error("not_found","Run not found"))
        quit 0
    }

    if +row.ownerId'=+userId {
        do ##class(TestOps.Util.DB).WriteJSON(403, ##class(TestOps.Util.DB).Error("forbidden","Not allowed"))
        quit 0
    }

    quit $$$OK
}

ClassMethod UploadToRun(userId As %Integer, runId As %Integer) As %Status
{
    if '##class(TestOps.Api.Attachments).EnsureRunAccess(userId, runId) quit $$$OK

    set body=##class(TestOps.Util.DB).ReadJSONBody()
    if body="" quit $$$OK

    set fileName=$get(body.fileName, "")
    set mime=$get(body.mime, "application/octet-stream")
    set contentB64=$get(body.contentBase64, "")

    if fileName=""!(contentB64="") {
        do ##class(TestOps.Util.DB).WriteJSON(400, ##class(TestOps.Util.DB).Error("bad_request","fileName and contentBase64 required"))
        quit $$$OK
    }

    if $length(contentB64) > 8*1024*1024 {
        do ##class(TestOps.Util.DB).WriteJSON(413, ##class(TestOps.Util.DB).Error("payload_too_large","Attachment too large"))
        quit $$$OK
    }

    do ##class(TestOps.Util.DB).Exec(
        "INSERT INTO TestOps_Attachment(runId, fileName, mime, sizeBytes, storageKey) VALUES(?,?,?,?,?)",
        runId, fileName, mime, 0, ""
    )
    set row=##class(TestOps.Util.DB).QueryOne("SELECT TOP 1 id FROM TestOps_Attachment WHERE runId=? ORDER BY id DESC", runId)
    set attId=+row.id

    set safeName=fileName
    set safeName=$translate(safeName, "\/:*?""<>|", "_________")

    set storageKey=attId_"-"_safeName
    set fullPath=..BasePath()_"/"_storageKey

    try {
        set bin=$SYSTEM.Encryption.Base64Decode(contentB64)
    } catch ex {
        do ##class(TestOps.Util.DB).WriteJSON(400, ##class(TestOps.Util.DB).Error("bad_request","Invalid base64"))
        quit $$$OK
    }

    set stream=##class(%Stream.FileBinary).%New()
    set stream.Filename=fullPath
    do stream.Write(bin)
    do stream.%Save()

    do ##class(TestOps.Util.DB).Exec(
        "UPDATE TestOps_Attachment SET storageKey=?, sizeBytes=? WHERE id=?",
        storageKey, $length(bin), attId
    )

    set out=##class(TestOps.Util.DB).QueryOne("SELECT id, runId, fileName, mime, sizeBytes, createdAt FROM TestOps_Attachment WHERE id=?", attId)

    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("attachment", out)
    do ##class(TestOps.Util.DB).WriteJSON(201, res)

    quit $$$OK
}

ClassMethod Download(userId As %Integer, id As %Integer) As %Status
{
    set row=##class(TestOps.Util.DB).QueryOne(
        "SELECT a.id, a.fileName, a.mime, a.storageKey, a.runId, p.ownerId " _
        "FROM TestOps_Attachment a JOIN TestOps_Run r ON r.id=a.runId JOIN TestOps_Project p ON p.id=r.projectId " _
        "WHERE a.id=?",
        id
    )

    if row="" {
        set %response.Status=404
        do %response.Write("Not found")
        quit $$$OK
    }
    if +row.ownerId'=+userId {
        set %response.Status=403
        do %response.Write("Forbidden")
        quit $$$OK
    }

    set fullPath=..BasePath()_"/"_row.storageKey
    set stream=##class(%Stream.FileBinary).%New()
    set stream.Filename=fullPath

    if 'stream.%Exists() {
        set %response.Status=404
        do %response.Write("File missing")
        quit $$$OK
    }

    set %response.ContentType=row.mime
    do %response.SetHeader("Content-Disposition", "attachment; filename="""_row.fileName_"""")

    do stream.OutputToDevice()
    quit $$$OK
}

}