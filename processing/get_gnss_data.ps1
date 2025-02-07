param ($site, $rover, $time0, $time1, $timezone)

# The material in this file is covered under the Espion4D License
# which should be provided along with this material
# Copyright (c) 2023 Espion4D LLC

## DATABASE SETTINGS
Set-Variable -Name "HOST_NAME" -Value "db-engr-cce-gnss-db1.postgres.database.azure.com"
Set-Variable -Name "PORT" -Value 5432

# GET DATA SCRIPT
Set-Variable -Name "SQL_SCRIPT" -Value "save_csv.sql"

# USER CREDENTIALS
Set-Variable -Name "USER" -Value "osu"
$env:PGPASSWORD='ozGWPj%4@vXVhQ5MUctJ'

# Get todays date
$date=Get-Date -Format "yyyyMMdd"

# output name
Set-Variable -Name "csv_name" -Value ".\${date}_${site}_${rover}.csv"

# retrieve data from database
$data=Write-Output "" | & psql -h $HOST_NAME -U $USER -p $PORT -d $site -v table=$rover -v time0=$time0 -v time1=$time1 -v timezone=$timezone -f $SQL_SCRIPT --quiet

# Save to csv
$data | Out-File -Filepath $csv_name