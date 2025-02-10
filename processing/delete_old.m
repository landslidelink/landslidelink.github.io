% Define the folder path where CSV files are stored
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing';

% Set the threshold for deleting old files (e.g., 180 days = 6 months)
daysToKeep = 0; 
cutoffDate = datetime('now') - days(daysToKeep);

% Get a list of all CSV files in the folder
csvFiles = dir(fullfile(folderPath, '*.csv'));

% Loop through each file and check its modification date
for i = 1:length(csvFiles)
    filePath = fullfile(folderPath, csvFiles(i).name);
    fileDate = datetime(csvFiles(i).datenum, 'ConvertFrom', 'datenum');

    % Delete the file if it's older than the cutoff date
    if fileDate < cutoffDate
        fprintf('Deleting old file: %s (Last Modified: %s)\n', csvFiles(i).name, fileDate);
        delete(filePath);
    end
end

fprintf('Cleanup complete! All CSV files older than %d days have been deleted.\n', daysToKeep);
