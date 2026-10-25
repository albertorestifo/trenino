$ErrorActionPreference = 'Stop'
$exe = 'C:\Program Files\Bambu Studio\bambu-studio.exe'
$root = 'C:\Users\Alberto\Documents\tsw_io\docs\mechanical\fdm-stl'
$work = 'C:\Users\Alberto\Documents\tsw_io\docs\mechanical\slicer-check'
$profile = Join-Path $work 'profiles'
$out = Join-Path $work 'sliced'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$machine = Join-Path $profile 'machine-p2s-04-full.json'
$filament = Join-Path $profile 'filament-pla-basic-p2s-full.json'
# process-cam.json has enable_support=1 for the underside boss-relief roofs.
# This runner loads that profile for every cam slice; keep this support setting enabled.
$parts = @(
    @{ Name = 'roller'; Pattern = '*01 — Roller*.stl' },
    @{ Name = 'hub'; Pattern = '*02 — Hub*.stl' },
    @{ Name = 'cam'; Pattern = '*03 — Cam*.stl' },
    @{ Name = 'fork'; Pattern = '*04 — Fork*.stl' },
    @{ Name = 'bracket'; Pattern = '*05 — Bracket*.stl' }
)

foreach ($part in $parts) {
    $stl = Get-ChildItem -LiteralPath $root -Filter $part.Pattern -File | Select-Object -First 1
    if (-not $stl) { throw "Could not find STL for $($part.Name): $($part.Pattern)" }
    $process = Join-Path $profile "process-$($part.Name).json"
    $exportName = "$($part.Name).gcode.3mf"
    $result = Join-Path $out $exportName
    $stdout = Join-Path $out "$($part.Name).stdout.log"
    $stderr = Join-Path $out "$($part.Name).stderr.log"
    $args = @(
        '--slice', '0', '--debug', '3',
        '--curr-bed-type=Textured PEI Plate',
        '--load-filament-ids', '1', '--load-defaultfila',
        '--load-settings', "$machine;$process",
        '--load-filaments', $filament,
        '--outputdir', $out,
        '--export-3mf', $exportName,
        $stl.FullName
    )
    $quoted = $args | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }
    $argLine = $quoted -join ' '
    $proc = Start-Process -FilePath $exe -ArgumentList $argLine -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $file = Get-Item -LiteralPath $result -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Part = $part.Name
        Input = $stl.FullName
        ExitCode = $proc.ExitCode
        Output = if ($file) { $file.FullName } else { '' }
        OutputBytes = if ($file) { $file.Length } else { 0 }
        StdoutLog = $stdout
        StderrLog = $stderr
    } | ConvertTo-Json -Compress
}
