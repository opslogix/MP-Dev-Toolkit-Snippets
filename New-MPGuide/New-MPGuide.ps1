# 
# Name: New-MPGuide.ps1 
# 
# Description:
# This script creates a HTML document from an XML managament pack.
# First it extracts information about the various entities and workflows and
# then it creates an HTML document from templates.
#
# Version: 1.0

param (
		[string]$MPFile,            # The MP file to generate document for.
        [switch]$ShowOutput,        # This enables output from the script.
        [switch]$Verbose,           # This enables verbose output.
        [switch]$ForceKnowledge,    # This collects all the descriptions from the knowledge doucuments.
                                    # Default is collection them from the description tag of the display string.
                                    # TODO: Make so that not everything goes on knowledge. Class and some other things
                                    # should still be from the display string.
        [switch]$OpenPage           # If this is supplied the script opens the HTML file in the default browser.
	)
#TODO: Implement SuppressWarnings

### Variables
$stylesheet = "bootstrap.min.css"   # This is the style sheet that gets embedded in the HTML document.
                                    # It needs to be located in the styles folder.

$scriptOutput += "Starting script.`n"
if ($Verbose)
{
    $scriptOutput += "Arguments and Varibles:`n"
    $scriptOutput += "`tMPFILE: '$MPFile'`n"
    $scriptOutput += "`tShowOutput: '$ShowOutput'`n"
    $scriptOutput += "`tVerbose: '$Verbose'`n"
    $scriptOutput += "`tForceKnowledge: '$ForceKnowledge'`n"
    $scriptOutput += "`tSuppressWarning: '$SuppressWarning'`n"
    $scriptOutput += "`tstylesheet: '$stylesheet'`n"
}


### Functions
function Get-DisplayName($elementid)
{
    # This function get the display name from the display string and returns it.
    # If not found it replaces the name with an error message.
    $desc = $xml.SelectNodes("//DisplayString[(@ElementID='$elementid') and not (@SubElementID)]").Name
    if ([string]::IsNullOrEmpty($desc))
    {
        $desc = "<span class=""text-danger"">No display name found.</span>"
    }
    return $desc
}
function Get-Description($elementid)
{
    # This function get the description for the element. If not found it replaces the name with an error message.
    # It either gets it from the display string or from the knowledge document.
    if($ForceKnowledge)
    {
        $desc = $xml.SelectSingleNode("//KnowledgeArticle[@ElementID='$elementid']").MamlContent.section.para
        if ([string]::IsNullOrEmpty($desc))
        {
            $desc =  "<div class=""alert alert-danger"" role=""alert""><span><strong>Unable to find description</strong><br />Please add a Knowledge Article for '$elementid' and update the summary section.</span></div>"
        }
    }
    else
    {
        $desc = $xml.SelectNodes("//DisplayString[(@ElementID='$elementid') and not (@SubElementID)]").Description
        if ([string]::IsNullOrEmpty($desc))
        {
            $desc =  "<div class=""alert alert-danger"" role=""alert""><span><strong>Unable to find description</strong><br />Please add a display string for '$elementid' and update the description element.</span></div>"
        }
    }
    return $desc
}

function Get-CommonWorkflowProperties($workflow)
{
    # This function gets a number of default properties for a workflow.
    # This is to reduce redundant code. DRY and all that.
    # In some cases the workflow don't have one of the properties, it will just
    # be empty then.
    $id = $workflow.ID
    $header = $workflow.ID.Replace("$mpid.","") # This removes the MPID from the workflow id.
                                                # Makes it easier to read.
    $target = $workflow.Target
    $enabled = $workflow.Enabled
    $displayname = Get-DisplayName($id)
    $summary = Get-Description($id)
    
    # Create a new object and add the properties.
    $w = New-Object psobject
    $w | Add-Member -MemberType NoteProperty -Name ID -Value $id
    $w | Add-Member -MemberType NoteProperty -Name Header -Value $header
    $w | Add-Member -MemberType NoteProperty -Name DisplayName -Value $displayname
    $w | Add-Member -MemberType NoteProperty -Name Target -Value $target
    $w | Add-Member -MemberType NoteProperty -Name Enabled -Value $enabled
    $w | Add-Member -MemberType NoteProperty -Name Summary -Value $summary

    return $w   
}

