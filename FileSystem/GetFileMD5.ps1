$someFilePath = "C:\Temp\1.txt"
$md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$hash = ($md5.ComputeHash([System.IO.File]::ReadAllBytes($someFilePath)) |  foreach { $_.ToString("X2") }) -join ""
$hash