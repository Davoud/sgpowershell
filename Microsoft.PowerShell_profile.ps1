Import-Module "C:\Users\davoodn\Documents\PowerShell\AnsiUtils.psm1"
Import-Module "C:\Users\davoodn\Documents\PowerShell\LineTools.psm1"
Set-Variable -Name MyWorkSpace -Value ""
Set-Variable -Name DbName -Value ""
Set-Variable -Name Conf
Set-Variable -Name BasePath -Value "D:\Alborz\src\System"
Set-Variable -Name JalaliDate -Value "//"
Set-Variable -Name JalaliDayOfWeek -Value " "
class Config {

    [string]$Web
    [string]$EngH
    [string]$Era
    [string]$Eng
    [bool]$IsNetCore    

    Config([string]$targetPath) {
        $this.IsNetCore = $targetPath -match ".*-windows$"
        $ext = if ($this.IsNetCore) { "dll" } else { "exe" }        
        $this.Web = Join-Path $targetPath "webroot\web.config"
        $this.EngH = Join-Path $targetPath "SgProcessEngineHost.$ext.config"
        $this.Era = Join-Path $targetPath "SgRuleActionManager.$ext.config"
        $this.Eng = Join-Path $targetPath "SgProcessEngine.$ext.config"        
    }
}

function format-drive-name {
    param (
        [string]$dn
    )
    if ($dn -eq "D:" || $dn -eq "D") { return "𝓓" }
    if ($dn -eq "C:" || $dn -eq "C") { return "𝓒" }
    if ($dn -eq "E:" || $dn -eq "E") { return "𝓔" }
    return $dn    
}

function prompt { 
    $oldColor = $Host.UI.RawUI.ForegroundColor       
    $fullPath = [System.IO.Path]::GetFullPath($executionContext.SessionState.Path.CurrentLocation)
    $currentFolder = $fullPath -split '[\\/]' | Where-Object { $_ }    
    $driveName = format-drive-name $currentFolder[0]   
    $currentFolder = $currentFolder 
        | Select-Object -Skip 1 
        | ForEach-Object { (ANSI $_ -Style "$ITALIC$FG_MAGENTA") }
          
    Write-Host "`n $driveName `u{1F4C2} $($currentFolder -Join ', ') " -NoNewline 
        
    if($null -ne (git rev-parse --git-dir)) {
        $branchName  = (git branch --show-current)        
        if($branchName.Length -gt 30) {
            Write-Host "`n   (🌿 $branchName)" -ForegroundColor Cyan
        }
        else {
            Write-Host " (🌿 $branchName)" -ForegroundColor Cyan
        }
    } 
    else {
        Write-Host ""
    }    

    $Host.UI.RawUI.ForegroundColor = $oldColor
    return " ➤ " 
}



function SgInit {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("dvp", "18", "19", "main", "ui2")]
        [string]$wd
    )     
 
    $paths = @{
        "dvp" = "D:\Alborz\src\System\Dvp\Bin\net8.0-windows"
	    "main" = "D:\Alborz\src\System\Main\Bin\net8.0-windows"
        "18" = "D:\Alborz\src\System\Prd\V18\R18.0.x\Bin"
        "19" = "D:\Alborz\src\System\Prd\V19\R19.0.x\Bin"
        "ui2" = "D:\SystemGit\UI2\apps\farayar"
    }

    $targetPath = $paths[$wd]    

    if (Test-Path $targetPath) {	
        Set-Location -Path $targetPath  	   
        
        $global:Conf = [Config]::new($targetPath)
        
        $deployInfo = Join-Path $targetPath "..\DeployInfo.json"               

        if(Test-Path $deployInfo) {            
            $json = Get-Content -Path $deployInfo -Raw | ConvertFrom-Json
            $base = if ($Conf.IsNetCore) { $json.App."net8.0" } else { $json.App }
            $bldInfo = $Base.BuildNumber -Split '[.]' | Where-Object { $_ } | Select-Object -Skip 1            
            $Global:MyWorkSpace = "🛠️$(ANSI $bldInfo[0] -Style "$FG_GREEN").$(trimDate($bldInfo[1])).$(ANSI $bldInfo[2] -Style "$FG_YELLOW")"
            $Global:DbName = "🛢️$(ANSI $base.DataBase -Style "$ITALIC")" 
        }
        else {            
            $Global:MyWorkSpace = $wd            
        }
             
    } else {
        Write-Error "Path does not exist: $targetPath"
    }
    Get-EnvInfo
}

