<#
  Build-GooseDesigns.ps1
  Regenerates the GooseDesigns montage repo from the two sources of truth:
    - Obsidian vault project:  _reps, attachments (canonical PNG list), Design Taste Ledger, Concept
    - OneDrive trending-mocks: the live NN-slug.html originals
  Idempotent: aggregate files (README/CATALOG/ledger/concept/styles) are rebuilt every run;
  day folders are additive (files copied, day README overwritten).
  Pure PowerShell so the 6AM automation can call it unattended.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot     = (Split-Path -Parent $PSScriptRoot),
    [string]$MocksRoot    = "C:\Users\shyamsridhar\OneDrive - Microsoft\Documents\Microsoft Scout\trending-mocks",
    [string]$VaultProject = "C:\Users\shyamsridhar\code\obsidian-vault\03_projects\github-trending-design"
)

$ErrorActionPreference = 'Stop'
$emdash = [char]0x2014
$arrow  = [char]0x2192
$mid    = [char]0x00B7   # middle dot

function StripWiki([string]$s){
    if([string]::IsNullOrEmpty($s)){ return '' }
    $s = [regex]::Replace($s, '\[\[([^\]\|]+)\|([^\]]+)\]\]', '$2')
    $s = [regex]::Replace($s, '\[\[([^\]]+)\]\]', '$1')
    return $s
}
function MdCell([string]$s){
    if([string]::IsNullOrEmpty($s)){ return '' }
    return ($s -replace '\|','\|').Trim()
}
function WeekdayLong([string]$d){ ([datetime]::ParseExact($d,'yyyy-MM-dd',$null)).ToString('dddd, MMMM d') }
function WeekdayName([string]$d){ ([datetime]::ParseExact($d,'yyyy-MM-dd',$null)).ToString('dddd') }
function NormStyle([string]$style){
    $base = $style; $accent = ''
    if($style -match '^\s*([^(/]+?)\s*[\(/]\s*(.+?)\s*\)?\s*$'){
        $base = $Matches[1]; $accent = $Matches[2]
    }
    $b = $base.ToLower().Trim()
    $fam = $b
    if($b -match 'terminal'){ $fam = 'terminal-dark' }
    elseif($b -match 'editorial'){ $fam = 'editorial' }
    elseif($b -match 'hud'){ $fam = 'hud' }
    elseif($b -match 'blueprint'){ $fam = 'blueprint' }
    if(-not $fam){ $fam = 'unsorted' }
    $accent = $accent.Trim().TrimEnd(')',' ',',')
    return ,@($fam, $accent)
}
function RepoUrl($r){ if($r.owner){ "https://github.com/$($r.owner)/$($r.name)" } else { '' } }
function RepoCell($r){
    if($r.owner){ "[$($r.owner)/$($r.name)](https://github.com/$($r.owner)/$($r.name))" } else { $r.name }
}

# ---------- resolve sources ----------
$attachDir   = Join-Path $VaultProject 'attachments'
$ledgerPath  = Join-Path $VaultProject 'Design Taste Ledger.md'
$conceptPath = Join-Path $VaultProject ("Concept " + $emdash + " Design Taste.md")

if(-not (Test-Path -LiteralPath $attachDir)){ throw "attachments not found: $attachDir" }

# ---------- parse Design Taste Ledger ----------
# line: - {date} - [[{date}|rep]] - {owner/name} - {style} - {idea} -> {verdict}
$ledgerByDate = @{}
if(Test-Path -LiteralPath $ledgerPath){
    foreach($ln in (Get-Content -LiteralPath $ledgerPath -Encoding UTF8)){
        if($ln -notmatch '^\s*-\s'){ continue }
        if($ln -notmatch '\[\[\d{4}-\d{2}-\d{2}'){ continue }
        $body  = $ln -replace '^\s*-\s*',''
        $parts = $body -split (" " + $emdash + " "), 5
        if($parts.Count -lt 4){ continue }
        $d     = $parts[0].Trim()
        $repo  = $parts[2].Trim()
        $style = $parts[3].Trim()
        $idea  = ''; $verdict = ''
        if($parts.Count -ge 5){
            $iv = $parts[4] -split (" " + $arrow + " "), 2
            $idea = $iv[0].Trim()
            if($iv.Count -ge 2){ $verdict = $iv[1].Trim() }
        }
        if(-not $ledgerByDate.ContainsKey($d)){ $ledgerByDate[$d] = New-Object System.Collections.ArrayList }
        [void]$ledgerByDate[$d].Add([pscustomobject]@{ repo=$repo; style=$style; idea=$idea; verdict=$verdict })
    }
}

