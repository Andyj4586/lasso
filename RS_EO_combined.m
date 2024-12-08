%RS_EO_01_Constellation_Initialization
%Initial Epoch Definition
Year = 2025;
Month = 3;
Day = 21;
Hour = 1;
Minute = 0;
Seconds = 0;

% Duration and Steptime
duration = hours(2);
steptime = 15;

startTime = datetime(Year,Month,Day,Hour,Minute,Seconds);
stopTime = startTime + duration;

scenario = satelliteScenario(startTime,stopTime,steptime);

% Initial Orbit Settings
Altitude = 600;
SMA = Altitude * 1000 + 6378000;
ecc= 1e-5;
inc = 98;
AOP = 0;
number_of_SATs = 15;
TA = 0:360/number_of_SATs:360-360/number_of_SATs;
Orbit_propagator = 'SGP4';

% Number of Satellite for each orbit

% Orbit 1
satellite_name = "RS-1";
RAAN = 0;
satellite_orbit_1 = satellite(scenario,...
                               SMA * ones(number_of_SATs,1),...
                               ecc * ones(number_of_SATs,1),...
                               inc * ones(number_of_SATs,1),...
                               RAAN * ones(number_of_SATs,1),...
                               AOP * ones(number_of_SATs,1),...
                               TA,...
                               Name = satellite_name +"-" +(1:number_of_SATs), ...
                               OrbitPropagator = Orbit_propagator);


% Orbit 2
satellite_name = "RS-2";
RAAN = 45;
satellite_orbit_2 = satellite(scenario,...
                               SMA * ones(number_of_SATs,1),...
                               ecc * ones(number_of_SATs,1),...
                               inc * ones(number_of_SATs,1),...
                               RAAN * ones(number_of_SATs,1),...
                               AOP * ones(number_of_SATs,1),...
                               TA,...
                               Name = satellite_name +"-" +(1:number_of_SATs), ...
                               OrbitPropagator = Orbit_propagator);


% Orbit 3
satellite_name = "RS-3";
RAAN = 90;
satellite_orbit_3 = satellite(scenario,...
                               SMA * ones(number_of_SATs,1),...
                               ecc * ones(number_of_SATs,1),...
                               inc * ones(number_of_SATs,1),...
                               RAAN * ones(number_of_SATs,1),...
                               AOP * ones(number_of_SATs,1),...
                               TA,...
                               Name = satellite_name +"-" +(1:number_of_SATs), ...
                               OrbitPropagator = Orbit_propagator);

% Orbit 4
satellite_name = "RS-4";
RAAN = 135;
satellite_orbit_4 = satellite(scenario,...
                               SMA * ones(number_of_SATs,1),...
                               ecc * ones(number_of_SATs,1),...
                               inc * ones(number_of_SATs,1),...
                               RAAN * ones(number_of_SATs,1),...
                               AOP * ones(number_of_SATs,1),...
                               TA,...
                               Name = satellite_name +"-" +(1:number_of_SATs), ...
                               OrbitPropagator = Orbit_propagator);

% gt = groundTrack(satellite_orbit_3,"LeadTime",0,"Trailtime",7200);

play(scenario)
% 
% save('~/Redstone_Project/RS_EO/RS_EO_01_Constellation_Initialization/constellation_setting.mat','scenario');

%% RS_EO_02_Constant_Area_Capture
clear;
addpath('~/Desktop/Redstone_Project/RS_EO/RS_EO_01_Constellation_Initialization/');
addpath('~/Desktop/Redstone_Project/RS_EO/RS_EO_02_Constant_Area_Capture/');
load('constellation_setting.mat')

ground_target = ["Paradise CA", 39.7596, -121.6219, 542]
elevation_angle_condition = 45;


gs = groundStation(scenario,"Name",ground_target(:,1), ...
                        "Latitude",str2double(ground_target(:,2)), ...
                        "Longitude", str2double(ground_target(:,3)), ...
                        "Altitude", str2double(ground_target(:,4)), ...
                        "MinElevationAngle", elevation_angle_condition ...
                        );