function New-ClassHTML ($element)
{
    # This function generates the HTML for a class element.
    
    # This line reads the content of the template. It is returned as a string[] 
    # object (one element for each new line). Each element in the array is then 
    # joined by a `n to convert it to a string object and preserve the
    # new lines. 
    $class_template = [string]::Join("`n",$(Get-Content "./templates/class_template.html"))
    # Replace some common properties in the template.
    $class_template = $class_template.Replace("@@CLASSID@@",$element.id)
    $class_template = $class_template.Replace("@@CLASSSUMMARY@@",$element.Summary)
    $class_template = $class_template.Replace("@@CLASSDISPLAYNAME@@",$element.DisplayName)
    
    # Generate a table for class properties.
    if ($class.Properties.Count -ne 0)
    {
        $properties = "<table class=""table table-striped"">`n"
        $properties += "<tr><th>ID</th><th>Type</th><th>Key</th></tr>`n"
        foreach ($property in $element.Properties)
        {
            $properties += "<tr><td>$($property.ID)</td><td>$($property.Type)</td><td>$($property.Key)</td></tr>`n"
        }
        $properties += "</table>"
    }
    else
    {
        $properties = "<em>No properties defined</em>"
    }
    $class_template = $class_template.Replace("@@PROPERTIES@@",$properties)
    return $class_template
}
function New-DiscoveryHTML ($discovery)
{
    # This function generates the HTML for a discovery workflow.
    #TODO: Change so that this function uses the generic function. 
    
    # This line reads the content of the template. It is returned as a string[] 
    # object (one element for each new line). Each element in the array is then 
    # joined by a `n to convert it to a string object and preserve the
    # new lines. 
    $discovery_template = [string]::Join("`n", $(Get-Content "./templates/discovery_template.html"))
    # Replace some common properties in the template.
    $discovery_template = $discovery_template.Replace("@@DISCOVERYHEADER@@", $discovery.Header)
    $discovery_template = $discovery_template.Replace("@@DISCOVERYID@@", $discovery.Id)
    $discovery_template = $discovery_template.Replace("@@DISCOVERYDISPLAYNAME@@", $discovery.DisplayName)
    $discovery_template = $discovery_template.Replace("@@DISCOVERYSUMMARY@@", $discovery.Summary)
    
    # Generate a table for the discovery info.
    $discoveryinfo = "<table class=""table table-striped"">`n"
    $discoveryinfo += "<tr><th>Enabled</th><th>Target</th><th>TypeId</th></tr>`n"
    $discoveryinfo += "<tr><td>$($discovery.Enabled)</td><td>$($discovery.Target)</td><td>$($discovery.DiscoveryTypeID)</td></tr>`n"
    $discoveryinfo += "</table>"
    $discovery_template = $discovery_template.Replace("@@DISCOVERYINFO@@", $discoveryinfo)
    
    # Generate a table for the discovered classes.
    $discoverdclasses = ""
    if ($discovery.Classes.Count -ne 0)
    {
        $discoverdclasses = "<h4>Discovered classes</h4>"
        $discoverdclasses += "<table class=""table table-striped"">`n"
        $discoverdclasses += "<tr><th>TypeId</th></tr>`n"
        foreach ($dclass in $discovery.Classes)
        {
            $discoverdclasses += "<tr><td>$dclass</td></tr>`n"
        }
        $discoverdclasses += "</table>"
    }
    $discovery_template = $discovery_template.Replace("@@DISCOVEREDCLASSES@@", $discoverdclasses)
    
    # Generate a table for the discovered relationships.
    $discoveredrelationship = ""
    if ($discovery.RelationShips.Count -ne 0)
    {
        $discoveredrelationship = "<h4>Discovered relationships</h4>"
        $discoveredrelationship += "<table class=""table table-striped"">`n"
        $discoveredrelationship += "<tr><th>TypeId</th></tr>`n"
        foreach ($drel in $discovery.RelationShips)
        {
            $discoveredrelationship += "<tr><td>$drel</td></tr>`n"
        }
        $discoveredrelationship += "</table>"
    }
    $discovery_template = $discovery_template.Replace("@@DISCOVEREDRELATIONSHIPS@@", $discoveredrelationship)
    
    return $discovery_template 
}  

