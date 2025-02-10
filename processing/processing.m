

clc
clear vars

% Define which rovers to include in the analysis (e.g., [2, 4])
%_________________________________________________________________________

selected_rovers = [1,3,4,5,6];

%_________________________________________________________________________


% Import Rover Data
%_________________________________________________________________________
import = true;
tic

datapath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing';
num_rovers = length(selected_rovers);
current_date = datestr(now,'yyyymmdd'); %get current date
rover_filenames = arrayfun(@(n) sprintf('%s_hoos_r%d.csv', current_date, n), selected_rovers, 'UniformOutput', false);

target_start = datetime('now') - days(30);
target_start.Format = 'yyyy-MM-dd HH:mm:ss';
target_end =   datetime('2029-08-22 00:00:00');

if import
    addpath(datapath);

    % Loop through each selected rover file
    for idx = 1:num_rovers
        i = selected_rovers(idx);
        rover_data = readtable(fullfile(datapath, rover_filenames{idx}), 'NumHeaderLines', 1);
        
        % Parse rover time data
        rover_time = datetime(regexprep(string(rover_data{:, 2}), '-[0-9][0-9]$', ''), ...
                              'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm:ss');
        
        % Extract data within the target time range
        idx_time = (rover_time >= target_start) & (rover_time <= target_end);
        rover_time = rover_time(idx_time);
        xc = rover_data{idx_time, 3} * 100; % Convert to cm
        yc = rover_data{idx_time, 4} * 100;
        zc = rover_data{idx_time, 5} * 100;%ZZZZZ
        xsd = rover_data{idx_time, 6};
        ysd = rover_data{idx_time, 7};
        zsd = rover_data{idx_time, 8};%ZZZZZZ
        err = rover_data{idx_time, 10};

        % Only keep good data
        valid_idx = (err == 0) & (xsd < 0.02) & (ysd < 0.02) & (zsd < 0.02);
        rover_time = rover_time(valid_idx);
        xc = xc(valid_idx);
        yc = yc(valid_idx);
        zc = zc(valid_idx);%ZZZZZ

        % Remove outliers and smooth data
        outliers = isoutlier(xc, 'movmedian', 12) | isoutlier(yc, 'movmedian', 12) | isoutlier(zc, 'movmedian', 12);
        xc = smoothdata(xc(~outliers), 'gaussian', 60);
        yc = smoothdata(yc(~outliers), 'gaussian', 60);
        zc = smoothdata(zc(~outliers), 'gaussian', 60); %ZZZZZZZ
        rover_time = rover_time(~outliers);

        % Ensure time is unique and ordered
        [rover_time, unique_idx] = unique(rover_time);
        xc = xc(unique_idx);
        yc = yc(unique_idx);
        zc = zc(unique_idx);

        % Store data in variables
        eval(sprintf('xc_r%d = xc;', i));
        eval(sprintf('yc_r%d = yc;', i));
        eval(sprintf('zc_r%d = zc;', i));
        eval(sprintf('rover_time_r%d = rover_time;', i));
    end
end

%_________________________________________________________________________
% Define a common time vector with 30-minute increments
all_times = [];  % Initialize an empty array to collect all rover times

% Collect all time data from each rover
for idx = 1:num_rovers
    i = selected_rovers(idx);
    rover_time = eval(sprintf('rover_time_r%d', i));
    all_times = [all_times; rover_time];  % Append times from each rover
end
common_start_time = min(all_times, [], 'omitnan');
common_end_time = max(all_times, [], 'omitnan');
common_time = (common_start_time:minutes(30):common_end_time)';

dat = table(common_time, 'VariableNames', {'time'});

% Loop through each rover to interpolate and resample data
for idx = 1:num_rovers
    i = selected_rovers(idx);
    
    rover_time = eval(sprintf('rover_time_r%d', i));
    xc = eval(sprintf('xc_r%d', i));
    yc = eval(sprintf('yc_r%d', i));
    zc = eval(sprintf('zc_r%d', i));
    
    % Preprocess data for interpolation
    xc_preprocessed = nan(size(common_time));
    yc_preprocessed = nan(size(common_time));
    zc_preprocessed = nan(size(common_time));
    
    % Interpolate after first non-NaN and set values before it
    if ~isempty(rover_time)
        % Find indices of first and last valid data points in rover_time
        first_idx = find(~isnan(xc), 1, 'first');
        last_idx = find(~isnan(xc), 1, 'last');
        
        % Set values before first_idx to the first valid entry
        xc_preprocessed(common_time < rover_time(first_idx)) = xc(first_idx);
        yc_preprocessed(common_time < rover_time(first_idx)) = yc(first_idx);
        zc_preprocessed(common_time < rover_time(first_idx)) = zc(first_idx);
        
        % % Set values after last_idx to NaN (to avoid extrapolation)
        % xc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % yc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % zc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        
        % Interpolate within the valid range
        xc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, xc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        yc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, yc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        zc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, zc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
    end
    
    % Add the processed data to the dat table
    dat.(sprintf('x_r%d', i)) = xc_preprocessed;
    dat.(sprintf('y_r%d', i)) = yc_preprocessed;
    dat.(sprintf('z_r%d', i)) = zc_preprocessed;
    
    % Compute cumulative displacement and velocity
    cumdisp = sqrt((xc_preprocessed - xc_preprocessed(1)).^2 + ...
                   (yc_preprocessed - yc_preprocessed(1)).^2 + ...
                   (zc_preprocessed - zc_preprocessed(1)).^2);
    cumdisp = smoothdata(cumdisp, 'gaussian', 48);
    dt = gradient(days(common_time - common_time(1)));
    vel = gradient(cumdisp) ./ dt;
    vel(vel<0) = 0;
    % Add to the dat table
    dat.(sprintf('cumdisp_r%d', i)) = cumdisp;
    dat.(sprintf('vel_r%d', i)) = vel;
end

legend_labels = cell(1, num_rovers);
for i = 1:num_rovers
    legend_labels{i} = sprintf('R%d', selected_rovers(i));
end

% Get current timestamp
last_update = datetime('now');
last_update.Format = 'MM-dd-yyyy HH:mm';
next_update=last_update+days(1);

fig = figure;
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Cumulative Displacement (cm)');

% Dynamically insert last update time in the title
title(sprintf('Cumulative 3D Displacement Over Past 30 Days \n Updated %s  |  Next Update: %s', ...
    last_update, next_update));

grid on;
grid minor;

% Adjust figure size without removing axis labels
set(gca, 'Units', 'normalized', 'OuterPosition', [0.01 0.01 0.99 0.99]); 

% Set figure background to white and adjust size
set(gcf, 'Color', 'w', 'Position', [100, 100, 1000, 600]); % [x, y, width, height]

% Define output path
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\data'; 
fileName = fullfile(folderPath, 'hoosdat.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');
close (fig);

%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________

clc
clear vars

% Define which rovers to include in the analysis (e.g., [2, 4])
%_________________________________________________________________________

selected_rovers = [1,2,3,4];

%_________________________________________________________________________


% Import Rover Data
%_________________________________________________________________________
import = true;
tic

datapath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing';
num_rovers = length(selected_rovers);
current_date = datestr(now,'yyyymmdd'); %get current date
rover_filenames = arrayfun(@(n) sprintf('%s_azi_r%d.csv', current_date, n), selected_rovers, 'UniformOutput', false);

target_start = datetime('now') - days(30);
target_start.Format = 'yyyy-MM-dd HH:mm:ss';
target_end =   datetime('2029-08-22 00:00:00');

if import
    addpath(datapath);

    % Loop through each selected rover file
    for idx = 1:num_rovers
        i = selected_rovers(idx);
        rover_data = readtable(fullfile(datapath, rover_filenames{idx}), 'NumHeaderLines', 1);
        
        % Parse rover time data
        rover_time = datetime(regexprep(string(rover_data{:, 2}), '-[0-9][0-9]$', ''), ...
                              'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm:ss');
        
        % Extract data within the target time range
        idx_time = (rover_time >= target_start) & (rover_time <= target_end);
        rover_time = rover_time(idx_time);
        xc = rover_data{idx_time, 3} * 100; % Convert to cm
        yc = rover_data{idx_time, 4} * 100;
        zc = rover_data{idx_time, 5} * 100;%ZZZZZ
        xsd = rover_data{idx_time, 6};
        ysd = rover_data{idx_time, 7};
        zsd = rover_data{idx_time, 8};%ZZZZZZ
        err = rover_data{idx_time, 10};

        % Only keep good data
        valid_idx = (err == 0) & (xsd < 0.02) & (ysd < 0.02) & (zsd < 0.02);
        rover_time = rover_time(valid_idx);
        xc = xc(valid_idx);
        yc = yc(valid_idx);
        zc = zc(valid_idx);%ZZZZZ

        % Remove outliers and smooth data
        outliers = isoutlier(xc, 'movmedian', 12) | isoutlier(yc, 'movmedian', 12) | isoutlier(zc, 'movmedian', 12);
        xc = smoothdata(xc(~outliers), 'gaussian', 60);
        yc = smoothdata(yc(~outliers), 'gaussian', 60);
        zc = smoothdata(zc(~outliers), 'gaussian', 60); %ZZZZZZZ
        rover_time = rover_time(~outliers);

        % Ensure time is unique and ordered
        [rover_time, unique_idx] = unique(rover_time);
        xc = xc(unique_idx);
        yc = yc(unique_idx);
        zc = zc(unique_idx);

        % Store data in variables
        eval(sprintf('xc_r%d = xc;', i));
        eval(sprintf('yc_r%d = yc;', i));
        eval(sprintf('zc_r%d = zc;', i));
        eval(sprintf('rover_time_r%d = rover_time;', i));
    end