ground_target_lla = [39.7596, -121.6219, 542];
ground_target_ecef = lla2ecef(ground_target_lla);
r_gs = norm(ground_target_ecef);

ac = access(scenario.Satellites, gs);

ac.LineColor = 'r';
[satellite_no,timestep] = find(accessStatus(ac) == 1);
contact_info = [satellite_no,timestep];
captured_satellite_no = unique(contact_info(:,1));

accessIntervals(ac)

sat_time_duration = zeros(length(captured_satellite_no),3);
sat_time_duration(:,1) = captured_satellite_no;
satellite_namespace = scenario.Satellites.Name;

for i = 1:length(captured_satellite_no)
  timestep_index = find(contact_info(:,1) == captured_satellite_no(i));
  timesteps = contact_info(timestep_index,2);
  starting_timestep =  min(timesteps);
  sat_time_duration(i,2) = starting_timestep;
  sat_time_duration(i,3) = (length(timesteps)-1);
end

sat_time_duration

sat_posvel_info = struct();
no_of_sats = length(captured_satellite_no);


% Create Scenario 2



for sat_index = 1:no_of_sats
  sat_posvel_info.(['sat',num2str(sat_index)]).('satellite_name') = satellite_namespace{sat_time_duration(sat_index,1)};
  selected_start_time = scenario.StartTime + seconds(scenario.SampleTime * (sat_time_duration(sat_index,2)-1));
  selected_end_time = selected_start_time + seconds(scenario.SampleTime * sat_time_duration(sat_index,3));
  [r_eci,v_eci] = states(scenario.Satellites(sat_time_duration(sat_index,1)),selected_start_time,'CoordinateFrame','inertial');

  sat_posvel_info.(['sat',num2str(sat_index)]).('start_epoch') = selected_start_time;
  sat_posvel_info.(['sat',num2str(sat_index)]).('end_epoch') = selected_end_time;

  [a,ecc,incl,RAAN,argp,nu] = ijk2keplerian(r_eci,v_eci);

  sat_posvel_info.(['sat',num2str(sat_index)]).('orbit_parameter') = [ecc,incl,RAAN,argp,nu]';

  scenario_temp = satelliteScenario(selected_start_time,selected_end_time,0.1);
  orbit_propagation = satellite(scenario_temp,a,ecc,incl,RAAN,argp,nu,"OrbitPropagator","sgp4");
  [r_ecef_prop, v_ecef_prop, t_prop] = states(orbit_propagation,'CoordinateFrame','ecef');

  r_ecef_prop = r_ecef_prop';
  v_ecef_prop = v_ecef_prop';
  t_prop = t_prop';

  sat_posvel_info.(['sat',num2str(sat_index)]).('r_ecef') = r_ecef_prop;
  sat_posvel_info.(['sat',num2str(sat_index)]).('v_ecef') = v_ecef_prop;
  sat_posvel_info.(['sat',num2str(sat_index)]).('time_vector') = t_prop;

  range_vector = zeros(length(t_prop),1);
  for prop_index = 1:length(t_prop)
  range_vector(prop_index) = norm(r_ecef_prop(prop_index,:) - ground_target_ecef);
  end

  sat_posvel_info.(['sat',num2str(sat_index)]).('range_vector') = range_vector;
  minimum_range = min(range_vector);
  index_for_minimum_range = find(range_vector == minimum_range);
  sat_posvel_info.(['sat',num2str(sat_index)]).('minimum_range_km') =  minimum_range/1000; 
  sat_posvel_info.(['sat',num2str(sat_index)]).('time_of_minimum_range') = t_prop(index_for_minimum_range);
  r_sat = norm(r_ecef_prop(index_for_minimum_range,:));
  roll_angle = acos((r_sat^2+minimum_range^2-r_gs^2)/(2*minimum_range*r_sat))/pi*180;


  lla_of_min_range = ecef2lla(r_ecef_prop(index_for_minimum_range,:));

  sat_posvel_info.(['sat',num2str(sat_index)]).('ground_target_lla') = ground_target_lla;
  sat_posvel_info.(['sat',num2str(sat_index)]).('lla_of_minimum_range') = lla_of_min_range;


  vel_of_min_range = v_ecef_prop(index_for_minimum_range,:);
  sat_posvel_info.(['sat',num2str(sat_index)]).('vel_of_minimum_range') = vel_of_min_range;

  if vel_of_min_range(3) * (lla_of_min_range(2) - ground_target_lla(2)) > 0
    roll_angle = - roll_angle;
  end
  sat_posvel_info.(['sat',num2str(sat_index)]).('roll_angle') = roll_angle;
