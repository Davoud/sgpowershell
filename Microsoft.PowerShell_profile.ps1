Import-Module "C:\Users\davoodn\Documents\PowerShell\AnsiUtils.psm1"
Import-Module "C:\Users\davoodn\Documents\PowerShell\LineTools.psm1"
Set-Variable -Name MyWorkSpace -Value ""
Set-Variable -Name DbName -Value ""
Set-Variable -Name Conf
Set-Variable -Name BasePath -Value "D:\Alborz\src\System"
Set-Variable -Name JalaliDate -Value ""
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

$JalaliDate = Get-Date

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
          
    Write-Host " $driveName `u{1F4C2} $($currentFolder -Join ', ') " -NoNewline 
        
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
        [Parameter(Mandatory = $false)]
        [ValidateSet("dvp", "17", "18", "19", "ui2", "ps", "help")]
        [string]$wd = "help"
    )          

    $paths = @{
        "dvp" = "D:\Alborz\src\System\Dvp\Bin\net8.0-windows"	   
        "17" = "D:\Alborz\src\System\Prd\V17\R17.0.x\Bin"
        "18" = "D:\Alborz\src\System\Prd\V18\R18.0.x\Bin"
        "19" = "D:\Alborz\src\System\Prd\V19\R19.0.x\Bin"
        "ui2" = "D:\SystemGit\UI2\apps\farayar"
        "ps" = "C:\Users\davoodn\Documents\PowerShell" 
    }

    if($wd -eq "help") {
        WriteANSI "Supported Input: " $BOLD
        $paths | Format-Table -AutoSize
        return
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
            
            #🛠️
            $Global:MyWorkSpace = if ($bldInfo.Length -gt 2) {        
                 "$(ANSI $bldInfo[0] -Style "$FG_GREEN").$(trimDate($bldInfo[1])).$(ANSI $bldInfo[2] -Style "$FG_YELLOW")"
            } else { "" }
            #🛢️
            $Global:DbName = if($base.DataBase.Length -gt 0) { $base.DataBase } else { "" }
        }
        else {            
            $Global:MyWorkSpace = ""           
            $Global:DbName = ""
        }
             
    } else {
        Write-Error "Path does not exist: $targetPath"
    }

    $Global:JalaliDate = Get-JalaliDate | Convert-NumbersToPersian 
    $Global:JalaliDayOfWeek = $Global:JalaliDayOfWeek = Get-JalaliWeekDay  

    Get-Ws
}

