param (
    [Parameter(Mandatory = $true)]
    [string]$SolutionFilePath
)

function Get-ProjectsFromSln {
    param (
        [string]$slnPath
    )

    $projects = @{}
    $lines = Get-Content -Path $slnPath

    foreach ($line in $lines) {
        if ($line -match 'Project$"{.*}"$ = "([^"]+)", "([^"]+)", "{.*}') {
            $projectName = $matches[1]
            $projectPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($slnPath), $matches[2])
            $projects += @{$projectPath = @{ Name = $projectName; Dependencies = @() }}
        }
    }

    return $projects
}

function Get-DependencySectionsFromSln {
    param (
        [string]$slnPath,
        [hashtable]$projects
    )

    $lines = Get-Content -Path $slnPath
    $inDependencySection = $false
    $currentProjectGuid = $null

    foreach ($line in $lines) {
        if ($line -match 'Project$"{.*}"$.$\{(.*)}$ has section ProjectDependencies') {
            $currentProjectGuid = $matches[1]
            $inDependencySection = $true
            continue
        }

        if ($inDependencySection -and $line.TrimStart() -eq 'EndProjectSection') {
            $inDependencySection = $false
            $currentProjectGuid = $null
            continue
        }

        if ($inDependencySection -and $line -match '^\s*(\{.*\}) = .*$') {
            $depGuid = $matches[1]

            # Find the project whose GUID matches the dependency
            foreach ($key in $projects.Keys) {
                $projectGuidLine = Get-Content -Path $key | Where-Object { $_ -match '<ProjectGuid>$\{.*\}</ProjectGuid>' }
                if ($projectGuidLine -match '\{.*\}') {
                    $guid = $matches[0]
                    if ($guid -eq $depGuid) {
                        $depName = $projects[$key].Name
                        $projects[$key].DependsOn += $depName
                        break
                    }
                }
            }
        }
    }
}

function Get-ProjectReferencesFromCsProj {
    param (
        [string]$csprojPath,
        [hashtable]$projects
    )

    $projectDir = [System.IO.Path]::GetDirectoryName($csprojPath)
    $xml = [xml](Get-Content -Path $csprojPath)
    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace("ms", "http://schemas.microsoft.com/developer/msbuild/2003")

    $references = $xml.SelectNodes("//ms:ProjectReference/@Include", $ns)

    $deps = @()

    foreach ($ref in $references) {
        $relPath = $ref.Value
        $absPath = [System.IO.Path]::Combine($projectDir, $relPath)
        $absPath = [System.IO.Path]::GetFullPath($absPath)

        if (Test-Path $absPath) {
            $depName = $projects[$absPath].Name
            if ($depName) {
                $deps += $depName
            }
        }
    }

    return $deps
}

function Sort-ProjectsByDependency {
    param (
        [hashtable]$projects
    )

    $sorted = New-Object Collections.ArrayList
    $visited = @{}
    $inStack = @{}

    function Visit {
        param ([string]$name, [string]$path)

        if ($visited.ContainsKey($name)) {
            if ($inStack.ContainsKey($name)) {
                Write-Error "Circular dependency detected at '$name'"
                exit 1
            }
            return
        }

        $visited[$name] = $true
        $inStack[$name] = $true

        foreach ($dep in $projects[$path].DependsOn) {
            $depPath = $projects.Keys | Where-Object { $projects[$_].Name -eq $dep }
            if ($depPath) {
                Visit -name $dep -path $depPath
            }
        }

        $inStack.Remove($name) > $null
        [void]$sorted.Add($path)
    }

    foreach ($path in $projects.Keys) {
        $name = $projects[$path].Name
        if (-not $visited.ContainsKey($name)) {
            Visit -name $name -path $path
        }
    }

    return $sorted.ToArray()
}

# Main Execution

Write-Host "Parsing solution file: $SolutionFilePath"

$slnDir = [System.IO.Path]::GetDirectoryName($SolutionFilePath)
Set-Location -Path $slnDir

$projects = Get-ProjectsFromSln -slnPath $SolutionFilePath
Get-DependencySectionsFromSln -slnPath $SolutionFilePath -projects $projects

# Optionally scan for ProjectReference in each csproj to detect more dependencies
foreach ($path in $projects.Keys) {
    $deps = Get-ProjectReferencesFromCsProj -csprojPath $path -projects $projects
    $projects[$path].DependsOn += $deps
    $projects[$path].DependsOn = $projects[$path].DependsOn | Select-Object -Unique
}

$orderedPaths = Sort-ProjectsByDependency -projects $projects

Write-Host "`nOrdered Projects:"
foreach ($path in $orderedPaths) {
    $name = $projects[$path].Name
    Write-Output "$name -> $path"
}