function New-WorkflowHTML ($workflow)
{
    # This function generates the HTML for a generic workflow.
    # It is called from the other HTML-generating functions for a basic template.
    
    # This line reads the content of the template. It is returned as a string[] 
    # object (one element for each new line). Each element in the array is then 
    # joined by a `n to convert it to a string object and preserve the
    # new lines.
    $workflow_template = [string]::Join("`n", $(Get-Content "./templates/monitor_template.html"))
    # Replace some common properties in the template.
    $workflow_template = $workflow_template.Replace("@@WORKFLOWHEADER@@", $workflow.Header)
    $workflow_template = $workflow_template.Replace("@@WORKFLOWID@@", $workflow.Id)
    $workflow_template = $workflow_template.Replace("@@WORKFLOWDISPLAYNAME@@", $workflow.DisplayName)
    $workflow_template = $workflow_template.Replace("@@WORKFLOWSUMMARY@@", $workflow.Summary)
    
    return $workflow_template
}

function New-MonitorHTML ($workflow)
{
    # This function generates the HTML for a monitor workflow.
    
    # Get a basic workflow template.
    $workflow_template = New-WorkflowHTML($workflow)
    # Add a table for the monitor properties.
    $workflowinfo = "<table class=""table table-striped"">`n"
    $workflowinfo += "<tr><th>Enabled</th><th>Target</th><th>TypeId</th></tr>`n"
    $workflowinfo += "<tr><td>$($workflow.Enabled)</td><td>$($workflow.Target)</td><td>$($workflow.TypeId)</td></tr>`n"
    $workflowinfo += "</table>"
    $workflow_template = $workflow_template.Replace("@@WORKFLOWINFO@@", $workflowinfo)
    
    return $workflow_template
}   

function New-ViewHTML ($workflow)
{
    # This function generates the HTML for a view entity.
    
    # Get a basic template.
    $workflow_template = New-WorkflowHTML($workflow)
    # Add a table for the view properties.
    $workflowinfo = "<table class=""table table-striped"">`n"
    $workflowinfo += "<tr><th>Enabled</th><th>Target</th><th>Visible</th></tr>`n"
    $workflowinfo += "<tr><td>$($workflow.Enabled)</td><td>$($workflow.Target)</td><td>$($workflow.Visible)</td></tr>`n"
    $workflowinfo += "</table>"
    $workflow_template = $workflow_template.Replace("@@WORKFLOWINFO@@", $workflowinfo)
    
    
    return $workflow_template
} 
function New-TaskHTML ($workflow)
{
    # This function generates the HTML for a task workflow.
    
    # Get a basic template.
    $workflow_template = New-WorkflowHTML($workflow)
    # Add a table for the task properties.
    $workflowinfo = "<table class=""table table-striped"">`n"
    $workflowinfo += "<tr><th>Enabled</th><th>Target</th></tr>`n"
    $workflowinfo += "<tr><td>$($workflow.Enabled)</td><td>$($workflow.Target)</td></tr>`n"
    $workflowinfo += "</table>"
    $workflow_template = $workflow_template.Replace("@@WORKFLOWINFO@@", $workflowinfo)
    
    
    return $workflow_template
}
function New-FolderHTML ($workflow)
{
    # This function generates the HTML for a folder entity.
    
    # Get a basic template.
    $workflow_template = New-WorkflowHTML($workflow)
    # Add a table for the task properties.
    $workflowinfo = "<table class=""table table-striped"">`n"
    $workflowinfo += "<tr><th>Parent Folder</th></tr>`n"
    $workflowinfo += "<tr><td>$($workflow.ParentFolder)</td></tr>`n"
    $workflowinfo += "</table>"
    $workflow_template = $workflow_template.Replace("@@WORKFLOWINFO@@", $workflowinfo)
    
    
    return $workflow_template
} 
  
###########################################
### Load and extract data from XML File ###

# Check that we can find the MP File
$scriptOutput += "Checking path to supplied MPFile. "
if (Test-Path $MPfile)
{
	$scriptOutput += "Supplied path OK.`n"
}
else
{
	Write-Error "Can't find supplied MP file ($MPFile). Aborting script."
	exit
}

