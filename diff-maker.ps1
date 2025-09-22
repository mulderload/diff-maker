param (
    [string]$sourcePath,
    [string]$targetPath,
    [string]$outputPath
)

if (-not $sourcePath -or -not $targetPath -or -not $outputPath) {
    Write-Host "All parameters (sourcePath, targetPath, outputPath) must be provided."
    exit
}

if (-not (Test-Path $sourcePath) -or -not (Test-Path $targetPath) -or -not (Test-Path $outputPath)) {
    Write-Host "One or more paths are invalid."
    exit
}

# Scans
$sourceFiles = @{}  # Relative files paths in source (key: filePath / value: hash)
$sourceHashes = @{} # Reverse of sourceFiles         (key: hash     / value: filePath)
$targetFiles = @{}  # Relative file paths in target  (key: filePath / value: hash)

# Results
$newFiles = @()
$copiedFiles = @{}
$deletedFiles = @()

function Get-RelativePath($fullPath, $basePath) {
    return $fullPath.Substring($basePath.Length).TrimStart('\')
}

# Scan files in sourcePath
Get-ChildItem -Path $sourcePath -Recurse -File | ForEach-Object {
    $relPath = Get-RelativePath $_.FullName $sourcePath
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash

    $sourceFiles[$relPath] = $hash
    $sourceHashes[$hash] = $relPath
}

# Scan files in targetPath
Get-ChildItem -Path $targetPath -Recurse -File | ForEach-Object {
    $relPath = Get-RelativePath $_.FullName $targetPath
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash

    $targetFiles[$relPath] = $hash
}

# Compare files from targetPath
foreach ($targetFile in $targetFiles.GetEnumerator()) {
    $targetRelPath = $targetFile.Key
    $targetHash = $targetFile.Value

    if ($sourceFiles.ContainsKey($targetRelPath)) {
        $sourceHash = $sourceFiles[$targetRelPath];
        if ($sourceHash -ne $targetHash) {
            Write-Output "[MODIFY] `t $targetRelPath"
            $newFiles += $targetRelPath;
        }
    } elseif ($sourceHashes.ContainsKey($targetHash)) {
        $sourceRelPath = $sourceHashes[$targetHash];
        Write-Output "[COPY] `t`t $sourceRelPath => $targetRelPath"
        $copiedFiles[$targetRelPath] = $sourceRelPath;
    } else {
        Write-Output "[NEW] `t`t $targetRelPath"
        $newFiles += $targetRelPath;
    }
}

# Compare files from sourcePath (to find deleted files)
foreach($sourceRelPath in $sourceFiles.Keys) {
    if (-not $targetFiles.ContainsKey($sourceRelPath)) {
        Write-Output "[DELETE] `t $sourceRelPath"
        $deletedFiles += $sourceRelPath;
    }
}

# Copy newFiles to outputPath
foreach ($file in $newFiles) {
    $targetFilePath = Join-Path $targetPath $file
    $destinationFilePath = Join-Path $outputPath $file

    # Créer les sous-dossiers nécessaires dans le dossier de destination
    $destinationDir = Split-Path $destinationFilePath -Parent
    if (-not (Test-Path $destinationDir)) {
        # Créer les répertoires parents nécessaires
        New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
    }

    # Copier le fichier
    Write-Output "[ADD] $destinationFilePath"
    Copy-Item -Path $targetFilePath -Destination $destinationFilePath -Force
}

# Generate nsis.txt
$nsisFilePath = "$outputPath\nsis.txt"

if (Test-Path $nsisFilePath) {
    # Clear file if already exists
    Clear-Content $nsisFilePath 
} else {
    # Or create empty file
    New-Item -Path $nsisFilePath -ItemType File | Out-Null
}

# Write "CopyFiles" instructions
foreach ($targetRelPath in $copiedFiles.Keys | Sort-Object) {
    $sourceRelPath = $copiedFiles[$targetRelPath]
    
    # Ajouter une ligne CopyFiles dans le fichier NSIS
    Add-Content -Path $nsisFilePath -Value "CopyFiles ""$sourceRelPath"" ""$targetRelPath"""
}

# Write "Delete" instructions
foreach ($deletedFile in $deletedFiles | Sort-Object) {
    # Ajouter une ligne Delete dans le fichier NSIS
    Add-Content -Path $nsisFilePath -Value "Delete ""$deletedFile"""
}

Write-Output "nsis.txt generated !"