end

for sat_index = 1:no_of_sats
  data_length = length(sat_posvel_info.(['sat',num2str(sat_index)]).('time_vector'));

  lla_center = zeros(data_length,3);
  lla_end1 = zeros(data_length,3);
  lla_end2 = zeros(data_length,3);

  r_ecef_input_vector = sat_posvel_info.(['sat',num2str(sat_index)]).('r_ecef');
  v_ecef_input_vector = sat_posvel_info.(['sat',num2str(sat_index)]).('v_ecef');
  roll_angle =  sat_posvel_info.(['sat',num2str(sat_index)]).('roll_angle');

  for index = 1:data_length

        r_ecef_input = r_ecef_input_vector(index,:);
        v_ecef_input = v_ecef_input_vector(index,:);
        [center,end2,end1] =  ground_pointing_from_tilt_angle(r_ecef_input, v_ecef_input, roll_angle);

       lla_center(index,:) = center;
       lla_end1(index,:) = end1;
       lla_end2(index,:) = end2;

  end

       sat_posvel_info.(['sat',num2str(sat_index)]).('lla_sat') = ecef2lla(r_ecef_input_vector);
       sat_posvel_info.(['sat',num2str(sat_index)]).('lla_center') = lla_center;
       sat_posvel_info.(['sat',num2str(sat_index)]).('lla_end1') = lla_end1;
       sat_posvel_info.(['sat',num2str(sat_index)]).('lla_end2') = lla_end2;

end

uif = uifigure;
g = geoglobe(uif,'NextPlot','add');
figure;
hold(g,'on')

for sat_index = 1:no_of_sats

lla_center = sat_posvel_info.(['sat',num2str(sat_index)]).('lla_center');
lla_end1 = sat_posvel_info.(['sat',num2str(sat_index)]).('lla_end1');
lla_end2 = sat_posvel_info.(['sat',num2str(sat_index)]).('lla_end2');
lla_sat = sat_posvel_info.(['sat',num2str(sat_index)]).('lla_sat');


geoplot3(g,lla_center(:,1), lla_center(:,2), 3000,"g",'LineWidth',3)
geoplot3(g,lla_end1(:,1), lla_end1(:,2), 3000,"r",'LineWidth',3)
geoplot3(g,lla_end2(:,1), lla_end2(:,2), 3000,"b",'LineWidth',3)
geoplot3(g,lla_sat(:,1), lla_sat(:,2), lla_sat(:,3),"c",'LineWidth',3)

end

hold(g,'off')

%% RS_EO_03_Wide_Area_Capture
clear;
addpath('~/Redstone_Project/RS_EO/RS_EO_01_Constellation_Initialization/');
addpath('~/Redstone_Project/RS_EO/RS_EO_03_Wide_Area_Capture/');
load('constellation_setting.mat')

ground_target = ["Paradise CA", 39.7596, -121.6219, 542]
elevation_angle_condition = 45;


gs = groundStation(scenario,"Name",ground_target(:,1), ...
                        "Latitude",str2double(ground_target(:,2)), ...
                        "Longitude", str2double(ground_target(:,3)), ...
                        "Altitude", str2double(ground_target(:,4)), ...
                        "MinElevationAngle", elevation_angle_condition ...
                        );

ground_target_lla = [39.7596, -121.6219, 542];
ground_target_ecef = lla2ecef(ground_target_lla);
r_gs = norm(ground_target_ecef);

ac = access(scenario.Satellites, gs);