end

%_________________________________________________________________________
% Define a common time vector with 30-minute increments
all_times = [];  % Initialize an empty array to collect all rover times

% Collect all time data from each rover
for idx = 1:num_rovers
    i = selected_rovers(idx);
    rover_time = eval(sprintf('rover_time_r%d', i));
    all_times = [all_times; rover_time];  % Append times from each rover
end
common_start_time = min(all_times, [], 'omitnan');
common_end_time = max(all_times, [], 'omitnan');
common_time = (common_start_time:minutes(30):common_end_time)';

dat = table(common_time, 'VariableNames', {'time'});

% Loop through each rover to interpolate and resample data
for idx = 1:num_rovers
    i = selected_rovers(idx);
    
    rover_time = eval(sprintf('rover_time_r%d', i));
    xc = eval(sprintf('xc_r%d', i));
    yc = eval(sprintf('yc_r%d', i));
    zc = eval(sprintf('zc_r%d', i));
    
    % Preprocess data for interpolation
    xc_preprocessed = nan(size(common_time));
    yc_preprocessed = nan(size(common_time));
    zc_preprocessed = nan(size(common_time));
    
    % Interpolate after first non-NaN and set values before it
    if ~isempty(rover_time)
        % Find indices of first and last valid data points in rover_time
        first_idx = find(~isnan(xc), 1, 'first');
        last_idx = find(~isnan(xc), 1, 'last');
        
        % Set values before first_idx to the first valid entry
        xc_preprocessed(common_time < rover_time(first_idx)) = xc(first_idx);
        yc_preprocessed(common_time < rover_time(first_idx)) = yc(first_idx);
        zc_preprocessed(common_time < rover_time(first_idx)) = zc(first_idx);
        
        % % Set values after last_idx to NaN (to avoid extrapolation)
        % xc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % yc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % zc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        
        % Interpolate within the valid range
        xc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, xc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        yc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, yc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        zc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, zc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
    end
    
    % Add the processed data to the dat table
    dat.(sprintf('x_r%d', i)) = xc_preprocessed;
    dat.(sprintf('y_r%d', i)) = yc_preprocessed;
    dat.(sprintf('z_r%d', i)) = zc_preprocessed;
    
    % Compute cumulative displacement and velocity
    cumdisp = sqrt((xc_preprocessed - xc_preprocessed(1)).^2 + ...
                   (yc_preprocessed - yc_preprocessed(1)).^2 + ...
                   (zc_preprocessed - zc_preprocessed(1)).^2);
    cumdisp = smoothdata(cumdisp, 'gaussian', 48);
    dt = gradient(days(common_time - common_time(1)));
    vel = gradient(cumdisp) ./ dt;
    vel(vel<0) = 0;
    % Add to the dat table
    dat.(sprintf('cumdisp_r%d', i)) = cumdisp;
    dat.(sprintf('vel_r%d', i)) = vel;
end

legend_labels = cell(1, num_rovers);
for i = 1:num_rovers
    legend_labels{i} = sprintf('R%d', selected_rovers(i));
end

% Get current timestamp
last_update = datetime('now');
last_update.Format = 'MM-dd-yyyy HH:mm';
next_update=last_update+days(1);

fig = figure;
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Cumulative Displacement (cm)');

% Dynamically insert last update time in the title
title(sprintf('Cumulative 3D Displacement Over Past 30 Days \n Updated %s  |  Next Update: %s', ...
    last_update, next_update));

grid on;
grid minor;

% Adjust figure size without removing axis labels
set(gca, 'Units', 'normalized', 'OuterPosition', [0.01 0.01 0.99 0.99]); 

% Set figure background to white and adjust size
set(gcf, 'Color', 'w', 'Position', [100, 100, 1000, 600]); % [x, y, width, height]

% Define output path
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\data'; 
fileName = fullfile(folderPath, 'azidat.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');
close (fig);

%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________

clc
clear vars

% Define which rovers to include in the analysis (e.g., [2, 4])
%_________________________________________________________________________

selected_rovers = [1,2,3];

%_________________________________________________________________________


% Import Rover Data
%_________________________________________________________________________
import = true;
tic

datapath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing';
num_rovers = length(selected_rovers);
current_date = datestr(now,'yyyymmdd'); %get current date
rover_filenames = arrayfun(@(n) sprintf('%s_woodward_creek_r%d.csv', current_date, n), selected_rovers, 'UniformOutput', false);

target_start = datetime('now') - days(30);
target_start.Format = 'yyyy-MM-dd HH:mm:ss';
target_end =   datetime('2029-08-22 00:00:00');

if import
    addpath(datapath);

    % Loop through each selected rover file
    for idx = 1:num_rovers
        i = selected_rovers(idx);
        rover_data = readtable(fullfile(datapath, rover_filenames{idx}), 'NumHeaderLines', 1);
        
        % Parse rover time data
        rover_time = datetime(regexprep(string(rover_data{:, 2}), '-[0-9][0-9]$', ''), ...
                              'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm:ss');
        
        % Extract data within the target time range
        idx_time = (rover_time >= target_start) & (rover_time <= target_end);
        rover_time = rover_time(idx_time);
        xc = rover_data{idx_time, 3} * 100; % Convert to cm
        yc = rover_data{idx_time, 4} * 100;
        zc = rover_data{idx_time, 5} * 100;%ZZZZZ
        xsd = rover_data{idx_time, 6};
        ysd = rover_data{idx_time, 7};
        zsd = rover_data{idx_time, 8};%ZZZZZZ
        err = rover_data{idx_time, 10};

        % Only keep good data
        valid_idx = (err == 0) & (xsd < 0.02) & (ysd < 0.02) & (zsd < 0.02);
        rover_time = rover_time(valid_idx);
        xc = xc(valid_idx);
        yc = yc(valid_idx);
        zc = zc(valid_idx);%ZZZZZ

        % Remove outliers and smooth data
        outliers = isoutlier(xc, 'movmedian', 12) | isoutlier(yc, 'movmedian', 12) | isoutlier(zc, 'movmedian', 12);
        xc = smoothdata(xc(~outliers), 'gaussian', 60);
        yc = smoothdata(yc(~outliers), 'gaussian', 60);
        zc = smoothdata(zc(~outliers), 'gaussian', 60); %ZZZZZZZ
        rover_time = rover_time(~outliers);

        % Ensure time is unique and ordered
        [rover_time, unique_idx] = unique(rover_time);
        xc = xc(unique_idx);
        yc = yc(unique_idx);
        zc = zc(unique_idx);

        % Store data in variables
        eval(sprintf('xc_r%d = xc;', i));
        eval(sprintf('yc_r%d = yc;', i));
        eval(sprintf('zc_r%d = zc;', i));
        eval(sprintf('rover_time_r%d = rover_time;', i));
    end
end

%_________________________________________________________________________
% Define a common time vector with 30-minute increments
all_times = [];  % Initialize an empty array to collect all rover times

% Collect all time data from each rover
for idx = 1:num_rovers
    i = selected_rovers(idx);
    rover_time = eval(sprintf('rover_time_r%d', i));
    all_times = [all_times; rover_time];  % Append times from each rover
end
common_start_time = min(all_times, [], 'omitnan');
common_end_time = max(all_times, [], 'omitnan');
common_time = (common_start_time:minutes(30):common_end_time)';

dat = table(common_time, 'VariableNames', {'time'});

% Loop through each rover to interpolate and resample data
for idx = 1:num_rovers
    i = selected_rovers(idx);
    
    rover_time = eval(sprintf('rover_time_r%d', i));
    xc = eval(sprintf('xc_r%d', i));
    yc = eval(sprintf('yc_r%d', i));
    zc = eval(sprintf('zc_r%d', i));
    
    % Preprocess data for interpolation
    xc_preprocessed = nan(size(common_time));
    yc_preprocessed = nan(size(common_time));
    zc_preprocessed = nan(size(common_time));
    
    % Interpolate after first non-NaN and set values before it
    if ~isempty(rover_time)
        % Find indices of first and last valid data points in rover_time
        first_idx = find(~isnan(xc), 1, 'first');
        last_idx = find(~isnan(xc), 1, 'last');
        
        % Set values before first_idx to the first valid entry
        xc_preprocessed(common_time < rover_time(first_idx)) = xc(first_idx);
        yc_preprocessed(common_time < rover_time(first_idx)) = yc(first_idx);
        zc_preprocessed(common_time < rover_time(first_idx)) = zc(first_idx);
        
        % % Set values after last_idx to NaN (to avoid extrapolation)
        % xc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % yc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % zc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        
        % Interpolate within the valid range
        xc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, xc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        yc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, yc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        zc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, zc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
    end
    
    % Add the processed data to the dat table
    dat.(sprintf('x_r%d', i)) = xc_preprocessed;
    dat.(sprintf('y_r%d', i)) = yc_preprocessed;
    dat.(sprintf('z_r%d', i)) = zc_preprocessed;
    
    % Compute cumulative displacement and velocity
    cumdisp = sqrt((xc_preprocessed - xc_preprocessed(1)).^2 + ...
                   (yc_preprocessed - yc_preprocessed(1)).^2 + ...
                   (zc_preprocessed - zc_preprocessed(1)).^2);
    cumdisp = smoothdata(cumdisp, 'gaussian', 48);
    dt = gradient(days(common_time - common_time(1)));
    vel = gradient(cumdisp) ./ dt;
    vel(vel<0) = 0;
    % Add to the dat table
    dat.(sprintf('cumdisp_r%d', i)) = cumdisp;
    dat.(sprintf('vel_r%d', i)) = vel;
