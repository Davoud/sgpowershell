param(
    [string]$SolutionPath = ".\MySolution.sln"
)

# Helper function to resolve full path
function Resolve-ProjectPath($baseDir, $relativePath) {
    return [System.IO.Path]::GetFullPath((Join-Path $baseDir $relativePath -Resolve))
}

# Step 1: Extract .csproj paths from .sln
Write-Host "Reading solution: $SolutionPath"
$slnDir = Split-Path -Path $SolutionPath
$projectLines = Get-Content $SolutionPath | Where-Object { $_ -match '^Project\(' }

$csprojPaths = @{}
foreach ($line in $projectLines) {
    if ($line -match '\"([^\"]+\.csproj)\"') {
        $relPath = $matches[1]
        $fullPath = Resolve-ProjectPath $slnDir $relPath
        $csprojPaths[$fullPath] = @()
    }
}

# Step 2: Parse project references to build dependency map
foreach ($proj in $csprojPaths.Keys) {
    $projDir = Split-Path -Path $proj
    $xml = [xml](Get-Content $proj)

    $refs = $xml.Project.ItemGroup.ProjectReference.Include | ForEach-Object {
        Resolve-ProjectPath $projDir $_
    }

    $csprojPaths[$proj] = $refs
}

# Step 3: Topological sort (Kahn's algorithm)
function TopoSort($graph) {
    $inDegree = @{}
    $graph.Keys | ForEach-Object {
        $inDegree[$_] = 0
    }

    foreach ($node in $graph.Keys) {
        foreach ($dep in $graph[$node]) {
            if ($inDegree.ContainsKey($dep)) {
                $inDegree[$dep]++
            }
        }
    }

    $queue = New-Object System.Collections.Generic.Queue[Object]
    $inDegree.Keys | Where-Object { $inDegree[$_] -eq 0 } | ForEach-Object { $queue.Enqueue($_) }

    $sorted = @()
    while ($queue.Count -gt 0) {
        $n = $queue.Dequeue()
        $sorted += $n
        foreach ($m in $graph[$n]) {
            if ($inDegree.ContainsKey($m)) {
                $inDegree[$m]--
                if ($inDegree[$m] -eq 0) {
                    $queue.Enqueue($m)
                }
            }
        }
    }

    if ($sorted.Count -ne $graph.Count) {
        throw "Cycle detected in project references"
    }

    return $sorted
}

# Step 4: Output sorted project paths
try {
    $sortedProjects = TopoSort $csprojPaths
    Write-Host "`nProjects in dependency order:`n"
    $sortedProjects | ForEach-Object { Write-Output $_ }
} catch {
    Write-Error $_
}
