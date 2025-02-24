param(
    [Parameter(Position=0)]
    [string]$Mode,

    [Parameter(Position=1)]
    [string]$InputFile,

    [Parameter(Position=2)]
    [string]$OutputFile
)

# If InputFile not provided, take the first file in current directory
if (-not $InputFile) {
    $InputFile = Get-ChildItem -File | Select-Object -First 1 | ForEach-Object { $_.FullName }
    if (-not $InputFile) {
        Write-Error "No input file found in current directory."
        exit
    }
}

# Resolve input path (must exist)
$InputFile = (Resolve-Path $InputFile).Path

# Auto-generate OutputFile if not provided
if (-not $OutputFile) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)

    if ($Mode -eq "encode") {
        $OutputFile = "$baseName.b64"
    }
    else {
        # For decode, strip .b64 if present
        if ([System.IO.Path]::GetExtension($InputFile) -eq ".b64") {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
        }
        $OutputFile = "$baseName.decoded"
    }
    $OutputFile = Join-Path -Path (Get-Location) -ChildPath $OutputFile
}
elseif (-not [System.IO.Path]::IsPathRooted($OutputFile)) {
    $OutputFile = Join-Path -Path (Get-Location) -ChildPath $OutputFile
}

# --- Encode ---
if ($Mode -eq "encode") {
    try {
        $data = [System.IO.File]::ReadAllBytes($InputFile)
        $ext  = [System.IO.Path]::GetExtension($InputFile)
        $encoded = [System.Convert]::ToBase64String($data)

        # Write extension header + encoded data
        $content = "EXT:$ext`n$encoded"
        [System.IO.File]::WriteAllText($OutputFile, $content)

        Write-Host "File encoded with extension preserved: $OutputFile"
    }
    catch {
        Write-Error "Encoding failed: $_"
    }
}

# --- Decode ---
elseif ($Mode -eq "decode") {
    try {
        $content = Get-Content $InputFile -Raw
        $header, $text = $content -split "`r?`n", 2

        $ext = ".decoded"
        if ($header -like "EXT:*") {
            $ext = $header.Substring(4)
        }

        # If OutputFile was auto-generated, adjust extension
        if ($OutputFile -like "*.decoded") {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
            $OutputFile = Join-Path -Path (Get-Location) -ChildPath "$baseName$ext"
        }

        $decoded = [System.Convert]::FromBase64String($text)
        [System.IO.File]::WriteAllBytes($OutputFile, $decoded)

        Write-Host "File decoded and restored extension: $OutputFile"
    }
    catch {
        Write-Error "Decoding failed: $_"
    }
}