end

legend_labels = cell(1, num_rovers);
for i = 1:num_rovers
    legend_labels{i} = sprintf('R%d', selected_rovers(i));
end

% Get current timestamp
last_update = datetime('now');
last_update.Format = 'MM-dd-yyyy HH:mm';
next_update=last_update+days(1);

fig = figure;
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Cumulative Displacement (cm)');

% Dynamically insert last update time in the title
title(sprintf('Cumulative 3D Displacement Over Past 30 Days \n Updated %s  |  Next Update: %s', ...
    last_update, next_update));

grid on;
grid minor;

% Adjust figure size without removing axis labels
set(gca, 'Units', 'normalized', 'OuterPosition', [0.01 0.01 0.99 0.99]); 

% Set figure background to white and adjust size
set(gcf, 'Color', 'w', 'Position', [100, 100, 1000, 600]); % [x, y, width, height]

% Define output path
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\data'; 
fileName = fullfile(folderPath, 'wooddat.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');
close (fig);

%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________

clc
clear vars

% Define which rovers to include in the analysis (e.g., [2, 4])
%_________________________________________________________________________

selected_rovers = [1,2,3];

%_________________________________________________________________________


% Import Rover Data
%_________________________________________________________________________
import = true;
tic

datapath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing';
num_rovers = length(selected_rovers);
current_date = datestr(now,'yyyymmdd'); %get current date
rover_filenames = arrayfun(@(n) sprintf('%s_retz_creek_r%d.csv', current_date, n), selected_rovers, 'UniformOutput', false);

target_start = datetime('now') - days(30);
target_start.Format = 'yyyy-MM-dd HH:mm:ss';
target_end =   datetime('2029-08-22 00:00:00');

if import
    addpath(datapath);

    % Loop through each selected rover file
    for idx = 1:num_rovers
        i = selected_rovers(idx);
        rover_data = readtable(fullfile(datapath, rover_filenames{idx}), 'NumHeaderLines', 1);
        
        % Parse rover time data
        rover_time = datetime(regexprep(string(rover_data{:, 2}), '-[0-9][0-9]$', ''), ...
                              'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm:ss');
        
        % Extract data within the target time range
        idx_time = (rover_time >= target_start) & (rover_time <= target_end);
        rover_time = rover_time(idx_time);
        xc = rover_data{idx_time, 3} * 100; % Convert to cm
        yc = rover_data{idx_time, 4} * 100;
        zc = rover_data{idx_time, 5} * 100;%ZZZZZ
        xsd = rover_data{idx_time, 6};
        ysd = rover_data{idx_time, 7};
        zsd = rover_data{idx_time, 8};%ZZZZZZ
        err = rover_data{idx_time, 10};

        % Only keep good data
        valid_idx = (err == 0) & (xsd < 0.02) & (ysd < 0.02) & (zsd < 0.02);
        rover_time = rover_time(valid_idx);
        xc = xc(valid_idx);
        yc = yc(valid_idx);
        zc = zc(valid_idx);%ZZZZZ

        % Remove outliers and smooth data
        outliers = isoutlier(xc, 'movmedian', 12) | isoutlier(yc, 'movmedian', 12) | isoutlier(zc, 'movmedian', 12);
        xc = smoothdata(xc(~outliers), 'gaussian', 60);
        yc = smoothdata(yc(~outliers), 'gaussian', 60);
        zc = smoothdata(zc(~outliers), 'gaussian', 60); %ZZZZZZZ
        rover_time = rover_time(~outliers);

        % Ensure time is unique and ordered
        [rover_time, unique_idx] = unique(rover_time);
        xc = xc(unique_idx);
        yc = yc(unique_idx);
        zc = zc(unique_idx);

        % Store data in variables
        eval(sprintf('xc_r%d = xc;', i));
        eval(sprintf('yc_r%d = yc;', i));
        eval(sprintf('zc_r%d = zc;', i));
        eval(sprintf('rover_time_r%d = rover_time;', i));
    end
end

%_________________________________________________________________________
% Define a common time vector with 30-minute increments
all_times = [];  % Initialize an empty array to collect all rover times

% Collect all time data from each rover
for idx = 1:num_rovers
    i = selected_rovers(idx);
    rover_time = eval(sprintf('rover_time_r%d', i));
    all_times = [all_times; rover_time];  % Append times from each rover
end
common_start_time = min(all_times, [], 'omitnan');
common_end_time = max(all_times, [], 'omitnan');
common_time = (common_start_time:minutes(30):common_end_time)';

dat = table(common_time, 'VariableNames', {'time'});

% Loop through each rover to interpolate and resample data
for idx = 1:num_rovers
    i = selected_rovers(idx);
    
    rover_time = eval(sprintf('rover_time_r%d', i));
    xc = eval(sprintf('xc_r%d', i));
    yc = eval(sprintf('yc_r%d', i));
    zc = eval(sprintf('zc_r%d', i));
    
    % Preprocess data for interpolation
    xc_preprocessed = nan(size(common_time));
    yc_preprocessed = nan(size(common_time));
    zc_preprocessed = nan(size(common_time));
    
    % Interpolate after first non-NaN and set values before it
    if ~isempty(rover_time)
        % Find indices of first and last valid data points in rover_time
        first_idx = find(~isnan(xc), 1, 'first');
        last_idx = find(~isnan(xc), 1, 'last');
        
        % Set values before first_idx to the first valid entry
        xc_preprocessed(common_time < rover_time(first_idx)) = xc(first_idx);
        yc_preprocessed(common_time < rover_time(first_idx)) = yc(first_idx);
        zc_preprocessed(common_time < rover_time(first_idx)) = zc(first_idx);
        
        % % Set values after last_idx to NaN (to avoid extrapolation)
        % xc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % yc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % zc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        
        % Interpolate within the valid range
        xc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, xc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        yc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, yc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        zc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, zc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
    end
    
    % Add the processed data to the dat table
    dat.(sprintf('x_r%d', i)) = xc_preprocessed;
    dat.(sprintf('y_r%d', i)) = yc_preprocessed;
    dat.(sprintf('z_r%d', i)) = zc_preprocessed;
    
    % Compute cumulative displacement and velocity
    cumdisp = sqrt((xc_preprocessed - xc_preprocessed(1)).^2 + ...
                   (yc_preprocessed - yc_preprocessed(1)).^2 + ...
                   (zc_preprocessed - zc_preprocessed(1)).^2);
    cumdisp = smoothdata(cumdisp, 'gaussian', 48);
    dt = gradient(days(common_time - common_time(1)));
    vel = gradient(cumdisp) ./ dt;
    vel(vel<0) = 0;
    % Add to the dat table
    dat.(sprintf('cumdisp_r%d', i)) = cumdisp;
    dat.(sprintf('vel_r%d', i)) = vel;
end

legend_labels = cell(1, num_rovers);
for i = 1:num_rovers
    legend_labels{i} = sprintf('R%d', selected_rovers(i));
end

% Get current timestamp
last_update = datetime('now');
last_update.Format = 'MM-dd-yyyy HH:mm';
next_update=last_update+days(1);

fig = figure;
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Cumulative Displacement (cm)');

% Dynamically insert last update time in the title
title(sprintf('Cumulative 3D Displacement Over Past 30 Days \n Updated %s  |  Next Update: %s', ...
    last_update, next_update));

grid on;
grid minor;

% Adjust figure size without removing axis labels
set(gca, 'Units', 'normalized', 'OuterPosition', [0.01 0.01 0.99 0.99]); 

% Set figure background to white and adjust size
set(gcf, 'Color', 'w', 'Position', [100, 100, 1000, 600]); % [x, y, width, height]

% Define output path
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\data'; 
fileName = fullfile(folderPath, 'retzdat.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');
close (fig);

%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________

clc
clear vars

% Define which rovers to include in the analysis (e.g., [2, 4])
%_________________________________________________________________________

selected_rovers = [1,2,3];

%_________________________________________________________________________


% Import Rover Data
%_________________________________________________________________________
import = true;
tic

datapath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing';
num_rovers = length(selected_rovers);
current_date = datestr(now,'yyyymmdd'); %get current date
rover_filenames = arrayfun(@(n) sprintf('%s_Moolack_r%d.csv', current_date, n), selected_rovers, 'UniformOutput', false);

target_start = datetime('now') - days(30);
target_start.Format = 'yyyy-MM-dd HH:mm:ss';
target_end =   datetime('2029-08-22 00:00:00');