# ---------- enumerate canonical mocks (vault attachments) ----------
$mocksByDate = @{}
Get-ChildItem -LiteralPath $attachDir -Filter '*.png' | ForEach-Object {
    if($_.Name -match '^(\d{4}-\d{2}-\d{2})-(\d{2})-(.+)\.png$'){
        $d=$Matches[1]; $nn=$Matches[2]; $slug=$Matches[3]
        if(-not $mocksByDate.ContainsKey($d)){ $mocksByDate[$d]=New-Object System.Collections.ArrayList }
        [void]$mocksByDate[$d].Add([pscustomobject]@{ date=$d; nn=$nn; slug=$slug; png=$_.FullName })
    }
}

# ---------- merge into flat record list ----------
$all   = New-Object System.Collections.ArrayList
$dates = $mocksByDate.Keys | Sort-Object
foreach($d in $dates){
    $mocks = @($mocksByDate[$d] | Sort-Object nn)
    $led   = @()
    if($ledgerByDate.ContainsKey($d)){ $led = @($ledgerByDate[$d]) }
    for($i=0; $i -lt $mocks.Count; $i++){
        $m = $mocks[$i]
        $repo=''; $style=''; $idea=''; $verdict=''
        if($i -lt $led.Count){ $repo=$led[$i].repo; $style=$led[$i].style; $idea=$led[$i].idea; $verdict=$led[$i].verdict }
        if(-not $repo){ $repo = $m.slug }
        $owner=''; $name=$repo
        if($repo -match '/'){ $owner=$repo.Split('/')[0]; $name=$repo.Split('/',2)[1] }
        $family=$style; $accent=''
        $ns = NormStyle $style
        $family = $ns[0]; $accent = $ns[1]
        $dateDir = Join-Path $MocksRoot $d
        $htmlSrc = Join-Path $dateDir ("{0}-{1}.html" -f $m.nn,$m.slug)
        if(-not (Test-Path -LiteralPath $htmlSrc)){
            $cand = Get-ChildItem -LiteralPath $dateDir -Filter ("{0}-*.html" -f $m.nn) -ErrorAction SilentlyContinue | Select-Object -First 1
            if($cand){ $htmlSrc = $cand.FullName }
        }
        [void]$all.Add([pscustomobject]@{
            date=$d; nn=$m.nn; slug=$m.slug; repo=$repo; owner=$owner; name=$name;
            style=$style; family=$family; accent=$accent; idea=$idea; verdict=$verdict;
            pngSrc=$m.png; htmlSrc=$htmlSrc
        })
    }
}

$datesDesc = @($dates | Sort-Object -Descending)
$latest    = $datesDesc | Select-Object -First 1
$families  = @($all | Select-Object -ExpandProperty family -Unique | Sort-Object)

# ---------- write day folders + day pages ----------
$daysRoot = Join-Path $RepoRoot 'days'
New-Item -ItemType Directory -Force -Path $daysRoot | Out-Null
foreach($d in $dates){
    $dd = Join-Path $daysRoot $d
    New-Item -ItemType Directory -Force -Path $dd | Out-Null
    $recs = @($all | Where-Object { $_.date -eq $d } | Sort-Object nn)

    $styleList = (@($recs | ForEach-Object { $_.family } | Select-Object -Unique) -join ", ")
    $sb = @()
    $sb += "# Design Rep $emdash $(WeekdayLong $d)"
    $sb += ""
    $sb += "> $($recs.Count) mocks $emdash $styleList"
    $sb += ""
    $sb += "[Catalog](../../CATALOG.md) $mid [Home](../../README.md)"
    $sb += ""
    foreach($r in $recs){
        $pngDst  = Join-Path $dd ("{0}-{1}.png"  -f $r.nn,$r.slug)
        Copy-Item -LiteralPath $r.pngSrc -Destination $pngDst -Force
        $htmlName = $null
        if($r.htmlSrc -and (Test-Path -LiteralPath $r.htmlSrc)){
            $htmlName = ("{0}-{1}.html" -f $r.nn,$r.slug)
            Copy-Item -LiteralPath $r.htmlSrc -Destination (Join-Path $dd $htmlName) -Force
        }
        $sb += "## $(RepoCell $r)"
        $sb += ""
        $sb += "![$($r.name) $emdash $($r.family)](./$($r.nn)-$($r.slug).png)"
        $sb += ""
        $sb += "- **Style:** $($r.family)$(if($r.accent){" / $($r.accent)"})"
        if($r.idea){    $sb += "- **Idea tested:** $($r.idea)" }
        if($r.verdict){ $sb += "- **Verdict:** $($r.verdict)" }
        $links = @()
        if($htmlName){ $links += "[live .html](./$htmlName)" }
        if((RepoUrl $r)){ $links += "[repo on GitHub]($(RepoUrl $r))" }
        if($links.Count){ $sb += "- " + ($links -join " $mid ") }
        $sb += ""
    }
    Set-Content -Path (Join-Path $dd 'README.md') -Value ($sb -join "`n") -Encoding UTF8
}

