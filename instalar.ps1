# Datdata - Metodologia 2: descarga el paquete y ejecuta su instalador (setup.ps1).
# Uso, desde PowerShell, cmd o bash:
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://ricardo050427.github.io/datdata/instalar.ps1 | iex"
# (Archivo solo en ASCII a proposito: se ejecuta con Invoke-Expression y no depende de la codificacion.)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$datdataDir = Join-Path $env:TEMP "datdata-m2"
$datdataZip = Join-Path $datdataDir "EXPORTAR.zip"

if (Test-Path $datdataDir) { Remove-Item $datdataDir -Recurse -Force }
New-Item -ItemType Directory -Force $datdataDir | Out-Null

Write-Host "Descargando el paquete de la Metodologia 2..."
Invoke-WebRequest "https://ricardo050427.github.io/datdata/EXPORTAR.zip" -OutFile $datdataZip -UseBasicParsing
Expand-Archive -Path $datdataZip -DestinationPath $datdataDir -Force

$ErrorActionPreference = "Continue"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $datdataDir "setup.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Error "El instalador termino con problemas. Revisa la linea RESULTADO de arriba."
}
