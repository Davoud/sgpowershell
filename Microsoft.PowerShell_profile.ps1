Import-Module "C:\Users\davoodn\Documents\PowerShell\AnsiUtils.psm1"
Import-Module "C:\Users\davoodn\Documents\PowerShell\LineTools.psm1"
Set-Variable -Name MyWorkSpace -Value "`u{1F349}"
Set-Variable -Name Conf
Set-Variable -Name BasePath -Value "D:\Alborz\src\System"
Set-Variable -Name JalaliDate
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


function prompt { 
    $oldColor = $Host.UI.RawUI.ForegroundColor   
    
    $fullPath = [System.IO.Path]::GetFullPath($executionContext.SessionState.Path.CurrentLocation)

    $currentFolder = $fullPath -split '[\\/]' `
         | Where-Object { $_ } `         
         | ForEach-Object { 
            if ($_ -eq "D:") { return "𝓓:" }
            if ($_ -eq "C:") { return "𝓒:" }
            if ($_ -eq "E:") { return "𝓔:" }
            return (ANSI $_ -Style "$ITALIC$FG_MAGENTA") 
         } 

    Write-Host "`n$(Get-AnsiLink `u{1F4C2} $fullPath) $($currentFolder -Join ', ') " -NoNewline 
        
    if($null -ne (git rev-parse --git-dir)) {        
        Write-Host "`n   [$(git branch --show-current)]" -ForegroundColor Cyan
    } else {        
        Write-Host "🛠️ $MyWorkSpace" -ForegroundColor Blue   
    }

    $Host.UI.RawUI.ForegroundColor = $oldColor
    return "🔹 $JalaliDate ➤ " 
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

    $global:JalaliDate = Get-JalaliDate

    if (Test-Path $targetPath) {	
        Set-Location -Path $targetPath  	   
        
        $global:Conf = [Config]::new($targetPath)
        
        $deployInfo = Join-Path $targetPath "..\DeployInfo.json"               

        if(Test-Path $deployInfo) {            
            $json = Get-Content -Path $deployInfo -Raw | ConvertFrom-Json
            $base = if ($Conf.IsNetCore) { $json.App."net8.0" } else { $json.App }
            $bldInfo = $Base.BuildNumber -Split '[.]' | Where-Object { $_ } | Select-Object -Skip 1            
            $global:MyWorkSpace = "$(ANSI $bldInfo[0] -Style "$FG_GREEN").$(trimDate($bldInfo[1])).$(ANSI $bldInfo[2] -Style "$FG_YELLOW") 🛢️ $(ANSI $base.DataBase -Style "$ITALIC")" #`u{1F4C0}
        }
        else {            
            $global:MyWorkSpace = $wd            
        }
        
    } else {
        Write-Error "Path does not exist: $targetPath"
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
 
function server-set {
    param (       
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]             
        [string]$filePath
    )
    
    process {
        
        $reps = @{
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
        [PSCustomObject]@{ Row = "  1  "; Name = "`u{1F539} Rahkaran           "; Description = "(Rahkaran.exe)" }
        [PSCustomObject]@{ Row = "  2  "; Name = "`u{1F539} Era                "; Description = "(SgRuleActionManager.exe)" }
        [PSCustomObject]@{ Row = "  3  "; Name = "`u{1F539} Process Engine     "; Description = "(SgProcessEngine.exe)" }
        [PSCustomObject]@{ Row = "  4  "; Name = "`u{1F539} Server Manager     "; Description = "(ServerManger.exe)" }
        [PSCustomObject]@{ Row = "  5  "; Name = "`u{1F539} Workflow Designer  "; Description = "(SgProcessEngineHost.exe)" }
        [PSCustomObject]@{ Row = "  6  "; Name = "`u{1F539} Quit               "; Description = "(Exit the launcher)" }
    )
    
    $menu | Format-Table @{Label="     "; Expression={$_.Row}; Width=10; },
                         @{Label="Application                  "; Expression={$_.Name}; Width=60 },
                         @{Label="Description                  "; Expression={$_.Description}; Width=40 } -AutoSize      
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
        2 { 
            Write-Host "Starting SgRuleActionManager.exe..." -ForegroundColor Yellow
            Start-Process "SgRuleActionManager.exe"
          }
        3 { 
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
        6 { exit }
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
    $input = Read-Host (ANSI "Enter your choice (1-6)" -Style "$BLINK$FG_YELLOW")
    
    if ($input -match '^\d+$') {
        $choice = [int]$input
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