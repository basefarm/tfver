# tfver
Maintain multiple terraform versions


# Usage:
**tfver [-h|-l|-i|-u|-c|VERSION]**

|option|function|
|------|--------|
|-h|Displays this usage information|
|-l|List the Terraform versions available|
|-i|Install the systemwide-hook that enables tfver for all uses when logging in (NB This requires root privileges)|
|-u|Add a new version of Terraform to the list of available versions (NB This may require root privileges)|
|-c|Configure a personal preference for a specific version. This creates a .tfverrc file in your homedirectory|
|version|The version of Terraform that you wish to use. If you leave this blank, the default/latest version will be used|


