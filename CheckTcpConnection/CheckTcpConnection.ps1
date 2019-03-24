function GetLogFileName()
{
    $directoryName = "c:\Resources\CheckTcpConnection"
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
        $directoryName = "c:\Resources\CheckTcpConnection"
        $settingsFileName = Join-Path $directoryName -ChildPath $settingsFileName
        $settings = Get-Content -Raw -Path $settingsFileName | ConvertFrom-Json
        foreach($connection in $settings.connections)
        {
            AppendTextToLogFile $logFileName ("Connecting to " + $connection.address + ":" + $connection.port)
            $errorExist = $false
            $exceptionMessage = ""
            try
            {
                $response = Test-NetConnection -ComputerName $connection.address -port $connection.port
            }
            catch [System.Exception]
            {
                $exceptionMessage = $_.Exception.Message
                $errorExist = $true
            }

            if ($errorExist -or $response.TcpTestSucceeded -ne $true)
            {
                $message = ("Result: Error" + $(if ($exceptionMessage -ne "") {", $exceptionMessage"} Else {""}))
                AppendTextToLogFile $logFileName $message
                $message = "<p>" + $connection.name + "</p><p>" + $connection.address + ":" + $connection.port + ", " + $message + "</p>"
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
                AppendTextToLogFile $logFileName ("Result: Success")
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