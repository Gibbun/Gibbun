<# 
.SYNOPSIS 
    This script reads various XML files which contain system preferences, catalogs, software to install and then downloads and installs the appropriate packages along with Windows Updates. 
.NOTES 
    Author     : Drew Coobs - coobs1@illinois.edu 
#>
##############################################################################
#
# Copyright 2015 Drew Coobs.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##############################################################################

#Enabling script parameters (allows verbose, debug, checkonly, installonly)
[CmdletBinding()]
Param(
    [switch]$checkOnly,
	[switch]$installOnly
)

###########################################################
###   NETWORK CONNECTION TEST   ###########################
########################################################### 

$networkUp = (Test-NetConnection -InformationLevel Quiet)

If ($networkUp)
    {
    Write-Verbose "Network connection validated"
    }
Else
    {
    Write-Verbose "Could not validate network connection. Exiting..."
    Exit
    }

###########################################################
###   END OF NETWORK CONNECTION TEST   ####################
########################################################### 

###########################################################
###   CONSTANT VARIABLES   ################################
###########################################################

#Declare Gibbun install directory variable
$gibbunInstallDir = $env:SystemDrive + "\Progra~1\Gibbun"

#Declare path of ManagedInstalls.XML
$gibbunManagedInstallsXMLPath = (Join-Path $gibbunInstallDir ManagedInstalls.xml)

#Declare path of manifest


###########################################################
###   END OF CONSTANT VARIABLES   #########################
###########################################################

##################################################################################################################################
### RUNNING AS ADMIN CHECK #######################################################################################################
##################################################################################################################################

Write-Verbose "Starting...."

