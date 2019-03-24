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
    $jobNames = @("job.name1", "job.name2")
    $userId = "user.id"
    $apiToken = "api.token" #The API token is available here (http://jenkins.host.name/user/user.name/configure)
    $crumbIssuerApiUrl = "http://${hostName}/crumbIssuer/api/xml"    
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
        foreach($jobName in $jobNames)
        {
            try
            {
                AppendTextToFile $logFileName "${jobName} is being downloaded"
                $buildApiUrl = "http://${hostName}/job/${jobName}/lastSuccessfulBuild/api/json"
                $buildInfo = Invoke-WebRequest $buildApiUrl -Method GET -Headers $headers | ConvertFrom-Json
                $jobDirectoryName = Join-Path $workingDirectoryName -ChildPath $jobName
                New-Item -ItemType Directory -Force -Path $jobDirectoryName | Out-Null
                foreach($artifact in $buildInfo.artifacts)
                {
                    try
                    {
                        AppendTextToFile $logFileName "$($artifact.fileName) is being downloaded"
                        $artifactUrl = "http://${hostName}/job/${jobName}/lastSuccessfulBuild/artifact/"
                        $artifactUrl = ${artifactUrl} + ${artifact}.relativePath
                        $artifactFileName = Split-Path $artifactUrl -leaf
                        $artifactFileName = Join-Path $jobDirectoryName -ChildPath $artifactFileName
                        Invoke-WebRequest -Uri $artifactUrl -OutFile $artifactFileName -Headers $headers
                    }
                    catch [System.Exception]
                    {
                        AppendTextToFile $logFileName $_.Exception.Message
                        AppendTextToFile $logFileName "$($artifact.fileName) is not downloaded"
                    }
                }
            }
            catch [System.Exception]
            {
                AppendTextToFile $logFileName $_.Exception.Message
                AppendTextToFile $logFileName "${jobName} is not downloaded"
            }
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