function Get-EnvInfo
{
    $Global:JalaliDate = Get-JalaliDate | Convert-NumbersToPersian
    Write-Host "          $(ANSI $Global:JalaliDate -Style "$BOLD")" 
    Write-Host "          $(ANSI $JalaliDayOfWeek -Style "$BOLD")"
    
    if($Global:MyWorkSpace.Length -gt 0) {
        Write-Host "Build:    $Global:MyWorkSpace"
    }
    
    if($Global:DbName.Length -gt 0) {
        Write-Host "Database: $Global:DbName"
    }    
}

function trimDate
 {
    param (
        [Parameter(Mandatory)]
        [string]$i
    )    
    $p = $i.Substring(5, 8)    
    return "$($p.Substring(0,4))-$($p.Substring(4,2))-$($p.Substring(6,2))"    
}

function npp {
    param (       
        [Parameter(ValueFromPipeline)]             
        [string]$f
    )
    process {
        if(Test-Path $f) {
            Start-Process -FilePath "C:\Program Files\Notepad++\notepad++.exe" -ArgumentList "$f"
        }        
    }
}

function deploy {
    Start-Process -FilePath "C:\Users\davoodn\Desktop\BuildResultDeployer_Latest\Release\net9.0-windows\BuildResultDeployer.exe"
}

function dbset {
    param (       
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]             
        [string]$filePath,

        [Parameter(Mandatory = $true)]
        [string]$name
    )
    process {
        (Get-Content -Path $filePath -Raw) `
            -replace 'connectionString=".*"', `  
            "connectionString=`"Data Source=localhost;Initial Catalog=$name;Integrated Security=False;User ID=sa;Password=1`"" `
            | Set-Content -Path $filePath
    }
}
 
function Set-ServerUrl {
    param (       
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]             
        [string]$filePath
    )
    
    process {
        
        $reps = @{
            ':5001' = ':5000'
            ':5191' = ':5000'
            '127.0.0.1/rahkaranAddress' = 'localhost:5000'
            '127.0.0.1/hcmSelfServiceAddress' = 'localhost:5000'
        }

        $text = Get-Content -Path $filePath -Raw
        
        foreach ($key in $reps.Keys) {
            $text = $text -replace $key, $reps[$key]
        }

        $text | Set-Content -Path $filePath        
    }
}

function db {
    list-db @($Conf.Web, $Conf.Eng, $Conf.EngH, $Conf.Era)
}

function list-db {    
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline=$true)]
        [string[]]$Files
    )
    [int]$count = 1
    $results = foreach ($file in $Files) {
        $content = Get-Content -Path $file -Raw
        if (-not $content) { continue }

        $matchesAll = [regex]::Matches($content, 'connectionString="([^"]+)"')

        foreach ($match in $matchesAll) {
            $connStr = $match.Groups[1].Value
            
            $dataSource = if ($connStr -match 'Data Source=([^;]+)') { $matches[1] } else { $null }
            $catalog    = if ($connStr -match 'Initial Catalog=([^;]+)') { $matches[1] } else { $null }

            [PSCustomObject]@{
                No           = $count
                File         = [System.IO.Path]::GetFileName($file)
                Server       = $dataSource
                Database     = $catalog
            }
            $count += 1
        }
    }    
    $results | Format-Table -AutoSize
}

function Show-Menu {
    Clear-Host        
    WriteANSI "=== === ===    Rahkaran Application Launcher Menu     === === ===" -Style "$BOLD$INVERT"

    $menu = @(        
        menuItem 1 "Rahkaran" "Runs Rahkaran.exe (.NETCore)"
        menuItem 2 "Process Engine" "Runs SgProcessEngine.exe"
        menuItem 3 "Era" "Runs SgRuleActionManager.exe"
        menuItem 4 "Workflow Designer" "Runs SgProcessEngineHost.exe"
        menuItem 5 "Server Manager" "Runs ServerManger.exe"
        menuItem 6 "Reserved" ""
        menuSep         
        menuItem 7 "Framework Solution" "Opens the Framework.sln file"
        menuItem 8 "Process Engine Solution" "Opens the ProcessEngine.sln file"                
        menuItem 9 "Era Solution" "Opens the RuleActionManager.sln file"               
        menuItem 10 "Form Buidler Solution" "Opens the FormBuilder.sln file" 
        menuSep
        menuItem 11 "Database Info" "Display connection string info"
        menuItem 12 "Configurations" "List configuration files"
        menuItem 13 "Help me!" "Rewrite db connection and rahkaran ulr to all configs"
        menuSep
        menuItem 0 "Quit" "Quit App Launcher"
    )
    
    $menu | Format-Table @{Label="     "; Expression={$_.Row}; Width=10; },
                         @{Label="Application                  "; Expression={$_.Name}; Width=60 },
                         @{Label="Description                  "; Expression={$_.Description}; Width=40 } -AutoSize      
}

