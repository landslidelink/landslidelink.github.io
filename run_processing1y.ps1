# Define the MATLAB executable path (update if needed)
$matlabPath = "C:\Program Files\MATLAB\R2024b\bin\matlab.exe"

# Define the MATLAB script path (make sure it's saved as 'processing1y.m')
$scriptPath = "C:\Users\fulmere\Documents\GitHub\ll_processing\processing1y"

# Run MATLAB in batch mode (no UI) and execute the script
Start-Process -NoNewWindow -FilePath $matlabPath -ArgumentList "-batch `"run('$scriptPath'); exit;`""
