function constantAreaCapture(app)
    % Ensure that the scenario has been initialized
    if isempty(app.scenario) || isempty(app.scenario.Satellites)
        errordlg('Please initialize the constellation first.', 'Error');
        return;
    end
    
    % Ground target information from app inputs or predefined
    ground_target_name = "Paradise CA";
    ground_target_lat = app.AoILatitudeEditField.Value;
    ground_target_lon = app.AoILongitudeEditField.Value;
    ground_target_alt = 542;  % Altitude in meters
    elevation_angle_condition = 45;  
    
    % Create ground station at the target location
    gs = groundStation(app.scenario, ...
                       "Name", ground_target_name, ...
                       "Latitude", ground_target_lat, ...
                       "Longitude", ground_target_lon, ...
                       "Altitude", ground_target_alt, ...
                       "MinElevationAngle", elevation_angle_condition);
    
    % Compute ground target ECEF coordinates
    ground_target_lla = [ground_target_lat, ground_target_lon, ground_target_alt];
    ground_target_ecef = lla2ecef(ground_target_lla);
    r_gs = norm(ground_target_ecef);
    
    % Access analysis between satellites and ground station
    ac = access(app.scenario.Satellites, gs);
    ac.LineColor = 'r';
    [satellite_no, timestep] = find(accessStatus(ac) == 1);
    contact_info = [satellite_no, timestep];
    captured_satellite_no = unique(contact_info(:,1));
    
    % Prepare data for visualization
    sat_time_duration = zeros(length(captured_satellite_no), 3);
    sat_time_duration(:,1) = captured_satellite_no;
    satellite_namespace = app.scenario.Satellites.Name;

    
    for i = 1:length(captured_satellite_no)
        timestep_index = find(contact_info(:,1) == captured_satellite_no(i));
        timesteps = contact_info(timestep_index,2);
        starting_timestep = min(timesteps);
        sat_time_duration(i,2) = starting_timestep;
        sat_time_duration(i,3) = length(timesteps) - 1;
    end
    
    % Initialize storage for satellite positions and visualization
    sat_posvel_info = struct();
    no_of_sats = length(captured_satellite_no);
    
    % Compute satellite positions and other parameters
    for sat_index = 1:no_of_sats
        sat_number = sat_time_duration(sat_index,1);  % Satellite index
        
        % Debugging statements
        disp(['sat_index: ', num2str(sat_index)]);
        disp(['sat_number: ', num2str(sat_number)]);
        disp(['Length of satellite_namespace: ', num2str(length(satellite_namespace))]);
        
        sat_name = satellite_namespace(sat_number);
        
        % Start and end times for access period
        selected_start_time = app.scenario.StartTime + seconds(app.scenario.SampleTime * (sat_time_duration(sat_index,2)-1));
        selected_end_time = selected_start_time + seconds(app.scenario.SampleTime * sat_time_duration(sat_index,3));
        
        % Get satellite states at the selected start time
        [r_eci, v_eci] = states(app.scenario.Satellites(sat_number), selected_start_time, 'CoordinateFrame', 'inertial');
        
        % Store satellite information
        sat_field = ['sat', num2str(sat_index)];
        sat_posvel_info.(sat_field).('satellite_name') = sat_name;
        sat_posvel_info.(sat_field).('start_epoch') = selected_start_time;
        sat_posvel_info.(sat_field).('end_epoch') = selected_end_time;
        
        % Convert ECI to Keplerian elements
        [a, ecc_, incl, RAAN, argp, nu] = ijk2keplerian(r_eci, v_eci);
        sat_posvel_info.(sat_field).('orbit_parameter') = [ecc_, incl, RAAN, argp, nu]';
        
        % Create a temporary scenario for orbit propagation
        scenario_temp = satelliteScenario(selected_start_time, selected_end_time, 0.1);
        orbit_propagation = satellite(scenario_temp, a, ecc_, incl, RAAN, argp, nu, "OrbitPropagator", "sgp4");
        [r_ecef_prop, v_ecef_prop, t_prop] = states(orbit_propagation, 'CoordinateFrame', 'ecef');
        
        r_ecef_prop = r_ecef_prop';
        v_ecef_prop = v_ecef_prop';
        t_prop = t_prop';
        
        sat_posvel_info.(sat_field).('r_ecef') = r_ecef_prop;
        sat_posvel_info.(sat_field).('v_ecef') = v_ecef_prop;
        sat_posvel_info.(sat_field).('time_vector') = t_prop;
        
        % Compute range vector
        range_vector = vecnorm(r_ecef_prop - ground_target_ecef, 2, 2);
        sat_posvel_info.(sat_field).('range_vector') = range_vector;
        [minimum_range, index_for_minimum_range] = min(range_vector);
        sat_posvel_info.(sat_field).('minimum_range_km') = minimum_range / 1000;
        sat_posvel_info.(sat_field).('time_of_minimum_range') = t_prop(index_for_minimum_range);
        r_sat = norm(r_ecef_prop(index_for_minimum_range,:));
        roll_angle = acos((r_sat^2 + minimum_range^2 - r_gs^2) / (2 * minimum_range * r_sat)) * (180 / pi);
        
        lla_of_min_range = ecef2lla(r_ecef_prop(index_for_minimum_range,:));
        sat_posvel_info.(sat_field).('ground_target_lla') = ground_target_lla;
        sat_posvel_info.(sat_field).('lla_of_minimum_range') = lla_of_min_range;
        
        vel_of_min_range = v_ecef_prop(index_for_minimum_range,:);
        sat_posvel_info.(sat_field).('vel_of_minimum_range') = vel_of_min_range;
        
        if vel_of_min_range(3) * (lla_of_min_range(2) - ground_target_lla(2)) > 0
            roll_angle = -roll_angle;
        end
        sat_posvel_info.(sat_field).('roll_angle') = roll_angle;
    end
    
    % Compute ground points from tilt angles
    for sat_index = 1:no_of_sats
        sat_field = ['sat', num2str(sat_index)];
        data_length = length(sat_posvel_info.(sat_field).('time_vector'));
        
        lla_center = zeros(data_length,3);
        lla_end1 = zeros(data_length,3);
        lla_end2 = zeros(data_length,3);
        
        r_ecef_input_vector = sat_posvel_info.(sat_field).('r_ecef');
        v_ecef_input_vector = sat_posvel_info.(sat_field).('v_ecef');
        roll_angle = sat_posvel_info.(sat_field).('roll_angle');
        
        for index = 1:data_length
            r_ecef_input = r_ecef_input_vector(index,:);
            v_ecef_input = v_ecef_input_vector(index,:);
            [center, end2, end1] = ground_pointing_from_tilt_angle(r_ecef_input, v_ecef_input, roll_angle);
            
            lla_center(index,:) = center;
            lla_end1(index,:) = end1;
            lla_end2(index,:) = end2;
        end
        
        sat_posvel_info.(sat_field).('lla_sat') = ecef2lla(r_ecef_input_vector);
        sat_posvel_info.(sat_field).('lla_center') = lla_center;
        sat_posvel_info.(sat_field).('lla_end1') = lla_end1;
        sat_posvel_info.(sat_field).('lla_end2') = lla_end2;
    end
    
    % Visualization on geoglobe
    uif = uifigure;
    g = geoglobe(uif, 'NextPlot', 'add');
    hold(g, 'on');
    
    for sat_index = 1:no_of_sats
        sat_field = ['sat', num2str(sat_index)];
        
        lla_center = sat_posvel_info.(sat_field).('lla_center');
        lla_end1 = sat_posvel_info.(sat_field).('lla_end1');
        lla_end2 = sat_posvel_info.(sat_field).('lla_end2');
        lla_sat = sat_posvel_info.(sat_field).('lla_sat');
        
        geoplot3(g, lla_center(:,1), lla_center(:,2), 3000, "g", 'LineWidth', 3);
        geoplot3(g, lla_end1(:,1), lla_end1(:,2), 3000, "r", 'LineWidth', 3);
        geoplot3(g, lla_end2(:,1), lla_end2(:,2), 3000, "b", 'LineWidth', 3);
        geoplot3(g, lla_sat(:,1), lla_sat(:,2), lla_sat(:,3), "c", 'LineWidth', 3);
    end
    
    hold(g, 'off');
end