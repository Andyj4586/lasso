function coverage_map(Year, Month, Day, Hour, Minute, Seconds, durationHours, steptimeSeconds, Altitude, Eccentricity, Inclination, number_of_SATs, number_of_planes, Orbit_Propagator, viewing_angle)

    % Add necessary paths
    addpath('~/Redstone_Project/RS_HL/RS_HL_01_Constellation_Scinario_Formulation/');

    % Initial Epoch Definition
    duration = hours(durationHours);
    steptime = steptimeSeconds; % seconds
    startTime = datetime(Year, Month, Day, Hour, Minute, Seconds);

    time_parameters.startTime = startTime;
    time_parameters.duration = duration;
    time_parameters.steptime = steptime;

    % Initialize scenario
    scenario = scenario_initalization(time_parameters);

    % Orbit Settings
    AOP = 0; % Argument of Perigee (deg)

    % Generate RAAN values for evenly spaced planes
    RAAN_values = linspace(0, 360, number_of_planes + 1);
    RAAN_values(end) = []; % Remove the last value to avoid overlap with 0 degrees

    % Define initial orbit information
    satellites = [];
    satellites_per_plane = cell(1, length(RAAN_values));

    for i = 1:length(RAAN_values)
        RAAN = RAAN_values(i);
        satellite_name = "RS-" + i;
        orbit_information = struct('SMA', Altitude * 1000 + 6378000, ...
                                   'ecc', Eccentricity, ...
                                   'inc', Inclination, ...
                                   'RAAN', RAAN, ...
                                   'AOP', AOP);
        satellites_orbit = single_orbit_constellation(scenario, orbit_information, number_of_SATs, Orbit_Propagator, satellite_name);
        satellites = [satellites, satellites_orbit];
        satellites_per_plane{i} = satellites_orbit; % Store satellites of the current plane
    end

    number_of_SATs = length(satellites);
    time_vector = scenario.StartTime:seconds(scenario.SampleTime):scenario.StopTime;

    % ======= Define Ground Stations ========
    gs_locations = [
        struct('Name', 'Houston', 'Latitude', 29.7604, 'Longitude', -95.3698); % Houston, TX, USA
        struct('Name', 'Kennedy', 'Latitude', 28.5721, 'Longitude', -80.6480); % Kennedy Space Center, FL, USA
        struct('Name', 'Madrid', 'Latitude', 40.4168, 'Longitude', -3.7038); % Madrid, Spain
    ];

    % Add ground stations to the scenario using a for loop
    gs = []; % Initialize as an empty array
    for i = 1:length(gs_locations)
        gs = [gs, groundStation(scenario, ...
            'Name', gs_locations(i).Name, ...
            'Latitude', gs_locations(i).Latitude, ...
            'Longitude', gs_locations(i).Longitude)];
    end
    number_of_gs = length(gs);

    % ======= Visualization Update ========
    % Define Area of Interest (AoI) around Paradise, CA
    paradise_lat = 39.7596;  % Latitude of Paradise, CA
    paradise_lon = -121.6219; % Longitude of Paradise, CA

    % Define a 200 km x 200 km AoI
    half_side_km = 100; % 100 km half-side for a 200 km x 200 km square
    delta_lat = half_side_km / 111; % Approximate change in degrees latitude
    delta_lon = half_side_km / (111 * cosd(paradise_lat)); % Approximate change in degrees longitude

    % Set new AoI boundaries
    lat_min = paradise_lat - delta_lat;
    lat_max = paradise_lat + delta_lat;
    lon_min = paradise_lon - delta_lon;
    lon_max = paradise_lon + delta_lon;

    % Create a grid of points inside the new AoI
    numPoints = 20; % Adjust for resolution
    latGrid = linspace(lat_min, lat_max, numPoints);
    lonGrid = linspace(lon_min, lon_max, numPoints);
    [latPoints, lonPoints] = meshgrid(latGrid, lonGrid);

    % Calculate Coverage Radius based on Altitude and Viewing Angle
    coverage_radius = Altitude * tand(viewing_angle); % coverage_radius in km

    % Initialize Coverage Tracker
    interval_minutes = 5; % Interval to report coverage percentage
    required_coverage_time = 60; % 1 minute required coverage in seconds
    coverage_time_counter = zeros(size(latPoints)); % Track coverage duration for each grid point
    cumulative_coverage = false(size(latPoints)); % Track cumulative coverage across the entire simulation

    % ======= Access and Visualization Logic ========
    % Ground station access visualization
    for i = 1:number_of_gs
        ac = access(gs(i), satellites);
        ac.LineColor = 'r';
    end

    % Satellite to satellite access visualization for each plane
    for plane = 1:length(satellites_per_plane)
        satellites_orbit = satellites_per_plane{plane};
        num_sats_in_plane = length(satellites_orbit);
        for i = 1:num_sats_in_plane
            % Access between satellites in the same plane (next and previous)
            if i == 1
                ac = access(satellites_orbit(i), [satellites_orbit(2); satellites_orbit(end)]);
                ac.LineColor = 'b';
            elseif i == num_sats_in_plane
                ac = access(satellites_orbit(i), [satellites_orbit(end - 1); satellites_orbit(1)]);
                ac.LineColor = 'b';
            else
                ac = access(satellites_orbit(i), [satellites_orbit(i + 1); satellites_orbit(i - 1)]);
                ac.LineColor = 'b';
            end
        end
    end

    % ======= Dynamic Coverage Calculation and Visualization ========
    figure;
    for t = 1:length(time_vector)
        % Initialize an array to keep track of covered points at the current time
        current_coverage = false(size(latPoints));

        % Loop through each satellite
        for s = 1:number_of_SATs
            % Get satellite position at the current time
            satPos = states(satellites(s), time_vector(t), 'CoordinateFrame', 'geographic');
            satLat = satPos(1);
            satLon = satPos(2);

            % Calculate distance from each grid point to satellite
            for i = 1:numel(latPoints)
                pointLat = latPoints(i);
                pointLon = lonPoints(i);
                distance = distanceCalculator(satLat, satLon, pointLat, pointLon);

                % Check if the point is within the satellite's coverage radius
                if distance < coverage_radius % km
                    current_coverage(i) = true;
                    coverage_time_counter(i) = coverage_time_counter(i) + steptime; % Increment coverage time counter
                    cumulative_coverage(i) = true; % Track cumulative coverage
                end
            end

            % Plot satellite ground track and field of view
            fov_radius_deg = coverage_radius / 111; % Convert coverage radius to degrees latitude
            geoplot([satLat - fov_radius_deg, satLat + fov_radius_deg], [satLon - fov_radius_deg, satLon + fov_radius_deg], 'g', 'LineWidth', 1.5);
        end

        % Report coverage percentage every 5 minutes
        if mod(t - 1, interval_minutes * 60 / steptime) == 0
            % Determine which points have been covered for more than 1 minute
            covered_for_required_time = coverage_time_counter >= required_coverage_time;

            % Calculate the percentage of the AoI that meets the required coverage time
            covered_points = sum(covered_for_required_time(:));
            total_points = numel(latPoints);
            coverage_percentage = (covered_points / total_points) * 100;

            % Print the coverage percentage for the current interval
            fprintf('Coverage Percentage at t = %s (Covered for > 1 min): %.2f%%\n', datestr(time_vector(t)), coverage_percentage);

            % Reset the coverage time counter for the next interval
            coverage_time_counter(:) = 0;
        end

        % ======= Dynamic Visualization of Coverage ========
        cla; % Clear previous plot points
        geoplot([lat_min, lat_min, lat_max, lat_max, lat_min], ...
                [lon_min, lon_max, lon_max, lon_min, lon_min], 'm', 'LineWidth', 2);
        hold on;

        % Plot a marker for Paradise, CA
        geoscatter(paradise_lat, paradise_lon, 100, 'g', 'filled');
        text(paradise_lon, paradise_lat, ' Paradise, CA', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right', 'Color', 'green');

        % Plot the grid points for covered (red) and uncovered (blue) areas at current time
        geoscatter(latPoints(~current_coverage), lonPoints(~current_coverage), 20, 'b', 'filled');
        geoscatter(latPoints(current_coverage), lonPoints(current_coverage), 20, 'r', 'filled');
        geobasemap('satellite');
        title(['Satellite Coverage at Time: ', datestr(time_vector(t)), ' (200 km x 200 km around Paradise, CA)']);
        drawnow;
    end


    % ======= Ground Track Plotting ========
    leadTime = seconds(duration);
    trailTime = leadTime;
    groundTrack(satellites, "LeadTime", leadTime, "TrailTime", trailTime);

    % Play the scenario
    %play(scenario);
end

% ======= Helper Functions ========
% Distance Calculator Function
function distance = distanceCalculator(lat1, lon1, lat2, lon2)
    R = 6371; % Earth's radius in km
    dlat = deg2rad(lat2 - lat1);
    dlon = deg2rad(lon2 - lon1);
    a = sin(dlat/2)^2 + cos(deg2rad(lat1)) * cos(deg2rad(lat2)) * sin(dlon/2)^2;
    c = 2 * atan2(sqrt(a), sqrt(1 - a));
    distance = R * c;
end