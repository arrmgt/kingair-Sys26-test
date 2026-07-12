function Z = addDummyZFields(Z, dummyFields)
%ADDDUMMYZFIELDS Fill in Z fields that aren't available from data yet
%with a constant placeholder value.
%
%   Z = addDummyZFields(Z, dummyFields)
%
%   Z            - struct already built by buildZStruct/buildZFromStruct
%   dummyFields  - struct, each field a constant value to broadcast
%                  across every calibration point currently in Z (sized
%                  to match Z's existing fields), e.g.:
%                      dummyFields.mr = 0;   % mixing ratio unavailable for now
%
%   Call this AFTER buildZStruct/buildZFromStruct, and make sure the
%   corresponding channel is NOT listed in the varMap/rawVarNames passed
%   to the data-loading step (readNetCDFChunk will otherwise fail trying
%   to read a variable that doesn't exist in the file).
%
% See also: buildZStruct, buildZFromStruct, runCalibrationFit

fn = fieldnames(Z);
assert(~isempty(fn), 'addDummyZFields:emptyZ', 'Z has no fields yet -- build it first.');
n = numel(Z.(fn{1}));

dz = fieldnames(dummyFields);
for i = 1:numel(dz)
    Z.(dz{i}) = dummyFields.(dz{i}) * ones(n, 1);
end

end
