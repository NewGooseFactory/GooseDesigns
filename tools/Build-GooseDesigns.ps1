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
    [string]$RepoRoot     = "",
    [string]$MocksRoot    = "C:\Users\shyamsridhar\OneDrive - Microsoft\Documents\Microsoft Scout\trending-mocks",
    [string]$VaultProject = "C:\Users\shyamsridhar\code\obsidian-vault\03_projects\github-trending-design"
)

$ErrorActionPreference = 'Stop'
if([string]::IsNullOrWhiteSpace($RepoRoot)){
    $scriptDir = if($PSScriptRoot){ $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $RepoRoot  = Split-Path -Parent $scriptDir
}
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

# ---------- banner (montage hero) ----------
$bannerRel = "assets/banner.png"
$bannerAbs = Join-Path $RepoRoot "assets\banner.png"
try {
    $attDir = Join-Path $VaultProject "attachments"
    $mk     = Join-Path $RepoRoot "tools\make_banner.py"
    if((Test-Path $mk) -and (Test-Path $attDir)){
        & python $mk --attachments $attDir --out $bannerAbs --count 6 2>$null | Out-Null
        & python $mk --attachments $attDir --out (Join-Path $RepoRoot "assets\hero.png") --count 6 --no-title --no-labels 2>$null | Out-Null
    }
} catch { Write-Output "WARN: banner generation skipped: $($_.Exception.Message)" }
$haveBanner = Test-Path $bannerAbs

# ---------- README.md (homepage) ----------
$pagesUrl = "https://newgoosefactory.github.io/GooseDesigns/"
$rm = @()
$rm += "# GooseDesigns $emdash Daily UI Design Inspiration from Trending GitHub Repos"
$rm += ""
if($haveBanner){
    $rm += "![GooseDesigns $emdash a daily montage of hero and landing-page UI design mockups for trending GitHub repositories]($bannerRel)"
    $rm += ""
}
$rm += "![Updated daily](https://img.shields.io/badge/updated-daily-5eead4?style=flat-square) " +
       "![$($all.Count) mocks](https://img.shields.io/badge/mocks-$($all.Count)-1f6feb?style=flat-square) " +
       "![$($dates.Count) days](https://img.shields.io/badge/days-$($dates.Count)-30363d?style=flat-square) " +
       "[![Live site](https://img.shields.io/badge/live-GitHub%20Pages-2ea043?style=flat-square)]($pagesUrl) " +
       "![License MIT](https://img.shields.io/badge/license-MIT-2ea043?style=flat-square)"
$rm += ""
$rm += "**A fresh set of landing-page and hero-section design mockups every morning.** GooseDesigns is an automated design-practice gallery: each day it reads [GitHub Trending](https://github.com/trending), picks the most interesting repositories $emdash AI, autonomous agents, developer tools, local LLMs, and PKM $emdash and reimagines each project's **hero / landing-page UI** in a rotating visual style. Real product copy, accessible contrast, intentional motion, and no generic AI-gradient slop."
$rm += ""
$rm += "Use it for **UI inspiration, web-design examples, landing-page ideas, and front-end reference** $emdash $($all.Count) mockups across $($dates.Count) days and $($families.Count) style families, updated daily. See the **[full design catalog](CATALOG.md)** or the **[live gallery]($pagesUrl)**."
$rm += ""
$rm += "## Browse"
$rm += ""
$rm += "- **[Full catalog](CATALOG.md)** $emdash every mock in one searchable table"
$styleLinks = @()
foreach($fam in ($families | Sort-Object)){ $styleLinks += "[$fam](styles/$fam.md)" }
$rm += "- **By style:** " + ($styleLinks -join " $mid ")
$rm += "- **[Design Taste Ledger](ledger.md)**" + $(if(Test-Path (Join-Path $RepoRoot 'concept.md')){ " $mid **[Concept: Design Taste](concept.md)**" })
$rm += "- **[Design system & discoverability spec](DESIGN.md)** $emdash palette, type scale, the four style families, and how this repo is built for reach"
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

# ---------- index.html (designed GitHub Pages landing) ----------
# Native (zero-dependency) port of the scroll-expand hero: media grows on scroll,
# title halves drift apart, content reveals. Progressive enhancement + reduced-motion
# + no-JS fallbacks keep content crawlable. Regenerated daily so it never goes stale.
$siteUrl = $pagesUrl
$ogImg   = $pagesUrl + "assets/banner.png"
$idxDesc = "A fresh set of landing-page and hero-section UI design mockups every morning - AI, agents, dev tools, LLMs. Browse $($all.Count) mocks across $($dates.Count) days in rotating visual styles."

$idxLr = @()
if($latest){ $idxLr = @($all | Where-Object { $_.date -eq $latest } | Sort-Object nn) }
$cards = ""
foreach($r in $idxLr){
    $cap = if($r.owner){ "$($r.owner)/$($r.name)" } else { $r.name }
    $cards += "      <a class=""mock"" href=""days/$($r.date)/$($r.nn)-$($r.slug).html"">" +
              "<span class=""shot""><img loading=""lazy"" src=""days/$($r.date)/$($r.nn)-$($r.slug).png"" alt=""$cap landing-page hero mock, $($r.family) style""></span>" +
              "<span class=""mm""><b>$cap</b><i>$($r.family)</i></span></a>`n"
}
$chips = ""
foreach($fam in ($families | Sort-Object)){ $chips += "      <a class=""chip"" href=""catalog.html?style=$fam"">$fam</a>`n" }
$latestLabel = if($latest){ WeekdayLong $latest } else { "" }

$css = @'
:root{--bg:#0b0e14;--panel:#0f141d;--border:#1f2733;--text:#e6edf3;--muted:#8b98a9;--accent:#5eead4;--maxw:1120px}
*{box-sizing:border-box}
html,body{margin:0;background:var(--bg);color:var(--text)}
body{font-family:"Inter",-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility;line-height:1.5}
a{color:inherit;text-decoration:none}
img{display:block;max-width:100%}
.kicker{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
.hero{position:relative;min-height:100svh;display:flex;align-items:center;justify-content:center;overflow:hidden;text-align:center;padding:24px}
.hero-bg{position:absolute;inset:-3%;z-index:0;background-size:cover;background-position:center;filter:blur(10px) saturate(1.05);opacity:.45;transform:scale(1.06);transition:opacity .12s linear}
.hero .scrim{position:absolute;inset:0;z-index:1;background:rgba(9,12,18,.72)}
.media{position:absolute;left:50%;top:50%;z-index:2;margin:0;width:540px;height:330px;transform:translate(-50%,-50%);border-radius:16px;overflow:hidden;border:1px solid var(--border);box-shadow:0 30px 90px rgba(0,0,0,.5);will-change:width,height}
.media img{width:100%;height:100%;object-fit:cover;filter:blur(18px) saturate(1.06);transform:scale(1.08);will-change:filter,transform}
.media .mscrim{position:absolute;inset:0;background:radial-gradient(125% 105% at 50% 44%,rgba(8,11,17,.50) 0%,rgba(8,11,17,.74) 52%,rgba(8,11,17,.9) 100%);transition:opacity .12s linear}
.copy{position:relative;z-index:3;max-width:840px}
.kicker{margin:0 0 18px;font-size:12px;letter-spacing:.24em;text-transform:uppercase;color:var(--accent)}
.hero h1{margin:0;font-weight:800;letter-spacing:-.02em;font-size:clamp(2.8rem,9vw,6.2rem);line-height:.98}
.tl{display:block;will-change:transform}
.tl-r{color:var(--accent)}
.sub{margin:22px auto 0;max-width:560px;font-size:clamp(1rem,2.2vw,1.18rem);opacity:.92;text-shadow:0 1px 18px rgba(0,0,0,.5)}
.cue{margin:34px 0 0;color:var(--muted);font-size:13px;letter-spacing:.04em}
.cue .chev{display:inline-block;margin-left:6px;color:var(--accent);animation:bob 1.8s ease-in-out infinite}
@keyframes bob{0%,100%{transform:translateY(0)}50%{transform:translateY(5px)}}
.content{position:relative;z-index:2;max-width:var(--maxw);margin:0 auto;padding:72px 24px 110px}
.lead{max-width:680px;margin:2px 0 46px;font-size:clamp(1.06rem,2.4vw,1.32rem);line-height:1.5;color:var(--text)}
.topcat{position:fixed;top:18px;right:20px;z-index:30;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.82rem;color:var(--muted);border:1px solid var(--border);background:rgba(11,14,20,.6);-webkit-backdrop-filter:blur(6px);backdrop-filter:blur(6px);padding:7px 13px;border-radius:999px;transition:color .2s,border-color .2s}
.topcat:hover{color:var(--accent);border-color:var(--accent)}
.reveal{opacity:1;transform:none}
html.js .reveal{opacity:0;transform:translateY(16px);transition:opacity .7s cubic-bezier(.22,1,.36,1),transform .7s cubic-bezier(.22,1,.36,1)}
html.js.revealed .reveal{opacity:1;transform:none}
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin:0 0 64px}
.stats div{background:var(--panel);border:1px solid var(--border);border-radius:12px;padding:18px 16px;text-align:center}
.stats b{display:block;font-size:1.7rem;font-weight:800;letter-spacing:-.01em}
.stats span{display:block;margin-top:4px;color:var(--muted);font-size:.82rem}
.sec-head{display:flex;align-items:baseline;justify-content:space-between;gap:16px;margin:0 0 22px}
.sec-head h2{margin:0;font-size:1.5rem;font-weight:700;letter-spacing:-.01em}
.more{color:var(--accent);font-size:.92rem;white-space:nowrap}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:18px;margin:0 0 64px}
.mock{display:block;background:var(--panel);border:1px solid var(--border);border-radius:14px;overflow:hidden;transition:transform .2s ease,border-color .2s ease}
.mock:hover{transform:translateY(-3px);border-color:#34404f}
.mock .shot{display:block;aspect-ratio:16/10;overflow:hidden;background:#0c1118}
.mock .shot img{width:100%;height:100%;object-fit:cover;object-position:top}
.mock .mm{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:12px 14px}
.mock .mm b{font-weight:600;font-size:.95rem;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.mock .mm i{flex:none;font-style:normal;font-family:ui-monospace,monospace;font-size:.72rem;color:var(--accent);border:1px solid var(--border);padding:3px 8px;border-radius:999px}
.chips{display:flex;flex-wrap:wrap;gap:10px;margin:0 0 64px}
.chip{font-family:ui-monospace,monospace;font-size:.86rem;background:var(--panel);border:1px solid var(--border);padding:9px 14px;border-radius:999px;transition:border-color .2s,color .2s}
.chip:hover{border-color:var(--accent);color:var(--accent)}
.cta{display:flex;flex-wrap:wrap;gap:12px;margin:0 0 56px}
.btn{font-size:.95rem;font-weight:600;background:var(--panel);border:1px solid var(--border);padding:12px 18px;border-radius:10px;transition:border-color .2s,transform .2s}
.btn:hover{border-color:#34404f;transform:translateY(-1px)}
.btn.primary{background:var(--accent);color:#06231f;border-color:var(--accent)}
.foot{color:var(--muted);font-size:.86rem;border-top:1px solid var(--border);padding-top:22px}
.foot a{color:var(--accent)}
@media (max-width:768px){.stats{grid-template-columns:repeat(2,1fr)}.media{width:88vw;height:46vh}}
@media (prefers-reduced-motion:reduce){html.js .reveal{opacity:1;transform:none;transition:none}.cue .chev{animation:none}}
'@

$js = @'
(function(){
  var root=document.documentElement;
  try{
    var reduce=window.matchMedia&&window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    var force=location.search.indexOf("reveal=1")>=0;
    var media=document.getElementById("media");
    var bg=document.querySelector(".hero-bg");
    var mscrim=document.querySelector(".media .mscrim");
    var mimg=document.querySelector(".media img");
    var copy=document.querySelector(".copy");
    var tlL=document.getElementById("tlL"),tlR=document.getElementById("tlR");
    var cue=document.getElementById("cue");
    var progress=0,expanded=false,touchStartY=0;
    function vw(){return window.innerWidth} function vh(){return window.innerHeight}
    function sizes(){var mob=vw()<768;return{
      bw:mob?Math.min(360,vw()*0.9):Math.min(560,vw()*0.86),
      bh:mob?Math.min(300,vh()*0.40):Math.min(340,vh()*0.46),
      mw:mob?vw()*0.94:Math.min(1180,vw()*0.94),
      mh:mob?vh()*0.74:Math.min(720,vh()*0.86),
      spread:mob?26:18};}
    function apply(){var s=sizes(),p=progress;
      media.style.width=(s.bw+p*(s.mw-s.bw))+"px";
      media.style.height=(s.bh+p*(s.mh-s.bh))+"px";
      if(bg)bg.style.opacity=String(0.45*(1-p));
      if(mimg){mimg.style.filter="blur("+(18*(1-p)).toFixed(2)+"px) saturate(1.06)";mimg.style.transform="scale("+(1.08-p*0.08).toFixed(3)+")";}
      if(mscrim)mscrim.style.opacity=(1-p*0.82).toFixed(3);
      if(copy)copy.style.opacity=Math.max(0,1-p*1.35).toFixed(3);
      var x=p*s.spread;
      tlL.style.transform="translateX(-"+x+"vw)";
      tlR.style.transform="translateX("+x+"vw)";
      if(cue)cue.style.opacity=String(Math.max(0,1-p*2.2));}
    function setProgress(np){progress=Math.min(1,Math.max(0,np));apply();
      if(progress>=1){root.classList.add("revealed");expanded=true;document.body.style.overflow="";}}
    function onWheel(e){
      if(expanded){if(e.deltaY<0&&window.scrollY<=4){expanded=false;root.classList.remove("revealed");document.body.style.overflow="hidden";setProgress(progress-0.06);e.preventDefault();}return;}
      e.preventDefault();setProgress(progress+e.deltaY*0.0009);}
    function onTouchStart(e){touchStartY=e.touches[0].clientY;}
    function onTouchMove(e){if(!touchStartY)return;var y=e.touches[0].clientY,d=touchStartY-y;
      if(expanded){if(d<-18&&window.scrollY<=4){expanded=false;root.classList.remove("revealed");document.body.style.overflow="hidden";setProgress(progress-0.08);e.preventDefault();}return;}
      e.preventDefault();setProgress(progress+d*(d<0?0.008:0.0055));touchStartY=y;}
    function onScroll(){if(!expanded){window.scrollTo(0,0);}}
    if(reduce||force){progress=1;apply();root.classList.add("revealed");expanded=true;
      if(location.search.indexOf("shot=content")>=0){var h=document.querySelector(".hero");if(h)h.style.minHeight="360px";window.scrollTo(0,0);}
      return;}
    document.body.style.overflow="hidden";apply();
    window.addEventListener("wheel",onWheel,{passive:false});
    window.addEventListener("touchstart",onTouchStart,{passive:false});
    window.addEventListener("touchmove",onTouchMove,{passive:false});
    window.addEventListener("scroll",onScroll,{passive:true});
    window.addEventListener("resize",apply);
  }catch(err){root.classList.add("revealed");try{document.body.style.overflow="";}catch(e){}}
})();
'@

$ix = @()
$ix += "<!doctype html>"
$ix += "<html lang=""en"">"
$ix += "<head>"
$ix += "<meta charset=""utf-8"">"
$ix += "<meta name=""viewport"" content=""width=device-width, initial-scale=1"">"
$ix += "<title>GooseDesigns &mdash; Daily UI Design Inspiration from Trending GitHub Repos</title>"
$ix += "<meta name=""description"" content=""$idxDesc"">"
$ix += "<link rel=""canonical"" href=""$siteUrl"">"
$ix += "<meta name=""theme-color"" content=""#0b0e14"">"
$ix += "<meta property=""og:type"" content=""website"">"
$ix += "<meta property=""og:title"" content=""GooseDesigns &mdash; Daily UI Design Inspiration"">"
$ix += "<meta property=""og:description"" content=""$idxDesc"">"
$ix += "<meta property=""og:image"" content=""$ogImg"">"
$ix += "<meta property=""og:url"" content=""$siteUrl"">"
$ix += "<meta name=""twitter:card"" content=""summary_large_image"">"
$ix += "<meta name=""twitter:title"" content=""GooseDesigns &mdash; Daily UI Design Inspiration"">"
$ix += "<meta name=""twitter:description"" content=""$idxDesc"">"
$ix += "<meta name=""twitter:image"" content=""$ogImg"">"
$ix += "<script>document.documentElement.className='js';</script>"
$ix += "<style>$css</style>"
$ix += "</head>"
$ix += "<body>"
$ix += "<a class=""topcat"" href=""catalog.html"">Catalog &rarr;</a>"
$ix += "<header class=""hero"">"
$ix += "  <div class=""hero-bg"" style=""background-image:url('assets/hero.png')""></div>"
$ix += "  <div class=""scrim""></div>"
$ix += "  <figure class=""media"" id=""media""><img src=""assets/hero.png"" alt=""GooseDesigns montage &mdash; six landing-page hero mockups for trending GitHub repositories""><span class=""mscrim""></span></figure>"
$ix += "  <div class=""copy"">"
$ix += "    <p class=""kicker"">Daily Design Montage</p>"
$ix += "    <h1><span class=""tl tl-l"" id=""tlL"">Goose</span><span class=""tl tl-r"" id=""tlR"">Designs</span></h1>"
$ix += "    <p class=""cue"" id=""cue"">Scroll to explore <span class=""chev"">&darr;</span></p>"
$ix += "  </div>"
$ix += "</header>"
$ix += "<main class=""content"">"
$ix += "  <p class=""lead reveal"">A fresh set of landing-page &amp; hero-section UI mockups every morning &mdash; AI, agents, dev tools, LLMs &mdash; each reimagined in a rotating visual style.</p>"
$ix += "  <section class=""stats reveal"">"
$ix += "    <div><b>$($all.Count)</b><span>mocks</span></div>"
$ix += "    <div><b>$($dates.Count)</b><span>days</span></div>"
$ix += "    <div><b>$($families.Count)</b><span>style families</span></div>"
$ix += "    <div><b>Daily</b><span>updated 6am CT</span></div>"
$ix += "  </section>"
if($idxLr.Count){
    $ix += "  <section class=""reveal"">"
    $ix += "    <div class=""sec-head""><h2>Latest &mdash; $latestLabel</h2><a class=""more"" href=""catalog.html?day=$latest"">See all $($all.Count) in the catalog &rarr;</a></div>"
    $ix += "    <div class=""grid"">"
    $ix += $cards.TrimEnd()
    $ix += "    </div>"
    $ix += "  </section>"
}
$ix += "  <section class=""reveal"">"
$ix += "    <div class=""sec-head""><h2>Browse by style</h2></div>"
$ix += "    <div class=""chips"">"
$ix += $chips.TrimEnd()
$ix += "    </div>"
$ix += "  </section>"
$ix += "  <section class=""reveal cta"">"
$ix += "    <a class=""btn primary"" href=""catalog.html"">Browse all $($all.Count) mocks &rarr;</a>"
$ix += "    <a class=""btn"" href=""https://github.com/NewGooseFactory/GooseDesigns"">View source on GitHub</a>"
$ix += "  </section>"
$ix += "  <footer class=""foot reveal"">An automation reads GitHub Trending each morning, designs hero mocks in a rotating style, and regenerates this gallery &mdash; no generic AI-gradient slop. &middot; <a href=""https://github.com/NewGooseFactory/GooseDesigns/blob/main/DESIGN.md"">Design system</a> &middot; <a href=""https://github.com/NewGooseFactory/GooseDesigns/blob/main/ledger.md"">Taste ledger</a></footer>"
$ix += "</main>"
$ix += "<script>$js</script>"
$ix += "</body>"
$ix += "</html>"
Set-Content -Path (Join-Path $RepoRoot 'index.html') -Value ($ix -join "`n") -Encoding UTF8

# ---------- catalog.html (designed, filterable gallery of every mock) ----------
$catCss = @'
:root{--bg:#0b0e14;--panel:#0f141d;--border:#1f2733;--text:#e6edf3;--muted:#8b98a9;--accent:#5eead4;--maxw:1160px}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
html,body{margin:0;background:var(--bg);color:var(--text)}
body{font-family:"Inter",-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility;line-height:1.5}
a{color:inherit;text-decoration:none}
img{display:block;max-width:100%}
.bar{position:sticky;top:0;z-index:20;display:flex;align-items:center;justify-content:space-between;gap:16px;padding:14px 22px;background:rgba(11,14,20,.82);-webkit-backdrop-filter:blur(10px);backdrop-filter:blur(10px);border-bottom:1px solid var(--border)}
.bar .wm{font-weight:700;letter-spacing:-.01em;font-size:1rem}
.bar .wm b{color:var(--accent)}
.bar .right{display:flex;align-items:center;gap:16px;color:var(--muted);font-size:.88rem}
.bar .right a{transition:color .2s}
.bar .right a:hover{color:var(--text)}
.wrap{max-width:var(--maxw);margin:0 auto;padding:0 22px}
.head{padding:56px 0 18px}
.head .kicker{margin:0 0 12px;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:12px;letter-spacing:.24em;text-transform:uppercase;color:var(--accent)}
.head h1{margin:0;font-size:clamp(2rem,5vw,3rem);font-weight:800;letter-spacing:-.02em;line-height:1.04}
.head p{margin:16px 0 0;color:var(--muted);max-width:660px;font-size:1.02rem}
.filters{position:sticky;top:53px;z-index:10;display:flex;flex-wrap:wrap;gap:10px;padding:16px 0 14px;background:linear-gradient(var(--bg),var(--bg) 76%,rgba(11,14,20,0))}
.f{appearance:none;-webkit-appearance:none;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.84rem;line-height:1;color:var(--muted);background:var(--panel);border:1px solid var(--border);padding:9px 15px;border-radius:999px;cursor:pointer;transition:border-color .18s,color .18s,background .18s}
.f:hover{border-color:#34404f;color:var(--text)}
.f.on{color:#06231f;background:var(--accent);border-color:var(--accent)}
.day{scroll-margin-top:118px}
.day h2{display:flex;align-items:baseline;gap:12px;margin:30px 0 16px;font-size:1.16rem;font-weight:700;letter-spacing:-.01em}
.day h2 span{font-family:ui-monospace,monospace;font-size:.78rem;color:var(--muted);font-weight:400}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(290px,1fr));gap:18px;margin:0 0 12px}
.mock{display:block;background:var(--panel);border:1px solid var(--border);border-radius:14px;overflow:hidden;transition:transform .2s ease,border-color .2s ease}
.mock:hover{transform:translateY(-3px);border-color:#34404f}
.mock .shot{display:block;aspect-ratio:16/10;overflow:hidden;background:#0c1118}
.mock .shot img{width:100%;height:100%;object-fit:cover;object-position:top}
.mock .mm{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:12px 14px}
.mock .mm b{font-weight:600;font-size:.92rem;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.mock .mm i{flex:none;font-style:normal;font-family:ui-monospace,monospace;font-size:.7rem;color:var(--accent);border:1px solid var(--border);padding:3px 8px;border-radius:999px}
.empty{display:none;color:var(--muted);padding:48px 0 80px;text-align:center}
.foot{color:var(--muted);font-size:.86rem;border-top:1px solid var(--border);padding:26px 0 64px;margin-top:34px}
.foot a{color:var(--accent)}
@media (max-width:560px){.head{padding:40px 0 14px}.filters{top:51px}}
'@

$catJs = @'
(function(){
  var qs=new URLSearchParams(location.search);
  var style=(qs.get("style")||"all").toLowerCase();
  var fs=[].slice.call(document.querySelectorAll(".f"));
  var days=[].slice.call(document.querySelectorAll(".day"));
  var empty=document.querySelector(".empty");
  function norm(s){return (s||"").toLowerCase();}
  function apply(){
    var shown=0;
    days.forEach(function(d){
      var vis=0;
      [].slice.call(d.querySelectorAll(".mock")).forEach(function(c){
        var ok=style==="all"||norm(c.getAttribute("data-style"))===style;
        c.style.display=ok?"":"none"; if(ok){vis++;shown++;}
      });
      d.style.display=vis?"":"none";
    });
    if(empty)empty.style.display=shown?"none":"block";
    fs.forEach(function(f){ if(norm(f.getAttribute("data-f"))===style){f.classList.add("on");}else{f.classList.remove("on");} });
  }
  fs.forEach(function(f){
    f.addEventListener("click",function(){
      style=norm(f.getAttribute("data-f"));
      var u=new URL(location.href);
      if(style==="all"){u.searchParams.delete("style");}else{u.searchParams.set("style",style);}
      history.replaceState(null,"",u);
      apply();
    });
  });
  apply();
  var day=qs.get("day");
  if(day){var el=document.querySelector('.day[data-day="'+day+'"]');if(el){el.scrollIntoView();}}
})();
'@

$catUrl = $pagesUrl + "catalog.html"
$cx = @()
$cx += "<!doctype html>"
$cx += "<html lang=""en"">"
$cx += "<head>"
$cx += "<meta charset=""utf-8"">"
$cx += "<meta name=""viewport"" content=""width=device-width, initial-scale=1"">"
$cx += "<title>Catalog &mdash; GooseDesigns &middot; $($all.Count) daily UI hero mockups</title>"
$cx += "<meta name=""description"" content=""Browse every GooseDesigns hero mock &mdash; $($all.Count) landing-page UI designs across $($dates.Count) days, filterable by visual style. Click any card to open the live mock."">"
$cx += "<link rel=""canonical"" href=""$catUrl"">"
$cx += "<meta name=""theme-color"" content=""#0b0e14"">"
$cx += "<meta property=""og:type"" content=""website"">"
$cx += "<meta property=""og:title"" content=""GooseDesigns Catalog &mdash; $($all.Count) daily UI hero mockups"">"
$cx += "<meta property=""og:description"" content=""Every hero mock, newest first &mdash; filterable by visual style."">"
$cx += "<meta property=""og:image"" content=""$ogImg"">"
$cx += "<meta property=""og:url"" content=""$catUrl"">"
$cx += "<meta name=""twitter:card"" content=""summary_large_image"">"
$cx += "<meta name=""twitter:title"" content=""GooseDesigns Catalog &mdash; $($all.Count) daily UI hero mockups"">"
$cx += "<meta name=""twitter:image"" content=""$ogImg"">"
$cx += "<style>$catCss</style>"
$cx += "</head>"
$cx += "<body>"
$cx += "<div class=""bar"">"
$cx += "  <a class=""wm"" href=""./"">Goose<b>Designs</b></a>"
$cx += "  <div class=""right""><span>$($all.Count) mocks &middot; $($dates.Count) days</span><a href=""https://github.com/NewGooseFactory/GooseDesigns"">GitHub</a></div>"
$cx += "</div>"
$cx += "<header class=""wrap head"">"
$cx += "  <p class=""kicker"">Catalog</p>"
$cx += "  <h1>Every mock, newest first</h1>"
$cx += "  <p>The complete archive of daily hero &amp; landing-page UI mockups &mdash; $($all.Count) designs across $($dates.Count) days in $($families.Count) rotating visual styles. Filter by style, then open any card to view the live mock.</p>"
$cx += "</header>"
$cx += "<div class=""wrap"">"
$cx += "  <nav class=""filters"" aria-label=""Filter by visual style"">"
$cx += "    <button type=""button"" class=""f on"" data-f=""all"">All</button>"
foreach($fam in ($families | Sort-Object)){ $cx += "    <button type=""button"" class=""f"" data-f=""$fam"">$fam</button>" }
$cx += "  </nav>"
foreach($d in $datesDesc){
    $drecs = @($all | Where-Object { $_.date -eq $d } | Sort-Object nn)
    if(-not $drecs.Count){ continue }
    $cx += "  <section class=""day"" data-day=""$d"">"
    $cx += "    <h2>$(WeekdayLong $d) <span>$d &middot; $($drecs.Count) mocks</span></h2>"
    $cx += "    <div class=""grid"">"
    foreach($r in $drecs){
        $cap = if($r.owner){ "$($r.owner)/$($r.name)" } else { $r.name }
        $cx += "      <a class=""mock"" data-style=""$($r.family)"" href=""days/$($r.date)/$($r.nn)-$($r.slug).html"">" +
               "<span class=""shot""><img loading=""lazy"" src=""days/$($r.date)/$($r.nn)-$($r.slug).png"" alt=""$cap landing-page hero mock, $($r.family) style""></span>" +
               "<span class=""mm""><b>$cap</b><i>$($r.family)</i></span></a>"
    }
    $cx += "    </div>"
    $cx += "  </section>"
}
$cx += "  <p class=""empty"">No mocks in that style yet.</p>"
$cx += "  <footer class=""foot"">Generated daily by a Goose automation from GitHub Trending. <a href=""./"">&larr; Back to home</a> &middot; <a href=""https://github.com/NewGooseFactory/GooseDesigns/blob/main/DESIGN.md"">Design system</a> &middot; <a href=""https://github.com/NewGooseFactory/GooseDesigns/blob/main/ledger.md"">Taste ledger</a></footer>"
$cx += "</div>"
$cx += "<script>$catJs</script>"
$cx += "</body>"
$cx += "</html>"
Set-Content -Path (Join-Path $RepoRoot 'catalog.html') -Value ($cx -join "`n") -Encoding UTF8

Write-Output ("OK: {0} mocks, {1} days, {2} style families -> {3}" -f $all.Count, $dates.Count, $families.Count, $RepoRoot)
Write-Output ("Families: " + ($families -join ', '))
