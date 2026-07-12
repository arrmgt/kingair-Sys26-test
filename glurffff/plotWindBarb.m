function plotWindBarb(X,Y,speed,dir_from,varargin)
% plotWindBarb Draw simple meteorological wind barbs at X,Y
%   X,Y,speed,dir_from are vectors of same length.
%   dir_from: degrees, meteorological (wind coming from).
%   Optional name-value: 'Scale' (length scale), 'Color', 'LineWidth'.

% Parse options
p = inputParser; addParameter(p,'Scale',0.04,@isnumeric);
addParameter(p,'Color','k');
addParameter(p,'LineWidth',1);
parse(p,varargin{:});
S = p.Results.Scale; C = p.Results.Color; LW = p.Results.LineWidth;

% Barb geometry parameters (fraction of scale)
shaft = [0 1];         % line from (0,0) to (0,1)
flag_len = 0.25;       % triangle flag length (for 50 kt)
feather_len = 0.2;     % single feather length (for 10 kt)
gap = 0.02;

n = numel(X);
holdState = ishold; hold on
for i=1:n
    spd = speed(i);
    if spd < 2, continue; end  % skip near calm
    % Determine number of 50, 10, 5 knots
    n50 = floor(spd/50); spd = spd - 50*n50;
    n10 = floor(spd/10); spd = spd - 10*n10;
    n5  = round(spd/5);  % remaining 5-9 -> one 5 knot
    % Build barb segments along shaft (from tip backward)
    pos = 1;  % start at tip (shaft length = 1)
    segs = {}; % store line segments and filled flags
    for k=1:n50
        % triangle flag
        base = pos; tip = pos - flag_len;
        % triangle coordinates in local shaft coords (x,y)
        tri = [0,base;  -flag_len,base; 0,tip];
        segs{end+1} = struct('type','patch','xy',tri); %#ok<*AGROW>
        pos = pos - flag_len - gap;
    end
    for k=1:n10
        % long feather (line)
        xy = [0,pos; -feather_len,pos+feather_len];
        segs{end+1} = struct('type','line','xy',xy);
        pos = pos - feather_len - gap;
    end
    if n5==1
        xy = [0,pos; -feather_len/2,pos+feather_len/2];
        segs{end+1} = struct('type','line','xy',xy);
        pos = pos - feather_len/2 - gap;
    end
    % Draw shaft and elements rotated by wind direction
    theta = deg2rad(270 - dir_from(i)); % convert meteorological to math angle
    R = [cos(theta) -sin(theta); sin(theta) cos(theta)];
    % shaft
    p1 = [0,0]*S; p2 = [0,1]*S;
    P = [p1; p2]*R;
    plot(X(i)+P(:,1), Y(i)+P(:,2), 'Color', C, 'LineWidth', LW)
    % elements
    for s=1:numel(segs)
        xy = segs{s}.xy * S;
        xy = (xy * R) + [X(i), Y(i)];
        if strcmp(segs{s}.type,'line')
            plot(xy(:,1), xy(:,2), 'Color', C, 'LineWidth', LW)
        else
            patch(xy(:,1), xy(:,2), C, 'EdgeColor',C)
        end
    end
end
if ~holdState, hold off, end
axis equal
end
