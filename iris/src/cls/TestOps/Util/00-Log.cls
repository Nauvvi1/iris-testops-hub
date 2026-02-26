Class TestOps.Util.Log
{

/// Writes a single structured line to STDOUT so it appears in `docker compose logs`.
/// Keep this class dependency-free so it can be used during early init.
ClassMethod Write(level As %String, msg As %String, ex As %Exception.AbstractException = "")
{
    Set ts=$ZDATETIME($H,3)
    Set reqId="-"
    Set method="-"
    Set path="-"
    Set ip="-"

    If $Data(%request) Set method=$Get(%request.Method,"-")
    If $Data(%request) Set path=$Get(%request.CgiEnvs("REQUEST_URI"),"-")
    If $Data(%request) Set ip=$Get(%request.CgiEnvs("REMOTE_ADDR"),"-")
    If $Data(%request) Set reqId=$Get(%request.CgiEnvs("HTTP_X_REQUEST_ID"),"-")

    Write "[testops][",level,"][",ts,"][",reqId,"][",ip,"][",method," ",path,"] ",msg,!

    If (ex'="") {
        Write "[testops][",level,"] exception:",!
        Do ex.Display()
    }
}

ClassMethod Debug(msg As %String, ex As %Exception.AbstractException = "")
{
    Do ..Write("DEBUG", msg, ex)
}

ClassMethod Info(msg As %String, ex As %Exception.AbstractException = "")
{
    Do ..Write("INFO", msg, ex)
}

ClassMethod Warn(msg As %String, ex As %Exception.AbstractException = "")
{
    Do ..Write("WARN", msg, ex)
}

ClassMethod Error(msg As %String, ex As %Exception.AbstractException = "")
{
    Do ..Write("ERROR", msg, ex)
}

}