# Get the MP File
$managementPack = Get-ChildItem -Path $MPFile
if ($managementPack)
{
    $scriptOutput += "Loaded MPFile.`n"
}
else
{
    Write-Error "Failed to load MPFile."
    exit
}

# Check if XML or MP
if ($managementPack.Extension -eq ".xml")
{
    $scriptOutput += "MPFile is of a supported format (xml).`n"
}
elseif ($managementPack.Extension -eq ".mp")
{
    Write-Warning "This script does not support sealed management packs yet."
    exit
}
else
{
    Write-Error "The supplied file is not of a supported type."
    exit
}


### Extract data from XML file
# Open and get all elements
[xml] $xml = Get-Content -Path $managementPack
$scriptOutput += "Loaded read content of file.`n"

### Management pack info
$scriptOutput += "Reading MP Info.`n"
$mpid = $xml.SelectSingleNode("//Identity").ID
if($Verbose) {$scriptOutput += "`tmpid: $mpid`n"}

$mpversion = $xml.SelectSingleNode("//Identity").Version
if($Verbose) {$scriptOutput += "`tmpversion: '$mpversion'`n"}

$mpdisplayname = Get-DisplayName($mpid)
if($Verbose) {$scriptOutput += "`tmpdisplayname: '$mpdisplayname'`n"}

$mpsummary = Get-Description($mpid)    
if($Verbose) {$scriptOutput += "`tmpsummary: '$mpsummary'`n"}


### Classes
$scriptOutput += "Reading Class info.`n"
$ClassesList = New-Object System.Collections.ArrayList
$GroupsList = New-Object System.Collections.ArrayList
$classTypes = $xml.SelectNodes("//ClassTypes")
if($Verbose) {$scriptOutput += "`tFound $($($classTypes.ClassType).Count) class type(s).`n"}

foreach ($classType in $classTypes.ClassType)
{
    $classid = $classType.ID
    if($Verbose) {$scriptOutput += "`t'$classid'`n"}
    
    $classdisplayname = Get-DisplayName($classid)
    $classsummary  = Get-Description($classid)
        
    $class = New-Object psobject
    $class | Add-Member -MemberType NoteProperty -Name ID -Value $classid
    $class | Add-Member -MemberType NoteProperty -Name DisplayName -Value $classdisplayname
    $class | Add-Member -MemberType NoteProperty -Name Summary -Value $classsummary

    $classProperties = New-Object System.Collections.ArrayList
    foreach ($prop in $classType.SelectNodes("Property"))
    {
        $property = New-Object psobject
        $property | Add-Member -MemberType NoteProperty -Name ID -Value $prop.ID
        $property | Add-Member -MemberType NoteProperty -Name Type -Value $prop.Type
        $property | Add-Member -MemberType NoteProperty -Name Key -Value $prop.Key            
        
        $classProperties.Add($property) | Out-Null
    }
    $class | Add-Member -MemberType NoteProperty -Name Properties -Value $classProperties
    
    # Check if it's a group or a 'normal' class.
    # If it's a group it is stored in a seperate list and presented in its own section in the
    # MP guide.
    if ($classtype.Base -match ".*Group")
    {
        $GroupsList.Add($class) | Out-Null
    } 
    else
    {
        $ClassesList.Add($class) | Out-Null
    }
}
if($Verbose) {$scriptOutput += "Identified $($ClassesList.Count) class(es) and $($GroupsList.Count) group(s).`n"}

