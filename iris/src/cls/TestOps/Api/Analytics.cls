Class TestOps.Api.Analytics Extends %RegisteredObject
{

ClassMethod EnsureProjectAccess(userId As %Integer, projectId As %Integer) As %Boolean
{
    set row=##class(TestOps.Util.DB).QueryOne("SELECT id, ownerId FROM TestOps_Project WHERE id=?", projectId)
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

ClassMethod Dashboard(userId As %Integer, projectId As %Integer) As %Status
{
    if '##class(TestOps.Api.Analytics).EnsureProjectAccess(userId, projectId) quit $$$OK

    set sql="SELECT " _
        "SUM(CASE WHEN t.status='passed' THEN 1 ELSE 0 END) AS passCount, " _
        "SUM(CASE WHEN t.status='failed' THEN 1 ELSE 0 END) AS failCount, " _
        "COUNT(*) AS totalCount " _
        "FROM TestOps_TestCase t JOIN TestOps_Run r ON r.id=t.runId WHERE r.projectId=?"

    set stats=##class(TestOps.Util.DB).QueryOne(sql, projectId)
    if stats="" set stats=##class(TestOps.Util.DB).Obj()
    set pass=+$get(stats.passCount,0)
    set fail=+$get(stats.failCount,0)
    set total=+$get(stats.totalCount,0)
    set passRate=$select(total>0:((pass*100.0)/total), 1:0)

    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("passCount", pass)
    do res.%Set("failCount", fail)
    do res.%Set("totalCount", total)
    do res.%Set("passRate", passRate)
    do ##class(TestOps.Util.DB).WriteJSON(200, res)
    quit $$$OK
}

ClassMethod Flaky(userId As %Integer, projectId As %Integer) As %Status
{
    if '##class(TestOps.Api.Analytics).EnsureProjectAccess(userId, projectId) quit $$$OK

    set lastN=10
    set sub="SELECT TOP "_lastN_" id FROM TestOps_Run WHERE projectId=? ORDER BY id DESC"
    set sql="SELECT t.name, " _
        "SUM(CASE WHEN t.status='failed' THEN 1 ELSE 0 END) AS fails, " _
        "COUNT(*) AS total, " _
        "(SUM(CASE WHEN t.status='failed' THEN 1 ELSE 0 END)*100.0 / COUNT(*)) AS failRate " _
        "FROM TestOps_TestCase t JOIN TestOps_Run r ON r.id=t.runId " _
        "WHERE r.projectId=? AND r.id IN ("_sub_") " _
        "GROUP BY t.name HAVING COUNT(*) >= 2 ORDER BY failRate DESC"

    set rows=##class(TestOps.Util.DB).Query(sql, projectId, projectId)

    // attach history
    for i=0:1:(rows.%Size()-1) {
        set name=rows.%Get(i).name
        set hsql="SELECT TOP "_lastN_" t.status " _
            "FROM TestOps_TestCase t JOIN TestOps_Run r ON r.id=t.runId " _
            "WHERE r.projectId=? AND t.name=? AND r.id IN ("_sub_") " _
            "ORDER BY r.id DESC"
        set hist=##class(TestOps.Util.DB).Query(hsql, projectId, name, projectId)

        set statuses=##class(%DynamicArray).%New()
        for j=0:1:(hist.%Size()-1) {
            do statuses.%Push(hist.%Get(j).status)
        }
        do rows.%Get(i).%Set("history", statuses)
    }

    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("flaky", rows)
    do ##class(TestOps.Util.DB).WriteJSON(200, res)
    quit $$$OK
}

ClassMethod SimilarErrorsInProject(userId As %Integer, projectId As %Integer, fingerprint As %String) As %Status
{
    if '##class(TestOps.Api.Analytics).EnsureProjectAccess(userId, projectId) quit $$$OK

    set resArr=##class(TestOps.Util.DB).Query(
        "SELECT e.fingerprint, COUNT(*) AS occurrences, MAX(e.message) AS sampleMessage " _
        "FROM TestOps_ErrorEvent e JOIN TestOps_Run r ON r.id=e.runId " _
        "WHERE r.projectId=? AND e.fingerprint<>? GROUP BY e.fingerprint ORDER BY occurrences DESC",
        projectId, fingerprint)

    set out=##class(TestOps.Util.DB).Obj()
    do out.%Set("similar", resArr)
    do ##class(TestOps.Util.DB).WriteJSON(200, out)
    quit $$$OK
}

ClassMethod TopErrors(userId As %Integer, projectId As %Integer) As %Status
{
    if '##class(TestOps.Api.Analytics).EnsureProjectAccess(userId, projectId) quit $$$OK

    set rows=##class(TestOps.Util.DB).Query(
        "SELECT e.fingerprint, COUNT(*) AS occurrences, MAX(e.message) AS sampleMessage " _
        "FROM TestOps_ErrorEvent e JOIN TestOps_Run r ON r.id=e.runId " _
        "WHERE r.projectId=? GROUP BY e.fingerprint ORDER BY occurrences DESC",
        projectId)

    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("errors", rows)
    do ##class(TestOps.Util.DB).WriteJSON(200, res)
    quit $$$OK
}

}
