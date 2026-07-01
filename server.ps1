# server.ps1 - Pure PowerShell HTTP server using System.Net.HttpListener
# Zero installs required - .NET is built into Windows
# Streams PowerShell script output via Server-Sent Events

param(
    [int]$Port = 8888,
    [string]$Script = "installBookstack.ps1"
)

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptPath = Join-Path $ScriptDir "scripts\$Script"
$HtmlPath   = Join-Path $ScriptDir "web\demoscene.html"

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

Write-Host "Server running at http://127.0.0.1:$Port/" -ForegroundColor Cyan
Write-Host "Script: $ScriptPath" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop."

Start-Process "http://127.0.0.1:$Port/demoscene.html"

$streamHandler = {
    param($ctx, $sp)
    $resp = $ctx.Response
    $resp.ContentType = "text/event-stream; charset=utf-8"
    $resp.Headers.Add("Cache-Control", "no-cache")
    $resp.Headers.Add("Access-Control-Allow-Origin", "*")
    $resp.SendChunked = $true
    $writer = [System.IO.StreamWriter]::new($resp.OutputStream, [System.Text.Encoding]::UTF8)
    $writer.AutoFlush = $true
    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = "powershell.exe"
        $psi.Arguments              = "-NoProfile -ExecutionPolicy Bypass -Command `"& { . '$sp' } 5>&1`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        $psi.WorkingDirectory       = Split-Path $sp
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdoutTask = $proc.StandardOutput.ReadLineAsync()
        $stderrTask = $proc.StandardError.ReadLineAsync()
        while (-not $proc.HasExited -or $stdoutTask.Status -eq 'Running' -or $stderrTask.Status -eq 'Running') {
            if ($stdoutTask.IsCompleted) {
                $line = $stdoutTask.Result
                if ($null -ne $line) {
                    $esc = $line -replace "`r", ''
                    $writer.WriteLine("data: $esc"); $writer.WriteLine("")
                }
                $stdoutTask = $proc.StandardOutput.ReadLineAsync()
            }
            if ($stderrTask.IsCompleted) {
                $line = $stderrTask.Result
                if ($null -ne $line -and $line.Trim() -ne '') {
                    $esc = $line -replace "`r", ''
                    $writer.WriteLine("data: $esc"); $writer.WriteLine("")
                }
                $stderrTask = $proc.StandardError.ReadLineAsync()
            }
            Start-Sleep -Milliseconds 20
        }
        $proc.WaitForExit()
        $writer.WriteLine("data: __DONE__"); $writer.WriteLine("")
    } catch {
        try { $writer.WriteLine("data: [ERROR] $_"); $writer.WriteLine("") } catch {}
    } finally {
        try { $writer.Flush(); $resp.OutputStream.Close() } catch {}
    }
}

try {
    while ($listener.IsListening) {
        $asyncResult = $listener.BeginGetContext($null, $null)
        while (-not $asyncResult.IsCompleted) { Start-Sleep -Milliseconds 50 }
        $context = $listener.EndGetContext($asyncResult)
        $path = $context.Request.Url.AbsolutePath

        if ($path -eq "/" -or $path -eq "/demoscene.html") {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($HtmlPath)
                $context.Response.ContentType = "text/html; charset=utf-8"
                $context.Response.ContentLength64 = $bytes.Length
                $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                $context.Response.OutputStream.Close()
            } catch { $context.Response.Abort() }

        } elseif ($path -eq "/healthcheck") {
            $dockerOk = $false
            try {
                $p = Start-Process "docker" -ArgumentList "version" -NoNewWindow -Wait -PassThru -RedirectStandardOutput "NUL"
                $dockerOk = ($p.ExitCode -eq 0)
            } catch {}
            $ramGb    = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
            $cpuCores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
            $diskGb   = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
            $body = "{`"docker`":$($dockerOk.ToString().ToLower()),`"ram_gb`":$ramGb,`"cpu_cores`":$cpuCores,`"disk_gb`":$diskGb}"
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
            $context.Response.ContentType = "application/json"
            $context.Response.StatusCode = 200
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $context.Response.OutputStream.Close()

        } elseif ($path -eq "/stream") {
            $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
            $rs.Open()
            $ps = [System.Management.Automation.PowerShell]::Create()
            $ps.Runspace = $rs
            [void]$ps.AddScript($streamHandler).AddArgument($context).AddArgument($ScriptPath)
            [void]$ps.BeginInvoke()

        } else {
            $context.Response.StatusCode = 404
            $context.Response.OutputStream.Close()
        }
    }
} finally {
    $listener.Stop()
    Write-Host "Server stopped."
}
