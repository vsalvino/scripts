scripts
=======

My collection of random utility scripts, for safe keeping.


recurse-download.ps1
--------------------
PowerShell script to download a URL, or recursively crawl a site to download
all links. Similar to `wget --mirror` although this only downloads links
specified in `<a>` tags (not images, CSS, JavaScript, etc.).
