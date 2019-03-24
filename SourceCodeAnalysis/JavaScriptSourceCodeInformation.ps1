$directoryName = "c:\Programming\ua.fgiscs4\Frontend\src\"
$wildCard = "*.js"

function FormatSize([double]$value)
{
    $size = if ($value -lt 1KB) {"Bytes"} else {if ($value -lt 1MB) {"Kb"} else {if ($value -lt 1GB) {"Mb"} else {if ($value -lt 1TB) {"Gb"} else {"Tb"}}}}
    $value = if ($value -lt 1KB) {$value} else {if ($value -lt 1MB) {$value/1KB} else {if ($value -lt 1GB) {$value/1MB} else {if ($value -lt 1TB) {$value/1GB} else {$value/1TB}}}}
    $value = [Math]::Round($value,2,[MidPointRounding]::AwayFromZero)
    return "$value $size"
}

function GetNumberOfLines([string]$text)
{
    $lines = $text -split [System.Environment]::NewLine
    return $lines.Count
}

function GetNumberOfEmptyLines([string]$text)
{
    $result = 0
    $lines = $text -split [System.Environment]::NewLine
    foreach($line in $lines)
    {
        if([String]::IsNullOrWhiteSpace($line))
        {
            $result++
        }
    }
    return $result
}

function GetNumberOfNotEmptyLines([string]$text)
{
    $result = 0
    $lines = $text -split [System.Environment]::NewLine
    foreach($line in $lines)
    {
        if([String]::IsNullOrWhiteSpace($line) -ne $true)
        {
            $result++
        }
    }
    return $result
}

function GetNumberOfClasses([string]$text)
{
    $pattern = ".*(class){1}[\s]+.*[\{]{1}"
    $matches = [regex]::matches($text, $pattern)
    return $matches.Count
}

function GetFunctionNames([string]$text, $result)
{
    $excludedFunctionNames = @("if", "for", "while", "with", "switch", "typeof", "instanceof", "catch", "function", "return")
    $pattern = "([\.\(\w\$]+)[\s\=]*[\(]{1}(.*)[\)]{1}[\s]*[\{]{1}"
    $matches = [regex]::matches($text, $pattern)
    foreach($match in $matches)
    {
        if(($match.groups.count -ge 3) -and 
           ($excludedFunctionNames.Contains($match.groups[1].value) -ne $true) -and 
           ($match.groups[1].value.Contains("(") -ne $true) -and
           ($match.groups[2].value.Contains("""") -ne $true) -and
           ($match.groups[2].value.Contains("'") -ne $true) -and
           ($match.groups[2].value.Contains("(") -ne $true))
        {
            $result[$match.groups[1].value]++
        }
    }

    $pattern = "([\.\(\w\$]+)[\s]*[\=\:]{1}[\s]*(function){1}.*[\(]{1}(.*)[\)]{1}[\s]*[\{]{1}"
    $matches = [regex]::matches($text, $pattern)
    foreach($match in $matches)
    {
        if(($match.groups.count -ge 4) -and 
           ($excludedFunctionNames.Contains($match.groups[1].value) -ne $true) -and 
           ($match.groups[1].value.Contains("(") -ne $true) -and
           ($match.groups[3].value.Contains("""") -ne $true) -and
           ($match.groups[3].value.Contains("'") -ne $true) -and
           ($match.groups[3].value.Contains("(") -ne $true))
        {
            $result[$match.groups[1].value]++
        }
    }

    $pattern = "([\.\(\w\$]+)[\s]*[\=]{1}(.*)(=>){1}"
    $matches = [regex]::matches($text, $pattern)
    foreach($match in $matches)
    {
        if(($match.groups.count -ge 3) -and 
           ($excludedFunctionNames.Contains($match.groups[1].value) -ne $true) -and 
           ($match.groups[1].value.Contains("(") -ne $true) -and
           ($match.groups[2].value.Contains("""") -ne $true) -and
           ($match.groups[2].value.Contains("'") -ne $true) -and
           ([regex]::matches($match.groups[2].value, "\{").count -eq [regex]::matches($match.groups[2].value, "\}").count) -and
           ([regex]::matches($match.groups[2].value, "\(").count -eq [regex]::matches($match.groups[2].value, "\)").count))
        {
            $result[$match.groups[1].value]++
        }
    }
}

function Main() 
{
    $numberFiles = 0
    $totalSize = 0
    $numberLines = 0
    $numberEmptyLines = 0
    $numberCodeLines = 0
    $numberClasses = 0
    $excludeDublicateFunctionNames = @()
    $functionNames = New-Object System.Collections.Hashtable
    $path =  $directoryName = Join-Path $directoryName -ChildPath $wildCard
    $files = get-childitem -path $path -recurse | where {! $_.PSIsContainer}
    foreach ($file in $files)
    {
        $numberFiles++
        $totalSize += $file.length
        $fileContent = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        $numberLines += GetNumberOfLines $fileContent
        $numberEmptyLines += GetNumberOfEmptyLines $fileContent
        $numberCodeLines += GetNumberOfNotEmptyLines $fileContent
        $numberClasses += GetNumberOfClasses $fileContent
        GetFunctionNames $fileContent $functionNames
    }
    $dublicateFunctionNames = $functionNames.GetEnumerator() | 
                              Where-Object { $excludeDublicateFunctionNames.Contains($_.Name) -ne $true } | 
                              Where-Object { $_.Value -ge 2 } | 
                              Sort-Object { $_.Value } -Descending
    Write-Output ("Total size: " + (FormatSize $totalSize))
    Write-Output ("The number of files: " + $numberFiles)
    Write-Output ("The number of code lines: " + $numberCodeLines)
    Write-Output ("The number of empty lines: " + $numberEmptyLines)
    Write-Output ("The number of lines: " + $numberLines)
    Write-Output ("The number of classes: " + $numberClasses)
    Write-Output ("The number of functions: " + (($functionNames.Values | Measure-Object -Sum).Sum))
    Write-Output ("The number of dublicate functions: " + $dublicateFunctionNames.Count)
    Write-Output ($dublicateFunctionNames)
}

Main