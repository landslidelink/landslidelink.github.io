


img = imread('boyerarial.png'); % Read image

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
fileName = fullfile(folderPath, 'boyerarial.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');

% %%
% 
% % Force square
% targetSize = [1200 1200]; % or whatever size you like
% 
% img = imread('rcarial.png');
% img = imresize(img, targetSize);
% 
% imshow(img);
% axis off;
% set(gca, 'Position', [0 0 1 1]);
% set(gcf, 'Color', 'w', 'Position', [100, 100, targetSize(2), targetSize(1)]);
% 
% % Define output path
% folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\images'; 
% fileName = fullfile(folderPath, 'rcarial.svg'); 
% 
% print(fig, fileName, '-dsvg', '-r300');
