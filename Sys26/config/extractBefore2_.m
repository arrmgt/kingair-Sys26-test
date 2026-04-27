function y = extractBefore2_(x,pat);
% 
% Variables with position suffixes (e.g. "NRB" nose ring bottom)
%   must have the database template replaced by actual locator
%   (e.g. QQQ --> NRB)
%
% Character "_" is used to parse the suffixes
%
% Raw variables are assumed to have only one "_"
% Output variables:
%   There are some output variables with two "_"
%   (e.g. ACDP_1_NRB)
% This routine finds the suffix as the last _* string.
%

names = x;
names = string(names);    
mask = contains(names,'_'); 
if(sum(mask) <= 0); y = x; return; end

% find underscore positions for each entry
idxCell = regexp(names, pat, 'forceCellOutput');   % cell array of positions

% determine the position to extract before:
% - if >=2 underscores, use second position
% - if exactly 1 underscore, use first position
% - if none, leave as 0 (meaning "no change")
pos = zeros(size(names));
counts = cellfun(@numel, idxCell);
haveOne = counts == 1;
haveTwoOrMore = counts >= 2;
pos(haveOne) = cellfun(@(v) v(1), idxCell(haveOne));
pos(haveTwoOrMore) = cellfun(@(v) v(2), idxCell(haveTwoOrMore));

% apply extractBefore where pos > 0
y = names;
mask = pos > 0;
y(mask) = extractBefore(names(mask), pos(mask));

% out -> "a_b"    "foo"    "no_underscore"    "single"

end