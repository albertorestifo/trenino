$ErrorActionPreference = 'Stop'
$exe = 'C:\Program Files\Bambu Studio\bambu-studio.exe'
$root = 'C:\Users\Alberto\Documents\tsw_io\docs\mechanical\integrated-print'
$stlDir = Join-Path $root 'stl'
$profile = Join-Path $root 'profiles'
$out = Join-Path $root 'sliced'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$machine = 'C:\Users\Alberto\Documents\tsw_io\docs\mechanical\slicer-check\profiles\machine-p2s-04-full.json'
$filament = 'C:\Users\Alberto\Documents\tsw_io\docs\mechanical\slicer-check\profiles\filament-pla-basic-p2s-full.json'
$plain = Join-Path $profile 'process-integrated.json'
$supported = Join-Path $profile 'process-integrated-supports.json'
$rows = [System.Collections.Generic.List[object]]::new()

foreach ($stl in (Get-ChildItem -LiteralPath $stlDir -Filter '*.stl' -File | Sort-Object Name)) {
    $needsSupport = $stl.Name -match '^(frame-|moving-M01-|moving-M06-|moving-M08-|supports-S03-)'
    $process = if ($needsSupport) { $supported } else { $plain }
    $stem = [IO.Path]::GetFileNameWithoutExtension($stl.Name)
    $exportName = "$stem.gcode.3mf"
    $stdout = Join-Path $out "$stem.stdout.log"
    $stderr = Join-Path $out "$stem.stderr.log"
    $result = Join-Path $out $exportName
    Remove-Item -LiteralPath $result -Force -ErrorAction SilentlyContinue
    $args = @('--slice','0','--debug','3','--curr-bed-type=Textured PEI Plate',
        '--load-filament-ids','1','--load-defaultfila',
        '--load-settings',"$machine;$process",'--load-filaments',$filament,
        '--outputdir',$out,'--export-3mf',$exportName,$stl.FullName)
    $quoted = $args | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }
    $proc = Start-Process -FilePath $exe -ArgumentList ($quoted -join ' ') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $file = Get-Item -LiteralPath $result -ErrorAction SilentlyContinue
    $rows.Add([PSCustomObject]@{Part=$stl.Name;Supports=$needsSupport;ExitCode=$proc.ExitCode;
        Output=if($file){$file.FullName}else{''};OutputBytes=if($file){$file.Length}else{0};
        StdoutLog=$stdout;StderrLog=$stderr})
}
$rows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $root 'slice-report.json') -Encoding UTF8
$rows | Select-Object Part,Supports,ExitCode,OutputBytes | Format-Table -AutoSize
