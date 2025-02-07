

clc
%close all
% clear all

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
rover_filenames = arrayfun(@(n) sprintf('20250206_murphy_hill_r%d.csv', n), selected_rovers, 'UniformOutput', false);

target_start = datetime('2025-01-06 00:00:00');
target_end =   datetime('2025-08-22 00:00:00');

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



% raw_data_table = table();
% 
% for idx = 1:num_rovers
%     i = selected_rovers(idx);
% 
%     % retrieve the variables for each rover
%     rover_time = eval(sprintf('rover_time_r%d', i));
%     xc = eval(sprintf('xc_r%d', i));
%     yc = eval(sprintf('yc_r%d', i));
%     zc = eval(sprintf('zc_r%d', i));
% 
%     temp_table = table(rover_time, xc, yc, zc, ...
%         'VariableNames', {'time', sprintf('X_Rover%d', i), sprintf('Y_Rover%d', i), sprintf('Z_Rover%d', i)});
% 
%     if isempty(raw_data_table)
%         raw_data_table = temp_table;
%     else
%         raw_data_table = outerjoin(raw_data_table, temp_table, 'Keys', 'time', 'MergeKeys', true);
%     end
% end
% %_________________________________________________________________________




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


%_________________________________________________________________________

% Read Rainfall Data

%FC
% rain_data = readtable('fall_creek_rainfall.txt', 'NumHeaderLines', 3);
% rain_time = datetime(rain_data.(1), 'Format', 'yyyy-MM-dd HH:mm:ss');
% rain_time.Year = rain_time.Year + 2000; % Adjust the year rain_fall =
% rain_fall = 25.4 .* rain_data.(2); % Convert to mm

% % AZI
% rain_data = readtable('azi_rain_1_13.csv', 'NumHeaderLines', 11);
% rain_fall = rain_data.(2);
% rain_time = datetime(rain_data.(1), 'Format', 'yyyy-MM-dd HH:mm:ss');

% % hoos
% rain_data = readtable('hoos_rain_1_14.csv', 'NumHeaderLines', 11);
% rain_fall = rain_data.(2);
% rain_time = datetime(rain_data.(1), 'Format', 'yyyy-MM-dd HH:mm:ss');

% % wood
rain_data = readtable('wood_rain_1_14.csv', 'NumHeaderLines', 11);
rain_fall = rain_data.(2);
rain_time = datetime(rain_data.(1), 'Format', 'yyyy-MM-dd HH:mm:ss');

% % retz
% rain_data = readtable('retz_rain_1_14.csv', 'NumHeaderLines', 11);
% rain_fall = rain_data.(2);
% rain_time = datetime(rain_data.(1), 'Format', 'yyyy-MM-dd HH:mm:ss');

% % rm
% rain_data = readtable('rm_rain_1_14.csv', 'NumHeaderLines', 11);
% rain_fall = rain_data.(2);
% rain_time = datetime(rain_data.(1), 'Format', 'yyyy-MM-dd HH:mm:ss');

% % murph
% rain_data = readtable('murph_rain_1_14.csv', 'NumHeaderLines', 11);
% rain_fall = rain_data.(2);
% rain_time = datetime(rain_data.(1), 'Format', 'yyyy-MM-dd HH:mm:ss');

% % 26
% rain_data = readtable('26_rain_1_14.csv', 'NumHeaderLines', 11);
% rain_fall = rain_data.(2);
% rain_time = datetime(rain_data.(1), 'Format', 'yyyy-MM-dd HH:mm:ss');

% % jc
% rain_data = readtable('jc_rain_1_14.csv', 'NumHeaderLines', 11);
% rain_fall = rain_data.(2);
% rain_time = datetime(rain_data.(1), 'Format', 'yyyy-MM-dd HH:mm:ss');

% moo
% rain_data = readtable('moo_rain_1_14.csv', 'NumHeaderLines', 11);
% rain_fall = rain_data.(2);
% rain_time = datetime(rain_data.(1), 'Format', 'yyyy-MM-dd HH:mm:ss');


