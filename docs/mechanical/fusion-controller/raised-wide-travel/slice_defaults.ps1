param([string[]]$Only=@())
$ErrorActionPreference='Stop'
$revisionRoot=$PSScriptRoot
$sliceOutput=Join-Path $revisionRoot 'diagnostic-slices'
New-Item -ItemType Directory -Path $sliceOutput -Force | Out-Null
$selectedFiles=@(Get-ChildItem -LiteralPath (Join-Path $revisionRoot 'stl') -Filter '*.stl' | Sort-Object Name)
if($Only.Count -gt 0){$selectedFiles=@($selectedFiles | Where-Object {$Only -contains $_.Name})}
$results=[System.Collections.Generic.List[object]]::new()
foreach($meshFile in $selectedFiles){
 $stem=$meshFile.BaseName
 $sliceArgs=@('--slice','0','--debug','2','--curr-bed-type=Supertack Plate','--load-filament-ids','1','--load-defaultfila','--load-settings',((Join-Path $revisionRoot 'default-profiles\machine.json')+';'+(Join-Path $revisionRoot 'default-profiles\process.json')),'--load-filaments',(Join-Path $revisionRoot 'default-profiles\filament.json'),'--outputdir',$sliceOutput,'--export-3mf',($stem+'.gcode.3mf'),$meshFile.FullName)
 $quotedArgs=$sliceArgs | ForEach-Object {'"'+$_.Replace('"','\"')+'"'}
 $stdOut=Join-Path $sliceOutput ($stem+'.stdout.log');$stdErr=Join-Path $sliceOutput ($stem+'.stderr.log')
 $proc=Start-Process -FilePath 'C:\Program Files\Bambu Studio\bambu-studio.exe' -ArgumentList ($quotedArgs -join ' ') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdOut -RedirectStandardError $stdErr
 $outputFile=Join-Path $sliceOutput ($stem+'.gcode.3mf')
 $logText=(Get-Content -LiteralPath $stdOut -Raw)+(Get-Content -LiteralPath $stdErr -Raw)
 $issues=@($logText -split "`r?`n" | Where-Object {$_ -match '(?i)warning|error|failed|floating|not found'})
 $results.Add([pscustomobject]@{part=$meshFile.Name;exit_code=$proc.ExitCode;output_exists=(Test-Path -LiteralPath $outputFile);issues=$issues})
 Write-Output "$stem exit=$($proc.ExitCode)"
}
$reportName=if($Only.Count -gt 0){'selected-slice-report.json'}else{'slice-report.json'}
$results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $revisionRoot $reportName) -Encoding utf8