function Get-Ws {
    param( $Style = "$BOLD" )           
    $w = [Math]::Min($Host.UI.RawUI.WindowSize.Width, 100)

    $date = (Get-Date -Format "yyyy - MM - dd")
    $month = (Get-Date -Format "MMMM").PadLeft($w - $date.Length - 5, ' ')
    
    Clear-Host    
    WriteANSI ("═" * $w) -Style $Style    
    WriteANSI "  $JalaliDate  $($JalaliDayOfWeek.PadLeft($w - $JalaliDate.Length - 5, ' ')) " -Style $Style
    WriteAnSI "  $date $month" -Style $Style    
    WriteANSI ("─" * $w) -Style $Style    
    
    $extInfo = $false
    if($Global:MyWorkSpace.Length -gt 0) {
        $e = $Global:MyWorkSpace
        $bld = $e.PadLeft(0, ' ')         
        WriteANSI " 🛠️ $bld" -Style $Style
        $extInfo = $true
    }    
    if($Global:DbName.Length -gt 0) {
        $e = $Global:DbName
        $db = $e.PadLeft(0, ' ')
        WriteANSI " 🛢️ $db" -Style $Style
        $extInfo = $true
    }    
    if($extInfo) {
        WriteANSI ("═" * $w) -Style $Style
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

function Set-Db {
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

function Get-Db {
    Get-DbInfo @($Conf.Web, $Conf.Eng, $Conf.EngH, $Conf.Era)
}

function Get-DbInfo {    
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
    param ([bool]$idDev = $false)
    
    Clear-Host        
    WriteANSI "=== === ===    Rahkaran Application Launcher Menu     === === ===" -Style "$BOLD$INVERT"

    if($dev) {
        $menu = @(        
            menuItem 1 "Framework Solution" "Opens the Framework.sln file"
            menuItem 2 "Process Engine Solution" "Opens the ProcessEngine.sln file"                
            menuItem 3 "Era Solution" "Opens the RuleActionManager.sln file"                       
            menuItem 4 "Form Buidler Solution" "Opens the FormBuilder.sln file" 
            menuSep
            menuItem 0 "Quit" "Quit App Launcher"
        )
    }
    else {
        $menu = @(        
            menuItem 1 "Rahkaran" "Runs Rahkaran.exe (.NETCore)"
            menuItem 2 "Process Engine" "Runs SgProcessEngine.exe"
            menuItem 3 "Era" "Runs SgRuleActionManager.exe"
            menuItem 4 "Workflow Designer" "Runs SgProcessEngineHost.exe"
            menuItem 5 "Server Manager" "Runs ServerManger.exe"      
            menuSep
            menuItem 0 "Quit" "Quit App Launcher"
        )
    }
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
        [int]$choice,
        [bool]$isDev = $false
    )
    #TODO (replce with absoute paths)
    if($dev) {
        $pr = if ($Conf.IsNetCore) { ".." } else { "dfc"}
        switch ($choice) {
            1 { 
                 & "..\$pr\Framework\Framework.sln"
              }              
            2 {
                 & "..\$pr\Components\ProcessEngine\ProcessEngine.sln"
              }
            3 {
                &  "..\$pr\Components\BusinessRuleEngine\BusinessRuleEngine.sln"
              }
            4 {
                &  "..\$pr\Components\FormBuilder\FormBuilder.sln"
              }
            Default { Write-Host "Invalid selection: ($choice) `n" }  
        }
        return;
    }
    
    switch ($choice) {
        1 { 
            Write-Host $TITLEBAR "Rahkaran`a"            
            WriteANSI "                  R A H K A R A N                  " -Style $INVERT$BOLD
            & ".\Rahkaran.exe" #| grep -vE "warn|in app|====>|MetaEntity|\*|\?"
          }
        3 { 
            WriteANSI "Starting SgRuleActionManager.exe..." -Style $BLINK
            Start-Process "SgRuleActionManager.exe"
          }
        2 { 
            Write-Host $TITLEBAR "Process Engine`a"
            WriteANSI "           P R O C E S S    E N G I N E           " -Style $INVERT$BOLD
            & ".\SgProcessEngine.exe" 
          }
        5 { 
            WriteANSI "Starting ServerManager.exe..." -Style $BLINK
            Start-Process "ServerManager.exe"
          }        
        4 { 
            WriteANSI "Starting SgProcessEngineHost.exe..." -Style $BLINK
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
        [int]$code,        
        [switch]$dev
    )
        
    if (-not [string]::IsNullOrEmpty($code)) {
       if($code -match '^\d+$') {
         $choice = [int]$code
         if($choice -ge 1 -and $choice -le 6) {
            Run-Selection -choice $choice -isDev $dev       
            return
         } 
       }       
    }
   
    Show-Menu -isDev $dev
    $choice = Read-Host (ANSI "Enter your choice (1-6)" -Style "$BLINK$FG_YELLOW")
    
    if ($choice -match '^\d+$') {
        $choice = [int]$choice
        Run-Selection -choice $choice $dev               
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
        "Monday"    { return "هبنش ود"  }
        "Tuesday"   { return "هبنش هس"  }
        "Wednesday" { return "هبنش راهچ" }
        "Thursday"  { return "هبنش جنپ" }
        "Friday"    { return "هعمج" }
        "Saturday"  { return "هبنش" }
        "Sunday"    { return "هبنش کـی" }
        default     { return "الله" }
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


function Set-WebConfig {
    param ( 
        [Alias("l", "lock")]       
        [Parameter(Mandatory = $false)]
        [string]$LockFileName = "",

        [Alias("d")]       
        [Parameter(Mandatory = $false)]
        [string]$DataBase = ""
    )    

    $remLines = @('ReportServer', 'IsBpmDevelopmentMode', 'ProcessEngineEnabled') 
    $newLines = @(
        '        <add key="IsBpmDevelopmentMode" value="true" />', 
        '        <add key="ProcessEngineEnabled" value="true" />') 
    
    if($LockFileName.Length -gt 0) { 
        $remLines += @('LockLicenseGuid', 'SoftLicensePath')
        $newLines += @(
            '        <add key="LockLicenseGuid" value="{00000000-0000-0000-0000-00000000000d}" />',
		    "        <add key=`"SoftLicensePath`" value=`"D:\soft\$LockFileName.sgsl`" />")
    }

    Remove-LineByPattern -InputFile $Conf.Web -Patterns $remLines -Verbose

    Add-LinesAfterMatch -InputFile $Conf.Web -MatchPattern "<appSettings>" `
        -LinesToInsert $newLines `
        -InsertAfterFirstOnly `
        -Verbose

    if($DataBase.Length -gt 0) {
        Set-DB -filePath $Web.Conf -name $DataBase
    }
}
