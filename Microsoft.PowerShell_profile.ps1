#Import-Module "C:\Users\davoodn\Documents\PowerShell\AnsiUtils.psm1"
Import-Module "C:\Users\davoodn\Documents\PowerShell\LineTools.psm1"
Import-Module "C:\Users\davoodn\Documents\PowerShell\WorkItems.psm1"

Set-Variable -Name MyWorkSpace -Value ""
Set-Variable -Name DbName -Value ""
Set-Variable -Name Conf
Set-Variable -Name BasePath -Value "D:\Alborz\src\System"
Set-Variable -Name JalaliDate -Value ""
Set-Variable -Name JalaliDayOfWeek -Value " "
Set-Variable -Name HasInit -Value $false
Set-Variable -Name CodeLine -Value "dfc"

Set-Alias -Name edit -Value micro.exe
Set-Alias -Name zip -Value Compress-Archive
Set-Alias -Name unzip -Value Expand-Archive

class Config {

    [string]$Web
    [string]$EngH
    [string]$Era
    [string]$Eng
    [string]$SrvM
    [bool]$IsNetCore    

    Config([string]$targetPath) {
        $this.IsNetCore = $targetPath -match ".*-windows$"
        $ext = if ($this.IsNetCore) { "dll" } else { "exe" }        
        $this.Web = Join-Path $targetPath "webroot\web.config"
        $this.EngH = Join-Path $targetPath "SgProcessEngineHost.$ext.config"
        $this.Era = Join-Path $targetPath "SgRuleActionManager.$ext.config"
        $this.Eng = Join-Path $targetPath "SgProcessEngine.$ext.config" 
        $this.SrvM = Join-Path $targetPath "ServerManager.$ext.config"        
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
    if(-not $HasInit) {
        return "$PWD>"
    }
  
    if($null -ne (git rev-parse --git-dir)) {        
        return promptgit
    }

    $oldColor = $Host.UI.RawUI.ForegroundColor       
    $fullPath = [System.IO.Path]::GetFullPath($executionContext.SessionState.Path.CurrentLocation)
    $currentFolder = $fullPath -split '[\\/]' | Where-Object { $_ }    
    $driveName = format-drive-name $currentFolder[0]   
    $currentFolder = $currentFolder 
        | Select-Object -Skip 1 
        | ForEach-Object { (ANSI $_ -Style "$ITALIC$FG_MAGENTA") }
          
    Write-Host " $driveName `u{1F4C2} $($currentFolder -Join ', ') "     
    
    $Host.UI.RawUI.ForegroundColor = $oldColor
    return " ➤ " 
}

function promptgit {
    $branchName  = (git branch --show-current)     
    $fullPath = [System.IO.Path]::GetFullPath($executionContext.SessionState.Path.CurrentLocation)   
    
    $blen = $branchName.Length
    $plen = $fullPath.Length

    $branchNameStyled = (ANSI $branchName -Style "$ITALIC$FG_BLUE")
    $fullPathStyled = (ANSI $fullPath -Style "$BOLD$FG_GREEN")

    $width = [Math]::Min($Host.UI.RawUI.WindowSize.Width, 100)
   
    $line = " ─" * ($width / 4)
    $bline = "━" * ($width - 1)     
    
    if($blen + $plen + 10 -gt $width) {
        Write-Host "┏$bline" 
        Write-Host "┃ `u{1F4C2} $fullPathStyled"
        Write-Host "┃ 🌿 $branchNameStyled" 
        Write-Host "┖─┯───$line"           
        return "  ╰─▶ " 
    }
    else {
        Write-Host "┏$bline" 
        Write-Host "┃ `u{1F4C2} $fullPathStyled (🌿$branchNameStyled)" 
        Write-Host "┖─┯───$line"         
            return "  ╰─▶ " 
    }    
}

function SgInit {
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet("dvp", "17", "18", "19", "19+", "ui2", "ps", "help", "20", "20+")]
        [string]$wd = "help",

        [switch]$NoClear

    )          

    $paths = @{
        "dvp" = "D:\Alborz\src\System\Dvp\Bin\net8.0-windows"	   
        "17" = "D:\Alborz\src\System\Prd\V17\R17.0.x\Bin"
        "18" = "D:\Alborz\src\System\Prd\V18\R18.0.x\Bin"
        "19" = "D:\Alborz\src\System\Prd\V19\R19.0.x\Bin"
        "19+" = "D:\Alborz\src\System\Prd\V19\R19.1.x\Bin\net8.0-windows"
        "20" = "D:\Alborz\src\System\Prd\V20\R20.0.x\Bin\net8.0-windows"
        "20+" = "D:\Alborz\src\System\Prd\V20\R20.1.x\Bin\net8.0-windows"
        "ui2" = "D:\SystemGit\UI2\apps\farayar"
        "ps" = "C:\Users\davoodn\Documents\PowerShell" 
    }

    if($wd -eq "help") {
        WriteANSI "Supported Input: " $BOLD
        $paths | Format-Table -AutoSize
        return
    }

    if ($wd -eq "dvp") {
        $Global:CodeLine = ".."
    }

    $targetPath = $paths[$wd]    

    if (Test-Path $targetPath) {
        $Global:BasePath = $targetPath	
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

    $Global:HasInit = $true

    if($NoClear) {
        Get-Ws
    }
    else {
        Get-Ws -ClearHost
    }
}