### Discoveries
$scriptOutput += "Reading Discovery info.`n"
$DiscoveriesList = New-Object System.Collections.ArrayList
$discoveries = $xml.SelectNodes("//Discoveries")   
if($Verbose) {$scriptOutput += "`tFound $($($discoveries.Discovery).Count) discoveries.`n"}    
foreach ($discovery in $discoveries.Discovery)
{
    $o = Get-CommonWorkflowProperties($discovery)
    if($Verbose) {$scriptOutput += "`t'$($o.id)'`n"}
    $o | Add-Member -MemberType NoteProperty -Name DiscoveryTypeID -Value $discovery.Datasource.TypeId
    
    $discoveredClasses = New-Object System.Collections.ArrayList  
    foreach ($discoveredClass in $discovery.DiscoveryTypes.SelectNodes("DiscoveryClass"))
    {
        $discoveredClasses.Add($discoveredClass.TypeID) | Out-Null
    }
    $o | Add-Member -MemberType NoteProperty -Name Classes -Value $discoveredClasses
    
    $discoveredRelationShips = New-Object System.Collections.ArrayList  
    foreach ($discoveredClass in $discovery.DiscoveryTypes.SelectNodes("DiscoveryRelationship"))
    {
        $discoveredRelationShips.Add($discoveredClass.TypeID) | Out-Null
    }
    $o | Add-Member -MemberType NoteProperty -Name RelationShips -Value $discoveredRelationShips

    # TODO: Find a way to extract the parameters.
    $discoveryParameters = New-Object System.Collections.ArrayList
    foreach ($param in $ds.Childnodes)
    {
        $parameter = New-Object psobject
        $parameter | Add-Member -MemberType NoteProperty -Name $param.Name -Value $param
        $discoveryParameters.Add($parameter) | Out-Null
    }
    $o | Add-Member -MemberType NoteProperty -Name Properties -Value $discoveryParameters
    $discoveryParameters[0]
    $DiscoveriesList.Add($o) | Out-Null
}

### Monitors
$scriptOutput += "Reading Monitor info.`n"
$MonitorsList = New-Object System.Collections.ArrayList
$monitors = $xml.SelectNodes("//Monitors")
if($Verbose) {$scriptOutput += "`tFound $($($monitors.UnitMonitor).Count) monitors.`n"}
foreach ($monitor in $monitors.UnitMonitor)
{
    $o = Get-CommonWorkflowProperties($monitor)
    if($Verbose) {$scriptOutput += "`t'$($o.id)'`n"}
    $o | Add-Member -MemberType NoteProperty -Name TypeId -Value $monitor.TypeID
    $MonitorsList.Add($o) | Out-Null
}

### Rules
$scriptOutput += "Reading Rules info.`n"
$RulesList = New-Object System.Collections.ArrayList
$rules = $xml.SelectNodes("//Rules")
if($Verbose) {$scriptOutput += "`tFound $($($Rules.Rule).Count) rules.`n"}
foreach ($rule in $rules.Rule)
{
    $o = Get-CommonWorkflowProperties($rule)
    if($Verbose) {$scriptOutput += "`t'$($o.id)'`n"}
    $o | Add-Member -MemberType NoteProperty -Name TypeId -Value $rule.DataSources.DataSource.TypeId
    $RulesList.Add($o) | Out-Null
}

### Views
$scriptOutput += "Reading View info.`n"
$ViewsList = New-Object System.Collections.ArrayList
$views = $xml.SelectNodes("//Views")    
if($Verbose) {$scriptOutput += "`tFound $($($Views.View).Count) views.`n"}
foreach ($view in $views.View)
{
    $o = Get-CommonWorkflowProperties($view)
    if($Verbose) {$scriptOutput += "`t'$($o.id)'`n"}
    $o | Add-Member -MemberType NoteProperty -Name Visible -Value $view.Visible
    $ViewsList.Add($o) | Out-Null
}

### Tasks
$scriptOutput += "Reading Tasks info.`n"
$TasksList = New-Object System.Collections.ArrayList
$tasks = $xml.SelectNodes("//Tasks")   
if($Verbose) {$scriptOutput += "`tFound $($($tasks.Task).Count) tasks.`n"}

foreach ($task in $tasks.Task)
{
    $o = Get-CommonWorkflowProperties($task)
    if($Verbose) {$scriptOutput += "`t'$($o.id)'`n"}
    $TasksList.Add($o) | Out-Null
}

# Folders
$scriptOutput += "Reading Tasks info.`n"
$FoldersList = New-Object System.Collections.ArrayList
$folders = $xml.SelectNodes("//Folders")   
if($Verbose) {$scriptOutput += "`tFound $($($folders.Folder).Count) folders.`n"}

