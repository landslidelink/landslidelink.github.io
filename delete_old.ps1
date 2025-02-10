# Define the MATLAB executable path (update if needed)
$matlabPath = "C:\Program Files\MATLAB\R2023a\bin\matlab.exe"

# Define the MATLAB script path 
$scriptPath = "C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing\delete_old.m"

# Run MATLAB in batch mode (no UI) and execute the script
Start-Process -NoNewWindow -FilePath $matlabPath -ArgumentList "-batch `"run('$scriptPath'); exit;`""
