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

function Convert-NumbersToPersian {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline)]
        [string]$txtInput
    )
    $map = @{ '0' = '۰'; '1' = '۱'; '2' = '۲'; '3' = '۳'; '4' = '۴'; '5' = '۵'; '6' = '۶'; '7' = '۷'; '8' = '۸'; '9' = '۹' }
    $result = $txtInput.ToCharArray() | ForEach-Object { $map["$_"] ?? " $_ " }
    return $result -Join ''
}

function Set-Title {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$InputString,

        [Parameter(Mandatory=$false)]
        [string]$Pattern = 'http://localhost:\d+',

        [Parameter(Mandatory=$false)]
        [string]$TitlePrefix = "ng " # Optional prefix for the title
    )
    Begin {
        # Optional: Store original title if you want to restore it later (not implemented here)
        # $OriginalTitle = $Host.UI.RawUI.WindowTitle
    }
    Process {        
        if ($InputString -match $Pattern) {           
            $Host.UI.RawUI.WindowTitle = "$TitlePrefix$($matches[0])"
        }        
        Write-Output $InputString
    }
    End {
        
    }
}