Import-Module "C:\Users\davoodn\Documents\PowerShell\AnsiUtils.psm1"
#Import-Module "C:\Users\davoodn\Documents\PowerShell\LineTools.psm1"



class BuildInfo {
    [string]$Name
    [int]$DefinitionId
    [string]$Project    
    
    BuildInfo([string]$name, [int]$defId, [string]$project) {
        $this.Name = $name
        $this.DefinitionId = $defId
        $this.Project = $project
    }
    
    [string]GetClickable()
    {
        return (Get-Link $this.Name "https://alborzscm/SGIBS/$($this.Project)/_build?definitionId=$($this.DefinitionId)")        
    }
}

function Add-MenuItem {
    param ([string]$num, [string]$lable, [string]$description = "")
    return [PSCustomObject]@{ Row = " $num "; Name = "🛠️ $lable"; Description = $(ANSI $description -Style $ITALIC$DIM) }
}

function Show-Azure {
    param (
    	[Parameter(Mandatory = $false)]
        [ValidateSet("dvp", "17", "18", "19", "ui2", "ps", "")]
        [string]$wd = ""
    )
    
    $menu = @()

    $json = Get-Content -Path   "$(Split-Path -Path $PROFILE)\BuildsInfo.json" -Raw | ConvertFrom-Json

    switch ($wd) {
        "dvp" 
        {   
            $index = 1                         
            $menu = $json.Main | ForEach-Object { 
                Add-MenuItem "$index" (Get-BuildLink $_.Name $_.Id $_.Project) 
                $index += 1
            }
            
        }
        "19" 
        {
            [BuildInfo[]]$buids = @(
                [BuildInfo]::new("SGBuild.Rls19_0_x.2020", 2028, "General"),
                [BuildInfo]::new("SGBuild.Mnt19_0_x.2020", 2029, "General"),
                [BuildInfo]::new("GeneralBuild.Dfc19_0_x.2020", 2040, "General")
            )

            $menu = $buids | ForEach-Object { $_.GetClickable() } | ForEach-Object { Add-MenuItem "04" $_ }

        }        
        Default 
        {
                       
        }        
    }

    if ($menu.Length -gt 0) {
        $menu | Format-Table `
                @{Label="    "; Expression={$_.Row}; Width=10; },
                @{Label="Build Name" + (" " * 20); Expression={$_.Name}; Width=60 } -AutoSize
                #@{Label="" + (" " * 48); Expression={$_.Description}; Width=40 } -AutoSize    
    }
    
    
}

function Get-RepoUrl {
    param (       
       [int]$DefinitionId,
       [string]$Project
    )
    return "https://alborzscm/SGIBS/$Project/_build?definitionId=$DefinitionId"
}

function Get-BuildLink {
    param (
        [string]$Name,
        [int]$DefinitionId,
        [string]$ProjName = "General"
    )
    Get-Link $Name "https://alborzscm/SGIBS/$ProjName/_build?definitionId=$DefinitionId"
   
}
