Class TestOps.Api.Auth
{

ClassMethod Register() As %Status
{
    set body=##class(TestOps.Util.DB).ReadJSONBody()
    if body="" { quit $$$OK }

    set email=$get(body.email,"")
    set password=$get(body.password,"")
    if email=""!(password="") {
        do ##class(TestOps.Util.DB).WriteJSON(400, ##class(TestOps.Util.DB).Error("bad_request","email and password required"))
        quit $$$OK
    }

    set salt=##class(TestOps.Util.DB).RandomHex(16)
    set passHash=##class(TestOps.Util.DB).HashPassword(password, salt)

    try {
        do ##class(TestOps.Util.DB).Exec(
            "INSERT INTO TestOps_User(email, passHash, passSalt, role) VALUES(?, ?, ?, 'owner')",
            email, passHash, salt
        )
    } catch ex {
        do ##class(TestOps.Util.DB).WriteJSON(409, ##class(TestOps.Util.DB).Error("conflict","User already exists"))
        quit $$$OK
    }

    quit ..LoginInternal(email, password)
}

ClassMethod Login() As %Status
{
    set body=##class(TestOps.Util.DB).ReadJSONBody()
    if body="" { quit $$$OK }

    set email=$get(body.email,"")
    set password=$get(body.password,"")
    quit ..LoginInternal(email, password)
}

ClassMethod LoginInternal(email As %String, password As %String) As %Status
{
    if email=""!(password="") {
        do ##class(TestOps.Util.DB).WriteJSON(400, ##class(TestOps.Util.DB).Error("bad_request","email and password required"))
        quit $$$OK
    }

    set row=##class(TestOps.Util.DB).QueryOne("SELECT id, passHash, passSalt, role FROM TestOps_User WHERE email = ?", email)
    if row="" {
        do ##class(TestOps.Util.DB).WriteJSON(401, ##class(TestOps.Util.DB).Error("unauthorized","Invalid credentials"))
        quit $$$OK
    }

    set ok=##class(TestOps.Util.DB).VerifyPassword(password, row.passSalt, row.passHash)
    if 'ok {
        do ##class(TestOps.Util.DB).WriteJSON(401, ##class(TestOps.Util.DB).Error("unauthorized","Invalid credentials"))
        quit $$$OK
    }

    set token=##class(TestOps.Util.DB).CreateSession(+row.id)

    set res=##class(TestOps.Util.DB).Obj()
    do res.%Set("token", token)

    set u=##class(TestOps.Util.DB).Obj()
    do u.%Set("id", +row.id)
    do u.%Set("email", email)
    do u.%Set("role", row.role)

    do res.%Set("user", u)
    do ##class(TestOps.Util.DB).WriteJSON(200, res)

    quit $$$OK
}

}