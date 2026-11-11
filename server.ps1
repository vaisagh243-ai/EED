param (
    [int]$Port = 8080
)

$Root = $PSScriptRoot
if ([string]::IsNullOrEmpty($Root)) {
    $Root = (Get-Location).Path
}

$ip = [System.Net.IPAddress]::Loopback
$listener = New-Object System.Net.Sockets.TcpListener($ip, $Port)

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".json" = "application/json; charset=utf-8"
}

try {
    $listener.Start()
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "  KCRAFT STUDIO WEB SERVER ONLINE" -ForegroundColor Yellow
    Write-Host "  URL: http://127.0.0.1:$Port/" -ForegroundColor Cyan
    Write-Host "  Root: $Root" -ForegroundColor Gray
    Write-Host "  Press Ctrl+C to terminate." -ForegroundColor DarkGray
    Write-Host "==========================================================" -ForegroundColor Green

    # Try to open browser
    Start-Process "http://127.0.0.1:$Port/" -ErrorAction SilentlyContinue

    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $writer = New-Object System.IO.BinaryWriter($stream)

        $requestLine = $reader.ReadLine()
        if (-not [string]::IsNullOrEmpty($requestLine)) {
            $tokens = $requestLine.Split(' ')
            if ($tokens.Length -ge 2 -and $tokens[0] -eq 'GET') {
                $rawUrl = $tokens[1]
                $cleanUrl = [System.Uri]::UnescapeDataString($rawUrl.Split('?')[0])
                if ($cleanUrl -eq "/" -or [string]::IsNullOrWhiteSpace($cleanUrl)) {
                    $cleanUrl = "/index.html"
                }

                $filePath = [System.IO.Path]::Combine($Root, $cleanUrl.TrimStart("/").Replace("/", [System.IO.Path]::DirectorySeparatorChar))

                if ([System.IO.File]::Exists($filePath)) {
                    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                    $mime = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { "application/octet-stream" }
                    $bytes = [System.IO.File]::ReadAllBytes($filePath)

                    $header = "HTTP/1.1 200 OK`r`nContent-Type: $mime`r`nContent-Length: $($bytes.Length)`r`nAccess-Control-Allow-Origin: *`r`nConnection: close`r`n`r`n"
                    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)

                    $writer.Write($headerBytes)
                    $writer.Write($bytes)
                    $writer.Flush()
                } else {
                    $notFoundBody = [System.Text.Encoding]::UTF8.GetBytes("<html><body><h1>404 Not Found</h1><p>$cleanUrl</p></body></html>")
                    $header = "HTTP/1.1 404 Not Found`r`nContent-Type: text/html`r`nContent-Length: $($notFoundBody.Length)`r`nConnection: close`r`n`r`n"
                    $writer.Write([System.Text.Encoding]::ASCII.GetBytes($header))
                    $writer.Write($notFoundBody)
                    $writer.Flush()
                }
            }
        }

        $writer.Close()
        $reader.Close()
        $stream.Close()
        $client.Close()
    }
} finally {
    $listener.Stop()
}
