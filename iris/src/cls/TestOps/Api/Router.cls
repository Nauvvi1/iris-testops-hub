Class TestOps.Api.Router Extends TestOps.Api.Dispatch
{

XData UrlMap
{
<Routes>
        <Route Url="/health" Method="GET" Call="Health" />
  <!-- Auth -->
  <Route Url="/auth/login" Method="POST" Call="AuthLogin" />
  <Route Url="/auth/register" Method="POST" Call="AuthRegister" />
  <Route Url="/auth/me" Method="GET" Call="AuthMe" />

  <!-- Projects -->
  <Route Url="/projects" Method="GET" Call="ProjectsList" />
  <Route Url="/projects" Method="POST" Call="ProjectsCreate" />
  <Route Url="/projects/:id" Method="PATCH" Call="ProjectsUpdate" />
  <Route Url="/projects/:id" Method="DELETE" Call="ProjectsDelete" />
  <Route Url="/projects/:id/rotate-token" Method="POST" Call="ProjectsRotate" />

  <!-- Runs -->
  <Route Url="/projects/:projectId/runs" Method="GET" Call="RunsList" />
  <Route Url="/runs/:runId" Method="GET" Call="RunsGet" />
  <Route Url="/runs/:runId/diff" Method="GET" Call="RunsDiff" />
  <Route Url="/testcases/:testCaseId/annotate" Method="POST" Call="RunsAnnotate" />

  <!-- Analytics -->
  <Route Url="/projects/:id/dashboard" Method="GET" Call="AnalyticsDashboard" />
  <Route Url="/projects/:id/errors/top" Method="GET" Call="AnalyticsTopErrors" />
  <Route Url="/projects/:id/flaky" Method="GET" Call="AnalyticsFlaky" />
  <Route Url="/projects/:projectId/errors/:fp/similar" Method="GET" Call="AnalyticsSimilar" />

  <!-- Ingest & attachments -->
  <Route Url="/ingest/run" Method="POST" Call="IngestRun" />
  <Route Url="/runs/:runId/attachments" Method="POST" Call="AttachUpload" />
</Routes>
}

ClassMethod AuthLogin() As %Status { Return ##class(TestOps.Api.Auth).Login() }
ClassMethod AuthRegister() As %Status { Return ##class(TestOps.Api.Auth).Register() }
ClassMethod AuthMe() As %Status { Return ##class(TestOps.Api.Auth).Me() }

ClassMethod ProjectsList() As %Status { Return ##class(TestOps.Api.Projects).List() }
ClassMethod ProjectsCreate() As %Status { Return ##class(TestOps.Api.Projects).Create() }
ClassMethod ProjectsUpdate(id As %Integer) As %Status { Return ##class(TestOps.Api.Projects).Update(id) }
ClassMethod ProjectsDelete(id As %Integer) As %Status { Return ##class(TestOps.Api.Projects).Delete(id) }
ClassMethod ProjectsRotate(id As %Integer) As %Status { Return ##class(TestOps.Api.Projects).RotateToken(id) }

ClassMethod RunsList(projectId As %Integer) As %Status { Return ##class(TestOps.Api.Runs).ListByProject(projectId) }
ClassMethod RunsGet(runId As %Integer) As %Status { Return ##class(TestOps.Api.Runs).Get(runId) }
ClassMethod RunsDiff(runId As %Integer) As %Status { Return ##class(TestOps.Api.Runs).DiffWithPrev(runId) }
ClassMethod RunsAnnotate(testCaseId As %Integer) As %Status { Return ##class(TestOps.Api.Runs).AnnotateTest(testCaseId) }

ClassMethod AnalyticsDashboard(id As %Integer) As %Status { Return ##class(TestOps.Api.Analytics).Dashboard(id) }
ClassMethod AnalyticsTopErrors(id As %Integer) As %Status { Return ##class(TestOps.Api.Analytics).TopErrors(id) }
ClassMethod AnalyticsFlaky(id As %Integer) As %Status { Return ##class(TestOps.Api.Analytics).Flaky(id) }
ClassMethod AnalyticsSimilar(projectId As %Integer, fp As %String) As %Status { Return ##class(TestOps.Api.Analytics).Similar(projectId, fp) }

ClassMethod IngestRun() As %Status { Return ##class(TestOps.Api.Ingest).Run() }
ClassMethod AttachUpload(runId As %Integer) As %Status { Return ##class(TestOps.Api.Attachments).UploadToRun(runId) }

}
