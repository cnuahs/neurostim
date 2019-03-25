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
%
% Keyboard:
%   Pressing 'b' simulates a 200 ms eye blink
    
    
    properties (Access=public)
        useMouse@logical=false;
        keepExperimentSetup@logical=true;
        eye@char='LEFT'; %LEFT,RIGHT, or BOTH
        tmr@timer;
    end
    
    properties
        x@double=NaN; % Should have default values, otherwise behavior checking can fail.
        y@double=NaN;
        z@double=NaN;
        pupilSize@double;
        valid@logical = true;  % valid=false signals a temporary absence of data (due to a blink for instance)
    end
    
    methods
        function o = eyetracker(c)
            o = o@neurostim.plugin(c,'eye'); % Always eye such that it can be accessed through cic.eye
            
            o.addProperty('eyeClockTime',[]);
            o.addProperty('hardwareModel','');
            o.addProperty('softwareVersion','');
            o.addProperty('sampleRate',1000,'validate',@isnumeric);
            o.addProperty('backgroundColor',[]);
            o.addProperty('foregroundColor',[]);
            o.addProperty('clbTargetColor',[1,0,0]);
            o.addProperty('clbTargetSize',0.25);
            o.addProperty('continuous',false);
            o.addProperty('tolerance',3); % Used to set default tolerance on behaviors.eyeMovement
            
            o.addKey('w','Toggle Blink');
            o.tmr = timer('name','eyetracker.blink','startDelay',200/1000,'ExecutionMode','singleShot','TimerFcn',{@o.openEye});

            o.addProperty('clbMatrix',[],'sticky',true); % manual calibration matrix (optional)
        end
        
        function afterFrame(o)
            if o.useMouse
                [currentX,currentY,buttons] = o.cic.getMouse;
                if buttons(1) || o.continuous
                    [currentX,currentY] = o.raw2ns(currentX,currentY);
                    
                    o.x=currentX;
                    o.y=currentY;
                end
            end
        end
                      
        function keyboard(o,key)
            switch upper(key)
                case 'W'
                    % Simulate a blink
                    o.valid = false;                    
                    if strcmpi(o.tmr.Running,'Off')
                        start(o.tmr);                    
                    end                   
            end
        end
        function openEye(o,varargin)
            o.valid = true;
            writeToFeed(o,['Blink Ends'])
        end
        
        function [x,y] = raw2ns(o,x,y,cm)
          if nargin < 4
            cm = o.clbMatrix;
          end
          
          if isempty(cm)
            return % pass through
          end
          
          xy = [x,y,ones(size(x))]*cm;
          
          x = xy(:,1);
          y = xy(:,2);
        end
        
        function [x,y] = ns2raw(o,x,y,cm)
          if nargin < 4
            cm = o.clbMatrix;
          end
          
          if isempty(cm)
            return % pass through
          end
                    
          xy = [x,y,ones(size(x))]*inv(cm);
          
          x = xy(:,1);
          y = xy(:,2);
        end
        
    end
    
end