# ---------- CATALOG.md (master searchable table) ----------
$cat = @()
$cat += "# Catalog $emdash every design rep"
$cat += ""
$cat += "Searchable master index. **$($all.Count) mocks** across **$($dates.Count) days**. Newest first."
$cat += ""
$cat += "Tip: press <kbd>t</kbd> in GitHub's file finder, or search e.g. ``repo:NewGooseFactory/GooseDesigns blueprint`` / a repo name / an idea keyword."
$cat += ""
$cat += "| Date | Day | Repository | Style | Accent | Idea tested | Verdict | Preview | Page |"
$cat += "|------|-----|------------|-------|--------|-------------|---------|---------|------|"
foreach($d in $datesDesc){
    foreach($r in @($all | Where-Object { $_.date -eq $d } | Sort-Object nn)){
        $prev = "[png](days/$($r.date)/$($r.nn)-$($r.slug).png)"
        $page = "[$($r.date)](days/$($r.date)/)"
        $cat += "| $($r.date) | $(WeekdayName $r.date) | $(RepoCell $r) | $(MdCell $r.family) | $(MdCell $r.accent) | $(MdCell $r.idea) | $(MdCell $r.verdict) | $prev | $page |"
    }
}
Set-Content -Path (Join-Path $RepoRoot 'CATALOG.md') -Value ($cat -join "`n") -Encoding UTF8

# ---------- styles/{family}.md ----------
$stylesRoot = Join-Path $RepoRoot 'styles'
New-Item -ItemType Directory -Force -Path $stylesRoot | Out-Null
Get-ChildItem -LiteralPath $stylesRoot -Filter '*.md' -ErrorAction SilentlyContinue | Remove-Item -Force
$styleBlurb = @{
    'terminal-dark' = "Near-black dev-tool aesthetic (Linear / Vercel / Raycast). One electric accent per mock, mono details."
    'editorial'     = "Light, calm, technical-editorial. Strong serif headline + clean sans, generous whitespace (Stripe-essay)."
    'hud'           = "Top Gun aviation-instrument HUD. Amber/green readouts, subtle grid, restrained $emdash never game-UI cheesy."
    'blueprint'     = "Architectural blueprint / schematic. Drafting grid, technical annotations, single ink accent."
}
foreach($fam in $families){
    $recs = @($all | Where-Object { $_.family -eq $fam } | Sort-Object @{Expression='date';Descending=$true}, @{Expression='nn';Descending=$false})
    $s = @()
    $s += "# Style $emdash $fam"
    $s += ""
    if($styleBlurb.ContainsKey($fam)){ $s += $styleBlurb[$fam]; $s += "" }
    $s += "$($recs.Count) mocks in this family. [Back to home](../README.md) $mid [Catalog](../CATALOG.md)"
    $s += ""
    $s += "| Date | Repository | Accent | Idea tested | Verdict | Preview |"
    $s += "|------|------------|--------|-------------|---------|---------|"
    foreach($r in $recs){
        $prev = "[png](../days/$($r.date)/$($r.nn)-$($r.slug).png)"
        $s += "| [$($r.date)](../days/$($r.date)/) | $(RepoCell $r) | $(MdCell $r.accent) | $(MdCell $r.idea) | $(MdCell $r.verdict) | $prev |"
    }
    Set-Content -Path (Join-Path $stylesRoot ("{0}.md" -f $fam)) -Value ($s -join "`n") -Encoding UTF8
}

# ---------- ledger.md (GitHub-native copy of Design Taste Ledger) ----------
$lg = @()
$lg += "# Design Taste Ledger"
$lg += ""
$lg += "Append-only record $emdash one line per mock: date $mid repo $mid style $mid idea tested $arrow verdict."
$lg += ""
foreach($d in $dates){
    foreach($r in @($all | Where-Object { $_.date -eq $d } | Sort-Object nn)){
        $line = "- $($r.date) $emdash [rep](days/$($r.date)/) $emdash $($r.repo) $emdash $($r.style)"
        if($r.idea){ $line += " $emdash $($r.idea)" }
        if($r.verdict){ $line += " $arrow $($r.verdict)" }
        $lg += $line
    }
}
Set-Content -Path (Join-Path $RepoRoot 'ledger.md') -Value ($lg -join "`n") -Encoding UTF8

