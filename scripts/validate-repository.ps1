[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$required = @(
    'SKILL.md',
    'README.md',
    'agents/openai.yaml',
    'docs/README.md'
)
$errors = [System.Collections.Generic.List[string]]::new()

foreach ($relativePath in $required) {
    $path = Join-Path $Root $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("Falta el archivo requerido: $relativePath")
    }
}

$markdownFiles = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.md' |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
$linkPattern = '\[[^\]]*\]\(([^)]+)\)'

foreach ($file in $markdownFiles) {
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        $lineNumber++
        foreach ($match in [regex]::Matches($line, $linkPattern)) {
            $target = $match.Groups[1].Value.Trim().Trim('<', '>')
            if ($target -match '^(?:https?://|mailto:|#)') { continue }

            $pathPart = ($target -split '#', 2)[0].Split('?')[0]
            if ([string]::IsNullOrWhiteSpace($pathPart)) { continue }
            $resolved = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $pathPart))
            if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
                $displayPath = $resolved.Substring($Root.Length).TrimStart('\', '/')
                $errors.Add("Enlace roto en $($file.FullName):$lineNumber -> $target (resuelve a $displayPath)")
            }
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Repositorio válido: $($required.Count) archivos requeridos y $($markdownFiles.Count) documentos Markdown revisados."