#Check that script is being run as administrator; Exit if not.
    If (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
       [Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        Write-Warning "You are not running this script as a system administrator!`nPlease re-run this script as an Administrator!"
        Break
    }

##################################################################################################################################
### END OF RUNNING AS ADMIN CHECK ################################################################################################
##################################################################################################################################

#################################################################################################################
### MANAGEDINSTALLS.XML #########################################################################################
#################################################################################################################
 
Write-Verbose "Loading ManagedInstalls.XML"
#Check that ManagedInstalls.XML exists
If (!(Test-Path ($gibbunManagedInstallsXMLPath)))
    {
    Write-Warning "Could not find ManagedInstalls.XML Exiting..."
    Exit
    }

#Load ManagedInstalls.xml file into variable $managedInstallsXML
[xml]$managedInstallsXML = Get-Content ($gibbunManagedInstallsXMLPath)

#Parse ManagedInstalls.xml and insert necessary data into variables. Report error messages if encountered.
Try
    {
    $client_Identifier = $managedInstallsXML.ManagedInstalls.ClientIdentifier
    }
Catch
    {
    Write-Warning "ManagedInstall.XML is missing ClientIdentifier..."
    }

Try
    {
    $installWindowsUpdates = $managedInstallsXML.ManagedInstalls.InstallWindowsUpdates
    }
Catch
    {
    Write-Warning "ManagedInstall.XML is missing installWindowsUpdates..."
    }

Try
    {
    $windowsUpdatesOnly = $managedInstallsXML.ManagedInstalls.WindowsUpdatesOnly
    }
Catch
    {
    Write-Warning "ManagedInstall.XML is missing WindowsUpdatesOnly..."
    }

Try
    {
    [int]$daysBetweenWindowsUpdates = [int]$managedInstallsXML.ManagedInstalls.DaysBetweenWindowsUpdates
    }
Catch
    {
    Write-Warning "ManagedInstall.XML is missing DaysBetweenWindowsUpdates..."
    }

Try
    {
    [DateTime]$lastWindowsUpdateCheck = [DateTime]$managedInstallsXML.ManagedInstalls.LastWindowsUpdateCheck
    }
Catch
    {
    Write-Warning "ManagedInstall.XML is missing LastWindowsUpdateCheck..."
    }

Try
    {
    $logFilePath = $managedInstallsXML.ManagedInstalls.LogFile
    }
Catch
    {
    Write-Warning "ManagedInstall.XML is missing LogFile..."
    }

Try
    {
    $loggingEnabled = $managedInstallsXML.ManagedInstalls.LoggingEnabled
    }
Catch
    {
    Write-Warning "ManagedInstall.XML is missing LoggingEnabled..."
    }

Try
    {
    $softwareRepoURL = $managedInstallsXML.ManagedInstalls.SoftwareRepoURL
    }
Catch
    {
    Write-Warning "ManagedInstall.XML is missing SoftwareRepoURL..."
    }

#convert boolean values in XML from strings to actual boolean
[bool]$installWindowsUpdates = [System.Convert]::ToBoolean($installWindowsUpdates)
[bool]$windowsUpdatesOnly = [System.Convert]::ToBoolean($windowsUpdatesOnly)
[bool]$loggingEnabled = [System.Convert]::ToBoolean($loggingEnabled)

#################################################################################################################
### END OF MANAGEDINSTALLS.XML ##################################################################################
#################################################################################################################

#############################################################################################################
### DIRECTORY CHECK #########################################################################################
######################## ####################################################################################

#Create GibbunInstalls folder if it doesn't exist.
New-Item -ItemType Directory -Force -Path $logFilePath | Out-Null

#Create log folder if it doesn't exist.
New-Item -ItemType Directory -Force -Path (Join-Path $gibbunInstallDir GibbunInstalls) | Out-Null

#Create Manifests folder if it doesn't exist.
New-Item -ItemType Directory -Force -Path (Join-Path $gibbunInstallDir GibbunInstalls\Manifests) | Out-Null

#Create Downloads folder if it doesn't exist.
New-Item -ItemType Directory -Force -Path (Join-Path $gibbunInstallDir GibbunInstalls\Downloads) | Out-Null

#Create Downloads folder if it doesn't exist.
New-Item -ItemType Directory -Force -Path (Join-Path $gibbunInstallDir GibbunInstalls\Catalogs) | Out-Null

#############################################################################################################
### END OF DIRECTORY CHECK ##################################################################################
######################## ####################################################################################

##################################################################################
###   LOGGING   ##################################################################
##################################################################################

If ($loggingEnabled)
    {
    Start-Transcript -path (Join-Path $logFilePath -ChildPath Gibbun.log) -Append
    }

##################################################################################
###   END OF LOGGING   ###########################################################
##################################################################################

######################################################################################################################################
### PREFLIGHT SCRIPT #################################################################################################################
######################## #############################################################################################################

#check if preflight script exists and call it if it does exist. Exit if preflight script encounters an error.
Write-Verbose "Checking if preflight script exists"
If (Test-Path (Join-Path $gibbunInstallDir -ChildPath preflight.ps1))
    {
    Write-Verbose "Preflight script exists";
    Write-Verbose "Running preflight script";
    Invoke-Expression (Join-Path $gibbunInstallDir -ChildPath \preflight.ps1);
        If ($LastExitCode > 0)
        {
        Write-Warning "Preflight script encountered an error"
        Exit
        }
    }
Else {Write-Verbose "Preflight script does not exist. If this is in error, please ensure script is in the Gibbun install directory"}

######################################################################################################################################
### END OF PREFLIGHT SCRIPT ##########################################################################################################
######################################################################################################################################

###########################################################################################################################################################################################################################################
### DOWNLOAD INITIAL MANIFEST #############################################################################################################################################################################################################
###########################################################################################################################################################################################################################################

#import BitsTransfer module
Write-Verbose "Importing BitsTransfer Module"
IPMO BitsTransfer

#create $haveManifest variable, will be changed to false if unable to find a manifest
$haveManifest = $True

If (-Not(($windowsUpdatesOnly)))
    {
    Write-Verbose "Getting manifest $client_Identifier"
    
    #Download manifest matching client_identifier in ManagedInstalls.XML. If unable to find it on server, attempt to download site-default manifest.
    Try
        {
        Start-BitsTransfer -Source ($softwareRepoURL + "/manifests/" + $client_Identifier + ".xml") -Destination ($gibbunInstallDir + "\GibbunInstalls\Manifests\" + $client_Identifier + ".xml") -TransferType Download -ErrorAction Stop
        Write-Verbose "Using manifest $client_Identifier"
        $initialManifest = $client_Identifier
        }
    Catch
        {
        Write-Verbose "Manifest $client_Identifier not found. Attempting site-default manifest instead..."
        $noClientIdentifier = $True
        }
    
    If ($noClientIdentifier)
        {
        Try
            {
            Start-BitsTransfer -Source ($softwareRepoURL + "/manifests/site-default.xml") -Destination ($gibbunInstallDir + "\GibbunInstalls\Manifests\site-default.xml") -TransferType Download -ErrorAction Stop
            Write-Verbose "Using manifest site-default"
            $initialManifest = "site-default"
            }
        Catch
            {
            Write-Verbose "Unable to locate $client_Identifier or site-default manifests. Skipping Gibbun installs..."
            $haveManifest = $False
            }
        }
    }

###########################################################################################################################################################################################################################################
### END OF DOWNLOAD INITIAL MANIFEST ######################################################################################################################################################################################################
###########################################################################################################################################################################################################################################

###########################################################################################################################
### LOAD INITIAL MANIFEST #################################################################################################
###########################################################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    {
    #Load $manifest.xml file into variable $manifestXML
    [xml]$initialManifestXML = (Get-Content ($gibbunInstallDir + "\GibbunInstalls\Manifests\" + $initialManifest + ".xml"))
    }
###########################################################################################################################
### END OF LOAD INITIAL MANIFEST ##########################################################################################
###########################################################################################################################

##########################################################################################
### OBTAIN LIST OF NESTED MANIFESTS ######################################################
##########################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    {
    #load list of Gibbun software installs from initial manifest into nestedManifestArray
    $nestedManifestArray = $initialManifestXML.manifest.NestedManifest.manifest

    #uncomment next line to display list of nested manifests held in $nestedManifestArray
    #Get-Variable nestedManifestArray
    }

##########################################################################################
### END OF OBTAIN LIST OF NESTED MANIFESTS ###############################################
##########################################################################################

##########################################################################################################################################################################################################################################
### DOWNLOAD NESTED MANIFESTS ############################################################################################################################################################################################################
##########################################################################################################################################################################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    {
    foreach ($nestedManifest in $nestedManifestArray)
        {      
        Write-Verbose "Getting manifest $nestedManifest"
    
        #Attempt to download manifest matching nested manifest.
        Try
            {
            Start-BitsTransfer -Source ($softwareRepoURL + "/manifests/" + $nestedManifest + ".xml") -Destination ($gibbunInstallDir + "\GibbunInstalls\Manifests\" + $nestedManifest + ".xml") -TransferType Download -ErrorAction Stop
            Write-Verbose "Using manifest $nestedManifest"
            }
        Catch
            {
            Write-Verbose "Manifest $nestedManifest not found."
            }
        }
    }

##########################################################################################################################################################################################################################################
### END OF DOWNLOAD NESTED MANIFESTS #####################################################################################################################################################################################################
##########################################################################################################################################################################################################################################

################################################################################################################################
### OBTAIN LIST OF GIBBUN SOFTWARE INSTALLS ####################################################################################
################################################################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    {
    #load list of Gibbun software installs from initial manifest into variable gibbunSoftware
    [array]$gibbunSoftware = $initialManifestXML.manifest.software.program

    #load nested manifests XML files into XML variable and then add nested installs into gibbunSoftware variable
    foreach ($nestedManifest in $nestedManifestArray)
        {
        #load manifest into XML
        [xml]$nestedManifestXML = (Get-Content ($gibbunInstallDir + "\GibbunInstalls\Manifests\" + $nestedManifest + ".xml"))

        #add install items from nested manifests to
        $gibbunSoftware += $nestedManifestXML.manifest.software.program
        }

    #remove any duplicate installs from gibbunSoftware variable
    $gibbunSoftware = $gibbunsoftware | select -uniq

    #uncomment next line to display list of software held in $gibbunSoftware
    #Get-Variable gibbunSoftware

    }

################################################################################################################################
### END OF OBTAIN LIST OF GIBBUN SOFTWARE INSTALLS #############################################################################
################################################################################################################################

###########################################################################################
### OBTAIN LIST OF CATALOGS ###############################################################
###########################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    {
    #load list of catalogs from initial manifest into catalogs array
    [array]$catalogs = $initialManifestXML.manifest.catalogs.catalog

    #load list of catalogs from nested manifests
    foreach ($nestedManifest in $nestedManifestArray)
        {
        $catalogs += $nestedManifestXML.manifest.catalogs.catalog
        }

    #remove any duplicate catalogs from catalogs variable
    $catalogs = $catalogs | select -uniq

    #uncomment next line to display list of catalogs held in $catalogs
    #Get-Variable catalogs
    }

###########################################################################################
### END OF OBTAIN LIST OF NESTED MANIFESTS ################################################
###########################################################################################

###########################################################################################################################################################################################################################
### DOWNLOAD CATALOGS #####################################################################################################################################################################################################
###########################################################################################################################################################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    {
    foreach ($catalog in $catalogs)
        {      
        Write-Verbose "Getting catalog $catalog"
    
        #Attempt to download catalog
        Try
            {
            Start-BitsTransfer -Source ($softwareRepoURL + "/catalogs/" + $catalog + ".xml") -Destination ($gibbunInstallDir + "\GibbunInstalls\Catalogs\" + $catalog + ".xml") -TransferType Download -ErrorAction Stop
            Write-Verbose "Using catalog $catalog"
            }
        Catch
            {
            Write-Verbose "Catalog $catalog not found."
            }
        }
    }

###########################################################################################################################################################################################################################
### END OF DOWNLOAD CATALOGS ##############################################################################################################################################################################################
###########################################################################################################################################################################################################################

###################################################################################################################################################################################
### OBTAIN SOFTWARE VERSIONS ######################################################################################################################################################
###################################################################################################################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    {
    #create variable $softwareVersionsArray
    [array]$softwareVersionsArray
    
    #go through each catalog and determine which software version to install **NOTE: Gibbun will install the first version of a software it sees (based on ordering of catalogs)**
    foreach ($catalog in $catalogs)
        {
        #load each catalog as XML file
        [xml]$catalogXML = (Get-Content ($gibbunInstallDir + "\GibbunInstalls\Catalogs\" + $catalog + ".xml"))
        
        #obtain software from currently loaded catalog and add it to $softwareVersionsArray variable for safe-keeping
        $softwareVersionsArray = ($softwareVersionsArray + ($catalogXML.catalog.software))
        }

    #pipe list of software to be installed into $softwareVersionsArray
    $softwareVersions = $softwareVersionsArray|Group-Object name|ForEach-Object {$_.Group[0]}
    
    #create $finalSoftwareVariable to avoid fixed size error when removing objects from array    
    [system.collections.arraylist]$finalSoftwareVersions = $softwareVersions
     
    #determine packages in catalog that intersect with manifest. remove those that do not intersect   
    ForEach ($package in $softwareVersions)
        {       
        If ($gibbunSoftware -notcontains $package.name)
            {
            $finalSoftwareVersions.Remove($package)
            }
        }
    }

###################################################################################################################################################################################
### END OF OBTAIN SOFTWARE VERSIONS ###############################################################################################################################################
###################################################################################################################################################################################

#####################################################################################################################
### OBTAIN REQUIRED INSTALL SOFTWARE VERSIONS #######################################################################
#####################################################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    {
    #creates empty array $requiredInstalls and pass it to a collection
    $requiredInstalls = {$Null}.Invoke()

    #determine required installs
    ForEach ($package in $finalSoftwareVersions)
        {       
        If ($package.requires.name -ne $Null)
            {
            $requiredInstalls.Add($package)
            }
        }
    
    #if $requiredInstalls is not empty, display required install software
    If ($requiredInstalls -ne $null)
        {
        foreach ($package in $requiredInstalls)
            {
            If ($package.name -ne $Null)
                {
                Write-Verbose "$package.name 'requires' $package.requires.name 'to be installed'"
                }
            }
        }

    #pipe list of software to be installed into $requiredSoftwareVersionsArray
    $requiredSoftwareVersions = $SoftwareVersionsArray|Group-Object name|ForEach-Object {$_.Group[0]}
    
    #create $finalRequiredSoftwareVariable to avoid fixed size error when removing objects from array    
    [system.collections.arraylist]$finalRequiredSoftwareVersions = $requiredSoftwareVersions
     
    #determine packages in catalog that intersect with required installs. remove those that do not intersect   
    ForEach ($package in $requiredSoftwareVersions)
        {       
        If (-Not($requiredInstalls.requires.name.Contains($package.name)))
            {
            $finalRequiredSoftwareVersions.Remove($package)
            }
        }
    }

#####################################################################################################################
### END OF OBTAIN REQUIRED INSTALL SOFTWARE VERSIONS ################################################################
#####################################################################################################################

#######################################################################################
### DETERMINE PACKAGES MISSING A CATALOG ##############################################
#######################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    {
    #creates empty array $softwareMissingCatalog and pass it to a collection
    $softwareMissingCatalog = {$Null}.Invoke()

    #determine packages in manifest that do not have a matching catalog   
    ForEach ($software in $gibbunSoftware)
        {       
        If (-Not($softwareVersions.name.Contains($software)))
            {
            $softwareMissingCatalog.Add($software)
            }
        }

    #determine required installs that do not have a matching catalog   
    ForEach ($package in $requiredInstalls)
        {       
        If (-Not($requiredSoftwareVersions.name.Contains($package.requires.name)))
            {
            $softwareMissingCatalog.Add($package.requires.name)
            }
        }
    #remove duplciates from $softwareMissingCatalog
    $softwareMissingCatalog = $softwareMissingCatalog|Group-Object name|ForEach-Object {$_.Group[0]}
    }

#######################################################################################
### END OF DETERMINE PACKAGES MISSING A CATALOG #######################################
#######################################################################################

#########################################################################################################################################
### DETERMINE DUPLICATE PACKAGES IN INSTALLS & REQUIRED INSTALLS  #######################################################################
#########################################################################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    {
    #create $packageDownloads to avoid fixed size error when removing objects from array    
    [system.collections.arraylist]$packageDownloads = $finalSoftwareVersions

    #determine packages in client manifest that intersect with required installs. remove the duplicates to prevent duplicate downloads  
    ForEach ($package in $finalRequiredSoftwareVersions)
        {       
        Try
            {
            If (-Not($packageDownloads.name.requires.Contains($package.requires.name)))
                {
                $packageDownloads.Add($package)
                }
            }
        Catch
            {
            }
        }
    }