if import
    addpath(datapath);

    % Loop through each selected rover file
    for idx = 1:num_rovers
        i = selected_rovers(idx);
        rover_data = readtable(fullfile(datapath, rover_filenames{idx}), 'NumHeaderLines', 1);
        
        % Parse rover time data
        rover_time = datetime(regexprep(string(rover_data{:, 2}), '-[0-9][0-9]$', ''), ...
                              'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm:ss');
        
        % Extract data within the target time range
        idx_time = (rover_time >= target_start) & (rover_time <= target_end);
        rover_time = rover_time(idx_time);
        xc = rover_data{idx_time, 3} * 100; % Convert to cm
        yc = rover_data{idx_time, 4} * 100;
        zc = rover_data{idx_time, 5} * 100;%ZZZZZ
        xsd = rover_data{idx_time, 6};
        ysd = rover_data{idx_time, 7};
        zsd = rover_data{idx_time, 8};%ZZZZZZ
        err = rover_data{idx_time, 10};

        % Only keep good data
        valid_idx = (err == 0) & (xsd < 0.02) & (ysd < 0.02) & (zsd < 0.02);
        rover_time = rover_time(valid_idx);
        xc = xc(valid_idx);
        yc = yc(valid_idx);
        zc = zc(valid_idx);%ZZZZZ

        % Remove outliers and smooth data
        outliers = isoutlier(xc, 'movmedian', 12) | isoutlier(yc, 'movmedian', 12) | isoutlier(zc, 'movmedian', 12);
        xc = smoothdata(xc(~outliers), 'gaussian', 60);
        yc = smoothdata(yc(~outliers), 'gaussian', 60);
        zc = smoothdata(zc(~outliers), 'gaussian', 60); %ZZZZZZZ
        rover_time = rover_time(~outliers);

        % Ensure time is unique and ordered
        [rover_time, unique_idx] = unique(rover_time);
        xc = xc(unique_idx);
        yc = yc(unique_idx);
        zc = zc(unique_idx);

        % Store data in variables
        eval(sprintf('xc_r%d = xc;', i));
        eval(sprintf('yc_r%d = yc;', i));
        eval(sprintf('zc_r%d = zc;', i));
        eval(sprintf('rover_time_r%d = rover_time;', i));
    end
end

%_________________________________________________________________________
% Define a common time vector with 30-minute increments
all_times = [];  % Initialize an empty array to collect all rover times

% Collect all time data from each rover
for idx = 1:num_rovers
    i = selected_rovers(idx);
    rover_time = eval(sprintf('rover_time_r%d', i));
    all_times = [all_times; rover_time];  % Append times from each rover
end
common_start_time = min(all_times, [], 'omitnan');
common_end_time = max(all_times, [], 'omitnan');
common_time = (common_start_time:minutes(30):common_end_time)';

dat = table(common_time, 'VariableNames', {'time'});

% Loop through each rover to interpolate and resample data
for idx = 1:num_rovers
    i = selected_rovers(idx);
    
    rover_time = eval(sprintf('rover_time_r%d', i));
    xc = eval(sprintf('xc_r%d', i));
    yc = eval(sprintf('yc_r%d', i));
    zc = eval(sprintf('zc_r%d', i));
    
    % Preprocess data for interpolation
    xc_preprocessed = nan(size(common_time));
    yc_preprocessed = nan(size(common_time));
    zc_preprocessed = nan(size(common_time));
    
    % Interpolate after first non-NaN and set values before it
    if ~isempty(rover_time)
        % Find indices of first and last valid data points in rover_time
        first_idx = find(~isnan(xc), 1, 'first');
        last_idx = find(~isnan(xc), 1, 'last');
        
        % Set values before first_idx to the first valid entry
        xc_preprocessed(common_time < rover_time(first_idx)) = xc(first_idx);
        yc_preprocessed(common_time < rover_time(first_idx)) = yc(first_idx);
        zc_preprocessed(common_time < rover_time(first_idx)) = zc(first_idx);
        
        % % Set values after last_idx to NaN (to avoid extrapolation)
        % xc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % yc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % zc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        
        % Interpolate within the valid range
        xc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, xc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        yc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, yc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        zc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, zc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
    end
    
    % Add the processed data to the dat table
    dat.(sprintf('x_r%d', i)) = xc_preprocessed;
    dat.(sprintf('y_r%d', i)) = yc_preprocessed;
    dat.(sprintf('z_r%d', i)) = zc_preprocessed;
    
    % Compute cumulative displacement and velocity
    cumdisp = sqrt((xc_preprocessed - xc_preprocessed(1)).^2 + ...
                   (yc_preprocessed - yc_preprocessed(1)).^2 + ...
                   (zc_preprocessed - zc_preprocessed(1)).^2);
    cumdisp = smoothdata(cumdisp, 'gaussian', 48);
    dt = gradient(days(common_time - common_time(1)));
    vel = gradient(cumdisp) ./ dt;
    vel(vel<0) = 0;
    % Add to the dat table
    dat.(sprintf('cumdisp_r%d', i)) = cumdisp;
    dat.(sprintf('vel_r%d', i)) = vel;
end

legend_labels = cell(1, num_rovers);
for i = 1:num_rovers
    legend_labels{i} = sprintf('R%d', selected_rovers(i));
end

% Get current timestamp
last_update = datetime('now');
last_update.Format = 'MM-dd-yyyy HH:mm';
next_update=last_update+days(1);

fig = figure;
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Cumulative Displacement (cm)');

% Dynamically insert last update time in the title
title(sprintf('Cumulative 3D Displacement Over Past 30 Days \n Updated %s  |  Next Update: %s', ...
    last_update, next_update));

grid on;
grid minor;

% Adjust figure size without removing axis labels
set(gca, 'Units', 'normalized', 'OuterPosition', [0.01 0.01 0.99 0.99]); 

% Set figure background to white and adjust size
set(gcf, 'Color', 'w', 'Position', [100, 100, 1000, 600]); % [x, y, width, height]

% Define output path
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\data'; 
fileName = fullfile(folderPath, 'moodat.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');
close (fig);


%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________

clc
clear vars

% Define which rovers to include in the analysis (e.g., [2, 4])
%_________________________________________________________________________

selected_rovers = [4];

%_________________________________________________________________________


% Import Rover Data
%_________________________________________________________________________
import = true;
tic

datapath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing';
num_rovers = length(selected_rovers);
current_date = datestr(now,'yyyymmdd'); %get current date
rover_filenames = arrayfun(@(n) sprintf('%s_Moolack_r%d.csv', current_date, n), selected_rovers, 'UniformOutput', false);

target_start = datetime('now') - days(30);
target_start.Format = 'yyyy-MM-dd HH:mm:ss';
target_end =   datetime('2029-08-22 00:00:00');

if import
    addpath(datapath);

    % Loop through each selected rover file
    for idx = 1:num_rovers
        i = selected_rovers(idx);
        rover_data = readtable(fullfile(datapath, rover_filenames{idx}), 'NumHeaderLines', 1);
        
        % Parse rover time data
        rover_time = datetime(regexprep(string(rover_data{:, 2}), '-[0-9][0-9]$', ''), ...
                              'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm:ss');
        
        % Extract data within the target time range
        idx_time = (rover_time >= target_start) & (rover_time <= target_end);
        rover_time = rover_time(idx_time);
        xc = rover_data{idx_time, 3} * 100; % Convert to cm
        yc = rover_data{idx_time, 4} * 100;
        zc = rover_data{idx_time, 5} * 100;%ZZZZZ
        xsd = rover_data{idx_time, 6};
        ysd = rover_data{idx_time, 7};
        zsd = rover_data{idx_time, 8};%ZZZZZZ
        err = rover_data{idx_time, 10};

        % Only keep good data
        valid_idx = (err == 0) & (xsd < 0.02) & (ysd < 0.02) & (zsd < 0.02);
        rover_time = rover_time(valid_idx);
        xc = xc(valid_idx);
        yc = yc(valid_idx);
        zc = zc(valid_idx);%ZZZZZ

        % Remove outliers and smooth data
        outliers = isoutlier(xc, 'movmedian', 12) | isoutlier(yc, 'movmedian', 12) | isoutlier(zc, 'movmedian', 12);
        xc = smoothdata(xc(~outliers), 'gaussian', 60);
        yc = smoothdata(yc(~outliers), 'gaussian', 60);
        zc = smoothdata(zc(~outliers), 'gaussian', 60); %ZZZZZZZ
        rover_time = rover_time(~outliers);

        % Ensure time is unique and ordered
        [rover_time, unique_idx] = unique(rover_time);
        xc = xc(unique_idx);
        yc = yc(unique_idx);
        zc = zc(unique_idx);

        % Store data in variables
        eval(sprintf('xc_r%d = xc;', i));
        eval(sprintf('yc_r%d = yc;', i));
        eval(sprintf('zc_r%d = zc;', i));
        eval(sprintf('rover_time_r%d = rover_time;', i));
    end
end

%_________________________________________________________________________
% Define a common time vector with 30-minute increments
all_times = [];  % Initialize an empty array to collect all rover times

% Collect all time data from each rover
for idx = 1:num_rovers
    i = selected_rovers(idx);
    rover_time = eval(sprintf('rover_time_r%d', i));
    all_times = [all_times; rover_time];  % Append times from each rover
end
common_start_time = min(all_times, [], 'omitnan');
common_end_time = max(all_times, [], 'omitnan');
common_time = (common_start_time:minutes(30):common_end_time)';

dat = table(common_time, 'VariableNames', {'time'});

