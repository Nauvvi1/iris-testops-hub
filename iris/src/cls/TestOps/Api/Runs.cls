Class TestOps.Api.Runs
{

ClassMethod EnsureProjectAccess(userId As %Integer, projectId As %Integer) As %Boolean
{
    set row=##class(TestOps.Util.DB).QueryOne("SELECT ownerId FROM TestOps_Project WHERE id=?", projectId)
    if row="" {
        do ##class(TestOps.Util.DB).WriteJSON(404, ##class(TestOps.Util.DB).Error("not_found","Project not found"))
        quit 0
    }
    if row.ownerId'=userId {
        do ##class(TestOps.Util.DB).WriteJSON(403, ##class(TestOps.Util.DB).Error("forbidden","Not allowed"))
        quit 0
    }
    quit 1
}

ClassMethod EnsureRunAccess(userId As %Integer, runId As %Integer, ByRef projectId As %Integer) As %Boolean
{
    set row=##class(TestOps.Util.DB).QueryOne("SELECT r.projectId, p.ownerId FROM TestOps_Run r JOIN TestOps_Project p ON p.id=r.projectId WHERE r.id=?", runId)
    if row="" {
        do ##class(TestOps.Util.DB).WriteJSON(404, ##class(TestOps.Util.DB).Error("not_found","Run not found"))
        quit 0
    }
    set projectId=+row.projectId
    if row.ownerId'=userId {
        do ##class(TestOps.Util.DB).WriteJSON(403, ##class(TestOps.Util.DB).Error("forbidden","Not allowed"))
        quit 0
    }
    quit 1
}

ClassMethod ListByProject(userId As %Integer, projectId As %Integer) As %Status
{
    if '##class(TestOps.Api.Runs).EnsureProjectAccess(userId, projectId) quit $$$OK
    set rows=##class(TestOps.Util.DB).Query(
        "SELECT runId, commitSha, branch, ciProvider, startedAt, durationMs, status, createdAt, total, passed, failed " _
        "FROM TestOps_RunStats WHERE projectId=? ORDER BY runId DESC", projectId)
    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("runs", rows)
    do ##class(TestOps.Util.DB).WriteJSON(200, res)
    quit $$$OK
}

ClassMethod Get(userId As %Integer, runId As %Integer) As %Status
{
    if '##class(TestOps.Api.Runs).EnsureRunAccess(userId, runId, .projectId) quit $$$OK

    set run=##class(TestOps.Util.DB).QueryOne(
        "SELECT runId, projectId, commitSha, branch, ciProvider, startedAt, durationMs, status, createdAt, total, passed, failed " _
        "FROM TestOps_RunStats WHERE runId=?", runId)

    set tests=##class(TestOps.Util.DB).Query(
        "SELECT t.id, t.name, t.status, t.durationMs, t.annotation, e.fingerprint, e.message " _
        "FROM TestOps_TestCase t LEFT JOIN TestOps_ErrorEvent e ON e.id=t.errorId " _
        "WHERE t.runId=? ORDER BY t.status DESC, t.durationMs DESC", runId)

    set errors=##class(TestOps.Util.DB).Query(
        "SELECT e.id, e.fingerprint, e.message, e.stacktrace, e.createdAt " _
        "FROM TestOps_ErrorEvent e WHERE e.runId=? ORDER BY e.id DESC", runId)

    set attachments=##class(TestOps.Util.DB).Query(
        "SELECT id, runId, testCaseId, fileName, mime, sizeBytes, createdAt FROM TestOps_Attachment WHERE runId=? ORDER BY id DESC", runId)

    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("run", run)
    do res.%Set("tests", tests)
    do res.%Set("errors", errors)
    do res.%Set("attachments", attachments)
    do ##class(TestOps.Util.DB).WriteJSON(200, res)
    quit $$$OK
}