# ---------- concept.md ----------
if(Test-Path -LiteralPath $conceptPath){
    $raw = Get-Content -LiteralPath $conceptPath -Encoding UTF8
    $out = @()
    foreach($line in $raw){ $out += (StripWiki $line) }
    Set-Content -Path (Join-Path $RepoRoot 'concept.md') -Value ($out -join "`n") -Encoding UTF8
}

# ---------- README.md (homepage) ----------
$rm = @()
$rm += "# GooseDesigns"
$rm += ""
$rm += "A **daily design montage**. Each morning an automation reads GitHub Trending, picks the most interesting repos (biased to AI / agents / dev-tools / LLM / PKM), and reimagines each one's hero/landing UI in a rotating visual style. Design practice, captured and made browsable."
$rm += ""
$rm += "**$($all.Count) mocks $mid $($dates.Count) days $mid $($families.Count) style families** and counting."
$rm += ""
$rm += "## Browse"
$rm += ""
$rm += "- **[Full catalog](CATALOG.md)** $emdash every mock in one searchable table"
$styleLinks = @()
foreach($fam in ($families | Sort-Object)){ $styleLinks += "[$fam](styles/$fam.md)" }
$rm += "- **By style:** " + ($styleLinks -join " $mid ")
$rm += "- **[Design Taste Ledger](ledger.md)**" + $(if(Test-Path (Join-Path $RepoRoot 'concept.md')){ " $mid **[Concept: Design Taste](concept.md)**" })
$rm += ""

if($latest){
    $lr = @($all | Where-Object { $_.date -eq $latest } | Sort-Object nn)
    $rm += "## Latest $emdash $(WeekdayLong $latest)"
    $rm += ""
    $rm += "<table><tr>"
    foreach($r in $lr){
        $cap = if($r.owner){ "$($r.owner)/$($r.name)" } else { $r.name }
        $rm += "<td align=""center"" width=""33%""><a href=""days/$($r.date)/""><img src=""days/$($r.date)/$($r.nn)-$($r.slug).png"" width=""320"" alt=""$cap""></a><br><sub><b>$cap</b><br>$($r.family)</sub></td>"
    }
    $rm += "</tr></table>"
    $rm += ""
    $rm += "[See the full day $arrow](days/$latest/)"
    $rm += ""
}

$rm += "## All reps"
$rm += ""
$rm += "| Date | Day | Mocks | Styles | Page |"
$rm += "|------|-----|-------|--------|------|"
foreach($d in $datesDesc){
    $recs = @($all | Where-Object { $_.date -eq $d } | Sort-Object nn)
    $styles = (@($recs | ForEach-Object { $_.family } | Select-Object -Unique) -join ", ")
    $rm += "| $d | $(WeekdayName $d) | $($recs.Count) | $styles | [open](days/$d/) |"
}
$rm += ""
$rm += "## Style rotation"
$rm += ""
$rm += "| Family | When | Feel |"
$rm += "|--------|------|------|"
$rm += "| terminal-dark | Mon / Thu | Near-black dev-tool; one electric accent (Linear / Vercel / Raycast) |"
$rm += "| editorial | Tue / Fri | Light, calm, serif headline + clean sans, generous whitespace (Stripe-essay) |"
$rm += "| hud | Wed / Sat | Top Gun aviation-instrument; amber/green readouts, subtle grid, restrained |"
$rm += "| blueprint | designer's choice | Architectural schematic; drafting grid, technical annotations |"
$rm += ""
$rm += "## How it works"
$rm += ""
$rm += "A scheduled ``Goose`` automation runs daily at 6:00 AM CT. It builds the trending briefing, writes 2$($emdash)3 self-contained HTML hero mocks in the day's style, screenshots each, and captures everything to an Obsidian vault. ``tools/Build-GooseDesigns.ps1`` then regenerates this repo (catalog, day pages, style indexes, homepage) from those sources and pushes. The build is idempotent $emdash re-running never duplicates."
$rm += ""
$rm += "## Search tips"
$rm += ""
$rm += "- Press <kbd>/</kbd> for repo search, or <kbd>t</kbd> for the file finder."
$rm += "- Code-search keywords land in [CATALOG.md](CATALOG.md): style names (``blueprint``, ``hud``), repo names, and the *idea tested* per mock."
$rm += "- Browse by visual family under [styles/](styles/)."
$rm += ""
$rm += "<sub>Generated by ``tools/Build-GooseDesigns.ps1`` $mid sources: GitHub Trending + an Obsidian design-practice vault.</sub>"
Set-Content -Path (Join-Path $RepoRoot 'README.md') -Value ($rm -join "`n") -Encoding UTF8

Write-Output ("OK: {0} mocks, {1} days, {2} style families -> {3}" -f $all.Count, $dates.Count, $families.Count, $RepoRoot)
Write-Output ("Families: " + ($families -join ', '))