function menuItem {
    param ([string]$num, [string]$lable, [string]$description)
    return [PSCustomObject]@{ Row = "  $num  "; Name = "`u{1F539} $lable"; Description = $(ANSI $description -Style $ITALIC$DIM) }
}

function menuSep {
    param ([string]$lable = "")
    return [PSCustomObject]@{ Row = ""; Name = "$lable"; Description = "" }    
}

function Run-Selection {
    param (
        [int]$choice
    )

    switch ($choice) {
        1 { 
            Write-Host "`e]0;Rahkaran`a"
            & ".\Rahkaran.exe" 
          }
        3 { 
            Write-Host "Starting SgRuleActionManager.exe..." -ForegroundColor Yellow
            Start-Process "SgRuleActionManager.exe"
          }
        2 { 
            Write-Host "`e]0;Process Engine`a"
            & ".\SgProcessEngine.exe" 
          }
        4 { 
            Write-Host "Starting ServerManager.exe..."
            Start-Process "ServerManager.exe"
          }        
        5 { 
            Write-Host "Starting SgProcessEngineHost.exe..."
            Start-Process "SgProcessEngineHost.exe" }
        0 { 
            return 
          }
        Default { Write-Host "Invalid selection: ($choice) `n" }
    }
}

function Sg {
    param (
        [Parameter(Mandatory = $false)]
        [int]$code
    )

    if (-not [string]::IsNullOrEmpty($code)) {
       if($code -match '^\d+$') {
         $choice = [int]$code
         if($choice -ge 1 -and $choice -le 6) {
            Run-Selection -choice $choice         
            return
         } 
       }       
    }
   
    Show-Menu
    $choice = Read-Host (ANSI "Enter your choice (1-6)" -Style "$BLINK$FG_YELLOW")
    
    if ($choice -match '^\d+$') {
        $choice = [int]$choice
        Run-Selection -choice $choice               
    } else {
        Write-Host "Please enter a valid number.`n"
        Pause
    }

}

function hybernate 
{    
    param (
        [Parameter(Mandatory = $false)]
        [int]$delaySeconds = 10800,

        [Parameter(Mandatory = $false)]
        [int]$name = "HibernateAfter"
    )
    $delaySeconds = 10800
    $Action = New-ScheduledTaskAction -Execute 'shutdown.exe' -Argument '/h'
    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds($delaySeconds)
    Register-ScheduledTask -TaskName "$name_$delaySeconds" -Action $Action -Trigger $Trigger -Description "Hibernates the system after $delaySeconds seconds."
}

function Get-JalaliDate {
    $now = Get-Date;
    $pc = New-Object System.Globalization.PersianCalendar; 
    return "$($pc.GetYear($now))/$( '{0:D2}' -f $pc.GetMonth($now) )/$( '{0:D2}' -f $pc.GetDayOfMonth($now) )"
}

function Get-JalaliWeekDay {
    $now = Get-Date;
    $pc = New-Object System.Globalization.PersianCalendar; 
    $day = $pc.GetDayOfWeek($now);

    switch ($day) {
        "Monday"    { return "هبنش ود" }
        "Tuesday"   { return "س" }
        "Wednesday" { return "چ" }
        "Thursday"  { return "پ" }
        "Friday"    { return "ج" }
        "Saturday"  { return "ش" }
        "Sunday"    { return "ی" }
        default     { return "." }
    }
}

function Get-AnsiLink {
    param (
        [string]$Name,
        [string]$FolderPath
    )
    try {
        $resolvedPath = Resolve-Path -Path $FolderPath -ErrorAction Stop
        $uri = "file:///$($resolvedPath.Path -replace '\\','/')"
                
        $startLink = "`e]8;;$uri`a"
        $endLink = "`e]8;;`a"

        "$startLink$Name$endLink"
    }
    catch {
        Write-Error "Invalid path: $FolderPath"
    }
}


$Global:JalaliDayOfWeek = Get-JalaliWeekDay
