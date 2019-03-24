function GetWorkingDirectoryName()
{    
    $directoryName = Split-Path $script:MyInvocation.MyCommand.Path
    $subDirectoryName = Get-Date -format "yyyyMMdd_HHmmss"
    $directoryName = Join-Path $directoryName -ChildPath $subDirectoryName
    return $directoryName
}

function AppendTextToFile([string] $fileName, [string] $text)
{
    $currentDateTime = Get-Date -format "yyyy-MM-dd HH:mm:ss.ffff"
    $fileContent = "${currentDateTime}  ${text}"
    $fileContent | Out-File -Append -Encoding "UTF8" $fileName
}

function Main() 
{
    $hostName = "jenkins.host.name"
    $jobName = "job.name"
    $userId = "user.id"
    $apiToken = "api.token" #The API token is available here (http://jenkins.host.name/user/user.name/configure)
    $crumbIssuerApiUrl = "http://${hostName}/crumbIssuer/api/xml"
    $lastSuccessfulBuildApiUrl = "http://${hostName}/job/${jobName}/lastSuccessfulBuild/api/json"
    $lastSuccessfulBuildArtifactUrl = "http://${hostName}/job/${jobName}/lastSuccessfulBuild/artifact/"
    $workingDirectoryName = GetWorkingDirectoryName
    $logFileName = Join-Path $workingDirectoryName -ChildPath "Log.txt"
    New-Item -ItemType Directory -Force -Path $workingDirectoryName | Out-Null
    AppendTextToFile $logFileName "The script has started downloading an artifact"
    try
    {
        $credentialsAsBytes = [System.Text.Encoding]::ASCII.GetBytes($userId+ ":" + $apiToken)
        $credentialsAsBase64String = [System.Convert]::ToBase64String($credentialsAsBytes)
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Basic ${credentialsAsBase64String}")
        [xml]$crumbs = Invoke-WebRequest $crumbIssuerApiUrl -Method GET -Headers $headers
        $headers.Add($crumbs.defaultCrumbIssuer.crumbRequestField, $crumbs.defaultCrumbIssuer.crumb)
        $buildInfo = Invoke-WebRequest $lastSuccessfulBuildApiUrl -Method GET -Headers $headers | ConvertFrom-Json
        foreach($artifact in $buildInfo.artifacts)
        {
           $artifactUrl = ${lastSuccessfulBuildArtifactUrl} + ${artifact}.relativePath
           $artifactFileName = Split-Path $artifactUrl -leaf
           $artifactFileName = Join-Path $workingDirectoryName -ChildPath $artifactFileName
           Invoke-WebRequest -Uri $artifactUrl -OutFile $artifactFileName -Headers $headers
        }
        AppendTextToFile $logFileName "The script is finished successfully"
        exit 0
    }
    catch [System.Exception]
    {
        AppendTextToFile $logFileName $_.Exception.Message
        AppendTextToFile $logFileName "The script is finished with an error"
        exit 1
    }
}

Main