#########################################################################################################################################
### END OF DETERMINE DUPLICATE PACKAGES IN INSTALLS & REQUIRED INSTALLS #################################################################
#########################################################################################################################################

#####################################################################################################################################
### DETERMINE WHICH PACKAGES ACTUALLY NEED INSTALLED ################################################################################
#####################################################################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    {
    #for each required software install, check if preinstall check script exists. If it does, run it.
    ForEach ($package in $packageDownloads)
        {
        If ($package.installcheck_script -ne $Null)
            {
            #read install check script for each software and write it to string
            [String]$installCheck_ScriptString = $package.installcheck_script

            #convert string to scriptblock
            $installCheck_Script = [Scriptblock]::Create($installCheck_ScriptString)

            #pass in the base64 encoded version of the script to avoid possible issues if it uses escape characters
            $encodedInstallCheck_Script = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($installCheck_Script))
            
            #start separate powershell instance to process the install check script
            $installCheck_ScriptProcess = (Start-Process powershell.exe -ArgumentList "-EncodedCommand",$encodedInstallCheck_Script -PassThru -Wait)

            #if exit code does not equal 0, software is considered to be installed and removed from list of software to download
            If ($installCheck_ScriptProcess.ExitCode -ne 0)
                {
                $packageDownloads.Remove($package)
                }
            }
        #If no install check script, check if package is installed via registry
        Else
            {
            }
                        
       
            <#obtain software name as listed in Programs and Features in Control Panel
            $win32name = $package.win32_name
            $win32.version = $package.win32_version#>
        }
    }

