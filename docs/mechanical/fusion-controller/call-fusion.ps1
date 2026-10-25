param([string]$ScriptPath,[switch]$ReadOnly,[string]$QueryPattern,[string]$Filter)
$h=@{Accept='application/json, text/event-stream';'MCP-Session-Id'='eed7cc21-8fa8-4486-a801-87766cb8f34a'}
if($QueryPattern){$name='fusion_mcp_read';$arguments=@{queryType='apiDocumentation';searchPattern=$QueryPattern;apiCategory='all';filter=$Filter}}else{$name='fusion_mcp_execute';$arguments=@{featureType='script';object=@{script=(Get-Content -LiteralPath $ScriptPath -Raw);readOnly=[bool]$ReadOnly}}}
$b=@{jsonrpc='2.0';id=10;method='tools/call';params=@{name=$name;arguments=$arguments}}|ConvertTo-Json -Depth 12
$r=Invoke-RestMethod -Uri 'http://127.0.0.1:27182/mcp' -Method Post -ContentType 'application/json' -Headers $h -Body $b -TimeoutSec 900
foreach($c in $r.result.content){if($c.type -eq 'text'){$c.text}}



