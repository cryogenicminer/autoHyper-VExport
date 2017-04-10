
[cmdletbinding(SupportsShouldProcess=$True)]

Param(
  [Parameter(Position=0,Mandatory=$True,
  HelpMessage="Enter the virtual machine name or names",
  ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
  [ValidateNotNullorEmpty()]
  [Alias("name")]
  [string[]]$VM,

  [Parameter(Position=1)] [ValidateNotNullorEmpty()] [string]$bkupFolder,
  [Parameter(Position=2)] [ValidateNotNullorEmpty()] [string]$configFile,
  [Parameter(Position=3)] [ValidateNotNullorEmpty()] [string]$logFile,
  [Parameter(Position=4)] [ValidateNotNullorEmpty()] [int]$bkupLen,
  [Parameter(Position=5)] [ValidateNotNullorEmpty()] [int]$bkupRetention,
  [Parameter(Position=6)] [ValidateNotNullorEmpty()] [string]$slackIcon,
  [Parameter(Position=7)] [ValidateNotNullorEmpty()] [string]$slackChannel,
  [Parameter(Position=8)] [ValidateNotNullorEmpty()] [string]$slackUsername,
  [Parameter(Position=9)] [ValidateNotNullorEmpty()] [switch]$bugKilling,
  [Parameter(Position=10)] [ValidateNotNullorEmpty()] [switch]$slackSilent,
  [Parameter(Position=11)] [ValidateNotNullorEmpty()] [switch]$force
)

Begin {
#---LOAD-CONFIG-FILE-----------------------------------------------------------#
  If (-Not $configFile) { $configFile = Join-Path (pwd) "bkupConfig.json" }
  $Config = (Get-Content -Raw -Path "$configFile") | ConvertFrom-Json

#---DEFAULT-PARAMETERS---------------------------------------------------------#
  If (-Not $bkupFolder) {     $bkupFolder =     Join-Path (pwd) $Config.BackupFolder }
  If (-Not $logFile) {        $logFile =        Join-Path (pwd) $Config.LogFile }
  If (-Not $bkupLen) {        $bkupLen =        $Config.BackupLenght }
  If (-Not $bkupRetention) {  $bkupRetention =  $Config.BackupRetention }

  $maxRunningJobs = $Config.MaxRunningJobs
  $maxVMBJobs =     $Config.MaxVMBJobs
  $jobCheckDelay =  $Config.JobCheckDealy
  $jobPrefix =      $Config.JobPrefix
  $type =           $Config.FolderPrefix
  $slackKey =       $Config.SlackKey

  If (-Not $slackIcon) {      $slackIcon =      $Config.SlackIcon }
  If (-Not $slackChannel) {   $slackChannel =   $Config.SlackChannel }
  If (-Not $slackUsername) {  $slackUsername =  $Config.SlackUsername }

  $verboseState =   $Config.Verbose #Doesnt do anything yet, not sure if its policaly safe
} #End of "Begin"

Process { #Gets repeted for each item in the pipe object
  $ListVM += $VM #Take all individual VM add them into 1 object, for post process.
} #End of "Process"

End {

# === === === === === === === === === **** === === === === === === === === === #
#
#                                    TODOs
#
#   Add check for if it is waiting too long, then return out of the script.
#   All outputs dump to file or var, that gets past to slack at once.
#   Claculate delted old filds at once, instead of interating thougth fn
#   No way to tell if a job finished succesfuly, just that is tarted errorless
#   Check that we only delete files that are backups...
#
# === === === === === === === === === **** === === === === === === === === === #

#---SLACK-MESSAGINF-FUNCTION---------------------------------------------------#
  function SendSlackMessage { #Takes a Pipe Input
    [CmdletBinding()]
    Param([Parameter(ValueFromPipeline=$TRUE)]$message)
    $payload = @{
    	"channel" = "$slackChannel"; #Slack variables set in config file.
    	"icon_emoji" = "$slackIcon";
    	"username" = "$slackUsername";}
    $payload.Add("text", $message)

    Invoke-WebRequest `
      -Uri "https://hooks.slack.com/services/$slackKey" `
      -Method "POST" `
      -Body (ConvertTo-Json -Compress -InputObject $payload) `
      -UseBasicParsing
  }

#---VERBAL-OUTPUT-FUNCTION-----------------------------------------------------#
  Function NoticeOutput {
    [CmdletBinding()]
    Param([Parameter(ValueFromPipeline=$TRUE)]$Content,
          [switch]$Warning,
          [switch]$Slack)
    Write-Verbose $Content
    If ($Warning.IsPresent) { Write-Warning $Content }
    if (-Not $slackSilent -And $Slack.IsPresent) { $Content | SendSlackMessage }
  }

#---UPDATE-FOLDER-COUNT--------------------------------------------------------#
  Function GetSubFolders() {
    Try {
      #get only directories under the path that start with Weekly or Monthly
      If ($bugKilling) { "Checking $bkupFolder for subfolders" | NoticeOutput -Verbose -Slack }
      $subFolders =  dir -Path $bkupFolder -Directory -ErrorAction Stop
      #$subFolders.Count
      return $subFolders
    }
    Catch {
      #bail out of the script, if cant find folders.
      "Failed to enumerate folders from $path" | NoticeOutput -Warning -Slack
      return
    }
  }

#---CHECK-RUNNING-JOBS---------------------------------------------------------#
  Function RunningJobsCheck() {
    $runningJobs = Get-Job -State "Running"
    Foreach ($job in $runningJobs) { #Possible to do this in one line as extracint all objects with the name * match into an array?
      If ($job.Name -match "$jobPrefix") {
        $runningVMB ++
        $job.Name
      }
    }

    $runningJobsCount = $runningJobs.Count
    If ($bugKilling) { "Runing Jobs Total: $runningJobsCount, Running BKUP Jobs: $runningVMB" | NoticeOutput -Verbose }#-Slack }

    IF ($runningJobs.Count -lt $maxRunningJobs -and $runningVMB -lt $maxVMBJobs) {
      If ($bugKilling) { "RunningJobsCheck = $True Continue!" | NoticeOutput -Verbose -Slack }
      return "True"
    }
    Else {
      If ($bugKilling) { "RunningJobsCheck = $False Dont Continue!" | NoticeOutput -Verbose -Slack }
      return "False"
    }
  }

# === RUNNING SCRIPT === === === === **** === === === === === === === === === #

  #$sub = GetSubFolders
  #$sub
  #'asf'

#---CHECK-MACHINES-TO-BACKUP---------------------------------------------------#
  #Going backwards would be faster with large datasets
  #$bkupLen = 6 # FOR TESTING PURPOSES ONLY

  If (-Not $force) { #only if regarding log
    $log = Get-Content $logFile #Where the bkup log files are
    [array]::Reverse($log) #Check it backwards, fastest

    Foreach ( $line in $log ) {

      if ($line -match "[a-zA-Z]") {
        $bkupDate = $line | %{$_.split("[]")[1]} | Get-Date #Converts the date string to a PS date object
        $logLen = ( Get-Date).AddDays( -$bkupLen) #Calculate what date is the bkup cut-off

        If ( -not ($logLen -ge $bkupDate)) {
          $bkupLenLog += $line + " " #Get a string of all the bkups within the date range
          "$bkupLenLog" | NoticeOutput -Verbose
        }
      }
    }
  }

  If ($bugKilling) { "bkupLenLog: $bkupLenLog" | NoticeOutput -Verbose -Slack}
  $toBkup = @()  #assign toBkup as an array

  Foreach ( $VM in $ListVM ) {
    $NameVM = $VM

    if ( -Not ("$bkupLenLog" -like "*$NameVM*" ) ) { #To see if the VM is located within all the bkup records withink the last X days
      $toBkupStr += ", " +$NameVM #String
      $toBkup += $NameVM
    }
  }
  $logVM = get-date -format "[MM/dd/yyyy hh:mm:ss]" #Get current date

#---ONLY-PROCEED-IF-toBkup-IS-VALID--------------------------------------------#

  if ( $toBkup ) { #if there is acualy anything to Bkup continue
    $logAppend = $logVM + $toBkupStr #add the date prefix to string of toBkup machines
    "To Backup: $toBkup" | NoticeOutput -Verbose -Slack

#---FIND-AND-DELETE-OLDEST-FOLDER-UNTILL-RETAIN--------------------------------#
  # probobly would work better if I calculated what out of an array I wanted and
  # then chose to delete everything else, that way I dont have poll GetSubFolders
    $subFolders = GetSubFolders
    #$subFolders
    #$bkupRentention
    #$subFolders
    While ($subFolders.Count -gt $bkupRetention) {
      $oldest = $subFolders | sort CreationTime | Select -first 1
      If ($bugKilling) { "Removing: $oldest" | NoticeOutput -Verbose -Slack }
      $oldest | Remove-Item -Recurse -Force
      $subFolders = GetSubFolders
    }

#----GENERATE-THE-FILE-NAME----------------------------------------------------#
    $nowTime = Get-Date #name format is Type_Year_Month_Day_HourMinute
    $childPath = "{0}_{1}_{2:D2}_{3:D2}_{4:D2}{5:D2}{6:D2}" -f $type,$nowTime.year,$nowTime.month,$nowTime.day,$nowTime.hour,$nowTime.minute,$nowTime.second
    $new = Join-Path -Path $bkupFolder -ChildPath $childPath
    Try {
      #$BackupFolder = New-Item -Path $new -ItemType directory -ErrorAction Stop #Create new backup folder
      If ($bugKilling) { "Created New Folder: $new" | NoticeOutput -Verbose -Slack }
    }
    Catch {
      "Failed to create folder $new. $($_.exception.message)" | NoticeOutput -Verbose -Slack
      Return
    }

#---BACKING-UP----------------------------------------------------#
    #$BackupFolder = $Null #Debug Testing Override
    #$BackupFolder = $True #Debug Testing Override
    if ($BackupFolder) { #If there is a folder to backup to continue

      foreach ($nameVM in $toBkup) {
        $VMBName = $jobPrefix + $nameVM
        $VMBName | NoticeOutput -Verbose

        If ( (RunningJobsCheck) -eq "False") {
          #if RunningJobsCheck says dont start a job, begin wait-check cycle
          If ($bugKilling) { "it was false" | NoticeOutput -Slack -Verbose }

          while ( (RunningJobsCheck) -eq "False") {
            #Sleep for $jobCheckDelay before checking to see if jobs are free again
            if ($bugKilling) { "entering stasis for $jobCheckDelay s" | NoticeOutput -Verbose -Slack }
            Start-Sleep -s $jobCheckDelay
          }
        }
        #If RunningJobsCheck says start job:
        If ($bugKilling) { "Green Light for Backups, Check" | NoticeOutput -Verbose -Slack }

        Try {
          #Start-Job -Name $VMBName -ScriptBlock { Start-Sleep -s ($jobCheckDelay - 5) } #Fake job for Debug purposes
          Start-Job -Name $VMBName -ScriptBlock { Export-VM -Name $args[0] -Path $args[1] } -ArgumentList @($nameVM, $BackupFolder)
          "Began $VMBName backup" | NoticeOutput -Verbose -Slack
        }
        Catch {
          "FAILED: $VMBName job, failed the 'Try/Catch'"
        }
      } #close "foreach ($nameVM in $toBkup)"

      $logAppend | Out-File -FilePath "$logFile" -Append -encoding ASCII #Write new line to log, formated corretly as ASCII

    } #close "if ($BackupFolder)"
  } #close "if ( $toBkup )"
  else {
    If ($bugKilling) { "Nothing regestered to backedup this session" | NoticeOutput -Verbose -Slack }
  }
  "Exiting BackupVM-Script" | NoticeOutput -Verbose -Slack
} #close "End"