ac.LineColor = 'r';
[satellite_no,timestep] = find(accessStatus(ac) == 1);
contact_info = [satellite_no,timestep];
captured_satellite_no = unique(contact_info(:,1));

% accessIntervals(ac)

sat_time_duration = zeros(length(captured_satellite_no),3);
sat_time_duration(:,1) = captured_satellite_no;
satellite_namespace = scenario.Satellites.Name;

for i = 1:length(captured_satellite_no)
  timestep_index = find(contact_info(:,1) == captured_satellite_no(i));
  timesteps = contact_info(timestep_index,2);
  starting_timestep =  min(timesteps);
  sat_time_duration(i,2) = starting_timestep;
  sat_time_duration(i,3) = (length(timesteps)-1);
end

% sat_time_duration

sat_posvel_info = struct();
no_of_sats = length(captured_satellite_no);


% Create Scenario 2
initial_roll_angle_info =  zeros(no_of_sats,3);


for sat_index = 1:no_of_sats
  sat_posvel_info.(['sat',num2str(sat_index)]).('satellite_name') = satellite_namespace{sat_time_duration(sat_index,1)};
  selected_start_time = scenario.StartTime + seconds(scenario.SampleTime * (sat_time_duration(sat_index,2)-1));
  selected_end_time = selected_start_time + seconds(scenario.SampleTime * sat_time_duration(sat_index,3));
  [r_eci,v_eci] = states(scenario.Satellites(sat_time_duration(sat_index,1)),selected_start_time,'CoordinateFrame','inertial');

  sat_posvel_info.(['sat',num2str(sat_index)]).('start_epoch') = selected_start_time;
  sat_posvel_info.(['sat',num2str(sat_index)]).('end_epoch') = selected_end_time;

  [a,ecc,incl,RAAN,argp,nu] = ijk2keplerian(r_eci,v_eci);

  sat_posvel_info.(['sat',num2str(sat_index)]).('orbit_parameter') = [ecc,incl,RAAN,argp,nu]';

  scenario_temp = satelliteScenario(selected_start_time,selected_end_time,0.1);
  orbit_propagation = satellite(scenario_temp,a,ecc,incl,RAAN,argp,nu,"OrbitPropagator","sgp4");
  [r_ecef_prop, v_ecef_prop, t_prop] = states(orbit_propagation,'CoordinateFrame','ecef');

  r_ecef_prop = r_ecef_prop';
  v_ecef_prop = v_ecef_prop';
  t_prop = t_prop';

  sat_posvel_info.(['sat',num2str(sat_index)]).('r_ecef') = r_ecef_prop;
  sat_posvel_info.(['sat',num2str(sat_index)]).('v_ecef') = v_ecef_prop;
  sat_posvel_info.(['sat',num2str(sat_index)]).('time_vector') = t_prop;

  range_vector = zeros(length(t_prop),1);
  for prop_index = 1:length(t_prop)
  range_vector(prop_index) = norm(r_ecef_prop(prop_index,:) - ground_target_ecef);
  end

  sat_posvel_info.(['sat',num2str(sat_index)]).('range_vector') = range_vector;
  minimum_range = min(range_vector);
  index_for_minimum_range = find(range_vector == minimum_range);
  sat_posvel_info.(['sat',num2str(sat_index)]).('minimum_range_km') =  minimum_range/1000; 
  sat_posvel_info.(['sat',num2str(sat_index)]).('time_of_minimum_range') = t_prop(index_for_minimum_range);
  r_sat = norm(r_ecef_prop(index_for_minimum_range,:));
  roll_angle_initial = acos((r_sat^2+minimum_range^2-r_gs^2)/(2*minimum_range*r_sat))/pi*180;


  lla_of_min_range = ecef2lla(r_ecef_prop(index_for_minimum_range,:));

  sat_posvel_info.(['sat',num2str(sat_index)]).('ground_target_lla') = ground_target_lla;

  sat_posvel_info.(['sat',num2str(sat_index)]).('lla_of_minimum_range') = lla_of_min_range;
  sat_posvel_info.(['sat',num2str(sat_index)]).('ecef_of_minimum_range') = r_ecef_prop(index_for_minimum_range,:);

  vel_of_min_range = v_ecef_prop(index_for_minimum_range,:);
  sat_posvel_info.(['sat',num2str(sat_index)]).('vel_of_minimum_range') = vel_of_min_range;

  if vel_of_min_range(3) * (lla_of_min_range(2) - ground_target_lla(2)) > 0
    roll_angle_initial = - roll_angle_initial;
  end
  sat_posvel_info.(['sat',num2str(sat_index)]).('roll_angle_initial') = roll_angle_initial;
  initial_roll_angle_info(sat_index,2) = roll_angle_initial;
  initial_roll_angle_info(sat_index,3) = abs(roll_angle_initial);
  initial_roll_angle_info(sat_index,1) = sat_index;
