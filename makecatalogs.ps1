<# 
.SYNOPSIS 
    This script reads each pkgsinfo which contain installer settings for each installer and then compiles them all into the appropriate catalog XML files . 
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

###########################################################
###   CONSTANT VARIABLES   ################################
###########################################################

#Declare Gibbun install directory variable
$gibbunInstallDir = $env:SystemDrive + "\Progra~1\Gibbun"

#Declare path of ManagedInstalls.XML
$gibbunManagedInstallsXMLPath = (Join-Path $gibbunInstallDir ManagedInstalls.xml)

###########################################################
###   END OF CONSTANT VARIABLES   #########################
###########################################################

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
    $CatalogsRepoPath = $managedInstallsXML.ManagedInstalls.CatalogsRepoPath
    }
Catch
    {
    Write-Warning "Encountered an error loading SoftwareRepoURL from ManagedInstall.XML..."
    }

#################################################################################################################
### END OF MANAGEDINSTALLS.XML ##################################################################################
#################################################################################################################

#############################################################################################################
### DIRECTORY CHECK #########################################################################################
#############################################################################################################

#Check that pkgsinfo directory exists
If (!(Test-Path ($CatalogsRepoPath + "/pkgsinfo")))
    {
    Write-Warning "Could not find pkgsinfo directory Exiting..."
    Exit
    }

#Check that catalogs directory exists
If (!(Test-Path ($CatalogsRepoPath + "/catalogs")))
    {
    Write-Warning "Could not find pkgsinfo directory Exiting..."
    Exit
    }

#############################################################################################################
### END OF DIRECTORY CHECK ##################################################################################
#############################################################################################################

#start with empty catalogs array
$catalogs = @{}

$pkgsinfo = Get-ChildItem -Path ($CatalogsRepoPath + "/pkgsinfo") -Recurse -Filter *.xml | ForEach-Object -Process {$_.FullName}

$finalXml = ('<?xml version="1.0" encoding="UTF-8"?>
<catalog>')

ForEach ($file in $pkgsinfo)
    {
    [xml]$pkgsinfoXML = Get-Content ($file)   
    $finalXml += $pkgsinfoXML.catalog.InnerXml
    }
$finalXML += "</catalog>"
[XML]$XML = $finalXml
$path = ($CatalogsRepoPath + "/catalogs")
[xml]$XML.Save("$path\all.xml")