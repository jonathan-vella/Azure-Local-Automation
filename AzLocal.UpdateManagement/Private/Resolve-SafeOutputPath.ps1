function Resolve-SafeOutputPath {
    <#
    .SYNOPSIS
        Validates and resolves a user-supplied output file path, rejecting
        obvious abuse shapes.
    .DESCRIPTION
        Applies defence-in-depth before the module writes a caller-controlled
        path to disk:
        - Rejects null / whitespace-only paths.
        - Rejects paths containing any control character (< 0x20) including
          NUL, CR, LF, TAB, which Windows rejects anyway but which should be
          caught with a clear message long before File.IO does.
        - Rejects any path segment equal to '..' to block trivial traversal
          above the caller's intended root.
        - Caps the resolved absolute path at 248 characters so the containing
          directory plus an 8.3 filename still fits inside the MAX_PATH=260
          limit that Windows PowerShell 5.1 enforces by default.
        - Resolves the path to an absolute form (relative paths are rooted at
          the current working directory).
        - Optionally requires one of an allowed extension set.
    .PARAMETER Path
        The path provided by the caller.
    .PARAMETER AllowedExtensions
        Optional array of extensions (including the leading dot, e.g. '.csv')
        that the path must end with. Comparison is case-insensitive.
    .OUTPUTS
        [string] absolute, validated path.
    .EXAMPLE
        $safe = Resolve-SafeOutputPath -Path $ExportPath -AllowedExtensions '.csv','.json','.xml'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string[]]$AllowedExtensions
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Output path is null or empty."
    }

    # Control-char check (covers NUL 0x00, TAB 0x09, LF 0x0A, CR 0x0D, etc.)
    foreach ($ch in $Path.ToCharArray()) {
        if ([int]$ch -lt 32) {
            throw "Output path contains a control character (0x{0:X2}). Path rejected." -f [int]$ch
        }
    }

    # Reject Windows-invalid filename characters in the leaf portion.
    # (Parent directory may legitimately contain characters like ':' in a
    # drive spec, so we only check the filename.)
    $leaf = [System.IO.Path]::GetFileName($Path)
    if ($leaf) {
        $invalid = [System.IO.Path]::GetInvalidFileNameChars()
        foreach ($c in $invalid) {
            if ($leaf.IndexOf($c) -ge 0) {
                throw "Output path leaf '$leaf' contains an invalid filename character."
            }
        }
    }

    # Traversal segment check.
    $segments = $Path -split '[\\/]+'
    foreach ($seg in $segments) {
        if ($seg -eq '..') {
            throw "Output path contains a '..' traversal segment and was rejected: $Path"
        }
    }

    # Resolve to absolute form. Do NOT require the file to exist (Resolve-Path
    # would throw) - use [IO.Path]::GetFullPath which handles relative inputs
    # against the current directory.
    try {
        $absolute = [System.IO.Path]::GetFullPath($Path)
    }
    catch {
        throw "Output path could not be resolved: $($_.Exception.Message)"
    }

    if ($absolute.Length -gt 248) {
        throw "Resolved output path exceeds 248 characters ($($absolute.Length)): $absolute"
    }

    if ($PSBoundParameters.ContainsKey('AllowedExtensions') -and $AllowedExtensions) {
        $ext = [System.IO.Path]::GetExtension($absolute)
        $ok = $false
        foreach ($allowed in $AllowedExtensions) {
            if ([string]::Equals($ext, $allowed, [System.StringComparison]::OrdinalIgnoreCase)) { $ok = $true; break }
        }
        if (-not $ok) {
            throw "Output path extension '$ext' is not in the allowed set ($(($AllowedExtensions) -join ', '))."
        }
    }

    return $absolute
}