% Loop through each rover to interpolate and resample data
for idx = 1:num_rovers
    i = selected_rovers(idx);
    
    rover_time = eval(sprintf('rover_time_r%d', i));
    xc = eval(sprintf('xc_r%d', i));
    yc = eval(sprintf('yc_r%d', i));
    zc = eval(sprintf('zc_r%d', i));
    
    % Preprocess data for interpolation
    xc_preprocessed = nan(size(common_time));
    yc_preprocessed = nan(size(common_time));
    zc_preprocessed = nan(size(common_time));
    
    % Interpolate after first non-NaN and set values before it
    if ~isempty(rover_time)
        % Find indices of first and last valid data points in rover_time
        first_idx = find(~isnan(xc), 1, 'first');
        last_idx = find(~isnan(xc), 1, 'last');
        
        % Set values before first_idx to the first valid entry
        xc_preprocessed(common_time < rover_time(first_idx)) = xc(first_idx);
        yc_preprocessed(common_time < rover_time(first_idx)) = yc(first_idx);
        zc_preprocessed(common_time < rover_time(first_idx)) = zc(first_idx);
        
        % % Set values after last_idx to NaN (to avoid extrapolation)
        % xc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % yc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % zc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        
        % Interpolate within the valid range
        xc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, xc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        yc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, yc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        zc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, zc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
    end
    
    % Add the processed data to the dat table
    dat.(sprintf('x_r%d', i)) = xc_preprocessed;
    dat.(sprintf('y_r%d', i)) = yc_preprocessed;
    dat.(sprintf('z_r%d', i)) = zc_preprocessed;
    
    % Compute cumulative displacement and velocity
    cumdisp = sqrt((xc_preprocessed - xc_preprocessed(1)).^2 + ...
                   (yc_preprocessed - yc_preprocessed(1)).^2 + ...
                   (zc_preprocessed - zc_preprocessed(1)).^2);
    cumdisp = smoothdata(cumdisp, 'gaussian', 48);
    dt = gradient(days(common_time - common_time(1)));
    vel = gradient(cumdisp) ./ dt;
    vel(vel<0) = 0;
    % Add to the dat table
    dat.(sprintf('cumdisp_r%d', i)) = cumdisp;
    dat.(sprintf('vel_r%d', i)) = vel;
end

legend_labels = cell(1, num_rovers);
for i = 1:num_rovers
    legend_labels{i} = sprintf('R%d', selected_rovers(i));
end

% Get current timestamp
last_update = datetime('now');
last_update.Format = 'MM-dd-yyyy HH:mm';
next_update=last_update+days(1);

fig = figure;
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend('Carmel Knoll');
ylabel('Cumulative Displacement (cm)');

% Dynamically insert last update time in the title
title(sprintf('Cumulative 3D Displacement Over Past 30 Days \n Updated %s  |  Next Update: %s', ...
    last_update, next_update));

grid on;
grid minor;

% Adjust figure size without removing axis labels
set(gca, 'Units', 'normalized', 'OuterPosition', [0.01 0.01 0.99 0.99]); 

% Set figure background to white and adjust size
set(gcf, 'Color', 'w', 'Position', [100, 100, 1000, 600]); % [x, y, width, height]

% Define output path
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\data'; 
fileName = fullfile(folderPath, 'cndat.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');
close (fig);


%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________

clc
clear vars

% Define which rovers to include in the analysis (e.g., [2, 4])
%_________________________________________________________________________

selected_rovers = [4];

%_________________________________________________________________________


% Import Rover Data
%_________________________________________________________________________
import = true;
tic

datapath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing';
num_rovers = length(selected_rovers);
current_date = datestr(now,'yyyymmdd'); %get current date
rover_filenames = arrayfun(@(n) sprintf('%s_Moolack_r%d.csv', current_date, n), selected_rovers, 'UniformOutput', false);

target_start = datetime('now') - days(30);
target_start.Format = 'yyyy-MM-dd HH:mm:ss';
target_end =   datetime('2029-08-22 00:00:00');

if import
    addpath(datapath);

    % Loop through each selected rover file
    for idx = 1:num_rovers
        i = selected_rovers(idx);
        rover_data = readtable(fullfile(datapath, rover_filenames{idx}), 'NumHeaderLines', 1);
        
        % Parse rover time data
        rover_time = datetime(regexprep(string(rover_data{:, 2}), '-[0-9][0-9]$', ''), ...
                              'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm:ss');
        
        % Extract data within the target time range
        idx_time = (rover_time >= target_start) & (rover_time <= target_end);
        rover_time = rover_time(idx_time);
        xc = rover_data{idx_time, 3} * 100; % Convert to cm
        yc = rover_data{idx_time, 4} * 100;
        zc = rover_data{idx_time, 5} * 100;%ZZZZZ
        xsd = rover_data{idx_time, 6};
        ysd = rover_data{idx_time, 7};
        zsd = rover_data{idx_time, 8};%ZZZZZZ
        err = rover_data{idx_time, 10};

        % Only keep good data
        valid_idx = (err == 0) & (xsd < 0.02) & (ysd < 0.02) & (zsd < 0.02);
        rover_time = rover_time(valid_idx);
        xc = xc(valid_idx);
        yc = yc(valid_idx);
        zc = zc(valid_idx);%ZZZZZ

        % Remove outliers and smooth data
        outliers = isoutlier(xc, 'movmedian', 12) | isoutlier(yc, 'movmedian', 12) | isoutlier(zc, 'movmedian', 12);
        xc = smoothdata(xc(~outliers), 'gaussian', 60);
        yc = smoothdata(yc(~outliers), 'gaussian', 60);
        zc = smoothdata(zc(~outliers), 'gaussian', 60); %ZZZZZZZ
        rover_time = rover_time(~outliers);

        % Ensure time is unique and ordered
        [rover_time, unique_idx] = unique(rover_time);
        xc = xc(unique_idx);
        yc = yc(unique_idx);
        zc = zc(unique_idx);

        % Store data in variables
        eval(sprintf('xc_r%d = xc;', i));
        eval(sprintf('yc_r%d = yc;', i));
        eval(sprintf('zc_r%d = zc;', i));
        eval(sprintf('rover_time_r%d = rover_time;', i));
    end
end

%_________________________________________________________________________
% Define a common time vector with 30-minute increments
all_times = [];  % Initialize an empty array to collect all rover times

% Collect all time data from each rover
for idx = 1:num_rovers
    i = selected_rovers(idx);
    rover_time = eval(sprintf('rover_time_r%d', i));
    all_times = [all_times; rover_time];  % Append times from each rover
end
common_start_time = min(all_times, [], 'omitnan');
common_end_time = max(all_times, [], 'omitnan');
common_time = (common_start_time:minutes(30):common_end_time)';

dat = table(common_time, 'VariableNames', {'time'});

% Loop through each rover to interpolate and resample data
for idx = 1:num_rovers
    i = selected_rovers(idx);
    
    rover_time = eval(sprintf('rover_time_r%d', i));
    xc = eval(sprintf('xc_r%d', i));
    yc = eval(sprintf('yc_r%d', i));
    zc = eval(sprintf('zc_r%d', i));
    
    % Preprocess data for interpolation
    xc_preprocessed = nan(size(common_time));
    yc_preprocessed = nan(size(common_time));
    zc_preprocessed = nan(size(common_time));
    
    % Interpolate after first non-NaN and set values before it
    if ~isempty(rover_time)
        % Find indices of first and last valid data points in rover_time
        first_idx = find(~isnan(xc), 1, 'first');
        last_idx = find(~isnan(xc), 1, 'last');
        
        % Set values before first_idx to the first valid entry
        xc_preprocessed(common_time < rover_time(first_idx)) = xc(first_idx);
        yc_preprocessed(common_time < rover_time(first_idx)) = yc(first_idx);
        zc_preprocessed(common_time < rover_time(first_idx)) = zc(first_idx);
        
        % % Set values after last_idx to NaN (to avoid extrapolation)
        % xc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % yc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % zc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        
        % Interpolate within the valid range
        xc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, xc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        yc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, yc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        zc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, zc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
    end
    
    % Add the processed data to the dat table
    dat.(sprintf('x_r%d', i)) = xc_preprocessed;
    dat.(sprintf('y_r%d', i)) = yc_preprocessed;
    dat.(sprintf('z_r%d', i)) = zc_preprocessed;
    
    % Compute cumulative displacement and velocity
    cumdisp = sqrt((xc_preprocessed - xc_preprocessed(1)).^2 + ...
                   (yc_preprocessed - yc_preprocessed(1)).^2 + ...
                   (zc_preprocessed - zc_preprocessed(1)).^2);
    cumdisp = smoothdata(cumdisp, 'gaussian', 48);
    dt = gradient(days(common_time - common_time(1)));
    vel = gradient(cumdisp) ./ dt;
    vel(vel<0) = 0;
    % Add to the dat table
    dat.(sprintf('cumdisp_r%d', i)) = cumdisp;
    dat.(sprintf('vel_r%d', i)) = vel;
end

legend_labels = cell(1, num_rovers);
for i = 1:num_rovers
    legend_labels{i} = sprintf('R%d', selected_rovers(i));
end

% Get current timestamp
last_update = datetime('now');
last_update.Format = 'MM-dd-yyyy HH:mm';
next_update=last_update+days(1);

fig = figure;
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Cumulative Displacement (cm)');