end

initial_roll_angle_info_original = initial_roll_angle_info;
initial_roll_angle_info = sortrows(initial_roll_angle_info,3);
sat_posvel_info.('initial_roll_angle_info') = initial_roll_angle_info;

final_roll_angle_info = zeros(no_of_sats,1);

for sat_index = 1:no_of_sats

    % if sat_index == 1
    selected_sat_index = initial_roll_angle_info(sat_index,1);
    % selected_roll_angle = initial_roll_angle_info(sat_index,3);
    % sat_posvel_info.(['sat',num2str(selected_sat_index)]).('roll_angle') = selected_roll_angle;
    % 
    % r_ecef_input = sat_posvel_info.(['sat',num2str(selected_sat_index)]).('ecef_of_minimum_range');
    % v_ecef_input = sat_posvel_info.(['sat',num2str(selected_sat_index)]).('vel_of_minimum_range');
    % [center,end2,end1] =  ground_pointing_from_tilt_angle(r_ecef_input, v_ecef_input, selected_roll_angle);
    % 
    % boundary_info = [end1', end2'];
    % final_roll_angle_info(selected_sat_index) = selected_roll_angle;
    % continue;    
    % end
    % 
    % selected_sat_index =  initial_roll_angle_info(sat_index,1);
    % selected_roll_angle = initial_roll_angle_info(sat_index,2);
    % r_ecef_input = sat_posvel_info.(['sat',num2str(selected_sat_index)]).('ecef_of_minimum_range');
    % v_ecef_input = sat_posvel_info.(['sat',num2str(selected_sat_index)]).('vel_of_minimum_range');
    % 
    updated_roll_angle = 0;


   %  while true
   % 
   %  [center,end2,end1] =  ground_pointing_from_tilt_angle(r_ecef_input, v_ecef_input, updated_roll_angle);
   %  updated_boundary_info = [end1', end2'];
   % 
   %      if selected_roll_angle > 0
   % 
   %          if updated_boundary_info(2,1) - boundary_info(2,2) < 0
   %          boundary_info(:,2) = updated_boundary_info(:,2)
   %          break;
   %          else
   %          updated_roll_angle = updated_roll_angle + 0.01;
   %          end
   %      end
   % 
   %      if selected_roll_angle < 0
   %          if updated_boundary_info(2,2) - boundary_info(2,1) < 0
   %          boundary_info(:,1) = updated_boundary_info(:,1)    
   %          break;
   %          else
   %          updated_roll_angle = updated_roll_angle - 0.01;
   %          end
   %      end
   %  end
   % 
   sat_posvel_info.(['sat',num2str(selected_sat_index)]).('roll_angle') = updated_roll_angle;  

   % final_roll_angle_info(selected_sat_index) = updated_roll_angle;
end    


