# Set the repository path
$repoPath = "C:\Users\fulmere\Documents\GitHub\landslidelink.github.io"

# Change directory to the repo
Set-Location $repoPath

# Add all changes
git add .

# Commit changes with a timestamp
$commitMessage = "Auto update on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
git commit -m "$commitMessage"

# Push changes to GitHub
git push origin main
