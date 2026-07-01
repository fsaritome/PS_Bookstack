<#
.SYNOPSIS
    BIGGUS SCREENUS — Demoscene monitor animation.
    Press any key to exit.
#>

[Console]::CursorVisible     = $false
[Console]::OutputEncoding    = [System.Text.Encoding]::UTF8
[Console]::BackgroundColor   = 'Black'
[Console]::Clear()

$W = [Console]::WindowWidth
$H = [Console]::WindowHeight

# ── Pre-computed sine table (3600 entries) ─────────────────────────────────
$PI2 = [Math]::PI * 2
$sinT = New-Object float[] 3600
for ($i = 0; $i -lt 3600; $i++) { $sinT[$i] = [Math]::Sin($i / 3600.0 * $PI2) }
function S([double]$a) { $sinT[(($a * 572.958 % 3600 + 3600) % 3600)] }
function C([double]$a) { $sinT[(($a * 572.958 % 3600 + 3600) % 3600 + 900) % 3600] }

# ── Plasma palette ─────────────────────────────────────────────────────────
$cc = [ConsoleColor]
$PLC = @($cc::DarkBlue,$cc::Blue,$cc::DarkMagenta,$cc::Magenta,
         $cc::DarkCyan,$cc::Cyan,$cc::DarkGreen,$cc::Green,
         $cc::DarkYellow,$cc::Yellow,$cc::DarkRed,$cc::Red,
         $cc::DarkGray,$cc::Gray,$cc::White,$cc::DarkCyan)
$PLG = ' .:;+=*#@%#'

# ── Write one char at (x,y) ────────────────────────────────────────────────
function W([int]$x,[int]$y,[char]$c,[ConsoleColor]$f) {
    if ($x -lt 0 -or $x -ge $W -or $y -lt 0 -or $y -ge $H) { return }
    [Console]::SetCursorPosition($x, $y)
    [Console]::ForegroundColor = $f
    [Console]::Write($c)
}

# ── Stars ──────────────────────────────────────────────────────────────────
$STARS = 1..60 | ForEach-Object {
    [PSCustomObject]@{
        x = Get-Random -Max ($W - 1)
        y = Get-Random -Min 3 -Max ($H - 4)
        p = Get-Random -Max 628
    }
}

# ── Monitor geometry (one big centred monitor) ─────────────────────────────
$MON_SW  = 40          # screen inner width
$MON_SH  = 10          # screen inner height
$MON_OW  = $MON_SW + 4 # outer bezel width
$MON_OH  = $MON_SH + 4 # outer bezel height

$MON_CX  = [int]($W / 2)
$MON_CY  = [int]($H / 2) - 6

# ── Cube vertices & edges ──────────────────────────────────────────────────
# Flat array: 8 vertices × 3 coords = 24 values
$CUBE_V = @(
    -1,-1,-1,  1,-1,-1,  1, 1,-1, -1, 1,-1,
    -1,-1, 1,  1,-1, 1,  1, 1, 1, -1, 1, 1
)
$CUBE_E = @(0,1,1,2,2,3,3,0,4,5,5,6,6,7,7,4,0,4,1,5,2,6,3,7)

# ── Jokes that cycle above the monitor ─────────────────────────────────────
$JOKES = @(
    "★  B I G G U S   S C R E E N U S  ★",
    "★  IT'S NOT TOO BIG — IT'S TOO SMALL  ★",
    "★  4K? I MEAN 4K PER QUADRANT  ★",
    "★  MY EYES CAN'T LEAVE MY DESK  ★",
    "★  NEAR SIDE: AMAZING  FAR SIDE: ALSO AMAZING  ★",
    "★  TURNING HEAD 30° TO SEE OTHER SIDE  ★",
    "★  THIS ISN'T A MONITOR — IT'S A WINDOW  ★",
    "★  PIXEL DENSITY: 0.04 PER MM  ★",
    "★  DO I NEED A MONITOR OR A WHITEBOARD?  ★",
    "★  BIG SCREEN ENERGY  ★"
)