% Dynamically insert last update time in the title
title(sprintf('Cumulative 3D Displacement Over Past 30 Days \n Updated %s  |  Next Update: %s', ...
    last_update, next_update));

grid on;
grid minor;

% Adjust figure size without removing axis labels
set(gca, 'Units', 'normalized', 'OuterPosition', [0.01 0.01 0.99 0.99]); 

% Set figure background to white and adjust size
set(gcf, 'Color', 'w', 'Position', [100, 100, 1000, 600]); % [x, y, width, height]

% Define output path
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\data'; 
fileName = fullfile(folderPath, 'hwy26dat.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');
close (fig);


%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________

clc
clear vars

% Define which rovers to include in the analysis (e.g., [2, 4])
%_________________________________________________________________________

selected_rovers = [1,2];

%_________________________________________________________________________


% Import Rover Data
%_________________________________________________________________________
import = true;
tic

datapath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing';
num_rovers = length(selected_rovers);
current_date = datestr(now,'yyyymmdd'); %get current date
rover_filenames = arrayfun(@(n) sprintf('%s_Johnson_Creek_r%d.csv', current_date, n), selected_rovers, 'UniformOutput', false);

target_start = datetime('now') - days(30);
target_start.Format = 'yyyy-MM-dd HH:mm:ss';
target_end =   datetime('2029-08-22 00:00:00');

if import
    addpath(datapath);

    % Loop through each selected rover file
    for idx = 1:num_rovers
        i = selected_rovers(idx);
        rover_data = readtable(fullfile(datapath, rover_filenames{idx}), 'NumHeaderLines', 1);
        
        % Parse rover time data
        rover_time = datetime(regexprep(string(rover_data{:, 2}), '-[0-9][0-9]$', ''), ...
                              'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm:ss');
        
        % Extract data within the target time range
        idx_time = (rover_time >= target_start) & (rover_time <= target_end);
        rover_time = rover_time(idx_time);
        xc = rover_data{idx_time, 3} * 100; % Convert to cm
        yc = rover_data{idx_time, 4} * 100;
        zc = rover_data{idx_time, 5} * 100;%ZZZZZ
        xsd = rover_data{idx_time, 6};
        ysd = rover_data{idx_time, 7};
        zsd = rover_data{idx_time, 8};%ZZZZZZ
        err = rover_data{idx_time, 10};

        % Only keep good data
        valid_idx = (err == 0) & (xsd < 0.02) & (ysd < 0.02) & (zsd < 0.02);
        rover_time = rover_time(valid_idx);
        xc = xc(valid_idx);
        yc = yc(valid_idx);
        zc = zc(valid_idx);%ZZZZZ

        % Remove outliers and smooth data
        outliers = isoutlier(xc, 'movmedian', 12) | isoutlier(yc, 'movmedian', 12) | isoutlier(zc, 'movmedian', 12);
        xc = smoothdata(xc(~outliers), 'gaussian', 60);
        yc = smoothdata(yc(~outliers), 'gaussian', 60);
        zc = smoothdata(zc(~outliers), 'gaussian', 60); %ZZZZZZZ
        rover_time = rover_time(~outliers);

        % Ensure time is unique and ordered
        [rover_time, unique_idx] = unique(rover_time);
        xc = xc(unique_idx);
        yc = yc(unique_idx);
        zc = zc(unique_idx);

        % Store data in variables
        eval(sprintf('xc_r%d = xc;', i));
        eval(sprintf('yc_r%d = yc;', i));
        eval(sprintf('zc_r%d = zc;', i));
        eval(sprintf('rover_time_r%d = rover_time;', i));
    end
end

%_________________________________________________________________________
% Define a common time vector with 30-minute increments
all_times = [];  % Initialize an empty array to collect all rover times

% Collect all time data from each rover
for idx = 1:num_rovers
    i = selected_rovers(idx);
    rover_time = eval(sprintf('rover_time_r%d', i));
    all_times = [all_times; rover_time];  % Append times from each rover
end
common_start_time = min(all_times, [], 'omitnan');
common_end_time = max(all_times, [], 'omitnan');
common_time = (common_start_time:minutes(30):common_end_time)';

dat = table(common_time, 'VariableNames', {'time'});

% Loop through each rover to interpolate and resample data
for idx = 1:num_rovers
    i = selected_rovers(idx);
    
    rover_time = eval(sprintf('rover_time_r%d', i));
    xc = eval(sprintf('xc_r%d', i));
    yc = eval(sprintf('yc_r%d', i));
    zc = eval(sprintf('zc_r%d', i));
    
    % Preprocess data for interpolation
    xc_preprocessed = nan(size(common_time));
    yc_preprocessed = nan(size(common_time));
    zc_preprocessed = nan(size(common_time));
    
    % Interpolate after first non-NaN and set values before it
    if ~isempty(rover_time)
        % Find indices of first and last valid data points in rover_time
        first_idx = find(~isnan(xc), 1, 'first');
        last_idx = find(~isnan(xc), 1, 'last');
        
        % Set values before first_idx to the first valid entry
        xc_preprocessed(common_time < rover_time(first_idx)) = xc(first_idx);
        yc_preprocessed(common_time < rover_time(first_idx)) = yc(first_idx);
        zc_preprocessed(common_time < rover_time(first_idx)) = zc(first_idx);
        
        % % Set values after last_idx to NaN (to avoid extrapolation)
        % xc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % yc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % zc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        
        % Interpolate within the valid range
        xc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, xc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        yc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, yc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        zc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, zc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
    end
    
    % Add the processed data to the dat table
    dat.(sprintf('x_r%d', i)) = xc_preprocessed;
    dat.(sprintf('y_r%d', i)) = yc_preprocessed;
    dat.(sprintf('z_r%d', i)) = zc_preprocessed;
    
    % Compute cumulative displacement and velocity
    cumdisp = sqrt((xc_preprocessed - xc_preprocessed(1)).^2 + ...
                   (yc_preprocessed - yc_preprocessed(1)).^2 + ...
                   (zc_preprocessed - zc_preprocessed(1)).^2);
    cumdisp = smoothdata(cumdisp, 'gaussian', 48);
    dt = gradient(days(common_time - common_time(1)));
    vel = gradient(cumdisp) ./ dt;
    vel(vel<0) = 0;
    % Add to the dat table
    dat.(sprintf('cumdisp_r%d', i)) = cumdisp;
    dat.(sprintf('vel_r%d', i)) = vel;
end

legend_labels = cell(1, num_rovers);
for i = 1:num_rovers
    legend_labels{i} = sprintf('R%d', selected_rovers(i));
end

% Get current timestamp
last_update = datetime('now');
last_update.Format = 'MM-dd-yyyy HH:mm';
next_update=last_update+days(1);

fig = figure;
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Cumulative Displacement (cm)');

% Dynamically insert last update time in the title
title(sprintf('Cumulative 3D Displacement Over Past 30 Days \n Updated %s  |  Next Update: %s', ...
    last_update, next_update));

grid on;
grid minor;

% Adjust figure size without removing axis labels
set(gca, 'Units', 'normalized', 'OuterPosition', [0.01 0.01 0.99 0.99]); 

% Set figure background to white and adjust size
set(gcf, 'Color', 'w', 'Position', [100, 100, 1000, 600]); % [x, y, width, height]

% Define output path
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\data'; 
fileName = fullfile(folderPath, 'jcdat.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');
close (fig);


%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________

clc
clear vars

% Define which rovers to include in the analysis (e.g., [2, 4])
%_________________________________________________________________________

selected_rovers = [1,2];

%_________________________________________________________________________


% Import Rover Data
%_________________________________________________________________________
import = true;
tic

datapath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing';
num_rovers = length(selected_rovers);
current_date = datestr(now,'yyyymmdd'); %get current date
rover_filenames = arrayfun(@(n) sprintf('%s_murphy_hill_r%d.csv', current_date, n), selected_rovers, 'UniformOutput', false);

target_start = datetime('now') - days(30);
target_start.Format = 'yyyy-MM-dd HH:mm:ss';
target_end =   datetime('2029-08-22 00:00:00');

if import
    addpath(datapath);

    % Loop through each selected rover file
    for idx = 1:num_rovers
        i = selected_rovers(idx);
        rover_data = readtable(fullfile(datapath, rover_filenames{idx}), 'NumHeaderLines', 1);
        
        % Parse rover time data
        rover_time = datetime(regexprep(string(rover_data{:, 2}), '-[0-9][0-9]$', ''), ...
                              'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm:ss');
        
        % Extract data within the target time range
        idx_time = (rover_time >= target_start) & (rover_time <= target_end);
        rover_time = rover_time(idx_time);
        xc = rover_data{idx_time, 3} * 100; % Convert to cm
        yc = rover_data{idx_time, 4} * 100;
        zc = rover_data{idx_time, 5} * 100;%ZZZZZ
        xsd = rover_data{idx_time, 6};
        ysd = rover_data{idx_time, 7};
        zsd = rover_data{idx_time, 8};%ZZZZZZ
        err = rover_data{idx_time, 10};

        % Only keep good data
        valid_idx = (err == 0) & (xsd < 0.02) & (ysd < 0.02) & (zsd < 0.02);
        rover_time = rover_time(valid_idx);
        xc = xc(valid_idx);
        yc = yc(valid_idx);
        zc = zc(valid_idx);%ZZZZZ

        % Remove outliers and smooth data
        outliers = isoutlier(xc, 'movmedian', 12) | isoutlier(yc, 'movmedian', 12) | isoutlier(zc, 'movmedian', 12);
        xc = smoothdata(xc(~outliers), 'gaussian', 60);
        yc = smoothdata(yc(~outliers), 'gaussian', 60);
        zc = smoothdata(zc(~outliers), 'gaussian', 60); %ZZZZZZZ
        rover_time = rover_time(~outliers);

        % Ensure time is unique and ordered
        [rover_time, unique_idx] = unique(rover_time);
        xc = xc(unique_idx);
        yc = yc(unique_idx);
        zc = zc(unique_idx);

        % Store data in variables
        eval(sprintf('xc_r%d = xc;', i));
        eval(sprintf('yc_r%d = yc;', i));
        eval(sprintf('zc_r%d = zc;', i));
        eval(sprintf('rover_time_r%d = rover_time;', i));
    end
