Class TestOps.Api.Ingest
{

ClassMethod Run(token As %String) As %Status
{
    set proj=##class(TestOps.Util.DB).QueryOne("SELECT id FROM TestOps_Project WHERE ingestToken=?", token)
    if proj="" {
        do ##class(TestOps.Util.DB).WriteJSON(404, ##class(TestOps.Util.DB).Error("not_found","Invalid ingest token"))
        quit $$$OK
    }

    set body=##class(TestOps.Util.DB).ReadJSONBody()
    if body="" { quit $$$OK }

    set run=$get(body.run,"")
    if run="" {
        do ##class(TestOps.Util.DB).WriteJSON(400, ##class(TestOps.Util.DB).Error("bad_request","run object required"))
        quit $$$OK
    }

    set commitSha=$get(run.commitSha,"")
    set branch=$get(run.branch,"")
    set ciProvider=$get(run.ciProvider,"")
    set startedAt=$get(run.startedAt,"")
    set durationMs=+$get(run.durationMs,0)
    set status=$get(run.status,"unknown")

    do ##class(TestOps.Util.DB).Exec("INSERT INTO TestOps_Run(projectId, commitSha, branch, ciProvider, startedAt, durationMs, status) VALUES(?,?,?,?,?,?,?)", proj.id, commitSha, branch, ciProvider, startedAt, durationMs, status)

    set runRow=##class(TestOps.Util.DB).QueryOne("SELECT TOP 1 id FROM TestOps_Run WHERE projectId=? ORDER BY id DESC", proj.id)
    set runId=runRow.id

    set tests=$get(body.tests,"")
    if tests'="" {
        for i=1:1:tests.%Size() {
            set t=tests.%Get(i)
            set name=$get(t.name,"")
            set tstatus=$get(t.status,"unknown")
            set tdur=+$get(t.durationMs,0)
            set errObj=$get(t.error,"")
            set errId=""
            if errObj'="" {
                set msg=$get(errObj.message,"")
                set st=$get(errObj.stacktrace,"")
                set fp=##class(TestOps.Py.NLP).Fingerprint(msg, st)
                do ##class(TestOps.Util.DB).Exec("INSERT INTO TestOps_ErrorEvent(runId, fingerprint, message, stacktrace) VALUES(?,?,?,?)", runId, fp, msg, st)
                set errRow=##class(TestOps.Util.DB).QueryOne("SELECT TOP 1 id FROM TestOps_ErrorEvent WHERE runId=? ORDER BY id DESC", runId)
                set errId=errRow.id
            }
            do ##class(TestOps.Util.DB).Exec("INSERT INTO TestOps_TestCase(runId, name, status, durationMs, errorId) VALUES(?,?,?,?,?)", runId, name, tstatus, tdur, errId)
        }
    }

    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("runId", runId)
    do ##class(TestOps.Util.DB).WriteJSON(201, res)
    quit $$$OK
}

}
