# server.ps1 - Pure PowerShell HTTP server, no installs required
# Uses System.Net.HttpListener (built into .NET / Windows)
# Runs mock-install.ps1 and streams output via Server-Sent Events

param(
    [int]$Port = 8888,
    [string]$Script = "installBookstack.ps1"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptPath = Join-Path $ScriptDir $Script
$HtmlPath   = Join-Path $ScriptDir "demoscene.html"

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "Server running at http://localhost:$Port/"
Write-Host "Press Ctrl+C to stop."

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

Write-Host "Server running at http://127.0.0.1:$Port/"
Write-Host "Press Ctrl+C to stop."

Start-Process "http://127.0.0.1:$Port/demoscene.html"

$ScriptDir_ = $ScriptDir
$ScriptPath_ = $ScriptPath
$HtmlPath_ = $HtmlPath

try {
    while ($listener.IsListening) {
        # GetContextAsync lets us handle each request in a runspace so /stream doesn't block
        $task = $listener.GetContextAsync()
        while (-not $task.IsCompleted) { Start-Sleep -Milliseconds 50 }
        $context = $task.Result
        $req  = $context.Request
        $resp = $context.Response
        $path = $req.Url.AbsolutePath

        if ($path -eq "/demoscene.html" -or $path -eq "/") {
            $bytes = [System.IO.File]::ReadAllBytes($HtmlPath_)
            $resp.ContentType = "text/html; charset=utf-8"
            $resp.ContentLength64 = $bytes.Length
            $resp.OutputStream.Write($bytes, 0, $bytes.Length)
            $resp.OutputStream.Close()

        } elseif ($path -eq "/stream") {
            # Run in a separate runspace so it doesn't block the main loop
            $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
            $rs.Open()
            $rs.SessionStateProxy.SetVariable('context', $context)
            $rs.SessionStateProxy.SetVariable('ScriptPath', $ScriptPath_)
            $ps = [System.Management.Automation.PowerShell]::Create()
            $ps.Runspace = $rs
            $ps.AddScript({
                param($ctx, $sp)
                $resp = $ctx.Response
                $resp.ContentType = "text/event-stream"
                $resp.Headers.Add("Cache-Control", "no-cache")
                $resp.Headers.Add("Access-Control-Allow-Origin", "*")
                $resp.SendChunked = $true
                $writer = [System.IO.StreamWriter]::new($resp.OutputStream, [System.Text.Encoding]::UTF8)
                $writer.AutoFlush = $true
                try {
                    $psi = [System.Diagnostics.ProcessStartInfo]::new()
                    $psi.FileName = "powershell.exe"
                    # -Command with 5>&1 merges Write-Host (stream 5) into stdout
                    # RedirectStandardError captures Docker/stderr output too
                    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { . '$sp' } 5>&1`""
                    $psi.RedirectStandardOutput = $true
                    $psi.RedirectStandardError  = $true
                    $psi.UseShellExecute = $false
                    $psi.CreateNoWindow  = $true
                    $proc = [System.Diagnostics.Process]::Start($psi)
                    while (-not $proc.StandardOutput.EndOfStream) {
                        $line = $proc.StandardOutput.ReadLine()
                        $escaped = $line -replace '\\', '\\\\' -replace "`n", '\n' -replace "`r", ''
                        $writer.WriteLine("data: $escaped")
                        $writer.WriteLine("")
                    }
                    $proc.WaitForExit()
                    $writer.WriteLine("data: __DONE__")
                    $writer.WriteLine("")
                } catch {
                    $writer.WriteLine("data: [ERROR] $_")
                    $writer.WriteLine("")
                } finally {
                    $writer.Flush()
                    $resp.OutputStream.Close()
                }
            }).AddArgument($context).AddArgument($ScriptPath_)
            $ps.BeginInvoke() | Out-Null

        } else {
            $resp.StatusCode = 404
            $resp.OutputStream.Close()
        }
    }
} finally {
    $listener.Stop()
}
