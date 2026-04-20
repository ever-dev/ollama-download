@echo off
setlocal EnableExtensions

REM Download Ollama library model weights from registry.ollama.ai into MODEL_TAG.gguf
REM (layer with mediaType application/vnd.ollama.image.model). No separate .ps1 file.
REM
REM Usage: download-ollama-model-registry.bat MODEL TAG [OUTDIR]

if "%~2"=="" (
  echo Usage: %~nx0 MODEL TAG [OUTDIR]
  echo Example: %~nx0 qwen3-coder 30b
  exit /b 1
)

set "BAT_MODEL=%~1"
set "BAT_TAG=%~2"
if not "%~3"=="" (
  set "BAT_OUTDIR=%~3"
) else (
  set "BAT_OUTDIR=%CD%"
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { $ErrorActionPreference='Stop'; $Model=$env:BAT_MODEL; $Tag=$env:BAT_TAG; $OutDir=$env:BAT_OUTDIR; if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir=(Get-Location).Path }; $Reg='https://registry.ollama.ai/v2/library'; $Want='application/vnd.ollama.image.model'; $accept=@('application/vnd.docker.distribution.manifest.v2+json','application/vnd.oci.image.manifest.v1+json','application/vnd.docker.distribution.manifest.list.v2+json','application/vnd.oci.image.index.v1+json') -join ', '; function Get-ManifestRaw([string]$ref) { return (Invoke-WebRequest -Uri ($Reg+'/'+$Model+'/manifests/'+$ref) -Headers @{ Accept=$accept } -UseBasicParsing).Content }; function Test-IsIndex($o) { if ($null -eq $o) { return $false }; $mt=[string]$o.mediaType; if ($mt -match 'manifest\.list|image\.index') { return $true }; if ($o.PSObject.Properties.Name -contains 'manifests' -and $o.manifests -and -not ($o.PSObject.Properties.Name -contains 'layers')) { return $true }; return $false }; function Get-ChildDigest($ix) { $list=@($ix.manifests); if ($list.Count -eq 0) { throw 'Manifest index has no manifests[]' }; $p=$list | Where-Object { $_.platform -and $_.platform.os -eq 'linux' -and $_.platform.architecture -eq 'amd64' } | Select-Object -First 1; if ($p) { return [string]$p.digest }; return [string]($list | Select-Object -First 1 -ExpandProperty digest) }; New-Item -ItemType Directory -Force -Path $OutDir | Out-Null; $outFile=Join-Path $OutDir ($Model+'_'+$Tag+'.gguf'); Write-Host ('Model: '+$Model+'  Tag: '+$Tag); Write-Host ('Output: '+$outFile); Write-Host ''; $raw=Get-ManifestRaw $Tag; Set-Content -LiteralPath (Join-Path $OutDir 'manifest.json') -Value $raw -Encoding utf8; $j=$raw | ConvertFrom-Json; if (Test-IsIndex $j) { $cd=Get-ChildDigest $j; Write-Host ('Resolved manifest index -> '+$cd); $raw=Get-ManifestRaw $cd; Set-Content -LiteralPath (Join-Path $OutDir 'manifest-image.json') -Value $raw -Encoding utf8; $j=$raw | ConvertFrom-Json }; if (-not $j.layers) { throw 'Unexpected manifest: no layers[]' }; $ml=@($j.layers | Where-Object { $_.digest -and $_.mediaType -eq $Want }); if ($ml.Count -eq 0) { throw ('No layer with mediaType '+$Want) }; if ($ml.Count -gt 1) { Write-Warning 'Multiple model layers; using the first.' }; $d=[string]$ml[0].digest; $blobUrl=$Reg+'/'+$Model+'/blobs/'+$d; Write-Host ('Downloading '+$d); $p=Start-Process -FilePath 'curl.exe' -ArgumentList @('-fL','-C','-','--retry','3','--retry-delay','2','-o',$outFile,$blobUrl) -Wait -PassThru -NoNewWindow; if ($p.ExitCode -ne 0) { throw ('curl.exe failed: '+$p.ExitCode) }; Write-Host ''; Write-Host 'Done.' }"

exit /b %ERRORLEVEL%