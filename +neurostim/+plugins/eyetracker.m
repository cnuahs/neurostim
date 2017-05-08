classdef eyetracker < neurostim.plugin
% Generic eyetracker class for PTB.
%
% Properties:
%   To be set by subclass: x,y,z - coordinates of eye position
%                          eyeClockTime - for synchronization
%
%   sampleRate - rate of samples to be taken.
%   backgroundColor - background colour for eyetracker functions.
%   c oundColor - foreground colour for eyetracker functions.
%   clbTargetColor - calibration target color.
%   clbTargetSize - calibration target size.
%   eyeToTrack - one of 'left','right','binocular' or 0,1,2.
%   useMouse - if set to true, uses the mouse coordinates as eye coordinates.

    
    
    properties (Access=public)
        useMouse@logical=false;
        keepExperimentSetup@logical=true;
    end
    
    properties
        x@double=NaN; % Should have default values, otherwise bhavior checking can fail.
        y@double=NaN;
        z@double=NaN;
        pupilSize@double;
    end
    
    methods
        function o= eyetracker(c)
            o = o@neurostim.plugin(c,'eye'); % Always eye such that it can be accessed through cic.eye
            
            o.addProperty('eyeClockTime',[]);
            o.addProperty('hardwareModel',[]);
            o.addProperty('sampleRate',1000,'validate',@isnumeric);
            o.addProperty('backgroundColor',[]);
            o.addProperty('foregroundColor',[]);
            o.addProperty('clbTargetColor',[1,0,0]);
            o.addProperty('clbTargetSize',0.25);
            o.addProperty('eyeToTrack','left');
            o.addProperty('continuous',false);
        end
        
        
        
        function afterFrame(o)
            if o.useMouse
                [currentX,currentY,buttons] = o.cic.getMouse;
                if buttons(1) || o.continuous
                    o.x=currentX;
                    o.y=currentY;
                end
            end
        end
    end
    
    methods (Access=protected)
        function trackedEye(o)
            if ischar(o.eyeToTrack)
                switch lower(o.eyeToTrack)
                    case {'left','l'}
                        o.eyeToTrack = 0;
                    case {'right','r'}
                        o.eyeToTrack = 1;
                    case {'binocular','b','binoc'}
                        o.eyeToTrack = 2;
                end
            end
        end
    end
end