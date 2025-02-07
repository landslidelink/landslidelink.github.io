param ($time0="'2020-09-01'", $time1="'2099-12-31'")

# The material in this file is covered under the Espion4D License
# which should be provided along with this material
# Copyright (c) 2023 Espion4D LLC

# SETTINGS
Set-Variable -Name "SITE" -Value "azi"
Set-Variable -Name "TIMEZONE" -Value "'US/Pacific'"
Set-Variable -Name "ROVERS" -Value "r1", "r2", "r3", "r4"

# Run loop to retrieve data
foreach ($rover in $ROVERS)
{
  Write-Host Retrieving data for $rover at $SITE
  .\get_gnss_data.ps1 -site $SITE -rover $rover -time0 $time0 -time1 $time1 -timezone $TIMEZONE
}