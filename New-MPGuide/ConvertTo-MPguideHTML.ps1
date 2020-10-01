#
# Script.ps1
#

param($markdownfile)

# Functions
function Get-ScriptDirectory
{
    Split-Path $script:MyInvocation.MyCommand.Path
}

# Variables
$pandoc_path = "C:\Users\<user>\AppData\Local\Pandoc\pandoc.exe";
$output_path = ".\output"
# $style_output_path = "..\BLogOutput\style"
# $images_output_path =  "..\BlogOutput\images"

Set-Location $(Get-ScriptDirectory)

$file = Get-ChildItem -Path $markdownfile


# Convert markdown doucument
pandoc "$($file.FullName)" --from=markdown_github --to=html5 --output "$output_path\$($file.BaseName).html" -H "styles/MPguide.css"