end

%_________________________________________________________________________
% Define a common time vector with 30-minute increments
all_times = [];  % Initialize an empty array to collect all rover times

% Collect all time data from each rover
for idx = 1:num_rovers
    i = selected_rovers(idx);
    rover_time = eval(sprintf('rover_time_r%d', i));
    all_times = [all_times; rover_time];  % Append times from each rover
end
common_start_time = min(all_times, [], 'omitnan');
common_end_time = max(all_times, [], 'omitnan');
common_time = (common_start_time:minutes(30):common_end_time)';

dat = table(common_time, 'VariableNames', {'time'});

% Loop through each rover to interpolate and resample data
for idx = 1:num_rovers
    i = selected_rovers(idx);
    
    rover_time = eval(sprintf('rover_time_r%d', i));
    xc = eval(sprintf('xc_r%d', i));
    yc = eval(sprintf('yc_r%d', i));
    zc = eval(sprintf('zc_r%d', i));
    
    % Preprocess data for interpolation
    xc_preprocessed = nan(size(common_time));
    yc_preprocessed = nan(size(common_time));
    zc_preprocessed = nan(size(common_time));
    
    % Interpolate after first non-NaN and set values before it
    if ~isempty(rover_time)
        % Find indices of first and last valid data points in rover_time
        first_idx = find(~isnan(xc), 1, 'first');
        last_idx = find(~isnan(xc), 1, 'last');
        
        % Set values before first_idx to the first valid entry
        xc_preprocessed(common_time < rover_time(first_idx)) = xc(first_idx);
        yc_preprocessed(common_time < rover_time(first_idx)) = yc(first_idx);
        zc_preprocessed(common_time < rover_time(first_idx)) = zc(first_idx);
        
        % % Set values after last_idx to NaN (to avoid extrapolation)
        % xc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % yc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % zc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        
        % Interpolate within the valid range
        xc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, xc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        yc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, yc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        zc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, zc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
    end
    
    % Add the processed data to the dat table
    dat.(sprintf('x_r%d', i)) = xc_preprocessed;
    dat.(sprintf('y_r%d', i)) = yc_preprocessed;
    dat.(sprintf('z_r%d', i)) = zc_preprocessed;
    
    % Compute cumulative displacement and velocity
    cumdisp = sqrt((xc_preprocessed - xc_preprocessed(1)).^2 + ...
                   (yc_preprocessed - yc_preprocessed(1)).^2 + ...
                   (zc_preprocessed - zc_preprocessed(1)).^2);
    cumdisp = smoothdata(cumdisp, 'gaussian', 48);
    dt = gradient(days(common_time - common_time(1)));
    vel = gradient(cumdisp) ./ dt;
    vel(vel<0) = 0;
    % Add to the dat table
    dat.(sprintf('cumdisp_r%d', i)) = cumdisp;
    dat.(sprintf('vel_r%d', i)) = vel;
end

legend_labels = cell(1, num_rovers);
for i = 1:num_rovers
    legend_labels{i} = sprintf('R%d', selected_rovers(i));
end

% Get current timestamp
last_update = datetime('now');
last_update.Format = 'MM-dd-yyyy HH:mm';
next_update=last_update+days(1);

fig = figure;
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Cumulative Displacement (cm)');

% Dynamically insert last update time in the title
title(sprintf('Cumulative 3D Displacement Over Past 30 Days \n Updated %s  |  Next Update: %s', ...
    last_update, next_update));

grid on;
grid minor;

% Adjust figure size without removing axis labels
set(gca, 'Units', 'normalized', 'OuterPosition', [0.01 0.01 0.99 0.99]); 

% Set figure background to white and adjust size
set(gcf, 'Color', 'w', 'Position', [100, 100, 1000, 600]); % [x, y, width, height]

% Define output path
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\data'; 
fileName = fullfile(folderPath, 'murphdat.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');
close (fig);


%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________

clc
clear vars

% Define which rovers to include in the analysis (e.g., [2, 4])
%_________________________________________________________________________

selected_rovers = [1,2];

%_________________________________________________________________________


% Import Rover Data
%_________________________________________________________________________
import = true;
tic

datapath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing';
num_rovers = length(selected_rovers);
current_date = datestr(now,'yyyymmdd'); %get current date
rover_filenames = arrayfun(@(n) sprintf('%s_roberts_mountain_r%d.csv', current_date, n), selected_rovers, 'UniformOutput', false);

target_start = datetime('now') - days(30);
target_start.Format = 'yyyy-MM-dd HH:mm:ss';
target_end =   datetime('2029-08-22 00:00:00');

if import
    addpath(datapath);

    % Loop through each selected rover file
    for idx = 1:num_rovers
        i = selected_rovers(idx);
        rover_data = readtable(fullfile(datapath, rover_filenames{idx}), 'NumHeaderLines', 1);
        
        % Parse rover time data
        rover_time = datetime(regexprep(string(rover_data{:, 2}), '-[0-9][0-9]$', ''), ...
                              'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm:ss');
        
        % Extract data within the target time range
        idx_time = (rover_time >= target_start) & (rover_time <= target_end);
        rover_time = rover_time(idx_time);
        xc = rover_data{idx_time, 3} * 100; % Convert to cm
        yc = rover_data{idx_time, 4} * 100;
        zc = rover_data{idx_time, 5} * 100;%ZZZZZ
        xsd = rover_data{idx_time, 6};
        ysd = rover_data{idx_time, 7};
        zsd = rover_data{idx_time, 8};%ZZZZZZ
        err = rover_data{idx_time, 10};

        % Only keep good data
        valid_idx = (err == 0) & (xsd < 0.02) & (ysd < 0.02) & (zsd < 0.02);
        rover_time = rover_time(valid_idx);
        xc = xc(valid_idx);
        yc = yc(valid_idx);
        zc = zc(valid_idx);%ZZZZZ

        % Remove outliers and smooth data
        outliers = isoutlier(xc, 'movmedian', 12) | isoutlier(yc, 'movmedian', 12) | isoutlier(zc, 'movmedian', 12);
        xc = smoothdata(xc(~outliers), 'gaussian', 60);
        yc = smoothdata(yc(~outliers), 'gaussian', 60);
        zc = smoothdata(zc(~outliers), 'gaussian', 60); %ZZZZZZZ
        rover_time = rover_time(~outliers);

        % Ensure time is unique and ordered
        [rover_time, unique_idx] = unique(rover_time);
        xc = xc(unique_idx);
        yc = yc(unique_idx);
        zc = zc(unique_idx);

        % Store data in variables
        eval(sprintf('xc_r%d = xc;', i));
        eval(sprintf('yc_r%d = yc;', i));
        eval(sprintf('zc_r%d = zc;', i));
        eval(sprintf('rover_time_r%d = rover_time;', i));
    end
end

%_________________________________________________________________________
% Define a common time vector with 30-minute increments
all_times = [];  % Initialize an empty array to collect all rover times

% Collect all time data from each rover
for idx = 1:num_rovers
    i = selected_rovers(idx);
    rover_time = eval(sprintf('rover_time_r%d', i));
    all_times = [all_times; rover_time];  % Append times from each rover
end
common_start_time = min(all_times, [], 'omitnan');
common_end_time = max(all_times, [], 'omitnan');
common_time = (common_start_time:minutes(30):common_end_time)';

dat = table(common_time, 'VariableNames', {'time'});

