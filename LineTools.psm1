function RemoveLine {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Pattern
    )

    if (-Not (Test-Path $Path)) {
        Write-Error "File '$Path' does not exist."
        return
    }

    $lines = Get-Content $Path
    $filteredLines = $lines | Where-Object { $_ -notmatch $Pattern }
    $filteredLines | Set-Content $Path
}

function InsertLineBefore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$NewLine
    )

    if (-Not (Test-Path $Path)) {
        Write-Error "File '$Path' does not exist."
        return
    }

    $lines = Get-Content $Path
    $output = @()

    foreach ($line in $lines) {
        if ($line -match $Pattern) {
            $output += $NewLine
        }
        $output += $line
    }

    $output | Set-Content $Path
}

function Colorify {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Color
    )
    process {
        $hex = $Color.TrimStart('#')

        if ($hex.Length -ne 6) {
            Write-Error "Color must be a 6-character hex string (e.g. FF00EE)"
            return $Text
        }

        try {
            $R = [Convert]::ToInt32($hex.Substring(0, 2), 16)
            $G = [Convert]::ToInt32($hex.Substring(2, 2), 16)
            $B = [Convert]::ToInt32($hex.Substring(4, 2), 16)
        } catch {        
            return $Text
        }
        
        return "`e[38;2;$R;$G;$B" + "m$Text`e[0m"
    }
}