param([string[]]$Only = @())
$ErrorActionPreference = 'Stop'
$exe = 'C:\Program Files\Bambu Studio\bambu-studio.exe'
$root = 'C:\Users\Alberto\Documents\tsw_io\docs\mechanical\fusion-controller'
$stlDir = Join-Path $root 'stl'
$profile = Join-Path $root 'profiles'
$out = Join-Path $root 'sliced'
$machine = Join-Path $profile 'machine-p2s-04-full.json'
$filament = Join-Path $profile 'filament-pla-basic-p2s-full.json'
$plain = Join-Path $profile 'process-reviewed.json'
$supported = Join-Path $profile 'process-reviewed-supports.json'
$required = @($exe,$machine,$filament,$plain,$supported)
foreach ($p in $required) { if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw "Required slicer input missing: $p" } }
if (-not (Test-Path -LiteralPath $stlDir -PathType Container)) { throw "STL directory missing: $stlDir" }
$allStls = @(Get-ChildItem -LiteralPath $stlDir -Filter '*.stl' -File | Sort-Object Name)
if ($allStls.Count -ne 27) { throw "Expected 27 reviewed STL files, found $($allStls.Count)" }
$stls = if ($Only.Count -gt 0) { @($allStls | Where-Object { $Only -contains $_.Name }) } else { $allStls }
if ($Only.Count -gt 0 -and $stls.Count -ne $Only.Count) { throw "Could not find all requested STL files: $($Only -join ', ')" }
New-Item -ItemType Directory -Force -Path $out | Out-Null
$rows = [System.Collections.Generic.List[object]]::new()
foreach ($stl in $stls) {
    $needsSupport = $stl.Name -match '^P01|^P02|^P05|^P09|^P10|^P11|^P13|^P17|^P18|^P19|^P20'
    $process = if ($needsSupport) { $supported } else { $plain }
    $stem = [IO.Path]::GetFileNameWithoutExtension($stl.Name)
    $exportName = "$stem.gcode.3mf"
    $result = Join-Path $out $exportName
    $stdout = Join-Path $out "$stem.stdout.log"
    $stderr = Join-Path $out "$stem.stderr.log"
    Remove-Item -LiteralPath $result -Force -ErrorAction SilentlyContinue
    $args = @('--slice','0','--debug','3','--curr-bed-type=Textured PEI Plate',
        '--load-filament-ids','1','--load-defaultfila','--load-settings',"$machine;$process",
        '--load-filaments',$filament,'--outputdir',$out,'--export-3mf',$exportName,$stl.FullName)
    $quoted = $args | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }
    $proc = Start-Process -FilePath $exe -ArgumentList ($quoted -join ' ') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $file = Get-Item -LiteralPath $result -ErrorAction SilentlyContinue
    $logText = (Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue) + "`n" + (Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue)
    $issues = @($logText -split "`r?`n" | Where-Object { $_ -match '(?i)warning|error|failed|floating|not found' })
    $ok = ($proc.ExitCode -eq 0 -and $file -and $file.Length -gt 0)
    $rows.Add([PSCustomObject]@{Part=$stl.Name;Supports=[bool]$needsSupport;ExitCode=$proc.ExitCode;
        Success=[bool]$ok;Output=if($file){$file.FullName}else{''};OutputBytes=if($file){$file.Length}else{0};
        Issues=$issues;StdoutLog=$stdout;StderrLog=$stderr})
    if (-not $ok) { throw "Slice failed for $($stl.Name): exit=$($proc.ExitCode), output=$([bool]$file)" }
}
$reportName = if ($Only.Count -gt 0) { 'slice-report-reslice.json' } else { 'slice-report.json' }
$rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $root $reportName) -Encoding UTF8
$rows | Select-Object Part,Supports,ExitCode,OutputBytes | Format-Table -AutoSize