% Loop through each rover to interpolate and resample data
for idx = 1:num_rovers
    i = selected_rovers(idx);
    
    rover_time = eval(sprintf('rover_time_r%d', i));
    xc = eval(sprintf('xc_r%d', i));
    yc = eval(sprintf('yc_r%d', i));
    zc = eval(sprintf('zc_r%d', i));
    
    % Preprocess data for interpolation
    xc_preprocessed = nan(size(common_time));
    yc_preprocessed = nan(size(common_time));
    zc_preprocessed = nan(size(common_time));
    
    % Interpolate after first non-NaN and set values before it
    if ~isempty(rover_time)
        % Find indices of first and last valid data points in rover_time
        first_idx = find(~isnan(xc), 1, 'first');
        last_idx = find(~isnan(xc), 1, 'last');
        
        % Set values before first_idx to the first valid entry
        xc_preprocessed(common_time < rover_time(first_idx)) = xc(first_idx);
        yc_preprocessed(common_time < rover_time(first_idx)) = yc(first_idx);
        zc_preprocessed(common_time < rover_time(first_idx)) = zc(first_idx);
        
        % % Set values after last_idx to NaN (to avoid extrapolation)
        % xc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % yc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % zc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        
        % Interpolate within the valid range
        xc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, xc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        yc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, yc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        zc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, zc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
    end
    
    % Add the processed data to the dat table
    dat.(sprintf('x_r%d', i)) = xc_preprocessed;
    dat.(sprintf('y_r%d', i)) = yc_preprocessed;
    dat.(sprintf('z_r%d', i)) = zc_preprocessed;
    
    % Compute cumulative displacement and velocity
    cumdisp = sqrt((xc_preprocessed - xc_preprocessed(1)).^2 + ...
                   (yc_preprocessed - yc_preprocessed(1)).^2 + ...
                   (zc_preprocessed - zc_preprocessed(1)).^2);
    cumdisp = smoothdata(cumdisp, 'gaussian', 48);
    dt = gradient(days(common_time - common_time(1)));
    vel = gradient(cumdisp) ./ dt;
    vel(vel<0) = 0;
    % Add to the dat table
    dat.(sprintf('cumdisp_r%d', i)) = cumdisp;
    dat.(sprintf('vel_r%d', i)) = vel;
end

legend_labels = cell(1, num_rovers);
for i = 1:num_rovers
    legend_labels{i} = sprintf('R%d', selected_rovers(i));
end

% Get current timestamp
last_update = datetime('now');
last_update.Format = 'MM-dd-yyyy HH:mm';
next_update=last_update+days(1);

fig = figure;
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Cumulative Displacement (cm)');

% Dynamically insert last update time in the title
title(sprintf('Cumulative 3D Displacement Over Past 30 Days \n Updated %s  |  Next Update: %s', ...
    last_update, next_update));

grid on;
grid minor;

% Adjust figure size without removing axis labels
set(gca, 'Units', 'normalized', 'OuterPosition', [0.01 0.01 0.99 0.99]); 

% Set figure background to white and adjust size
set(gcf, 'Color', 'w', 'Position', [100, 100, 1000, 600]); % [x, y, width, height]

% Define output path
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\data'; 
fileName = fullfile(folderPath, 'rmdat.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');
close (fig);

%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________
%___________________________________________________________________________

clc
clear vars

% Define which rovers to include in the analysis (e.g., [2, 4])
%_________________________________________________________________________

selected_rovers = [1,2];

%_________________________________________________________________________


% Import Rover Data
%_________________________________________________________________________
import = true;
tic

datapath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\processing';
num_rovers = length(selected_rovers);
current_date = datestr(now,'yyyymmdd'); %get current date
rover_filenames = arrayfun(@(n) sprintf('%s_weber_r%d.csv', current_date, n), selected_rovers, 'UniformOutput', false);

target_start = datetime('now') - days(30);
target_start.Format = 'yyyy-MM-dd HH:mm:ss';
target_end =   datetime('2029-08-22 00:00:00');

if import
    addpath(datapath);

    % Loop through each selected rover file
    for idx = 1:num_rovers
        i = selected_rovers(idx);
        rover_data = readtable(fullfile(datapath, rover_filenames{idx}), 'NumHeaderLines', 1);
        
        % Parse rover time data
        rover_time = datetime(regexprep(string(rover_data{:, 2}), '-[0-9][0-9]$', ''), ...
                              'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'Format', 'yyyy-MM-dd HH:mm:ss');
        
        % Extract data within the target time range
        idx_time = (rover_time >= target_start) & (rover_time <= target_end);
        rover_time = rover_time(idx_time);
        xc = rover_data{idx_time, 3} * 100; % Convert to cm
        yc = rover_data{idx_time, 4} * 100;
        zc = rover_data{idx_time, 5} * 100;%ZZZZZ
        xsd = rover_data{idx_time, 6};
        ysd = rover_data{idx_time, 7};
        zsd = rover_data{idx_time, 8};%ZZZZZZ
        err = rover_data{idx_time, 10};

        % Only keep good data
        valid_idx = (err == 0) & (xsd < 0.02) & (ysd < 0.02) & (zsd < 0.02);
        rover_time = rover_time(valid_idx);
        xc = xc(valid_idx);
        yc = yc(valid_idx);
        zc = zc(valid_idx);%ZZZZZ

        % Remove outliers and smooth data
        outliers = isoutlier(xc, 'movmedian', 12) | isoutlier(yc, 'movmedian', 12) | isoutlier(zc, 'movmedian', 12);
        xc = smoothdata(xc(~outliers), 'gaussian', 60);
        yc = smoothdata(yc(~outliers), 'gaussian', 60);
        zc = smoothdata(zc(~outliers), 'gaussian', 60); %ZZZZZZZ
        rover_time = rover_time(~outliers);

        % Ensure time is unique and ordered
        [rover_time, unique_idx] = unique(rover_time);
        xc = xc(unique_idx);
        yc = yc(unique_idx);
        zc = zc(unique_idx);

        % Store data in variables
        eval(sprintf('xc_r%d = xc;', i));
        eval(sprintf('yc_r%d = yc;', i));
        eval(sprintf('zc_r%d = zc;', i));
        eval(sprintf('rover_time_r%d = rover_time;', i));
    end
end

%_________________________________________________________________________
% Define a common time vector with 30-minute increments
all_times = [];  % Initialize an empty array to collect all rover times

% Collect all time data from each rover
for idx = 1:num_rovers
    i = selected_rovers(idx);
    rover_time = eval(sprintf('rover_time_r%d', i));
    all_times = [all_times; rover_time];  % Append times from each rover
end
common_start_time = min(all_times, [], 'omitnan');
common_end_time = max(all_times, [], 'omitnan');
common_time = (common_start_time:minutes(30):common_end_time)';

dat = table(common_time, 'VariableNames', {'time'});

% Loop through each rover to interpolate and resample data
for idx = 1:num_rovers
    i = selected_rovers(idx);
    
    rover_time = eval(sprintf('rover_time_r%d', i));
    xc = eval(sprintf('xc_r%d', i));
    yc = eval(sprintf('yc_r%d', i));
    zc = eval(sprintf('zc_r%d', i));
    
    % Preprocess data for interpolation
    xc_preprocessed = nan(size(common_time));
    yc_preprocessed = nan(size(common_time));
    zc_preprocessed = nan(size(common_time));
    
    % Interpolate after first non-NaN and set values before it
    if ~isempty(rover_time)
        % Find indices of first and last valid data points in rover_time
        first_idx = find(~isnan(xc), 1, 'first');
        last_idx = find(~isnan(xc), 1, 'last');
        
        % Set values before first_idx to the first valid entry
        xc_preprocessed(common_time < rover_time(first_idx)) = xc(first_idx);
        yc_preprocessed(common_time < rover_time(first_idx)) = yc(first_idx);
        zc_preprocessed(common_time < rover_time(first_idx)) = zc(first_idx);
        
        % % Set values after last_idx to NaN (to avoid extrapolation)
        % xc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % yc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        % zc_preprocessed(common_time > rover_time(last_idx)) = NaN;
        
        % Interpolate within the valid range
        xc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, xc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        yc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, yc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
        zc_preprocessed(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)) = ...
            interp1(rover_time, zc, common_time(common_time >= rover_time(first_idx) & common_time <= rover_time(last_idx)), 'linear');
    end
    
    % Add the processed data to the dat table
    dat.(sprintf('x_r%d', i)) = xc_preprocessed;
    dat.(sprintf('y_r%d', i)) = yc_preprocessed;
    dat.(sprintf('z_r%d', i)) = zc_preprocessed;
    
    % Compute cumulative displacement and velocity
    cumdisp = sqrt((xc_preprocessed - xc_preprocessed(1)).^2 + ...
                   (yc_preprocessed - yc_preprocessed(1)).^2 + ...
                   (zc_preprocessed - zc_preprocessed(1)).^2);
    cumdisp = smoothdata(cumdisp, 'gaussian', 48);
    dt = gradient(days(common_time - common_time(1)));
    vel = gradient(cumdisp) ./ dt;
    vel(vel<0) = 0;
    % Add to the dat table
    dat.(sprintf('cumdisp_r%d', i)) = cumdisp;
    dat.(sprintf('vel_r%d', i)) = vel;
end

legend_labels = cell(1, num_rovers);
for i = 1:num_rovers
    legend_labels{i} = sprintf('R%d', selected_rovers(i));
end

% Get current timestamp
last_update = datetime('now');
last_update.Format = 'MM-dd-yyyy HH:mm';
next_update=last_update+days(1);

fig = figure;
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Cumulative Displacement (cm)');

% Dynamically insert last update time in the title
title(sprintf('Cumulative 3D Displacement Over Past 30 Days \n Updated %s  |  Next Update: %s', ...
    last_update, next_update));

grid on;
grid minor;

% Adjust figure size without removing axis labels
set(gca, 'Units', 'normalized', 'OuterPosition', [0.01 0.01 0.99 0.99]); 

% Set figure background to white and adjust size
set(gcf, 'Color', 'w', 'Position', [100, 100, 1000, 600]); % [x, y, width, height]

% Define output path
folderPath = 'C:\Users\fulmere\Documents\GitHub\landslidelink.github.io\data'; 
fileName = fullfile(folderPath, 'webdat.svg'); 

% Save as SVG without borders
print(fig, fileName, '-dsvg', '-r300');
close (fig);



