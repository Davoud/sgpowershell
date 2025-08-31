# PowerShell script to display text in all 16 standard colors

# Array of all 16 standard console colors
$colors = @(
    "Black",
    "DarkBlue",
    "DarkGreen",
    "DarkCyan",
    "DarkRed",
    "DarkMagenta",
    "DarkYellow",
    "Gray",
    "DarkGray",
    "Blue",
    "Green",
    "Cyan",
    "Red",
    "Magenta",
    "Yellow",
    "White"
)

# Sample sentence to display
$sentence = "The quick brown fox jumps over the lazy dog"

Write-Host "Displaying sentence in all 16 standard colors:" -ForegroundColor White
Write-Host ""

# Display the sentence in each color
foreach ($color in $colors) {
    Write-Host "$color`: $sentence" -ForegroundColor $color
}

Write-Host ""
Write-Host "Background color examples:" -ForegroundColor White
Write-Host ""

# Display with background colors (using contrasting foreground colors)
$backgroundColors = @(
    @{Color = "Black"; Foreground = "White"},
    @{Color = "DarkBlue"; Foreground = "White"},
    @{Color = "DarkGreen"; Foreground = "White"},
    @{Color = "DarkCyan"; Foreground = "White"},
    @{Color = "DarkRed"; Foreground = "White"},
    @{Color = "DarkMagenta"; Foreground = "White"},
    @{Color = "DarkYellow"; Foreground = "Black"},
    @{Color = "Gray"; Foreground = "Black"},
    @{Color = "DarkGray"; Foreground = "White"},
    @{Color = "Blue"; Foreground = "White"},
    @{Color = "Green"; Foreground = "Black"},
    @{Color = "Cyan"; Foreground = "Black"},
    @{Color = "Red"; Foreground = "White"},
    @{Color = "Magenta"; Foreground = "White"},
    @{Color = "Yellow"; Foreground = "Black"},
    @{Color = "White"; Foreground = "Black"}
)

$sentence2 = "PowerShell Colors"
foreach ($bg in $backgroundColors) {
    Write-Host "$($bg.Color): $sentence2" -BackgroundColor $bg.Color -ForegroundColor $bg.Foreground
}

Write-Host ""
Write-Host "Complete! All 16 standard colors displayed." -ForegroundColor Green