[CmdletBinding()]param([Switch]$Git, [Switch]$Chocolatey)
$VerbosePreference = "continue"

# Where .nupkg will go. Usually inside of the Packages.
# directory within your nuget feed.
$destination = 'C:\nugetfeeds\MyFirstFeed\Packages'
# Path to Git
$git_bin = "$env:ProgramFiles\Git\bin\git.exe"
# Git Repo that includes automatic and manual pkgs.
# Using chocolatey core packages as an example.
$repo_url = 'https://github.com/chocolatey/chocolatey-coreteampackages.git'
# Where git choco pkg repo will exist on disk
$repo_dir = ($repo_url.Split('/')[-1]).Replace('.git','')
$repo = "C:\repo-choco-autopkgr\$($repo_dir)"

# Logs!
Start-Transcript -Path "C:\repo-choco-autopkgr\logs\autopkg.log" -Force

# Function to gather git log history.
function Get-GitHistory {
    Write-Verbose 'Getting git history...'
    Set-Location $repo
    $git_hist = (& $git_bin log --format="%ai`t%H`t%an`t%ae`t%s" -n 1) |
                ConvertFrom-Csv `
                    -Delimiter "`t" `
                    -Header ("Date","CommitId","Author","Email","Subject")

    return @{
        'Data' = $git_hist
        'Date' = $git_hist.Date
        'CommitID' = $git_hist.CommitID
        'Author' = $git_hist.Author
        'Email' = $git_hist.Email
        'Subject' = $git_hist.Subject
    }
}

# Function to check change id in repo.
function Get-RepoChangeID {
    # Ensure Repo Folder Exists
    If (!(Test-Path $repo)) {
        Write-Verbose "$repo does not exist, creating..."
        New-Item -ItemType Directory -Force -Path $repo
    }

    # Check Repo for Changes
    If (Test-Path "$repo\.git") {
        Set-Location $repo
        $git_id_before = (Get-GitHistory).CommitID
        Write-Verbose "Git pre_id = $git_id_before"
        & $git_bin pull 2>&1
        $git_id_after = (Get-GitHistory).CommitID
        Write-Verbose "Git post_id = $git_id_after"
    }Else {
        Set-Location (Split-Path $repo)
        Write-Verbose "Downloading repo..."
        & $git_bin clone $repo_url 2>&1
        $git_id_after = (Get-GitHistory).CommitID
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "Error Code: $LASTEXITCODE"
            Write-Verbose "Unable to pull git repo."
            Exit-Session
        }
    }

    return @{
        'pre_id' = $git_id_before
        'post_id' = $git_id_after
    }
}

# Function to get file changes within id diffs.
function Get-RepoDiff {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [string]$pre_id,
        [string]$post_id
    )

    $file_list = & $git_bin diff $pre_id $post_id --name-only --diff-filter=AM
    if ($null -eq $file_list) {
        Write-Verbose 'No changes to repo.'
    }else {
        foreach ($file in $file_list) {
            Write-Verbose $file
        }
    }

    return $file_list
}