# ── Scrolltext ─────────────────────────────────────────────────────────────
$SCROLL = ("  *** BIGGUS SCREENUS *** " +
           "WHEN 27 INCHES IS TOO SMALL *** " +
           "THE SCREEN IS SO BIG IT HAS ITS OWN ZIP CODE *** " +
           "NEEDS TWO HDMI CABLES AND A PRAYER *** " +
           "MY NECK HURTS AND I LOVE IT *** " +
           "BIG SCREENS DON'T LIE — THEY JUST STRETCH THE TRUTH *** " +
           "PRESS ANY KEY TO EXIT THIS OVERPOWERED EXPERIENCE *** ")
$scrollX = $W

# ── Flush key buffer ───────────────────────────────────────────────────────
Start-Sleep -Milliseconds 200
try { while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) } } catch {}

# ── Main loop ──────────────────────────────────────────────────────────────
$frame = 0
try {
    while (-not [Console]::KeyAvailable) {
        $frame++
        $t = $frame * 0.06

        # ── 1. PLASMA BACKGROUND ──────────────────────────────────────────
        for ($py = 0; $py -lt $H; $py++) {
            for ($px = 0; $px -lt $W; $px++) {
                $fx = $px / $W; $fy = $py / $H
                $sv1 = $fx * 12 + $t; $sv2 = $fy * 12 + $t * 0.7
                $sv3 = ($fx + $fy) * 8 + $t * 1.3
                $sv4 = [Math]::Sqrt($fx * $fx + $fy * $fy) * 10 + $t * 0.5
                $v = S $sv1 + S $sv2 + S $sv3 + S $sv4
                $vn = ($v + 4) / 8
                $gi = [Math]::Min($PLG.Length - 1, [int]($vn * $PLG.Length))
                $ci = [Math]::Min($PLC.Count - 1, [int]($vn * $PLC.Count))
                W $px $py $PLG[$gi] $PLC[$ci]
            }
        }

        # ── 2. STARS (over plasma) ────────────────────────────────────────
        foreach ($s in $STARS) {
            $bri = S ($t * 0.4 + $s.p / 100.0)
            $col = if ($bri -gt 0.7) { $cc::White } elseif ($bri -gt 0) { $cc::Gray } else { $cc::DarkGray }
            W $s.x $s.y '·' $col
        }

        # ── 3. MONITOR BEZEL ──────────────────────────────────────────────
        $bzCol = $PLC[([int]($t * 2)) % $PLC.Count]
        # Top bezel
        for ($i = 0; $i -lt $MON_OW; $i++) { W ($MON_CX - [int]($MON_OW / 2) + $i) $MON_CY '═' $bzCol }
        # Bottom bezel
        for ($i = 0; $i -lt $MON_OW; $i++) { W ($MON_CX - [int]($MON_OW / 2) + $i) ($MON_CY + $MON_OH - 1) '═' $bzCol }
        # Left bezel (vertical)
        for ($r = 1; $r -lt ($MON_OH - 1); $r++) { W ($MON_CX - [int]($MON_OW / 2)) ($MON_CY + $r) '║' $bzCol }
        # Right bezel
        for ($r = 1; $r -lt ($MON_OH - 1); $r++) { W ($MON_CX - [int]($MON_OW / 2) + $MON_OW - 1) ($MON_CY + $r) '║' $bzCol }
        # Corners
        W ($MON_CX - [int]($MON_OW / 2)) $MON_CY '╔' $bzCol
        W ($MON_CX - [int]($MON_OW / 2) + $MON_OW - 1) $MON_CY '╗' $bzCol
        W ($MON_CX - [int]($MON_OW / 2)) ($MON_CY + $MON_OH - 1) '╚' $bzCol
        W ($MON_CX - [int]($MON_OW / 2) + $MON_OW - 1) ($MON_CY + $MON_OH - 1) '╝' $bzCol

        # ── 4. SCREEN CONTENT (rotating wireframe cube) ───────────────────
        $sc = [int]($MON_SW / 3)
        $cx_ = $MON_CX
        $cy_ = $MON_CY + [int]($MON_SH / 2) + 1

        $ax = $t * 0.8; $ay = $t * 0.6
        $proj = @()
        for ($vi = 0; $vi -lt 8; $vi++) {
            $vx = $CUBE_V[$vi * 3]; $vy = $CUBE_V[$vi * 3 + 1]; $vz = $CUBE_V[$vi * 3 + 2]
            # Rotate Y
            $cay = C $ay; $say = S $ay
            $nx = $vx * $cay + $vz * $say; $nz = -$vx * $say + $vz * $cay
            $vx = $nx; $vz = $nz
            # Rotate X
            $cax = C $ax; $sax = S $ax
            $ny = $vy * $cax - $vz * $sax; $nz = $vy * $sax + $vz * $cax
            $vy = $ny; $vz = $nz
            # Perspective
            $p = 3.0 / ($vz + 4.0)
            $proj += [PSCustomObject]@{ sx = [int]($cx_ + $vx * $p * $sc); sy = [int]($cy_ + $vy * $p * $sc); z = $vz }
        }

        # Draw edges
        for ($ei = 0; $ei -lt $CUBE_E.Length; $ei += 2) {
            $a = $proj[$CUBE_E[$ei]]; $b = $proj[$CUBE_E[$ei + 1]]
            $dz = ($a.z + $b.z) / 2
            $ec = if ($dz -gt 0.3) { $cc::White } elseif ($dz -gt -0.5) { $cc::Cyan } else { $cc::DarkCyan }
            $dx = [Math]::Abs($b.sx - $a.sx); $dy = [Math]::Abs($b.sy - $a.sy)
            $sx = if ($a.sx -lt $b.sx) { 1 } else { -1 }
            $sy = if ($a.sy -lt $b.sy) { 1 } else { -1 }
            $err = $dx - $dy; $px = $a.sx; $py = $a.sy
            while ($true) {
                $ch = if ($dx -gt $dy) { '─' } elseif ($dy -gt $dx) { '│' } else { '╳' }
                W $px $py $ch $ec
                if ($px -eq $b.sx -and $py -eq $b.sy) { break }
                if ($err * 2 -gt -$dy) { $dx--; $px += $sx; $err -= $dy }
                if ($err * 2 -lt -$dx) { $dy--; $py += $sy; $err += $dx }
            }
        }

        # ── 5. MONITOR POLE + BASE ────────────────────────────────────────
        $poleX = $MON_CX
        $poleTop = $MON_CY + $MON_OH
        W $poleX $poleTop '╦' $bzCol
        W $poleX ($poleTop + 1) '║' $bzCol
        W ($poleX - 3) ($poleTop + 2) '╔' $bzCol
        W ($poleX - 2) ($poleTop + 2) '═' $bzCol
        W ($poleX - 1) ($poleTop + 2) '═' $bzCol
        W $poleX ($poleTop + 2) '╩' $bzCol
        W ($poleX + 1) ($poleTop + 2) '═' $bzCol
        W ($poleX + 2) ($poleTop + 2) '═' $bzCol
        W ($poleX + 3) ($poleTop + 2) '╗' $bzCol

        # ── 6. JOKE TEXT ABOVE MONITOR ────────────────────────────────────
        $joke = $JOKES[([int]($t * 0.5)) % $JOKES.Length]
        $jCol = $PLC[([int]($t * 3)) % $PLC.Count]
        $jx = $MON_CX - [int]($joke.Length / 2)
        for ($i = 0; $i -lt $joke.Length; $i++) {
            W ($jx + $i) ($MON_CY - 2) $joke[$i] $jCol
        }

        # ── 7. SCROLLTEXT AT BOTTOM ───────────────────────────────────────
        $scrollX--
        if ($scrollX -lt (-$SCROLL.Length)) { $scrollX = $W }
        $sY = $H - 1
        $sCol = $PLC[([int]($frame / 3)) % $PLC.Count]
        for ($i = 0; $i -lt $W; $i++) { W $i $sY '░' $cc::DarkBlue }
        $sStart = if ($scrollX -lt 0) { -$scrollX } else { 0 }
        $sDraw  = if ($scrollX -lt 0) { 0 } else { $scrollX }
        $sLen   = [Math]::Min($SCROLL.Length - $sStart, $W - $sDraw)
        if ($sLen -gt 0) {
            for ($i = 0; $i -lt $sLen; $i++) {
                W ($sDraw + $i) $sY $SCROLL[$sStart + $i] $sCol
            }
        }

        Start-Sleep -Milliseconds 40
    }
    [void][Console]::ReadKey($true)
}
finally {
    [Console]::CursorVisible = $true
    [Console]::ResetColor()
    [Console]::Clear()
    Write-Host ""
    Write-Host "  ★  BIGGUS SCREENUS — may your pixels always be numerous  ★  " -ForegroundColor Cyan
    Write-Host ""
}
