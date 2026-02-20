param(
  [string]$Root = "c:\Users\burin\jedechai_delivery_new\jedechai_delivery_new\android\app\build\intermediates"
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$bad = @()
Get-ChildItem -Path $Root -Recurse -Filter *.jar -ErrorAction SilentlyContinue | ForEach-Object {
  $jar = $_.FullName
  try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($jar)
    foreach ($e in $zip.Entries) {
      $y = $e.LastWriteTime.Year
      if ($y -lt 1980 -or $y -gt 2107) {
        $bad += [PSCustomObject]@{
          Year = $y
          Jar = $jar
          Entry = $e.FullName
        }
        break
      }
    }
    $zip.Dispose()
  }
  catch {
    # ignore unreadable jars
  }
}

if ($bad.Count -eq 0) {
  Write-Output "NO_BAD_JAR_ENTRIES"
}
else {
  $bad | Select-Object -First 200 | ForEach-Object {
    Write-Output ("{0} | {1} | {2}" -f $_.Year, $_.Jar, $_.Entry)
  }
}
