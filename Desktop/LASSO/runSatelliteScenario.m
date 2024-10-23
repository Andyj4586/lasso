function runSatelliteScenario(Year, Month, Day, Hour, Minute, Seconds, durationHours, steptimeSeconds, Altitude, Eccentricity, Inclination, number_of_SATs, number_of_planes, Orbit_Propagator, RAAN_offset)
    
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
    
    % Calculate RAAN values for evenly spaced planes with offset
    RAAN_values = linspace(0, 360, number_of_planes + 1) + RAAN_offset; % Add user-defined offset to RAAN values
    RAAN_values = mod(RAAN_values, 360); % Ensure RAAN stays within [0, 360] degrees
    RAAN_values(end) = []; % Remove the last value to avoid overlap with 0 degrees

    % Define initial orbit information
    orbit_information = struct('SMA', Altitude * 1000 + 6378000, ... % Semi-Major Axis in meters
                               'ecc', Eccentricity, ...
                               'inc', Inclination, ...
                               'AOP', AOP);

    % Generate satellite constellation for each plane
    satellites = [];
    satellites_per_plane = cell(1, number_of_planes); % Store satellites in each plane for reference
    for i = 1:number_of_planes
        orbit_information.RAAN = RAAN_values(i);
        satellite_name = "Plane-" + i;
        satellites_orbit = single_orbit_constellation(scenario, orbit_information, number_of_SATs, Orbit_Propagator, satellite_name);
        satellites = [satellites, satellites_orbit];
        satellites_per_plane{i} = satellites_orbit; % Store satellites for each plane
    end
    
    % Ground Station Information
    gs_info = ["Austin", 30.2672, -97.7431, 0;
               "Madrid", 40.4168, -3.7038, 667;
               "Sydney", -33.8688, 151.2093, 19];
    
    gs = [];
    for i = 1:size(gs_info, 1)
        gs = [gs, groundStation(scenario, ...
            "Name", gs_info(i, 1), ...
            "Latitude", str2double(gs_info(i, 2)), ...
            "Longitude", str2double(gs_info(i, 3)), ...
            "Altitude", str2double(gs_info(i, 4)), ...
            "MinElevationAngle", 15)];
    end

    % Compute Accesses between Ground Stations and Satellites
    for i = 1:length(gs)
        ac = access(gs(i), satellites);
        ac.LineColor = 'r';
    end

    % Compute Accesses between Satellites in the same orbital plane
    for plane_idx = 1:number_of_planes
        start_idx = (plane_idx - 1) * number_of_SATs + 1;
        end_idx = plane_idx * number_of_SATs;

        for sat_idx = start_idx:end_idx
            if sat_idx == start_idx
                neighbors = [satellites(start_idx + 1), satellites(end_idx)];
            elseif sat_idx == end_idx
                neighbors = [satellites(start_idx), satellites(end_idx - 1)];
            else
                neighbors = [satellites(sat_idx + 1), satellites(sat_idx - 1)];
            end
            ac = access(satellites(sat_idx), neighbors);
            ac.LineColor = 'b';
        end
    end

    % Compute Accesses between Satellites in different orbital planes
    for plane_idx = 1:number_of_planes
        current_plane_sats = satellites_per_plane{plane_idx};

        % Connect each satellite in the current plane to the satellite in the next plane
        next_plane_idx = mod(plane_idx, number_of_planes) + 1; % Wrap around to the first plane after the last
        next_plane_sats = satellites_per_plane{next_plane_idx};

        % Establish connections for each satellite in the current plane to a corresponding satellite in the next plane
        for sat_idx = 1:number_of_SATs
            ac = access(current_plane_sats(sat_idx), next_plane_sats);
            ac.LineColor = 'g'; % Green for inter-plane communication
            ac.LineWidth = 1;
        end
    end

    % Generate Ground Track Visualization
    leadTime = seconds(duration);
    trailTime = leadTime;
    groundTrack(satellites, "LeadTime", leadTime, "TrailTime", trailTime);

    % ======= 2D Map Ground Track Plot Over Area of Interest (AoI) ========
    % Define Area of Interest (AoI) around Paradise, CA
    paradise_lat = 39.7596;  % Latitude of Paradise, CA
    paradise_lon = -121.6219; % Longitude of Paradise, CA

    % Define a 200 km x 200 km AoI
    half_side_km = 100; % 100 km half-side for a 200 km x 200 km square
    delta_lat = half_side_km / 111; % Approximate change in degrees latitude
    delta_lon = half_side_km / (111 * cosd(paradise_lat)); % Approximate change in degrees longitude

    % Set AoI boundaries
    lat_min = paradise_lat - delta_lat;
    lat_max = paradise_lat + delta_lat;
    lon_min = paradise_lon - delta_lon;
    lon_max = paradise_lon + delta_lon;

    % Plot the AoI boundaries on a 2D map
    figure;
    geoAx = geoaxes; % Create geographic axes for plotting
    hold(geoAx, 'on'); % Hold on for plotting multiple elements

    % Plot AoI boundaries
    geoplot(geoAx, [lat_min, lat_min, lat_max, lat_max, lat_min], ...
            [lon_min, lon_max, lon_max, lon_min, lon_min], 'm', 'LineWidth', 2);

    % Set geographic map view to satellite
    geobasemap(geoAx, 'satellite');

    % Loop through each satellite and plot its ground track over time within the AoI
    time_steps = time_parameters.startTime:seconds(time_parameters.steptime):time_parameters.startTime + time_parameters.duration;

    for s = 1:length(satellites)
        latitudes = [];
        longitudes = [];
        % Gather satellite positions over time
        for t = 1:length(time_steps)
            satPos = states(satellites(s), time_steps(t), 'CoordinateFrame', 'geographic');
            latitudes = [latitudes; satPos(1)];
            longitudes = [longitudes; satPos(2)];
        end
        % Plot the satellite ground track
        geoplot(geoAx, latitudes, longitudes, 'g', 'LineWidth', 1.5);
    end

    title(geoAx, 'Satellite Ground Track Over Area of Interest (200 km x 200 km around Paradise, CA)');
    hold(geoAx, 'off');

    % Play the scenario
    play(scenario);
end