#####################################################################################################################################
### END OF DETERMINE WHICH PACKAGES ACTUALLY NEED INSTALLED #########################################################################
#####################################################################################################################################

##########################################################################################
### DISPLAY PACKAGES MISSING A CATALOG AND THOSE TO BE INSTALLED #########################
##########################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    { 
    #if $softwareMissingCatalog is not empty, display software that is missing a catalog
    If ($softwareMissingCatalog -ne $null)
        {
        Write-Warning "The following software is missing a catalog:"
        $softwareMissingCatalog
        #line break for easier reading
        Write-Host `n
        }

    If ($packageDownloads -ne $null)
        {
        Write-Host "The following packages will be downloaded and installed:"
        $packageDownloads
        "------------------------------------------------------------------------------------------------------------------------"
        #line break for easier reading
        Write-Host `n
        }
    }

##########################################################################################
### END OF DISPLAY PACKAGES MISSING A CATALOG AND THOSE TO BE INSTALLED ##################
##########################################################################################

###########################################################################################################################################################################################################################################
### DOWNLOAD GIBBUN SOFTWARE INSTALLS #####################################################################################################################################################################################################
###########################################################################################################################################################################################################################################

If ((-Not(($windowsUpdatesOnly))) -and ($haveManifest))
    {
    Write-Host "Begin Downloading packages"
    foreach ($package in $packageDownloads)
        {      
        $softwareName = $package.name
        $softwareVersion = $package.version
        $softwareInstallerLocation = $package.installer_location
        Write-Host "Downloading $softwareName $softwareVersion"
    
        #Attempt to download package
        Try
            {
            #replace backslashes with forward slashes to correct web server path to work for download path
            $softwareInstallerDownloadLocation=$softwareInstallerLocation -replace "/", "\"

            #Create download directory if it doesn't exist.
            New-Item -ItemType Directory -Force -Path ($gibbunInstallDir + "\GibbunInstalls\Downloads\" + $softwareInstallerDownloadLocation) | Out-Null

            #download installer
            Start-BitsTransfer -Source ($softwareRepoURL + "/packages/" + $softwareInstallerLocation) -Destination ($gibbunInstallDir + "\GibbunInstalls\Downloads\" + $softwareInstallerDownloadLocation) -TransferType Download -ErrorAction Stop
            }
        Catch
            {
            Write-Verbose "Encountered an error downloading $softwareName $softwareVersion"
            }
        }
    }

###########################################################################################################################################################################################################################################
### END OF DOWNLOAD GIBBUN SOFTWARE INSTALLS ##############################################################################################################################################################################################
###########################################################################################################################################################################################################################################

###########################################################################################################################
### WINDOWS UPDATES #######################################################################################################
###########################################################################################################################

#import PowerShell Windows Update modules
Write-Verbose "Importing Windows Update Modules"
IPMO (Join-Path $gibbunInstallDir -ChildPath Resources\WindowsUpdatePowerShellModule\PSWindowsUpdate)

#Check if $installWindowsUpdates is true in ManagedInstalls.XML. Skip Windows Updates if False.
If ($installWindowsUpdates -or $windowsUpdatesOnly)
    {
    #Check if Windows Updates been run in last $daysBetweenWindowsUpdates day(s). If so, skip Windows Updates.
    $windowsUpdateTimeSpan = (new-timespan -days $daysBetweenWindowsUpdates)
    If (((Get-Date) - $lastWindowsUpdateCheck) -gt $windowsUpdateTimeSpan)
        {
        Write-Verbose "Checking for available Windows Updates..."
        #Use command on next line for command information
        #Help Get-WUInstall –full
        #if checkonly is enabled, only download updates, otherwise, install Windows Updates (except for Language Packs)
        If ($checkOnly)
            {
            Get-WUInstall -NotCategory "Language packs" -MicrosoftUpdate -DownloadOnly -AcceptAll -IgnoreReboot -Verbose
            }
        Else
            {
            Get-WUInstall -NotCategory "Language packs" -MicrosoftUpdate -AcceptAll -IgnoreReboot -Verbose
            
            #Update LastWindowsUpdateCheck in ManagedInstalls.XML
            $managedInstallsXML.SelectSingleNode("//LastWindowsUpdateCheck").InnerText = (Get-Date)
            #save changes to ManagedInstalls.XML
            $managedInstallsXML.Save($gibbunInstallDir + "\ManagedInstalls.xml")
            }
        }
    }

###########################################################################################################################
### END OF WINDOWS UPDATES ################################################################################################
###########################################################################################################################

Write-Verbose "Finishing..."

######################################################################################################################################
### POSTFLIGHT SCRIPT ################################################################################################################
######################### ############################################################################################################

#check if postflight script exists and call it if it does exist. Exit if postflight script encounters an error.
Write-Verbose "Checking if postflight script exists"
If (Test-Path (Join-Path $gibbunInstallDir -ChildPath postflight.ps1))
    {
    Write-Verbose "Postflight script exists";
    Write-Verbose "Running postflight script";
    Invoke-Expression (Join-Path $gibbunInstallDir -ChildPath postflight.ps1);
        If ($LastExitCode > 0)
        {
        Write-Warning "Postflight script encountered an error"
        Exit
        }
    }
Else {Write-Verbose "Postflight script does not exist. If this is in error, please ensure script is in the Gibbun install directory"}

######################################################################################################################################
### END OF POSTFLIGHT SCRIPT #########################################################################################################
######################################################################################################################################

################################################################################################
### PENDING REBOOT CHECK #######################################################################
################################################################################################
 
#Check if there is a pending system reboot, if there is, the computer is restarted. 
[bool]$RebootStatus = Get-WURebootStatus -silent
If ($RebootStatus)
    {
    Write-Verbose "A system reboot is required. Restarting computer now..."
    Get-WURebootStatus -AutoReboot
    }
Else
    {
    Write-Verbose "A system reboot is not required"
    }

################################################################################################
### END OF PENDING REBOOT CHECK ################################################################
################################### ############################################################