function [PitchOffsetRadians,RollOffsetRadians,HeadOffsetRadians ...
	,SideslipFactor,AttackFactor,PStaticOffset] ...
	=AV410_factors(ncHEADER)

PitchOffsetRadians=ncreadatt(ncHEADER,'/','AWinds.PitchOffsetRadians');
if(isempty(PitchOffsetRadians))
    PitchOffsetRadians=0;
end

RollOffsetRadians=ncreadatt(ncHEADER,'/','AWinds.RollOffsetRadians');
if(isempty(RollOffsetRadians))
    RollOffsetRadians=0;
end

PitchOffsetRadians=ncreadatt(ncHEADER,'/','AWinds.PitchOffsetRadians');
if(isempty(PitchOffsetRadians))
    PitchOffsetRadians=0;
end

HeadOffsetRadians=ncreadatt(ncHEADER,'/','AWinds.HeadOffsetRadians');
if(isempty(HeadOffsetRadians))
    HeadOffsetRadians=0;
end

SideslipFactor=ncreadatt(ncHEADER,'/','AWinds.SideslipFactor');
if(isempty(SideslipFactor))
    SideslipFactor=0;
end

AttackFactor=ncreadatt(ncHEADER,'/','AWinds.AttackFactor');
if(isempty(AttackFactor))
    AttackFactor=0;
end

PStaticOffset=ncreadatt(ncHEADER,'/','AWinds.PStaticOffset');
if(isempty(PStaticOffset))
    PStaticOffset=0;
end

AttackFactor        = AttackFactor;
SideslipFactor      = SideslipFactor;
RollOffsetRadians   = RollOffsetRadians;
PitchOffsetRadians  = PitchOffsetRadians;
HeadOffsetRadians   = HeadOffsetRadians;
PStaticOffset       = PStaticOffset;


