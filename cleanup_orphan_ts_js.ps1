$ErrorActionPreference = 'Stop'

try {
    $scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    $projectRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path

    $tsRoot = Join-Path $projectRoot 'TypeScript'
    $jsRoot = Join-Path $projectRoot 'Content\JavaScript\TypeScript'

    Write-Host "ProjectRoot: `"$projectRoot`""
    Write-Host "TsRoot: `"$tsRoot`""
    Write-Host "JsRoot: `"$jsRoot`""
    Write-Host ''

    if (-not (Test-Path -LiteralPath $tsRoot -PathType Container)) {
        throw "TypeScript source directory not found: $tsRoot"
    }

    if (-not (Test-Path -LiteralPath $jsRoot -PathType Container)) {
        throw "JavaScript output directory not found: $jsRoot"
    }

    $scanned = 0
    $deleted = 0
    $pendingDeletes = @()
    $expectedOutputs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    function Get-OutputRelativeBasePath {
        param(
            [Parameter(Mandatory = $true)]
            [string]$RelativeTsPath
        )

        $relativeDirectory = Split-Path -Path $RelativeTsPath -Parent
        $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($RelativeTsPath)

        if ([string]::IsNullOrEmpty($relativeDirectory)) {
            return $fileNameWithoutExtension
        }

        return Join-Path $relativeDirectory $fileNameWithoutExtension
    }

    Get-ChildItem -LiteralPath $tsRoot -Recurse -File -Filter '*.ts' |
        Where-Object { -not $_.Name.EndsWith('.d.ts') } |
        ForEach-Object {
            $relativeTsPath = $_.FullName.Substring($tsRoot.Length).TrimStart('\')
            $relativeBasePath = Get-OutputRelativeBasePath -RelativeTsPath $relativeTsPath

            [void]$expectedOutputs.Add((Join-Path $jsRoot ($relativeBasePath + '.js')))
            [void]$expectedOutputs.Add((Join-Path $jsRoot ($relativeBasePath + '.js.map')))
        }

    Get-ChildItem -LiteralPath $jsRoot -Recurse -File |
        Where-Object { $_.Name.EndsWith('.js') -or $_.Name.EndsWith('.js.map') } |
        ForEach-Object {
            $scanned++

            if (-not $expectedOutputs.Contains($_.FullName)) {
                $pendingDeletes += $_.FullName
            }
        }

    Write-Host "Scanned: $scanned"
    Write-Host "Pending Delete: $($pendingDeletes.Count)"
    Write-Host ''

    if ($pendingDeletes.Count -eq 0) {
        Write-Host 'No orphan .js or .js.map files found.'
    } else {
        Write-Host 'Files to delete:'
        foreach ($file in $pendingDeletes) {
            Write-Host $file
        }

        Write-Host ''
        $confirm = Read-Host 'Delete these files? Input y to confirm'
        if ($confirm -eq 'y') {
            foreach ($file in $pendingDeletes) {
                Remove-Item -LiteralPath $file -Force

                if (-not (Test-Path -LiteralPath $file)) {
                    $deleted++
                    Write-Host "[DELETED] $file"
                } else {
                    Write-Warning "Failed to delete $file"
                }
            }
        } else {
            Write-Host 'Delete cancelled.'
        }
    }

    Write-Host ''
    Write-Host "Deleted: $deleted"
}
catch {
    Write-Error $_
}
finally {
    Write-Host ''
    Read-Host 'Press Enter to exit'
}
