#enable verbose messaging in the psm1 file
if ($myinvocation.line -match "-verbose") {
    $VerbosePreference = "continue"
}
Write-Verbose "Loading public functions"

#exclude files that have special requirements
Get-ChildItem -Path $PSScriptRoot\functions\*.ps1 -Exclude 'Get-MyCounter.ps1', 'Get-FileExtensionInfo.ps1' |
ForEach-Object -Process {
    Write-Verbose $_.fullname
    . $_.FullName
}

Write-Verbose "Loading Windows-specific commands"
if ($IsWindows -OR ($PSEdition -eq 'Desktop')) {
    . "$PSScriptRoot\functions\Get-MyCounter.ps1"
}

if ($IsCoreCLR) {
    Write-Verbose "Loading PowerShell 7 specific commands"
    . "$PSScriptRoot\functions\Get-FileExtensionInfo.ps1"
}

Write-Verbose "Define the global PSAnsiFileMap variable"
$json = "psansifilemap.json"

#test for user version in $HOME
$userjson = Join-Path -Path $HOME -ChildPath $json
$modjson = Join-Path -Path $PSScriptRoot -ChildPath $json

if (Test-Path -Path $userjson) {
    $map = $userjson
}
else {
    #use the file from this module
    $map = $modjson
}

#ConvertFrom-Json doesn't write simple objects to the pipeline in Windows PowerShell so I
#need to process the results individually.
$mapData = [System.Collections.Generic.List[object]]::new()

Get-Content -Path $map | ConvertFrom-Json | ForEach-Object { $_ } | ForEach-Object {
    $entry = [pscustomobject]@{
        PSTypeName  = "PSAnsiFileEntry"
        Description = $_.description
        Pattern     = $_.pattern
        Ansi        = $_.ansi
    }
    $mapData.Add($entry)
}
Set-Variable -Name PSAnsiFileMap -Value $mapdata -Scope Global

Write-Verbose "Define special character map"
$global:PSSpecialChar = @{
    FullBlock        = ([char]0x2588)
    LightShade       = ([char]0x2591)
    MediumShade      = ([char]0x2592)
    DarkShade        = ([char]0x2593)
    BlackSquare      = ([char]0x25A0)
    WhiteSquare      = ([char]0x25A1)
    BlackSmallSquare = ([char]0x25AA)
    WhiteSmallSquare = ([char]0x25AB)
    UpTriangle       = ([char]0x25B2)
    DownTriangle     = ([char]0x25BC)
    Lozenge          = ([char]0x25CA)
    WhiteCircle      = ([char]0x25CB)
    BlackCircle      = ([char]0x25CF)
    WhiteFace        = ([char]0x263A)
    BlackFace        = ([char]0x263B)
    SixPointStar     = ([char]0x2736)
    Diamond          = ([char]0x2666)
    Club             = ([char]0x2663)
    Heart            = ([char]0x2665)
    Spade            = ([char]0x2660)
    Section          = ([char]0x00A7)
    RightPointer     = ([char]0x25BA)
    LeftPointer      = ([char]0x25C4)
    BlackRectangle   = ([char]0x25AC)
}

Write-Verbose "Defining the variable `$PSSamplePath to the samples folder for this module"
$global:PSSamplePath = Join-Path -Path $PSScriptroot -ChildPath Samples

Write-Verbose "Add ToDo options to the ISE or VS Code"
if ($psEditor) {
    Write-Verbose "Defining VSCode additions"
    $sb = {
        Param($context = $psEditor.GetEditorContext() )
        $prompt = "What do you need to do?"
        $title = "To Do"
        $item = Invoke-InputBox -Title $title -Prompt $prompt
        $todo = "# TODO: $item [$(Get-Date)]"
        $context.CurrentFile.InsertText($todo)
    }
    $rParams = @{
        Name           = "Insert.ToDo"
        DisplayName    = "Insert ToDo"
        ScriptBlock    = $sb
        SuppressOutput = $false
    }
    Register-EditorCommand @rParams

    Write-Verbose "Adding Set-LocationToFile"
    Function Set-LocationToFile {
        #set location to directory of current file
        [CmdletBinding()]
        [alias("sd", "jmp")]
        [outputtype("none")]
        Param ()

        if ($host.name -match "Code") {

            $context = $psEditor.GetEditorContext()
            $thispath = $context.CurrentFile.Path
            $target = Split-Path -Path $thispath
            Write-Verbose "Using $thispath"
            Write-Verbose "Changing to $target"
            Set-Location -Path $target

            Clear-Host
        }
        else {
            Write-Warning "This command must be run in the VS Code integrated PowerShell terminal."
        }
    }
} #VSCode
elseif ($psise) {
    Write-Verbose "Defining ISE additions"

    if ($psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.DisplayName -notcontains "ToDo") {

        $action = {
            $prompt = "What do you need to do?"
            $title = "To Do"
            $item = Invoke-InputBox -Title $title -Prompt $prompt
            $todo = "# [$(Get-Date)] TODO: $item"
            $psise.CurrentFile.Editor.InsertText($todo)
            #jump cursor to the end
            $psise.CurrentFile.editor.SetCaretPosition($psise.CurrentFile.Editor.CaretLine, $psise.CurrentFile.Editor.CaretColumn)
        }
        #add the action to the Add-Ons menu
        $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("ToDo", $Action, "Ctrl+Alt+2" ) | Out-Null
    }

    Function Set-LocationToFile {
        [cmdletbinding()]
        [alias("sd", "jmp")]
        [OutputType("none")]
        Param()

        if ($host.name -match "ISE") {
            $path = Split-Path -Path $psISE.CurrentFile.FullPath
            Set-Location -Path $path
            Clear-Host
        }
        Else {
            Write-Warning "This command must be run the the PowerShell ISE."
        }
    }
}


#define a function to open the PDF version of the README and other documentation
Function Open-PSScriptToolsHelp {
    [cmdletbinding()]
    Param()
    Write-Verbose "Starting $($myinvocation.mycommand)"
    $pdf = Join-Path -Path $PSScriptRoot -ChildPath PSScriptToolsManual.pdf
    Write-Verbose "Testing the path $pdf"
    if (Test-Path -Path $pdf) {
        Try {
            Write-Verbose "Invoking the PDF"
            Invoke-Item -Path $pdf -ErrorAction Stop
        }
        Catch {
            Write-Warning "Failed to automatically open the PDF. You will need to manually open $pdf."
        }
    }
    else {
        Write-Warning "Can't find $pdf."
    }
    Write-Verbose "Ending $($myinvocation.MyCommand)"
}

$VerbosePreference = "silentlyContinue"