ClassMethod DiffWithPrev(userId As %Integer, runId As %Integer) As %Status
{
    if '##class(TestOps.Api.Runs).EnsureRunAccess(userId, runId, .projectId) quit $$$OK

    set prev=##class(TestOps.Util.DB).QueryOne(
        "SELECT TOP 1 id FROM TestOps_Run WHERE projectId=? AND id < ? ORDER BY id DESC", projectId, runId)

    if prev="" {
        set res=##class(TestOps.Util.DB).Obj()
        do res.%Set("previousRunId", "")
        do res.%Set("newFailures", ##class(%DynamicArray).%New())
        do res.%Set("fixedFailures", ##class(%DynamicArray).%New())
        do res.%Set("newErrorFingerprints", ##class(%DynamicArray).%New())
        do res.%Set("fixedErrorFingerprints", ##class(%DynamicArray).%New())
        do ##class(TestOps.Util.DB).WriteJSON(200, res)
        quit $$$OK
    }

    // New/Fixed failed test names
    set newFails=##class(TestOps.Util.DB).Query(
        "SELECT t.name FROM TestOps_TestCase t WHERE t.runId=? AND t.status='failed' AND t.name NOT IN (SELECT name FROM TestOps_TestCase WHERE runId=? AND status='failed')", runId, prev.id)
    set fixedFails=##class(TestOps.Util.DB).Query(
        "SELECT t.name FROM TestOps_TestCase t WHERE t.runId=? AND t.status='failed' AND t.name NOT IN (SELECT name FROM TestOps_TestCase WHERE runId=? AND status='failed')", prev.id, runId)

    // New/Fixed error fingerprints
    set newFp=##class(TestOps.Util.DB).Query(
        "SELECT e.fingerprint FROM TestOps_ErrorEvent e WHERE e.runId=? AND e.fingerprint NOT IN (SELECT fingerprint FROM TestOps_ErrorEvent WHERE runId=?) GROUP BY e.fingerprint", runId, prev.id)
    set fixedFp=##class(TestOps.Util.DB).Query(
        "SELECT e.fingerprint FROM TestOps_ErrorEvent e WHERE e.runId=? AND e.fingerprint NOT IN (SELECT fingerprint FROM TestOps_ErrorEvent WHERE runId=?) GROUP BY e.fingerprint", prev.id, runId)

    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("previousRunId", prev.id)
    do res.%Set("newFailures", newFails)
    do res.%Set("fixedFailures", fixedFails)
    do res.%Set("newErrorFingerprints", newFp)
    do res.%Set("fixedErrorFingerprints", fixedFp)
    do ##class(TestOps.Util.DB).WriteJSON(200, res)
    quit $$$OK
}

ClassMethod AnnotateTest(userId As %Integer, testCaseId As %Integer) As %Status
{
    set body=##class(TestOps.Util.DB).ReadJSONBody()
    if body="" { quit $$$OK }
    set annotation=$get(body.annotation, "")
    if annotation="" {
        do ##class(TestOps.Util.DB).WriteJSON(400, ##class(TestOps.Util.DB).Error("bad_request","annotation required"))
        quit $$$OK
    }

    // Ensure access via run/project
    set row=##class(TestOps.Util.DB).QueryOne(
        "SELECT r.id AS runId, p.ownerId FROM TestOps_TestCase t JOIN TestOps_Run r ON r.id=t.runId JOIN TestOps_Project p ON p.id=r.projectId WHERE t.id=?", testCaseId)
    if row="" {
        do ##class(TestOps.Util.DB).WriteJSON(404, ##class(TestOps.Util.DB).Error("not_found","Test case not found"))
        quit $$$OK
    }
    if row.ownerId'=userId {
        do ##class(TestOps.Util.DB).WriteJSON(403, ##class(TestOps.Util.DB).Error("forbidden","Not allowed"))
        quit $$$OK
    }

    do ##class(TestOps.Util.DB).Exec("UPDATE TestOps_TestCase SET annotation=? WHERE id=?", annotation, testCaseId)
    set tc=##class(TestOps.Util.DB).QueryOne("SELECT id, runId, name, status, durationMs, annotation FROM TestOps_TestCase WHERE id=?", testCaseId)
    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("testCase", tc)
    do ##class(TestOps.Util.DB).WriteJSON(200, res)
    quit $$$OK
}

}
