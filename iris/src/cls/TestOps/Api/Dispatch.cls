Class TestOps.Api.Dispatch Extends %CSP.REST
{

ClassMethod GetUserId() As %Integer
{
    set auth = %request.GetCgiEnv("HTTP_AUTHORIZATION")
    if $extract(auth,1,7)'="Bearer " quit 0
    set token=$extract(auth,8,*)
    quit ##class(TestOps.Util.DB).ValidateSession(token)
}

ClassMethod RequireAuth() As %Boolean
{
    set uid=..GetUserId()
    if uid'>0 {
        do ##class(TestOps.Util.DB).WriteJSON(401, ##class(TestOps.Util.DB).Error("unauthorized","Missing or invalid token"))
        quit 0
    }
    set %session.Data("userId")=uid
    quit 1
}

ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
    // Public routes
    if pUrl?1"/api/health".E { set pContinue=1 quit $$$OK }
    if pUrl?1"/api/auth/".E { set pContinue=1 quit $$$OK }
    if pUrl?1"/api/ingest/".E { set pContinue=1 quit $$$OK }

    // Everything else requires auth
    set pContinue=..RequireAuth()
    quit $$$OK
}

XData UrlMap
{
<Routes>
  <Route Url="/api/health" Method="GET" Call="Health"/>
  <Route Url="/api/auth/register" Method="POST" Call="AuthRegister"/>
  <Route Url="/api/auth/login" Method="POST" Call="AuthLogin"/>

  <Route Url="/api/projects" Method="GET" Call="ProjectsList"/>
  <Route Url="/api/projects" Method="POST" Call="ProjectsCreate"/>
  <Route Url="/api/projects/:id" Method="PATCH" Call="ProjectsUpdate"/>
  <Route Url="/api/projects/:id" Method="DELETE" Call="ProjectsDelete"/>
  <Route Url="/api/projects/:id/rotate-token" Method="POST" Call="ProjectsRotate"/>

  <Route Url="/api/ingest/:token/run" Method="POST" Call="IngestRun"/>

  <Route Url="/api/projects/:id/dashboard" Method="GET" Call="ProjectDashboard"/>
  <Route Url="/api/projects/:id/errors/top" Method="GET" Call="ProjectTopErrors"/>
  <Route Url="/api/projects/:id/errors/:fingerprint/similar" Method="GET" Call="ProjectSimilarErrors"/>
  <Route Url="/api/projects/:id/flaky" Method="GET" Call="ProjectFlaky"/>

  <Route Url="/api/projects/:id/runs" Method="GET" Call="ProjectRuns"/>
  <Route Url="/api/runs/:id" Method="GET" Call="RunGet"/>
  <Route Url="/api/runs/:id/diff" Method="GET" Call="RunDiff"/>
  <Route Url="/api/testcases/:id/annotate" Method="POST" Call="AnnotateTest"/>

  <Route Url="/api/runs/:id/attachments" Method="POST" Call="UploadRunAttachment"/>
  <Route Url="/api/attachments/:id/download" Method="GET" Call="DownloadAttachment"/>
</Routes>
}

ClassMethod Health() As %Status
{
    set obj=##class(TestOps.Util.DB).Obj()
    do obj.%Set("status","ok")
    do ##class(TestOps.Util.DB).WriteJSON(200, obj)
    quit $$$OK
}

ClassMethod AuthRegister() As %Status { quit ##class(TestOps.Api.Auth).Register() }
ClassMethod AuthLogin() As %Status { quit ##class(TestOps.Api.Auth).Login() }

ClassMethod ProjectsList() As %Status { quit ##class(TestOps.Api.Projects).List(%session.Data("userId")) }
ClassMethod ProjectsCreate() As %Status { quit ##class(TestOps.Api.Projects).Create(%session.Data("userId")) }
ClassMethod ProjectsUpdate(id As %String) As %Status { quit ##class(TestOps.Api.Projects).Update(%session.Data("userId"), +id) }
ClassMethod ProjectsDelete(id As %String) As %Status { quit ##class(TestOps.Api.Projects).Delete(%session.Data("userId"), +id) }
ClassMethod ProjectsRotate(id As %String) As %Status { quit ##class(TestOps.Api.Projects).RotateToken(%session.Data("userId"), +id) }

ClassMethod IngestRun(token As %String) As %Status { quit ##class(TestOps.Api.Ingest).Run(token) }

ClassMethod ProjectDashboard(id As %String) As %Status { quit ##class(TestOps.Api.Analytics).Dashboard(%session.Data("userId"), +id) }
ClassMethod ProjectTopErrors(id As %String) As %Status { quit ##class(TestOps.Api.Analytics).TopErrors(%session.Data("userId"), +id) }
ClassMethod ProjectFlaky(id As %String) As %Status { quit ##class(TestOps.Api.Analytics).Flaky(%session.Data("userId"), +id) }
ClassMethod ProjectSimilarErrors(id As %String, fingerprint As %String) As %Status { quit ##class(TestOps.Api.Analytics).SimilarErrorsInProject(%session.Data("userId"), +id, fingerprint) }

ClassMethod ProjectRuns(id As %String) As %Status { quit ##class(TestOps.Api.Runs).ListByProject(%session.Data("userId"), +id) }
ClassMethod RunGet(id As %String) As %Status { quit ##class(TestOps.Api.Runs).Get(%session.Data("userId"), +id) }
ClassMethod RunDiff(id As %String) As %Status { quit ##class(TestOps.Api.Runs).DiffWithPrev(%session.Data("userId"), +id) }
ClassMethod AnnotateTest(id As %String) As %Status { quit ##class(TestOps.Api.Runs).AnnotateTest(%session.Data("userId"), +id) }

ClassMethod UploadRunAttachment(id As %String) As %Status { quit ##class(TestOps.Api.Attachments).UploadToRun(%session.Data("userId"), +id) }
ClassMethod DownloadAttachment(id As %String) As %Status { quit ##class(TestOps.Api.Attachments).Download(%session.Data("userId"), +id) }

}
