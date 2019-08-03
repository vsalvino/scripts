scripts
=======

My collection of random utility scripts, for safe keeping.

azure-codecov.ps1
-----------------
Compares code coverage on Azure DevOps Pipelines between latest run of master
branch and specified BuildId.

recurse-download.ps1
--------------------
PowerShell script to download a URL, or recursively crawl a site to download
all links. Similar to `wget --mirror` although this only downloads links
specified in `<a>` tags (not images, CSS, JavaScript, etc.).

setup-remoting.ps1
------------------
Sets up PowerShell remoting on a Windows server. Requires Windows PowerShell and
Windows 10 / Server 2016 or higher.
