function out=wrap(in,varargin);
%function out=wrap(in);
% re-raps 0-2*pi type data
%
% out = wrap(in); 	 % assumes radians
% out = wrap(in,'deg');  % assumes degrees
% out = wrap(in,'flag'); % if anything in second argument, assumes degrees


if isempty(varargin)
  out = wrapTo2Pi(in); % Radians assumed			
else
  out = wrapTo360(in); % Otherwise degrees
end

end



 