for sat_index = 1:no_of_sats
  data_length = length(sat_posvel_info.(['sat',num2str(sat_index)]).('time_vector'));

  lla_center = zeros(data_length,3);
  lla_end1 = zeros(data_length,3);
  lla_end2 = zeros(data_length,3);

  r_ecef_input_vector = sat_posvel_info.(['sat',num2str(sat_index)]).('r_ecef');
  v_ecef_input_vector = sat_posvel_info.(['sat',num2str(sat_index)]).('v_ecef');
  roll_angle_initial =  sat_posvel_info.(['sat',num2str(sat_index)]).('roll_angle');

  for index = 1:data_length

        r_ecef_input = r_ecef_input_vector(index,:);
        v_ecef_input = v_ecef_input_vector(index,:);
       [center,end2,end1] =  ground_pointing_from_tilt_angle(r_ecef_input, v_ecef_input, roll_angle_initial);

       lla_center(index,:) = center;
       lla_end1(index,:) = end1;
       lla_end2(index,:) = end2;

  end

       sat_posvel_info.(['sat',num2str(sat_index)]).('lla_sat') = ecef2lla(r_ecef_input_vector);
       sat_posvel_info.(['sat',num2str(sat_index)]).('lla_center') = lla_center;
       sat_posvel_info.(['sat',num2str(sat_index)]).('lla_end1') = lla_end1;
       sat_posvel_info.(['sat',num2str(sat_index)]).('lla_end2') = lla_end2;

end

uif = uifigure;
g = geoglobe(uif,'NextPlot','add');
figure;
hold(g,'on')

for sat_index = 1:no_of_sats

lla_center = sat_posvel_info.(['sat',num2str(sat_index)]).('lla_center');
lla_end1 = sat_posvel_info.(['sat',num2str(sat_index)]).('lla_end1');
lla_end2 = sat_posvel_info.(['sat',num2str(sat_index)]).('lla_end2');
lla_sat = sat_posvel_info.(['sat',num2str(sat_index)]).('lla_sat');


geoplot3(g,lla_center(:,1), lla_center(:,2), 3000,"g",'LineWidth',3)
geoplot3(g,lla_end1(:,1), lla_end1(:,2), 3000,"r",'LineWidth',3)
geoplot3(g,lla_end2(:,1), lla_end2(:,2), 3000,"b",'LineWidth',3)
geoplot3(g,lla_sat(:,1), lla_sat(:,2), lla_sat(:,3),"c",'LineWidth',3)

end

hold(g,'off')

%% RS_EO_05_01_Satellite_Network_Design
clear;
addpath('~/Redstone_Project/RS_EO/RS_EO_01_Constellation_Initialization/');
load('constellation_setting.mat')

elevation_angle_condition = 15;

receiving_gs_info = ["Svalbard, Norway", 78.2300, 15.4100, 120;
                     "Alaska Satellite Facility, USA", 64.8581, -147.8494, 133;
                     "King Sejong Station, Antarctica", -62.2233, -58.7855, 11;
                     "Troll Station, Antarctica", -72.0167, 2.5333, 1275;
                     "McMurdo Station, Antarctica", -77.8419, 166.6863, 24;
                     "Tromsø, Norway", 69.6492, 18.9560, 10;
                     "Inuvik, Canada", 68.3600, -133.7236, 65;
                     "Prince Albert, Canada", 53.2022, -105.7453, 428;
                     "Wallops Island, Virginia, USA", 37.9402, -75.4661, 14;
                     "Santiago, Chile", -33.4489, -70.6693, 520;
                     "Hartebeesthoek, South Africa", -25.8870, 27.7044, 1415;
                     "Dongara, Australia", -29.2049, 114.9389, 20];


gs = groundStation(scenario,"Name",receiving_gs_info(:,1), ...
                        "Latitude",str2double(receiving_gs_info(:,2)), ...
                        "Longitude", str2double(receiving_gs_info(:,3)), ...
                        "Altitude", str2double(receiving_gs_info(:,4)), ...
                        "MinElevationAngle", elevation_angle_condition ...
                        );

list_of_Satellites = scenario.Satellites;
no_of_satellites = length(list_of_Satellites);
no_of_receiving_gs = length(receiving_gs_info(:,1));
no_of_timesteps = seconds(scenario.StopTime - scenario.StartTime)/scenario.SampleTime +1;


ac_between_orbit = access(list_of_Satellites(1:45),list_of_Satellites(16:60));
ac_between_orbit.LineColor = 'g';


