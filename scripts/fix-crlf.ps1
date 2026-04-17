Get-ChildItem -Recurse -File | Where-Object {
  $_.Name -eq 'Dockerfile' -or
  $_.Extension -in '.sh', '.conf', '.yml', '.yaml', '.sql'
} | ForEach-Object {
  $content = [System.IO.File]::ReadAllText($_.FullName)
  $content = $content -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($_.FullName, $content, (New-Object System.Text.UTF8Encoding($false)))
}