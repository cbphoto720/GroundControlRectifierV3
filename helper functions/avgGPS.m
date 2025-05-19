function Outputdata = avgGPS(GPSpoints,var,range)
% Find the Average of some GPS points

rows=range;
a=0; %preallocate avg
for i=1:length(rows)
    a=a+GPSpoints.(var)(rows(i));
end
a=a./length(rows);

% Work out precision
get_precision = @(x) find(mod(x, 10.^-(1:15)) == 0, 1, 'first');
% Get precision for each row element
decimal_places = arrayfun(get_precision, GPSpoints.(var)(rows));
max_precision = max(decimal_places); 
round_a = round(a, max_precision); % Round 'a' to the detected max precision (sometimes the iG8a will round values)

%Get headers
% headers = GPSpoints.Properties.VariableNames;
% VariableName = var;


Outputdata=sprintf(['%s AVG:     %f \n%s Rounded: %.',num2str(max_precision),'f\n'],var,a, var,round_a);
disp(Outputdata);
end