# Function to choco pack changes.
function Start-ChocoPkgr {
    [CmdletBinding(
        SupportsShouldProcess = $true
    )]
    param (
        [string]$pkg_name,
        [string]$pkg_folder
    )
    Write-Verbose "Creating/Updating Package: $pkg_name"
    Set-Location $destination

    if (Test-Path $pkg_name) {
        Remove-Item "$pkg_name" -Force -Recurse
    }

    & $env:ProgramData\chocolatey\bin\choco pack `
        "$repo\$pkg_folder\$pkg_name\$pkg_name.nuspec"
}

# Simple exit used in many places.
function Exit-Session {
    Stop-Transcript
    exit 0
}

# Detect if Server, if not exit.
$is_server = (Get-CimInstance Win32_OperatingSystem).Caption -Like "*Server*"
if ($is_server) {
    break
} else {
    Write-Error 'Please use a Windows Server Operating System.'
    Exit-Session
}

# Here we go...
Write-Output 'Starting The Mighty Choco Auto-Pkgr'

# Let's get to packaging!
if ($Git) {
    try {
        # Gathering git data.
        Write-Output 'Checking Git Pull Status:'
        $git_data = Get-RepoChangeID

        # Gather git log file difference.
        Write-Output 'Grabbing Git Log Difference:'
        if (!($null -eq $git_data.pre_id)) {
            $diff_list = Get-RepoDiff `
                            -pre_id $git_data.pre_id `
                            -post_id $git_data.post_id
        }else {
            Write-Verbose 'Fresh repo, no difference.'
        }
        $pkg_list = @()

        Write-Output 'Here we go:'
        if ($git_data.pre_id -eq $git_data.post_id) {
            Write-Verbose 'Git pre_id and post_id are a match, no updates landed.'
        }elseif ($null -eq $git_data.pre_id) {
            Write-Verbose 'Fresh repo, creating all packages detected.'
            $list = Get-ChildItem -Path $repo -Filter *.nuspec -Recurse -Name
            foreach ($item in $list) {
                Set-Location $destination
                $file = $item.Split('\')[-1] -replace '\.\w+$'

                if (Test-Path "$file") {
                    Remove-Item "$file" -Force -Recurse
                }
                & $env:ProgramData\chocolatey\bin\choco pack "$repo\$item"
            }
        }else {
            foreach ($item in $diff_list) {
                $nuspec_lookup = "*/*/*.nuspec"
                $scripts_lookup = "*/*/*/*.ps1"
                if ($item -like $scripts_lookup) {
                    $file = $item.Split('/')[-1]
                    Write-Verbose "Script Updated: $file"

                    $pkg_to_update = $item.Split('/')[-3]
                    $folder = $item.Split('/')[-4]
                    Write-Verbose "Package Update: $pkg_to_update in $folder"
                    $temp_list = New-Object -TypeName PSObject -Property @{
                        'Name' = $pkg_to_update
                        'Folder' = $folder
                    }
                    $pkg_list += $temp_list
                }elseif ($item -like $nuspec_lookup) {
                    $file = $item.Split('/')[-1] -replace '\.\w+$'
                    $folder = $item.Split('/')[-3]
                    Write-Verbose "Nuspec Update: $file in $folder"
                    $temp_list = New-Object -TypeName PSObject -Property @{
                        'Name' = $file
                        'Folder' = $folder
                    }
                    $pkg_list += $temp_list
                }
            }

            $pkg_list = $pkg_list | Select-Object -Unique Name,Folder
            Write-Output 'Choco Pack List:'
            if ($null -eq $pkg_list) {
                Write-Verbose 'No package to update/create.'
            }else {
                foreach ($pkg in $pkg_list) {
                    Start-ChocoPkgr -pkg_name $pkg.Name -pkg_folder $pkg.Folder
                }
            }
        }
    }
    catch {
        throw $_.Exception
    }
}

if ($Chocolatey) {
    # Ensure IE First Run Is Disabled because of Invoke-Expression
    Write-Output 'Ensuring IE First Run is disabled...'
    $ie_regkey = 'HKLM:\Software\Policies\Microsoft\Internet Explorer\Main'
    New-ItemProperty -Path $ie_regkey `
                    -Name 'DisableFirstRunCustomize' `
                    -Value '1' `
                    -PropertyType DWORD -Force

    # Download External Packages from Chocolatey
    Write-Output 'Pulling External Packages In:'
    $external_pkgs = @(
        'Atom',
        'chocolatey',
        'chocolatey-core.extension',
        'chromium',
        'osquery',
        'putty',
        'putty.install',
        'putty.portable',
        'vim'
    )
    foreach ($item in $external_pkgs) {
        # Scrape Site for version
        $scrape = Invoke-WebRequest -Uri "https://chocolatey.org/packages/$item"
        $scrapeVer = (($scrape.AllElements |
                    Where-Object {$_.title -match 'version'}).innerText)[0]

        # Some have beta pkgs
        if (!($scrapeVer)) {
            $scrapeVer = (($scrape.AllElements |
                        Where-Object {$_.title -match 'version'}).innerText)[3]
        }

        # Remove old and download
        Set-Location $destination
        $url = "https://packages.chocolatey.org/$item.$scrapeVer.nupkg"
        Write-Output $url
        Invoke-WebRequest -Uri $url -OutFile "$item.$scrapeVer.nupkg"
    }
}

# Restart IIS to ensure clean env before Re-Gen of cache
C:\Windows\System32\iisreset.exe /restart

# Remove cache File for Re-Gen Of Packages
Remove-Item "$destination\$env:COMPUTERNAME.*" -Force
Start-Sleep 90

# Compare list of packages within repo to production
Write-Output 'Purging Items Removed From Repo/List:'
if ($Git) {
  [array]$repo_list = Get-ChildItem -Path "$repo\*\*" -Name -Directory
} else {
  [array]$repo_list = @()
}

$repo_list += [array]$external_pkgs
$repo_list = $repo_list | Sort-Object

$prod_list = Get-ChildItem -Path $destination -Name -Directory |
             ForEach-Object { $_.Split('\')[-1] } | Sort-Object

$rem_list = (Compare-Object -ReferenceObject $repo_list `
            -DifferenceObject $prod_list).InputObject

if ($null -eq $rem_list) {
    Write-Verbose 'No package to purge.'
}else {
    foreach ($item in $rem_list) {
        Set-Location $destination
        Write-Verbose "$item - Purging"
        if (Test-Path $item) {
            # Remove .nupkg
            Remove-Item "$item.*" -Force -Recurse
            # Remove directory
            Remove-Item $item -Force -Recurse
        }
    }
}

Exit-Session
