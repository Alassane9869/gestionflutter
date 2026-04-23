# ==============================================================================
# SCRIPT DE RÉINITIALISATION "SORTIE D'USINE" - DANAYA+
# ==============================================================================

$AppName = "Danaya+"

Write-Host "--- RÉINITIALISATION DANAYA+ ---"

# Chemins standards de stockage Flutter/Windows
$Paths = @(
    "$env:APPDATA\$AppName",
    "$env:LOCALAPPDATA\$AppName",
    "$env:LOCALAPPDATA\com.example\danaya_plus",
    "$env:LOCALAPPDATA\Danaya\Danaya+"
)

$Found = $false

foreach ($Path in $Paths) {
    if (Test-Path $Path) {
        Write-Host "Nettoyage de : $Path"
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        $Found = $true
    }
}

if ($Found) {
    Write-Host "RÉINITIALISATION RÉUSSIE !"
    Write-Host "Le prochain lancement de DANAYA+ affichera le Guide d'Utilisation."
} else {
    Write-Host "Aucune donnée existante trouvée. L'application est déjà en état d'usine."
}