function Get-Ws {
    param(
        $Style = "$BOLD",
        [switch]$ClearHost
    )           
    $w = [Math]::Min($Host.UI.RawUI.WindowSize.Width, 100)

    $date = (Get-Date -Format "yyyy - MM - dd")
    $month = (Get-Date -Format "MMMM").PadLeft($w - $date.Length - 5, ' ')
    
    if($ClearHost) {
        Clear-Host    
    }
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
        [string]$name,

        [Parameter(Mandatory = $false)]
        [string]$server = "localhost",

        [Parameter(Mandatory = $false)]
        [string]$uid = "sa",

        [Parameter(Mandatory = $false)]
        [string]$password = "1"

    )
    process 
    {
        (Get-Content -Path $filePath -Raw) `
            -replace 'connectionString=".*"', `
            "connectionString=`"Data Source=$server;Initial Catalog=$name;Integrated Security=False;User ID=$uid;Password=$password`"" `
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

        $text | Set-Content -Path $filePath -Verbose        
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
    Write-Header "Rahkaran Application Launcher Menu"    

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
        $pr = Join-Path $BasePath ".." ".." $Global:CodeLine
        switch ($choice) {
            1 { 
                 & "$pr\Framework\Framework.sln"
              }              
            2 {
                 & "$pr\Components\ProcessEngine\ProcessEngine.sln"
              }
            3 {
                &  "$pr\Components\BusinessRuleEngine\BusinessRuleEngine.sln"
              }
            4 {
                &  "$pr\Components\FormBuilder\FormBuilder.sln"
              }
            Default { Write-Host "Invalid selection: ($choice) `n" }  
        }
        return;
    }
        
    switch ($choice) {
        1 { 
            Write-Host $TITLEBAR "Rahkaran`a"     
            Write-Header "R A H K A R A N "
            Restart-Service -Name Redis -Verbose			            
            & (Join-Path $BasePath "Rahkaran.exe")
          }
        3 { 
            WriteANSI "Starting SgRuleActionManager.exe..." -Style $BLINK
            Start-Process "SgRuleActionManager.exe"
          }
        2 { 
            Write-Host $TITLEBAR "Process Engine`a"
            Write-Header "P R O C E S S    E N G I N E"            
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

function Write-Header {
    param (
        [string]$title = ""
    )
    $width = [Math]::Min($Host.UI.RawUI.WindowSize.Width, 100)
    $spaces = " " * (($width / 2) - ($title.Length / 2))
    WriteANSI "$spaces$title$spaces" -Style $INVERT$BOLD	
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



function Set-All {
    param ( 
        [Alias("l", "lock")]       
        [Parameter(Mandatory = $false)]
        [string]$LockFileName = "",

        [Alias("d")]       
        [Parameter(Mandatory = $false)]
        [string]$DataBase = ""
    )    

    $remLines = @('ReportServerUrl', 'IsBpmDevelopmentMode', 'ProcessEngineEnabled') 
    $newLines = @(
        '    <add key="IsBpmDevelopmentMode" value="true" />', 
        '    <add key="ProcessEngineEnabled" value="true" />',
        '	 <add key="ReportServerUrl" value="" />') 
    
    if($LockFileName.Length -gt 0) { 
        $remLines += @('LockLicenseGuid', 'SoftLicensePath')
        $newLines += @(
            '        <add key="LockLicenseGuid" value="{00000000-0000-0000-0000-00000000000d}" />',
		    "        <add key=`"SoftLicensePath`" value=`"D:\soft\$LockFileName.sgsl`" />")
    }

    Remove-LineByPattern -InputFile $Conf.Web -Patterns $remLines -Verbose
    #TODO: $cleanedXmlContent = $xmlContent -replace '<!--.*?-->', ''
    Add-LinesAfterMatch -InputFile $Conf.Web -MatchPattern "<appSettings>" `
        -LinesToInsert $newLines `
        -InsertAfterFirstOnly `
        -Verbose

    if($DataBase.Length -gt 0) {
        Set-Db -filePath $Conf.Web -name $DataBase
        Set-Db -filePath $Conf.Eng -name $DataBase
    }
    
    Set-ServerUrl -filePath $Conf.Eng
    Set-ServerUrl -filePath $Conf.EngH
    Set-ServerUrl -filePath $Conf.SrvM

}


function Get-DllVersion {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-Error "DLL file not found at: $Path"
        return $null
    }

    try {
        $fileInfo = Get-Item $Path
        $versionInfo = $fileInfo.VersionInfo     
        return $versionInfo.FileVersion        

    } catch {
        Write-Error "An error occurred while retrieving DLL version for '$Path': $($_.Exception.Message)"
        return $null
    }
}

function SgBuild {    
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )   
    
    if ((Split-Path -Path $Path -Extension) -eq "csproj") 
    {
        [xml]$csproj = Get-Content -Path $Path
        $asmName = $csproj.SelectSingleNode("//AssemblyName").InnerText 
        $file = "$(Join-Path $BasePath $asmName).dll"
        $Version = Get-DllVersion -Path $file
            
        & dotnet build $Path --verbosity m -p:Version=$Version  
            
        Get-DllVersion $file | Write-Host
        $ ls $file
    }
    else {        
        & dotnet build $Path --verbosity m -f net8.0-windows | grep -v "warning"        
    }      
}

function Get-Last {
	param (
		[Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [string]$Path = "."
	)

	Get-childItem -Path $Path -File `
		| Sort-Object LastWriteTime -Descending `
		| Select-Object -First 1 `
		| ForEach-Object { $_.Name } 
}