foreach ($folder in $folders.Folder)
{
    $o = Get-CommonWorkflowProperties($folder)
    if($Verbose) {$scriptOutput += "`t'$($o.id)'`n"}
    $o | Add-Member -MemberType NoteProperty -Name ParentFolder -Value $folder.ParentFolder
    $FoldersList.Add($o) | Out-Null
}


##########################
### Generate HTML file ###

$scriptOutput += "Generating HTML output.`n"
# Load page template
$page = Get-Content "./templates/page_template.html"

# This line reads the content of the stylesheet. It is returned as a string[] 
# object (one element for each new line). Each element in the array is then 
# joined by a `n to convert it to a string object and preserve the
# new lines. 
$css = [string]::Join("`n",$(Get-Content "./styles/$stylesheet"))

# Insert CSS into template.
$page = $page.Replace("@@STYLE@@", $css)
if($Verbose) {$scriptOutput += "`tInserting stylesheet '$stylesheet'.`n"}

# Insert MP Info
$page = $page.Replace("@@MPDISPLAYNAME@@", $mpdisplayname)
$page = $page.Replace("@@MPSUMMARY@@", $mpsummary)
$page = $page.Replace("@@MPVERSION@@", $mpversion)
if($Verbose) {$scriptOutput += "`tInserting mp info.`n"}

# Insert TOC
# This code generates the TOC based on the different workflows and
# entities found.
# TODO: See if this can be put into a function and made easier to read.
$toc = [string]::Join("`n",$(Get-Content "./templates/toc_template.html"))
if($Verbose) {$scriptOutput += "`tGenerating table of contents.`n"}
if ($ClassesList.Count -ne 0)
{
    foreach ($class in $ClassesList)
    {
        $toc_classes += "<li><a href='#$($class.DisplayName)'>$($class.DisplayName)</a></li>`n"
    }    
}
else
{
    $toc_classes = "<li>No classes defined.</li>"
}
if ($GroupsList.Count -ne 0)
{
    foreach ($group in $GroupsList)
    {
        $toc_groups += "<li><a href='#$($group.DisplayName)'>$($group.DisplayName)</a></li>`n"
    }
}
else
{
    $toc_groups = "<li>No groups defined.</li>"
}
if ($DiscoveriesList.Count -ne 0)
{
    foreach ($discovery in $DiscoveriesList)
    {
        $toc_discoveries += "<li><a href='#$($discovery.Header)'>$($discovery.DisplayName)</a></li>`n"
    }
}
else
{
    $toc_discoveries = "<li>No discoveries defined.</li>"
}
if ($MonitorsList.Count -ne 0)
{
    foreach ($monitor in $MonitorsList)
    {
        $toc_monitors += "<li><a href='#$($monitor.Header)'>$($monitor.DisplayName)</a></li>`n"
    }
}
else
{
    $toc_monitors = "<li>No monitors defined.</li>"
}
if ($RulesList.Count -ne 0)
{
    foreach ($rule in $RulesList)
    {
        $toc_rules += "<li><a href='#$($rule.Header)'>$($rule.DisplayName)</a></li>`n"
    }
}
else
{
    $toc_rules = "<li>No rules defined.</li>"
}
if ($ViewsList.Count -ne 0)
{
    foreach ($view in $ViewsList)
    {
        $toc_views += "<li><a href='#$($view.Header)'>$($view.DisplayName)</a></li>`n"
    }
}
else
{
    $toc_views = "<li>No views defined.</li>"
}
if ($TasksList.Count -ne 0)
{
    foreach ($task in $TasksList)
    {
        $toc_tasks += "<li><a href='#$($task.Header)'>$($task.DisplayName)</a></li>`n"
    }
}
else
{
    $toc_tasks = "<li>No tasks defined.</li>"
}
if ($FoldersList.Count -ne 0)
{
    foreach ($folder in $FoldersList)
    {
        $toc_folders += "<li><a href='#$($folder.Header)'>$($folder.DisplayName)</a></li>`n"
    }
}
else
{
    $toc_folders = "<li>No views defined.</li>"
}
# Insert the HTML into the tempalte.
$toc = $toc.Replace("@@CLASSES@@", $toc_classes)
$toc = $toc.Replace("@@GROUPS@@", $toc_groups)
$toc = $toc.Replace("@@DISCOVERIES@@", $toc_discoveries)
$toc = $toc.Replace("@@MONITORS@@", $toc_monitors)
$toc = $toc.Replace("@@RULES@@", $toc_rules)
$toc = $toc.Replace("@@VIEWS@@", $toc_views)
$toc = $toc.Replace("@@TASKS@@", $toc_tasks)
$toc = $toc.Replace("@@FOLDERS@@", $toc_folders)
$page = $page.Replace("@@TOC@@", $toc)