ac_inside_orbit = access(list_of_Satellites(1:60),list_of_Satellites([2:15, 1, 17:30, 16, 32:45, 31, 47:60, 46]));
ac_inside_orbit.LineColor = 'b';



sat_to_sat_contact_matrix = zeros(no_of_satellites, no_of_satellites, no_of_timesteps);


% 주어진 인덱스 배열
index_order = 16:60;

% 패턴에 맞춰 1로 설정
for i = 1:45
    j = index_order(i);  % 해당 인덱스 배열에서 순서대로 선택
    sat_to_sat_contact_matrix(i, j, :) = 1;
end



% 주어진 인덱스 배열
index_order = [2:15, 1, 17:30, 16, 32:45, 31, 47:60, 46];

% 패턴에 맞춰 1로 설정
for i = 1:60
    j = index_order(i);  % 해당 인덱스 배열에서 순서대로 선택
    sat_to_sat_contact_matrix(i, j, :) = 1;
end


sat_to_gs_contact_matrix = zeros(no_of_satellites, no_of_receiving_gs, no_of_timesteps);

for index = 1:no_of_receiving_gs
    sat_to_gs_temp = access(list_of_Satellites, gs(index));
    sat_to_gs_temp.LineColor = 'r';
    sat_to_gs_contact_matrix(:,index,:) = accessStatus(sat_to_gs_temp);
end



play(scenario)

numGroundStations = length(receiving_gs_info(:,1));
numSatellites = length(list_of_Satellites);
time_index  = 20;

gs_to_sat_contact_matrix = permute(sat_to_gs_contact_matrix, [2, 1, 3]);
GS_to_Sat = gs_to_sat_contact_matrix(:,:,time_index);
Sat_to_Sat = sat_to_sat_contact_matrix(:,:,time_index);

% Create a graph object
G = graph();

% Add Ground Stations as nodes
for i = 1:numGroundStations
    G = addnode(G, sprintf('GS%d', i));
end

% Add Satellites as nodes
for i = 1:numSatellites
    G = addnode(G, sprintf('SAT%d', i));
end

% Add edges between Ground Stations and Satellites
for i = 1:numGroundStations
    for j = 1:numSatellites
        if GS_to_Sat(i, j) == 1
            G = addedge(G, sprintf('GS%d', i), sprintf('SAT%d', j));
        end
    end
end

% Add edges between Satellites
for i = 1:numSatellites
    for j = 1:numSatellites
        if Sat_to_Sat(i, j) == 1
            G = addedge(G, sprintf('SAT%d', i), sprintf('SAT%d', j));
        end
    end
end

% Number of ground stations and satellites
num_ground_stations = length(receiving_gs_info(:,1));
num_satellites = length(list_of_Satellites);

% Create the node position;
ground_station_radius = 10; % Radius of the small circle for ground stations
satellite_radius = 7; % Radius of the outer circle for satellites

% Ground station positions
ground_station_angles = linspace(0, 2* pi, num_ground_stations+1);
ground_station_angles = ground_station_angles(1:end-1);
ground_station_x = ground_station_radius * cos(ground_station_angles);
ground_station_y = ground_station_radius * sin(ground_station_angles);

% Satellite positions
satellite_angles = linspace(0, 2*pi, num_satellites+1);
satellite_angles = satellite_angles(1:end-1);
satellite_x = satellite_radius * cos(satellite_angles);
satellite_y = satellite_radius * sin(satellite_angles);

% Combine the node positions
x = [ground_station_x, satellite_x];
y = [ground_station_y, satellite_y];

% Plot the network graph
figure;
plot(G, 'XData', x, 'YData', y, 'NodeColor', [0.6 0.6 0.6], 'EdgeColor', 'k', 'LineWidth', 1);
hold on;

% Plot the ground stations in blue and the satellites in red
plot(ground_station_x, ground_station_y, 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
plot(satellite_x, satellite_y, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');

% Adjust the axis limits to fit the plot
axis equal;
title('Network Graph: Ground Stations and Satellites');