% Define the start of the water year
if target_start > datetime(year(target_start), 10, 1)
    wy_start = datetime(year(target_start), 10, 1); % October 1st before target_start
else
    wy_start = datetime(year(target_start) - 1, 10, 1); % October 1st before target_start
end

% Extract rainfall data starting from the water year
wy_idx = (rain_time >= wy_start) & (rain_time <= target_end); % Indices for water year range
rain_time_wy = rain_time(wy_idx); % Rainfall times in water year
rain_fall_wy = rain_fall(wy_idx); % Rainfall amounts in water year

% Calculate cumulative rainfall for the water year
cum_rain_wy = cumsum(rain_fall_wy);

% Initialize a rainfall column with NaNs in the dat table
dat.rainfall = zeros(height(dat), 1);
dat.cumrain = NaN(height(dat), 1); % Initialize cumulative rainfall with NaNs

% slap rainfall and cumulative rainfall to the closest times in dat.time
for i = 1:length(rain_time_wy)
    % Find the index of the closest time in dat.time
    [~, closest_idx] = min(abs(rain_time_wy(i) - dat.time));
    dat.rainfall(closest_idx) = rain_fall_wy(i);
    dat.cumrain(closest_idx) = cum_rain_wy(i);
end
dat.cumrain = fillmissing(dat.cumrain, 'previous');

ant = 7; %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

dat.antrain = movsum(dat.rainfall,[ant*48 0]);
%_________________________________________________________________________


figure;
% Velocity 
subplot(3,1,1);
legend_labels = cell(1, num_rovers);
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('vel_r%d', selected_rovers(i))));
    hold on;
    legend_labels{i} = sprintf('R%d', selected_rovers(i));
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Velocity (cm/day)');
title('Velocity');
grid on;
grid minor;

% Cumulative Displacement 
subplot(3,1,2);
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Cumulative Displacement (cm)');
title('Cumulative Displacement');
grid on;
grid minor;

%Rainfall and Anticedent Rainfall plots with two y-axes
subplot(3,1,3);

% Left Y-axis for rain_fall
yyaxis left;
hBar = bar(dat.time, dat.rainfall, 'b', 'edgecolor', 'b'); % Solid blue bars
ylabel('Rainfall (mm)', 'Color', 'k');
set(gca, 'YColor', 'k');
grid on;
grid minor;
hold on;

% Right Y-axis for antecedent rain
yyaxis right;
hLine = plot(dat.time, dat.antrain, '--b', 'LineWidth', 1.5); 
ylabel('Antecedent Rainfall (mm)', 'Color', 'k');
set(gca, 'YColor', 'k');

hBarAnnotation = plot(nan, nan, '-b'); 

% Adjust legend
xlabel('Time');
legend([hBarAnnotation, hLine], {'Rainfall', '5-day Antecedent Rainfall'}, 'Location', 'northwest');
title('Rainfall and Antecedent Rainfall');
grid on;
grid minor;

% Adjust x-axis limits for all subplots to be consistent
linkaxes(findall(gcf,'type','axes'), 'x'); % Link x-axes
xlabel('Time');

% 
figure;
for i = 1:num_rovers
    plot(dat.time, dat.(sprintf('cumdisp_r%d', selected_rovers(i))));
    hold on;
end
legend(legend_labels, 'Location', 'northwest');
ylabel('Cumulative Displacement (cm)');
title('Cumulative 3D Displacement');
grid on;
grid minor;

%%
% Inputs
time       = dat.time; 
rain_fall  = dat.rainfall;   
rain_ant = dat.antrain;
cum_rain = dat.cumrain;

% Define selected rovers
selected_rovers = [1,2]; 
days_anal = 7; % Length of analysis window in days
samples_per_window = 48 * days_anal; % Samples for days analyzed (e.g., 7 days)
step_size = samples_per_window / 2; % Step size for running window (e.g., half-window)

% Initialize variables for analysis
num_windows = floor((length(time) - samples_per_window) / step_size) + 1;

