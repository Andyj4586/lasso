function calculateCoverage(satellites, scenario, lat_min, lat_max, lon_min, lon_max)
    numPoints = 20; % Define the number of points along each dimension
    latGrid = linspace(lat_min, lat_max, numPoints);
    lonGrid = linspace(lon_min, lon_max, numPoints);
    [latPoints, lonPoints] = meshgrid(latGrid, lonGrid);
    gridPoints = [latPoints(:), lonPoints(:)];

    number_of_SATs = length(satellites);
    time_vector = scenario.StartTime:seconds(scenario.SampleTime):scenario.StopTime;

    % Initialize coverage tracking
    covered_points = zeros(size(gridPoints, 1), length(time_vector));

    for t = 1:length(time_vector)
        for s = 1:number_of_SATs
            % Get satellite position at current time
            satPos = states(satellites(s), time_vector(t), 'CoordinateFrame', 'geographic');
            satLat = satPos(1);
            satLon = satPos(2);

            % Calculate distance to each grid point
            for p = 1:size(gridPoints, 1)
                pointLat = gridPoints(p, 1);
                pointLon = gridPoints(p, 2);

                % Use distanceCalculator to check coverage
                distance = distanceCalculator(satLat, satLon, pointLat, pointLon);

                % Check if within coverage radius (e.g., 3000 km)
                if distance < 3000 % km
                    covered_points(p, t) = 1;
                end
            end
        end
    end

    % Calculate coverage percentage over time
    coverage_percentage = sum(covered_points, 1) / size(gridPoints, 1) * 100;

    % Plot coverage percentage over time
    figure;
    plot(time_vector, coverage_percentage);
    xlabel('Time');
    ylabel('Coverage Percentage (%)');
    title('Coverage Percentage Over Time for Area of Interest');
end
