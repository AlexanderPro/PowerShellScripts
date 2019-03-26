function GetLogFileName()
{
    $directoryName = Split-Path $script:MyInvocation.MyCommand.Path
    $fileName = Get-Date -format "yyyyMMdd"
    $fileName = $fileName + ".log"
    $directoryName = Join-Path $directoryName -ChildPath "Logs"
    $fileName = Join-Path $directoryName -ChildPath $fileName
    New-Item -ItemType Directory -Force -Path $directoryName | Out-Null
    return $fileName
}

function AppendTextToLogFile([string] $fileName, [string] $text)
{
    $currentDateTime = Get-Date -format "yyyy-MM-dd HH:mm:ss.ffff"
    $fileContent = "${currentDateTime}  ${text}"
    $fileContent | Out-File -Append -Encoding "UTF8" $fileName
}

function SendEmail($mail, [string] $body)
{
    #$credentials = New-Object Management.Automation.PSCredential $mail.login, ($mail.password | ConvertTo-SecureString -AsPlainText -Force)
    #Send-MailMessage -From $mail.from -To $mail.to -Subject $mail.subject -Body $body -SmtpServer $mail.host -port $mail.port -Credential $credentials -BodyAsHTML -Verbose -UseSsl

    $emailMessage = New-Object System.Net.Mail.MailMessage
    $emailMessage.From = $mail.from
    $emailMessage.To.Add($mail.to)
    $emailMessage.Subject = $mail.subject
    $emailMessage.IsBodyHtml = $true
    $emailMessage.Body = $body
    $smtpClient = New-Object System.Net.Mail.SmtpClient($mail.host, $mail.port)
    $smtpClient.EnableSsl = $mail.useSsl
    $smtpClient.Credentials = New-Object System.Net.NetworkCredential($mail.login, $mail.password)
    $smtpClient.Send($emailMessage)
}

function Main() 
{
    $logFileName = GetLogFileName
    AppendTextToLogFile $logFileName "The script has started"
    try
    {
        $settingsFileName = "Settings.json"
        $directoryName = Split-Path $script:MyInvocation.MyCommand.Path
        $settingsFileName = Join-Path $directoryName -ChildPath $settingsFileName
        $settings = Get-Content -Raw -Path $settingsFileName | ConvertFrom-Json
        foreach($webSite in $settings.webSites)
        {
            AppendTextToLogFile $logFileName ("Request " + $webSite.url)
            $errorExist = $false
            $exceptionMessage = ""
            try
            {
                $response = Invoke-WebRequest -Uri $webSite.url -TimeoutSec $webSite.timeOut
            }
            catch [System.Exception]
            {
                $exceptionMessage = $_.Exception.Message
                $errorExist = $true
            }
            
            if ($response.StatusCode -eq 200) 
            {
                foreach($phrase in $webSite.phrasesAllowed)
                {
                    if (!$response.Content.ToLower().Contains($phrase.ToLower()))
                    {
                        $errorExist = $true
                        break
                    }
                }
                foreach($phrase in $webSite.phrasesNotAllowed)
                {
                    if ($response.Content.ToLower().Contains($phrase.ToLower()))
                    {
                        $errorExist = $true
                        break
                    }
                }
            }
            
            if ($errorExist -or $response.StatusCode -ne 200)
            {
                $message = ("Status Code: " + $response.StatusCode + ", Result: Error" + $(if ($exceptionMessage -ne "") {", $exceptionMessage"} Else {""}))
                AppendTextToLogFile $logFileName $message
                $message = "<p>Web Site: " + $webSite.url + "</p><p>" + $message + "</p>"
                try
                {
                    SendEmail $settings.mail $message
                }
                catch [System.Exception]
                {
                    AppendTextToLogFile $logFileName $_.Exception.Message
                }
            }
            else
            {
                AppendTextToLogFile $logFileName ("Status Code: " + $response.StatusCode + ", Result: Success")
            }
        }
        AppendTextToLogFile $logFileName "The script is finished successfully"
        AppendTextToLogFile $logFileName "---------------"
        exit 0
    }
    catch [System.Exception]
    {
        AppendTextToLogFile $logFileName $_.Exception.Message
        AppendTextToLogFile $logFileName "The script is finished with an error"
        AppendTextToLogFile $logFileName "---------------"
        exit 1
    }
}

Main