# Windows Server Virtual Machine Backup Script

---

### Example:

* Manualy Call Backup function:
``` powershell
Get-VM | C:\yourpath\BackupVMScript\backupVMScript.ps1
#Backs Up all running VMs with settings from backupConfig.json
```

* Setup Schedualed BackupVM Task
```
Coming Soon, to a git Repository near YOU!
```

* Manual Call Backup Function with Parameters
``` powershell
Get-VM | C:\yourpath\BackupVMScript\backupVMScript.ps1 -bugKilling -slackSilent
#outputs all debug notifications without pushing them to slack
```
---

### Command Parameters:

Pipe input: takes ```Get-VM``` for all VMs, and ```Get-VM db01.example.net``` etc. for specific VMs

All Command Parameters are optional and overwrite ```backupConfig.json```

| Parameter | Description | Required |
| --------- | ----------- | -------- |
| -bkupFolder     | Absolute path, alternative to Backups folder    | No
| -configFile     | Absolute path, alternative to BkupConfig.json   | No
| -logFile        | Absolute path, alternative to log.txt           | No
| -bkupLen        | Integer, Length in days between desired backups | No
| -bkupRetention  | Integer, How many backups you would like to keep| No
| -slackIcon      | String, profil icon for Slack posts e.g. :fire: | No
| -slackChannel   | String, Name of Slack channel to post to        | No
| -slackUsername  | String, The name the bkupScript will post under | No
| -bugKilling     | Switch, Enable more outputs for debuging purpose| No
| -slackSilent    | Switch, Disable slack notifications             | No
| -force          | Switch, Bypass log, bakcup all VMs              | No

### Config Parameters
| Parameter | Description | Required |
| --------- | ----------- | -------- |
| -BackupFolder  | Absolute path, alternative to Backups folder    | Yes
| -LogFile       | Absolute path, alternative to log.txt           | Yes
| -BackupLenght  | Integer, Length in days between desired backups | Yes
| -Retention     | Integer, How many backups you would like to keep| Yes
| -SlackIcon     | String, profil icon for Slack posts e.g. :fire: | No
| -SlackChannel  | String, Name of Slack channel to post to        | No
| -SlackKey      | String, The name the bkupScript will post under | No
---
### Instaliation:

>Download the folder that contains the script from:
```
Coming Soon, to a git Repository near YOU!
```
The BackupVMScript folder should contain:
* backupVMScript.ps1
* backupConfig.json
* ~~BackupsFolder~~


>1. In the same folder as the ```backupVMScript.ps1``` and ```backupConfig.json``` add a folder tittled ```BackupsVM```
2. If you are using Slack, fill out the config file with your api key
3. Set the file to run daily, and adjust the config for the time between backups

---
### ToDo


* add support for basecamp
* Check if its been waiting too long
*  ~~Strip logfile, so newline errors are omitted~~
*  ~~add -force to override prudent tasks~~
*  ~~post to slack important, not urgent~~
* check if config has real bkupFolder

### Resources:
Original inspiration, and core code found @ [two tricks to automate the export of live vms in windows server](http://www.infoworld.com/article/2610395/windows-server/two-tricks-to-automate-the-export-of-live-vms-in-windows-server.html)