# Insert class info
#TODO: If the default text is used for class summary, show a warning together with the description.
# But only if SuppressWarnings is false.
if ($ClassesList.Count -eq 0) { $classesHTML = "<p>No classes defined</p>" }
foreach ($class in $ClassesList)
{
    if($Verbose) {$scriptOutput += "`tInserting info for class '$($class.DisplayName)'.`n"}
    $classesHTML += New-ClassHTML($class)
}
$page = $page.Replace("@@CLASSES@@", $classesHTML)

# Insert group info
if ($GroupsList.Count -eq 0) { $groupsHTML = "<p>No groups defined</p>" }
foreach ($group in $GroupsList)
{
    if($Verbose) {$scriptOutput += "`tInserting info for group '$($group.DisplayName)'.`n"}
    $groupsHTML += New-ClassHTML($group)
}
$page = $page.Replace("@@GROUPS@@", $groupsHTML)


# Insert Discovery info
if ($DiscoveriesList.Count -eq 0) { $discoveriesHTML = "<p>No discoveries defined</p>" }
foreach ($discovery in $DiscoveriesList)
{
    if($Verbose) {$scriptOutput += "`tInserting info for discovery '$($discovery.Header)'.`n"}
    $discoveriesHTML += New-DiscoveryHTML($discovery)
}
$page = $page.Replace("@@DISCOVERIES@@", $discoveriesHTML)

# Insert Monitor info
if ($MonitorsList.Count -eq 0) { $monitorsHTML = "<p>No monitors defined</p>" }
foreach ($monitor in $MonitorsList)
{
    if($Verbose) {$scriptOutput += "`tInserting info for monitor '$($monitor.Header)'.`n"}
    $monitorsHTML += New-MonitorHTML($monitor)
}
$page = $page.Replace("@@MONITORS@@", $monitorsHTML)

# Insert Rule info
if ($RulesList.Count -eq 0) { $rulesHTML = "<p>No rules defined</p>" }
foreach ($rule in $RulesList)
{
    if($Verbose) {$scriptOutput += "`tInserting info for rule '$($rule.Header)'.`n"}
    $rulesHTML += New-MonitorHTML($rule)
}
$page = $page.Replace("@@RULES@@", $rulesHTML)

# Insert View info
if ($ViewsList.Count -eq 0) { $viewsHTML = "<p>No views defined</p>" }
foreach ($view in $ViewsList)
{
    if($Verbose) {$scriptOutput += "`tInserting info for view '$($view.Header)'.`n"}
    $viewsHTML += New-ViewHTML($view)
}
$page = $page.Replace("@@VIEWS@@", $viewsHTML)

# Insert Task info
if ($TasksList.Count -eq 0) { $tasksHTML = "<p>No tasks defined</p>" }
foreach ($task in $TasksList)
{
    if($Verbose) {$scriptOutput += "`tInserting info for task '$($task.Header)'.`n"}
    $tasksHTML += New-TaskHTML($task)
}
$page = $page.Replace("@@TASKS@@", $tasksHTML)

# Insert Folder info
if ($FoldersList.Count -eq 0) { $foldersHTML = "<p>No folders defined</p>" }
foreach ($folder in $FoldersList)
{
    if($Verbose) {$scriptOutput += "`tInserting info for folder '$($folder.Header)'.`n"}
    $foldersHTML += New-FolderHTML($folder)
}
$page = $page.Replace("@@FOLDERS@@", $foldersHTML)


# Write document to disk
$page | Out-File -FilePath "./output/$mpid.html" -Encoding utf8
# Open the HTML document in a browser
if ($OpenPage)
{
    Invoke-Item "./output/$mpid.html"
}     

# Show output in console.
if ($ShowOutput)
{
    Write-Output $scriptOutput
}
