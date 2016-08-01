param($installPath, $toolsPath, $package, $project)

# if there is no project, then there is nothing to do
if (!$project) { return }

Import-Module (Join-Path $toolsPath "BuildTools.SqlCodeGuard.psm1") -Force

# turn it off
Uninstall-SqlCodeGuard $project
$project.Save()