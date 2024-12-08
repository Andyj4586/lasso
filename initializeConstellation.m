function initializeConstellation(app)
    % Extract user inputs from the app
    Year = app.YearEditField.Value;
    Month = app.MonthEditField.Value;
    Day = app.DayEditField.Value;
    Hour = app.HourEditField.Value;
    Minute = app.MinuteEditField.Value;
    Seconds = app.SecondsEditField.Value;
    
    durationHours = app.DurationEditField.Value;  % Assuming duration is in hours
    steptime = app.SteptimeEditField.Value;       % Assuming steptime is in seconds
    
    Altitude = app.AltitudeEditField.Value;       % Altitude in km
    ecc = app.EccentricityEditField.Value;
    inc = app.InclinationEditField.Value;
    number_of_SATs = app.NumberofSatellitesEditField.Value;
    number_of_planes = app.NumberofPlanesEditField.Value;
    RAAN_offset = app.RAANOffsetEditField.Value;
    Orbit_propagator = app.OrbitPropagatorDropDown.Value;  % Assuming it's a dropdown
    AoILatitude = app.AoILatitudeEditField.Value;
    AoILongitude = app.AoILongitudeEditField.Value;
    
    % Create datetime objects for scenario start and stop times
    startTime = datetime(Year, Month, Day, Hour, Minute, Seconds);
    stopTime = startTime + hours(durationHours);
    
    % Initialize the satellite scenario and store it in app properties
    app.scenario = satelliteScenario(startTime, stopTime, steptime);
    
    % Semi-Major Axis (SMA) in meters
    SMA = Altitude * 1000 + 6378000;
    AOP = 0;  % Argument of Perigee in degrees
    
    % Distribute satellites within each orbit
    TA = linspace(0, 360, number_of_SATs + 1);
    TA(end) = [];
    
    % Calculate RAAN values for evenly spaced planes
    RAAN_values = mod(linspace(0, 360, number_of_planes + 1) + RAAN_offset, 360);
    RAAN_values(end) = [];
    
    % Create satellites in each orbital plane
    for i = 1:number_of_planes
        satellite_name_prefix = "RS-" + i;
        RAAN = RAAN_values(i);
        
        satellite_names = satellite_name_prefix + "-" + (1:number_of_SATs);
        
        satellite(app.scenario, ...
                  SMA * ones(number_of_SATs,1), ...
                  ecc * ones(number_of_SATs,1), ...
                  inc * ones(number_of_SATs,1), ...
                  RAAN * ones(number_of_SATs,1), ...
                  AOP * ones(number_of_SATs,1), ...
                  TA', ...
                  'Name', satellite_names, ...
                  'OrbitPropagator', Orbit_propagator);
    end
    
end