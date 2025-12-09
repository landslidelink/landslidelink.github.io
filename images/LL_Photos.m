


img = imread('woodmap.png'); % Read image
fig = figure;
imshow(img);
axis off; % Remove axes
set(gca, 'Position', [0 0 1 1]); % Make image take full space
% Set figure background to match image
set(gca, 'XColor', 'none', 'YColor', 'none'); % Remove tick marks
set(gca, 'Units', 'normalized', 'Position', [0 0 1 1]); % Remove margins
set(gcf, 'Color', 'w', 'Position', [100, 100, size(img, 2), size(img, 1)]); % Adjust figure size

% Define output path
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\images'; 
fileName = fullfile(folderPath, 'fpsmap.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');
