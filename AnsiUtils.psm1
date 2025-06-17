# ANSIUtils.psm1
#ANSI "This is bold red!" -Style "$BOLD$FG_RED"
#ANSI "Custom RGB background" -Style "$(BGFromRGB 0 150 255)$FG_WHITE"
# Reset
$global:RESET = "`e[0m"
$global:TITLEBAR = "`e]0;"
$global:HLINK = "e]8;;"
$global:BEL = "`a"

# Text Styles
$global:BOLD       = "`e[1m"
$global:DIM        = "`e[2m"
$global:ITALIC     = "`e[3m"
$global:UNDERLINE  = "`e[4m"
$global:BLINK      = "`e[5m"
$global:INVERT     = "`e[7m"
$global:HIDDEN     = "`e[8m"

# Foreground Colors
$global:FG_BLACK   = "`e[30m"
$global:FG_RED     = "`e[31m"
$global:FG_GREEN   = "`e[32m"
$global:FG_YELLOW  = "`e[33m"
$global:FG_BLUE    = "`e[34m"
$global:FG_MAGENTA = "`e[35m"
$global:FG_CYAN    = "`e[36m"
$global:FG_WHITE   = "`e[37m"
$global:FG_DEFAULT = "`e[39m"

# Background Colors
$global:BG_BLACK   = "`e[40m"
$global:BG_RED     = "`e[41m"
$global:BG_GREEN   = "`e[42m"
$global:BG_YELLOW  = "`e[43m"
$global:BG_BLUE    = "`e[44m"
$global:BG_MAGENTA = "`e[45m"
$global:BG_CYAN    = "`e[46m"
$global:BG_WHITE   = "`e[47m"
$global:BG_DEFAULT = "`e[49m"

# Cursor Control
$global:CURSOR_HIDE    = "`e[?25l"
$global:CURSOR_SHOW    = "`e[?25h"
$global:SAVE_CURSOR    = "`e[s"
$global:RESTORE_CURSOR = "`e[u"
$global:CLEAR_SCREEN   = "`e[2J"
$global:CLEAR_LINE     = "`e[K"

# Functions
function WriteANSI {
    param(
        [string]$Text,
        [string]$Style = "",
        [switch]$NoNewLine
    )
    $cmd = "$Style$Text$global:RESET"
    if ($NoNewLine) {
        Write-Host $cmd -NoNewline
    } else {
        Write-Host $cmd
    }
}

function ANSI {
    param(
        [string]$Text,
        [string]$Style = ""
    )
    return "$Style$Text$global:RESET"
}

function FGFromRGB {
    param(
        [int]$R,
        [int]$G,
        [int]$B
    )
    return "`e[38;2;$R;$G;$B;m"
}

function BGFromRGB {
    param(
        [int]$R,
        [int]$G,
        [int]$B
    )
    return "`e[48;2;$R;$G;$B;m"
}

function Get-PadLeft {
    param(
        [string]$Text,        
        [int]$TotalWidth,
        [char]$WithChar = ' '
    )          

    $ansiPattern = "`e\[[\d;]*[a-zA-Z]"
    $visibleLength = ($Text -replace $ansiPattern).Length

    $padLength = $TotalWidth - $visibleLength    

    if ($padLength -le 0) {
        return $Text
    }    
    return ("$WithChar" * $padLength) + $Text     
}
