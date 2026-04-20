@echo off
setlocal EnableDelayedExpansion

REM Usage: download-ollama-registry.bat [MODEL] [TAG] [OUTDIR]
REM Example: download-ollama-registry.bat qwen3-coder 30b

set "MODEL=%~1"
set "TAG=%~2"
set "OUTDIR=%~3"

if "%MODEL%"=="" set "MODEL=qwen3-coder"
if "%TAG%"=="" set "TAG=30b"
if "%OUTDIR%"=="" set "OUTDIR=%CD%\ollama_registry_%MODEL%_%TAG%"

set "REG=https://registry.ollama.ai/v2/library"
set "MANIFEST_URL=%REG%/%MODEL%/manifests/%TAG%"

mkdir "%OUTDIR%" 2>nul

echo Model: %MODEL%  Tag: %TAG%
echo Output: %OUTDIR%
echo.

REM Fetch manifest (Docker/OCI registry style)
curl.exe -sSL -f -H "Accept: application/vnd.docker.distribution.manifest.v2+json" ^
  -H "Accept: application/vnd.oci.image.manifest.v1+json" ^
  -o "%OUTDIR%\manifest.json" "%MANIFEST_URL%"
if errorlevel 1 (
  echo Failed to download manifest. Check MODEL/TAG and your network.
  exit /b 1
)

REM Parse digests and download blobs
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$out=$env:OUTDIR;" ^
  "$reg=$env:REG;" ^
  "$model=$env:MODEL;" ^
  "$mf=Join-Path $out 'manifest.json';" ^
  "$j=Get-Content -Raw -LiteralPath $mf | ConvertFrom-Json;" ^
  "$digests=New-Object System.Collections.Generic.List[string];" ^
  "if ($j.PSObject.Properties.Name -contains 'config' -and $j.config -and $j.config.digest) { [void]$digests.Add([string]$j.config.digest) }" ^
  "if ($j.layers) { foreach ($l in $j.layers) { if ($l.digest) { [void]$digests.Add([string]$l.digest) } } }" ^
  "if ($digests.Count -eq 0) { throw 'No digests found in manifest.json (unexpected format).' }" ^
  "foreach ($d in $digests) {" ^
  "  $url = ('{0}/{1}/blobs/{2}' -f $reg,$model,$d);" ^
  "  $safe = $d -replace ':','-';" ^
  "  $dest = Join-Path $out $safe;" ^
  "  Write-Host ('Downloading blob ' + $d);" ^
  "  $code = Start-Process -FilePath 'curl.exe' -ArgumentList @('-fL','-C','-','--retry','3','--retry-delay','2','-o',$dest,$url) -Wait -PassThru;" ^
  "  if ($code.ExitCode -ne 0) { throw ('curl failed for blob ' + $d) }" ^
  "}"

if errorlevel 1 (
  echo PowerShell/curl blob download failed.
  exit /b 1
)

echo.
echo Done. Files are in:
echo   %OUTDIR%
echo.
echo Notes:
echo - These are registry blobs (often one large layer is the GGUF weights^); names look like sha256-.....
echo - This is NOT the same layout as `ollama pull` uses internally, but you can use the large blob like a GGUF with other tools or rename/import per your workflow.
exit /b 0