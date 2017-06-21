# Repo Chocolatey AutoPkgr

Powershell script that adds `.nupkgs` to your Nuget Feed based on a `git` repo as well as pulling from [Chocolatey.org](https://chocolatey.org/). Detects any changes, if so - run `choco pack` against the package. For external packages via Chocolatey.org, it will download the latest available, including Beta packages listed primarily.

## Prerequisites

1. [Windows Server](https://www.microsoft.com/en-us/cloud-platform/windows-server) - The following **`IIS`** features will be required:
    ```Powershell
    NetFx3
    NetFx3ServerFeatures
    NetFx4Extended-ASPNET45
    IIS-WebServerRole
    IIS-WebServer
    IIS-CommonHttpFeatures
    IIS-Security
    IIS-RequestFiltering
    IIS-StaticContent
    IIS-DefaultDocument
    IIS-DirectoryBrowsing
    IIS-HttpErrors
    IIS-ApplicationDevelopment
    IIS-NetFxExtensibility45
    IIS-ISAPIExtensions
    IIS-ISAPIFilter
    IIS-ASPNET45
    IIS-HealthAndDiagnostics
    IIS-HttpLogging
    IIS-BasicAuthentication
    IIS-WindowsAuthentication
    IIS-Performance
    IIS-HttpCompressionStatic
    IIS-WebServerManagementTools
    IIS-ManagementConsole
    ```
2. [.Net 4.6.2](https://www.microsoft.com/en-us/download/details.aspx?id=53344) - Install before enabling Nuget.
3. [Nuget.Server](https://www.nuget.org/packages/NuGet.Server/) - Nuget will host the feed in order to provide packages to your clients.
4. [Powershell 5](https://www.microsoft.com/en-us/download/details.aspx?id=54616) or above.

## Setup

1. Install a version of Windows Server.
    - Add the `IIS` role along with the features listed in prerequisites.
    - Ensure `.Net 4.6.2` and above is installed.

2. Head over to [NugetServer.net](http://nugetserver.net/) and select which you would like. I
preffered the free version in which has you use [Visual Studio](https://www.visualstudio.com/) to
create the empty web app.

3. Once the `Nuget` server has been setup and is live, pull down this repo and save the script where you'd like.

4. Install [Chocolatey](https://chocolatey.org/install) for use of tools.
    ```Powershell
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    ```

5. Change the variables in the top section of this script based on location of Nuget Server and `git` repo.
    ```Powershell
    $destination = 'C:\nugetfeeds\MyFirstFeed\Packages'
    $git_bin = "$env:ProgramFiles\Git\bin\git.exe"
    $repo_url = 'https://github.com/chocolatey/chocolatey-coreteampackages.git'
    $repo_dir = ($repo_url.Split('/')[-1]).Replace('.git','')
    $repo = "C:\repo-choco-autopkgr\$($repo_dir)"
    ```

6. Here's the fun part. You can either run this script manually where it stands, OR setup a `Scheduled Task` to run it every so often based on your needs.
    - Just want the external packages?
        ```Powershell
        .\repo-choco-autopkgr.ps1 -Chocolatey
        ```
    - Just the `git` repo?
        ```Powershell
        .\repo-choco-autopkgr.ps1 -Git
        ```
    - Or you want both.
        ```Powershell
        .\repo-choco-autopkgr.ps1 -Git -Chocolatey
        ```

7. Once the `.nupkg`'s start hitting your feed, Nuget Server will create folders for each one and cache the items in order for them to appear. Run a `clist` against your server to verify.

# Future

- Add support for `hg`
- Setup `IIS`
- Setup `Nuget Server`
- Setup `Chocolatey`
- Basically an All-In-One

# Feedback

Feel free to open an issue or submit a pull request.
