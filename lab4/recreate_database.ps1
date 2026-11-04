param(
    [string]$Database = "transport_card_db",
    [string]$User = "postgres",
    [string]$HostName = "localhost",
    [int]$Port = 5432
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

python "$Root\generator\generate_data.py"
if ($LASTEXITCODE -ne 0) { throw "Ошибка генерации тестовых данных" }

$PsqlArguments = @(
    "-X",
    "-v", "ON_ERROR_STOP=1",
    "-h", $HostName,
    "-p", $Port,
    "-U", $User,
    "-d", $Database
)

& psql @PsqlArguments -f "$Root\sql\01_schema.sql"
if ($LASTEXITCODE -ne 0) { throw "Ошибка создания схемы" }

& psql @PsqlArguments -f "$Root\sql\02_initial_data.sql"
if ($LASTEXITCODE -ne 0) { throw "Ошибка начального наполнения" }

& psql @PsqlArguments -f "$Root\generated\03_test_data.sql"
if ($LASTEXITCODE -ne 0) { throw "Ошибка загрузки тестовых данных" }

& psql @PsqlArguments -f "$Root\sql\04_verify.sql"
if ($LASTEXITCODE -ne 0) { throw "Ошибка проверки базы" }

Write-Host "База $Database успешно пересоздана и проверена." -ForegroundColor Green