% Initialize storage for plotting
all_x_values = []; % Antecedent rainfall 
all_y_values = []; % Cumulative rainfall 
all_sizes = [];    % Displacement values (bubble sizes)
all_colors = [];   % Rover identifiers (bubble colors)

% Loop through each rover and process displacements
for i = 1:length(selected_rovers)
    %  rover ID
    rover_id = selected_rovers(i);

    % Loop through windows
    for w = 1:num_windows
        % Define the start and end indices for the current window
        start_idx = 1 + (w-1) * step_size;
        end_idx = start_idx + samples_per_window - 1;

        if end_idx > length(time)
            break;
        end

        % Calculate antecedent rain at the end of the current window
        antecedent_rain = rain_ant(end_idx);

        % Calculate cumulative rainfall in the next window
        next_window_start = end_idx + 1;
        next_window_end = min(next_window_start + samples_per_window - 1, length(cum_rain));

                % Ensure next_window indices are valid
        if next_window_start > length(cum_rain) || next_window_end > length(cum_rain)
            continue; % Skip this window if indices are invalid
        end

        cumulative_rainfall = cum_rain(next_window_end) - cum_rain(next_window_start);

        % Calculate displacement for the current rover in the next window
        rover_cumdisp = dat.(sprintf('cumdisp_r%d', rover_id));
        displacement = rover_cumdisp(next_window_end) - rover_cumdisp(next_window_start);

        % Store values only if displacement is greater than 0
        if displacement > 0 & displacement < 60 %& cumulative_rainfall < 250 & antecedent_rain < 250  % ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            all_x_values = [all_x_values; antecedent_rain];
            all_y_values = [all_y_values; cumulative_rainfall];
            scale = 100; %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            all_sizes = [all_sizes; displacement * scale]; % Scale size for visualization
            all_colors = [all_colors; i]; 
        end
    end
end


figure;
legend_handles = [];

hold on;
for i = 1:length(selected_rovers)
    rover_indices = all_colors == i;
    h = scatter(all_x_values(rover_indices), all_y_values(rover_indices), ...
        all_sizes(rover_indices), 'square', 'DisplayName', sprintf('Rover %d', selected_rovers(i)));
    legend_handles = [legend_handles, h];
end

reference_displacements = [1, 5, 10, 20]; 
reference_sizes = reference_displacements * scale; 

% Add reference stuff
x_ref = max(all_x_values) * 0.9; 
y_ref_start = max(all_y_values) * 0.95; 
for j = 1:length(reference_displacements)
    scatter(x_ref, y_ref_start - (j-1) * 0.05 * max(all_y_values), ...
        reference_sizes(j),'square', 'k');
    
    text(x_ref + 0.05 * max(all_x_values), y_ref_start - (j-1) * 0.05 * max(all_y_values), ...
        sprintf('%d cm', reference_displacements(j)), 'VerticalAlignment', 'middle');
end

xlabel('Antecedent Rainfall at End of Current Window (mm)');
ylabel('Cumulative Rainfall in Next Window (mm)');
title('Rainfall-Displacement Sensitivity');
% xlim([0 250]);
% ylim([0 250]);
legend(legend_handles,'Location', 'best');
grid on; grid minor;
hold off;

% Define grid for antecedent and cumulative rainfall
x_edges = linspace(min(all_x_values), max(all_x_values), 100); % bins for antecedent rainfall
y_edges = linspace(min(all_y_values), max(all_y_values), 100); % bins for cumulative rainfall

% grid for storing displacements
displacement_grid = nan(length(x_edges)-1, length(y_edges)-1);

% Bin data and compute average displacement for each grid cell
for i = 1:length(x_edges)-1
    for j = 1:length(y_edges)-1
        % Find data points in the current grid cell
        in_cell = all_x_values >= x_edges(i) & all_x_values < x_edges(i+1) & ...
                  all_y_values >= y_edges(j) & all_y_values < y_edges(j+1);
        
        % Compute average displacement for the grid cell
        if any(in_cell)
            displacement_grid(i, j) = mean(all_sizes(in_cell) / scale); % Convert size back to displacement
        end
    end
