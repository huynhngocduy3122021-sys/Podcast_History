$ErrorActionPreference = 'Stop'

$postgresBin = 'C:\Program Files\PostgreSQL\18\bin'
$psql = Join-Path $postgresBin 'psql.exe'
$createdb = Join-Path $postgresBin 'createdb.exe'

if (-not (Test-Path $psql) -or -not (Test-Path $createdb)) {
    throw "PostgreSQL 18 command-line tools were not found in $postgresBin."
}

$role = Read-Host 'PostgreSQL role (press Enter for postgres)'
if ([string]::IsNullOrWhiteSpace($role)) {
    $role = 'postgres'
}

$securePassword = Read-Host 'PostgreSQL password' -AsSecureString
$passwordPointer = [IntPtr]::Zero

try {
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)

    $existing = & $psql -h localhost -p 5432 -U $role -d postgres -w -tAc `
        "SELECT datname FROM pg_database WHERE datname = 'Podcast_History'"
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not authenticate to PostgreSQL 18. The database was not changed.'
    }

    if (($existing -join '').Trim() -eq 'Podcast_History') {
        Write-Host 'Database Podcast_History already exists; it was left unchanged.'
    }
    else {
        & $createdb -h localhost -p 5432 -U $role -w --encoding=UTF8 --template=template0 Podcast_History
        if ($LASTEXITCODE -ne 0) {
            throw 'Database creation failed.'
        }
        Write-Host 'Created database Podcast_History.'
    }

    $version = & $psql -h localhost -p 5432 -U $role -d Podcast_History -w -tAc 'SHOW server_version'
    if ($LASTEXITCODE -ne 0) {
        throw 'The database exists, but the current role cannot connect to it.'
    }
    Write-Host "Connected to Podcast_History on PostgreSQL $($version.Trim())."
}
finally {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
    $securePassword.Dispose()
}