end

% Use inpaint_nans to fill in missing data
%filled_grid = inpaint_nans(displacement_grid, 4); % 4 indicates biharmonic interpolation?

% filled_grid = fillmissing2(displacement_grid,"v4"); % 4 indicates biharmonic interpolation?





% Generate x and y center points for the grid
x_centers = x_edges(1:end-1) + diff(x_edges)/2;
y_centers = y_edges(1:end-1) + diff(y_edges)/2;

[xx,yy]=meshgrid(x_centers,fliplr(y_centers));
data_temp=displacement_grid;
idx_temp=find(~isnan(displacement_grid));
data_temp=data_temp(idx_temp);
xx0=xx(idx_temp);
yy0=yy(idx_temp);


[f,gof]=fit([xx0, yy0],data_temp,"poly22",'upper',[0 1e6 1e6 1e6 1e6 1e6],"lower",[0 -1e6 -1e6 -1e6 -1e6 -1e6]);


filled_grid=f(xx,yy);
figure; imagesc(x_centers, y_centers,filled_grid)
set(gca, 'YDir', 'normal','ColorScale','log'); % Correct the y-axis direction
colorbar;
hold on
[contourX, contourY] = meshgrid(x_centers, y_centers); % Create grid matching heatmap
contour(contourX, contourY, filled_grid', 'LineColor', 'k', 'ShowText', 'on'); % Properly align contours
hold off;


% Plot the heat map
figure;
imagesc(x_centers, y_centers, filled_grid');
set(gca, 'YDir', 'normal','ColorScale','log'); % Correct the y-axis direction
colorbar;

%clim([0 30]);
% xlim([0 250]);
% ylim([0 250]);
colormap ("jet");
xlabel('Antecedent Rainfall at end of Current Window (mm)');
ylabel('Cumulative Rainfall in Next Window (mm)');
title('Average displacement heat map (inpaintnans)');
hold on
% Overlay contours

[contourX, contourY] = meshgrid(x_centers, y_centers); % Create grid matching heatmap
contour(contourX, contourY, filled_grid', 'LineColor', 'k', 'ShowText', 'on'); % Properly align contours
hold off;


%%

% % Plotting
% figure;
% hold on;
% 
% % Loop through each rover and plot its displacement
% for i = 1:length(selected_rovers)
%     % Filter out data points with zero displacement for the current rover
%     valid_indices = displacement_values(:, i) > 1; % Logical array for valid points
%     x_values = antecedent_rain_values(valid_indices);
%     y_values = cumulative_rainfall_values(valid_indices);
%     z_values = displacement_values(valid_indices, i); % Displacement for the current rover
% 
%     % Plot the data for the current rover
%     scatter(x_values, y_values, 50, z_values, 'filled', 'DisplayName', sprintf('Rover %d', selected_rovers(i)));
% end
% 
% % Add colorbar and set scale to logarithmic
% c = colorbar;
% colormap('jet');
% c.Label.String = 'Displacement (cm)';
% set(gca, 'ColorScale', 'log'); % Set the color scale to logarithmic
% 
% % Add labels, title, and legend
% xlabel('Antecedent Rainfall at End of Current Window (mm)');
% ylabel('Cumulative Rainfall in Next Window (mm)');
% title('Rainfall-Displacement Analysis (Logarithmic Color Scale)');
% grid on; grid minor;
% hold off;





%%
% Inputs
time       = dat.time; 
rain_fall  = dat.rainfall;   

% Define selected rovers
selected_rovers = [1,2,3,4]; % Example subset of rovers to process
days_anal = 15; % Length of analysis window in days
samples_per_window = 48 * days_anal;   % Samples for days analyzed (e.g., 5 days) %%%%%%%%%%
step_size = samples_per_window/2; % Step size for running window (e.g., 1 day)                      %%%%%%%%%%

% Set polynomial degree (1 for linear, 2 for quadratic)
poly_degree = 2;                                                                  %%%%%%%%%%

% Initialize storage for combined data
combined_rain = [];
combined_disp = [];

% Set up colors for each rover
colors = lines(length(selected_rovers)); % Use MATLAB's 'lines' colormap for distinct colors

% Initialize figure
figure;
hold on;

% Loop through each selected rover
for rover_idx = 1:length(selected_rovers)
    rover = selected_rovers(rover_idx); % Current rover number
    
    % Extract cumulative displacement for the current rover
    cum_disp = dat.(sprintf('cumdisp_r%d', rover));
    
    % Initialize running window outputs
    running_rain = [];
    running_disp = [];
    running_time = [];
    
    % Loop through the data in a running window
    for i = 1:step_size:(length(time) - samples_per_window + 1)
        % Define the current block of entries
        start_idx = i;
        end_idx = start_idx + samples_per_window - 1;
        
        % Compute total rainfall in the window
        block_rain = sum(rain_fall(start_idx:end_idx), 'omitnan');
        
        % Compute displacement increment in the window
        block_disp = cum_disp(end_idx) - cum_disp(start_idx);
        
        % Record the start time of the block
        running_time = [running_time; time(start_idx)];
        
        % Append results
        running_rain = [running_rain; block_rain];
        running_disp = [running_disp; block_disp];
    end
    
    % Filter out invalid data
    valid_idx = running_rain > 0 & running_disp > 0.0;% & running_rain < 900;               %%%%%%%%%%%%%%
    filtered_rain = running_rain(valid_idx);
    filtered_disp = running_disp(valid_idx);
    
    % Combine data for overall fit
    combined_rain = [combined_rain; filtered_rain];
    combined_disp = [combined_disp; filtered_disp];
    
    % Plot results for the current rover
    scatter(filtered_rain, filtered_disp, 50, 'filled', ...
        'MarkerFaceColor', colors(rover_idx, :), ...
        'DisplayName', sprintf('Rover %d', rover));
    
    % Fit a polynomial (linear or quadratic) to the individual rover's data
    if ~isempty(filtered_rain) && ~isempty(filtered_disp)
        % Polynomial fit using polyfit
        p = polyfit(filtered_rain, filtered_disp, poly_degree); % Degree controlled by poly_degree
        x_fit = linspace(min(filtered_rain), max(filtered_rain), 100); % Fit line x-values
        y_fit = polyval(p, x_fit); % Compute corresponding y-values

        % Plot the fitted line for the individual rover
        plot(x_fit, y_fit, '--', 'LineWidth', 1.5, 'Color', colors(rover_idx, :), ...
            'DisplayName', sprintf('Rover %d Fit', rover));
        
        % Calculate R-squared for the individual rover
        y_pred = polyval(p, filtered_rain); % Predicted y-values
        ss_res = sum((filtered_disp - y_pred).^2); % Residual sum of squares
        ss_tot = sum((filtered_disp - mean(filtered_disp)).^2); % Total sum of squares
        r_squared = 1 - (ss_res / ss_tot);
        fprintf('Rover %d R^2 (Degree %d): %.3f\n', rover, poly_degree, r_squared);
    end
end

% Fit a polynomial (linear or quadratic) to the combined data
if ~isempty(combined_rain) && ~isempty(combined_disp)
    % Polynomial fit using polyfit
    p_combined = polyfit(combined_rain, combined_disp, poly_degree); % Degree controlled by poly_degree
    x_combined_fit = linspace(min(combined_rain), max(combined_rain), 100); % Fit line x-values
    y_combined_fit = polyval(p_combined, x_combined_fit); % Compute corresponding y-values

    % Plot the fitted line for the combined data
    plot(x_combined_fit, y_combined_fit, 'k-', 'LineWidth', 2, 'DisplayName', 'Combined Fit');
    
    % Calculate R-squared for the combined fit
    y_pred_combined = polyval(p_combined, combined_rain); % Predicted y-values
    ss_res_combined = sum((combined_disp - y_pred_combined).^2); % Residual sum of squares
    ss_tot_combined = sum((combined_disp - mean(combined_disp)).^2); % Total sum of squares
    r_squared_combined = 1 - (ss_res_combined / ss_tot_combined);
    
    % Display the equation and R-squared
    fprintf('Combined Fitted Equation (Degree %d): y = ', poly_degree);
    for d = 1:length(p_combined)
        fprintf('%.5fx^%d ', p_combined(d), poly_degree - (d - 1));
        if d < length(p_combined)
            fprintf('+ ');
        end
    end
    fprintf('\nCombined R^2: %.3f\n', r_squared_combined);
end

xlabel('Weekly Rainfall (mm) over Analysis Period');
ylabel('Weekly Displacement (cm) over Analysis Period');
grid on; grid minor;
%title('Rainfall vs. Displacement');
legend('Location', 'best');
hold off;





%%


%%
X_matrix = [
    uniform_data_table.rain_cum, ...
    uniform_data_table.rain_int ...
];

Y = uniform_data_table.cumdisp_r5;

mdl = fitlm(X_matrix, Y, 'RobustOpts', 'on'); % Fit with numeric matrix
pred = predict(mdl, X_matrix);           % Predict with numeric matrix
disp(mdl);
fprintf('R^2 = %.3f, Adjusted R^2 = %.3f\n', ...
    mdl.Rsquared.Ordinary, mdl.Rsquared.Adjusted);

figure; 
plot(uniform_data_table.commontime,Y, 'k', 'MarkerSize', 3, 'DisplayName', 'Observed');
hold on;
plot(uniform_data_table.commontime,predict(mdl, X_matrix), 'r-', 'DisplayName', 'Predicted');
xlabel('Time Index');
ylabel('Cumulative Displacement (cm)');
legend('Location','best');
grid on;
title('Observed vs. Predicted Displacement');

%%
image_filename = 'hooslidar.png'; 
img = imread(image_filename);

% %cn
% x_positions = [274];
% y_positions = [189];

% %moo
% x_positions = [489, 421, 426];
% y_positions = [361, 757, 544];

% %wood
% x_positions = [533, 799, 873];
% y_positions = [409, 703, 897];

% %azi
% x_positions = [343, 424, 537, 342];
% y_positions = [607, 593, 581, 328];

%hoos
x_positions = [474, 644, 437,305,481];
y_positions = [346, 260, 294,480,175];

% %rm
% x_positions = [741, 603];
% y_positions = [761, 655];

% %jc
% x_positions = [445, 459];
% y_positions = [490, 278];

% %26
% x_positions = [655, 608];
% y_positions = [458, 335];

% Extract first and last non-NaN values for xc_r# and yc_r#
cum_x_displacements = zeros(1, num_rovers);
cum_y_displacements = zeros(1, num_rovers);

for i = 1:num_rovers
    % Get the non-NaN xc and yc values for the current rover
    xc_data = uniform_data_table.(sprintf('xc_r%d', selected_rovers(i)));
    yc_data = uniform_data_table.(sprintf('yc_r%d', selected_rovers(i)));
    
    % Find indices of valid (non-zero) data
    valid_idx = (xc_data ~= 0) & (yc_data ~= 0);
    
    % Find the first and last indices of non-zero values
    first_idx = find(valid_idx, 1, 'first');
    last_idx = find(valid_idx, 1, 'last');
    
    % Calculate cumulative displacement
        cum_x_displacements(i) = xc_data(last_idx) - xc_data(first_idx);
        cum_y_displacements(i) = yc_data(last_idx) - yc_data(first_idx);
end

% Overlay cumulative displacement vectors
figure;
imshow(img); % Display the background image
hold on;

quiv_scale = 0.05; % Scale for quiver arrows
for i = 1:num_rovers
    rover_name = sprintf('R%d', selected_rovers(i));
    text(x_positions(i) - 5, y_positions(i) - 15, rover_name, 'Color', 'black', ...
         'FontSize', 15, 'FontWeight', 'bold');
    quiver(x_positions(i), y_positions(i), cum_x_displacements(i) / quiv_scale, ...
           -cum_y_displacements(i) / quiv_scale, 'r', 'LineWidth', 2, 'MaxHeadSize', 2);
end

% Reference arrow for scale
ref_x_base = 100; ref_y_base = 400; ref_length = 2;
quiver(ref_x_base, ref_y_base, -ref_length/quiv_scale, 0, 0, 'b', 'LineWidth', 2, 'MaxHeadSize', 2);
text(ref_x_base + 2, ref_y_base, sprintf('%d cm', ref_length), 'Color', 'blue', ...
     'FontSize', 15, 'FontWeight', 'bold');

hold off;

%%























% % % %% Correlation
% % % 
% % % % Extract velocities and commontime
% % % vel3 = uniform_data_table.vel_r3;
% % % vel4 = uniform_data_table.vel_r4;
% % % commontime = uniform_data_table.commontime;
% % % 
% % % % Remove NaNs from the data
% % % valid_idx = ~isnan(vel3) & ~isnan(vel4);
% % % vel3_valid = vel3(valid_idx);
% % % vel4_valid = vel4(valid_idx);
% % % 
% % % % Ensure the velocities are zero-mean (so magnitude doesnt matter)
% % % vel3_valid = vel3_valid - mean(vel3_valid);
% % % vel4_valid = vel4_valid - mean(vel4_valid);
% % % 
% % % % Compute cross-correlation with normalized coefficients (between -1 and 1)
% % % [corr_vals, lags] = xcorr(vel3, vel4, 'coeff');
% % % 
% % % % Find the lag with maximum correlation
% % % [~, max_corr_idx] = max(corr_vals);
% % % top_lag = lags(max_corr_idx);
% % % 
% % % % Compute sampling interval (assuming uniform sampling)
% % % dt = median(diff(commontime));  % Time difference as duration
% % % dt_days = days(dt);  % Convert duration to days
% % % 
% % % % Compute time lag in days
% % % timelag = top_lag * dt_days;
% % % 
% % % % Display the result
% % % fprintf('Maximum correlation: %f at lag %d samples (%f days)\n', ...
% % %         corr_vals(max_corr_idx), top_lag, timelag);
% % % 
% % % % Plot the cross-correlation function
% % % figure;
% % % plot(lags * dt_days, corr_vals, 'LineWidth', 2);
% % % xlabel('Time Lag (days)');
% % % ylabel('Cross-Correlation Coefficient');
% % % title('Cross-Correlation between Velocities of Rover 3 and Rover 4');
% % % grid on;
% % % 
% % % time_point = target_end-(target_end - target_start)/2;
% % % corr_table = table(time_point, 'VariableNames', {'time'});
% % % corr_table.three_four_lag = xc_column;





















%%
% % % %% Break into Frequency Space
% % % 
% % % Fs = 0.000555555556;               % Sampling frequency (Hz)
% % % x = uniform_data_table.velx_r4;       % signal
% % % 
% % % % Compute the FFT
% % % X = fft(x);
% % % 
% % % % Compute the magnitude of the FFT
% % % magnitude = abs(X);
% % % % Normalize the magnitude to a maximum value of 1
% % % magnitude = magnitude / max(magnitude);
% % % 
% % % % Create the frequency vector
% % % N = length(x);
% % % frequencies = (0:N-1)*(Fs/N);
% % % 
% % % % Plot only the first half of the frequencies (positive frequencies)
% % % half_N = floor(N/2);
% % % frequencies_half = frequencies(1:half_N);
% % % magnitude_half = magnitude(1:half_N);
% % % 
% % % %figure;
% % % semilogx(frequencies_half, magnitude_half);%, 'linewidth', 3);
% % % grid on;grid minor;
% % % hold on;
% % % xlabel('Frequency (Hz)');
% % % ylabel('Magnitude');
% % % title('Frequency Spectrum');