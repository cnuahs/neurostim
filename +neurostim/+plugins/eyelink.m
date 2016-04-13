% Wrapper around the Eyelink Toolbox.
classdef eyelink < neurostim.plugins.eyetracker
    % New properties:
    %   keepExperimentSetup - 1 or 0. 
    %                         1: keep Eyelink functions using the same colour
    %                               setup as the experiment (i.e. background, foreground).
    %                         0: get Eyelink colour setup from parameters
    %                               below.
    %
    %   getSamples - if true, stores eye position/sample validity on every frame.
    %   getEvents - if true, stores eye event data in eyeEvts.
    %   eyeEvts - saves eyelink data in its original structure format.
    % 
    %   doTrackerSetup - true or false, setup before experiment.
    %   doDriftCorrect - true or false, setup before experiment.

    
    properties
        el@struct;
        eye;
        valid;
        commands = {'link_sample_data = LEFT,RIGHT,GAZE,GAZERES,AREA,VELOCITY'};
        edfFile@char = 'test.edf';
        getSamples@logical=true;
        getEvents@logical=false;
    end
    
    properties
        doTrackerSetup@logical  = false;  % Do it before the next trial
        doDriftCorrect@logical  = false;  % Do it before the next trial
    end

    properties (Dependent)
        isRecording@logical;
        isConnected@double;
    end
    
    methods
        function v = get.isRecording(~)
            v =Eyelink('CheckRecording');%returns 0 if connected.
            v = v==0; 
        end
        
        function v = get.isConnected(~)
            % Can return el.dummyconnected too
            v = Eyelink('isconnected');
        end
    end
    
    
    methods
        function o = eyelink(c)
            Eyelink; % Check that the EyelinkToolBox is available.
            %clear Eyelink;
            o = o@neurostim.plugins.eyetracker(c);
            o.addKey('F9',@keyboard,'DriftCorrect');
            o.addKey('F8',@keyboard,'EyelinkSetup');
            o.listenToEvent({'BEFOREEXPERIMENT','AFTEREXPERIMENT','BEFORETRIAL','AFTERFRAME'}); %The parent class is also listening to the AFTERFRAME event. Intended?
            o.addProperty('eyeEvts',struct);

        end
        
        function beforeExperiment(o,c,evt)
            
            o.el=EyelinkInitDefaults(c.onscreenWindow);
            
            %Initialise connection to Eyelink. Currently not allowing dummy
            %mode, because dialog box comes up behind PTB screen.
            if ~o.useMouse
                result = Eyelink('Initialize', 'PsychEyelinkDispatchCallback');
            end
            
            if result==-1
                c.error('STOPEXPERIMENT','Eyelink failed to initialize');
                return;
            end
            
            %Tell Eyelink about the pixel coordinates
            rect=Screen(c.onscreenWindow,'Rect');
            Eyelink('Command', 'screen_pixel_coords = %d %d %d %d',rect(1),rect(2),rect(3)-1,rect(4)-1);
            
            % setup sample rate
            if any(o.sampleRate==[250, 500, 1000])
                o.commands{end+1} = ['sample_rate = ' num2str(o.sampleRate)];
            else
               c.error('STOPEXPERIMENT','Requested eyelink sample rate is invalid'); 
            end  
            
            % make sure that we get gaze data from the Eyelink
            for i=1:length(o.commands)
                Eyelink('Command', o.commands{i});
            end
            
            % open file to record data to
            [~,tmpFile] = fileparts(tempname);
            o.edfFile= [tmpFile(end-7:end) '.edf']; %8 character limit
            Eyelink('Openfile', o.edfFile);
            if o.keepExperimentSetup
                restoreExperimentSetup(o);
            else eyelinkSetup(o);
            end
        end
        
        function afterExperiment(o,c,evt)

            Eyelink('StopRecording');
            Eyelink('CloseFile');
            try
%                 writeToFeed(o,'Attempting to receive Eyelink edf file');
%                 status=Eyelink('ReceiveFile',o.edfFile,[c.fullFile '.edf']); %change to OUTPUT dir
%                 writeToFeed(o,'Success.');
            catch
                error('Eyelink file failed to transfer to the NS computer');
            end
          Eyelink('Shutdown');
        end
        
        function beforeTrial(o,c,evt)
            o.trackedEye; %This doesn't currently do anything for Eyelink??
            
            % Do re-calibration if requested
            if o.doTrackerSetup && ~o.useMouse
                if ~o.keepExperimentSetup
                    eyelinkSetup(o);
                end
                EyelinkDoTrackerSetup(o.el); %Need to modify to allow ns to control the background RGB/lum CIE etc.
                o.doTrackerSetup = false;
                restoreExperimentSetup(o);
            end
            if o.doDriftCorrect && ~o.useMouse
                if ~o.keepExperimentSetup
                    eyelinkSetup(o);
                end
                o.el.TERMINATE_KEY = o.el.ESC_KEY;  % quit using ESC
                EyelinkDoDriftCorrection(o.el);
                o.doDriftCorrect = false;
                restoreExperimentSetup(o);
            end
            

            if ~o.isRecording
                Eyelink('StartRecording');
                available = Eyelink('EyeAvailable'); % get eye that's tracked
                if available == o.el.BINOCULAR 
                    o.eye = o.el.LEFT_EYE;
                elseif available == -1
%                     o.eye = available;
%                     o.eye = o.el.LEFT_EYE;
                    o.cic.error('STOPEXPERIMENT','eye not available')
                else
                    o.eye = available;
                end
            end
            
            Eyelink('Command','record_status_message %s%s%s',c.paradigm, '_TRIAL:',num2str(c.trial));
            Eyelink('Message','%s',['TR:' num2str(c.trial)]);   %will this be used to align clocks later?
            o.eyeClockTime = Eyelink('TrackerTime');

        end
        
        function afterFrame(o,c,evt)

            if ~o.isRecording
                c.error('STOPEXPERIMENT','Eyelink is not recording...');
                return;
            end
                       
            if o.getSamples
                % Continuous samples requested
                if Eyelink('NewFloatSampleAvailable') > 0
                    % get the sample in the form of an event structure
                    sample = Eyelink( 'NewestFloatSample');
                    % convert to physical coordinates
                    [o.x,o.y] = c.pixel2Physical(sample.gx(o.eye+1),sample.gy(o.eye+1));    % +1 as accessing MATLAB array
                    o.pupilSize = sample.pa(o.eye+1);
                    o.valid = o.x~=o.el.MISSING_DATA && o.y~=o.el.MISSING_DATA && o.pupilSize >0;
                end %
            end
            if o.getEvents
                % Only events requested
                switch  o.isConnected
                    case o.el.dummyconnected
                        % Use mousecoordinates, save everything as a
                        % endsacc event.
%                         [o.x,o.y] = o.mouseConnection(c);
                        eyeEvts = o.eyeEvts;
                        [eyeEvts.gx,eyeEvts.gy,eyeEvts.type] = deal(x,y,o.el.ENDSACC);
                        o.eyeEvts = eyeEvts;
                    case o.el.connected
                        evtype=Eyelink('getnextdatatype');
                        if any(ismember(evtype,[o.el.ENDSACC, o.el.ENDFIX, o.el.STARTBLINK,...
                                o.el.ENDBLINK,o.el.STARTSACC,o.el.STARTFIX,...
                                o.el.FIXUPDATE, o.el.INPUTEVENT,o.el.MESSAGEEVENT,...
                                o.el.BUTTONEVENT, o.el.STARTPARSE, o.el.ENDPARSE]))
                            o.eyeEvts = Eyelink('GetFloatData', evtype);
                        else               
%                             o.cic.error('STOPEXPERIMENT','Eyelink is not connected');
                        end
                end
                % x and y
                
            end
        end
        
        function keyboard(o,key,~)
            switch upper(key)
                case 'F9'
                    o.doDriftCorrect  =true;
                case 'F8'
                    o.doTrackerSetup  = true;
            end
        end
        
    end
    
    methods (Access=protected)
        % Add an eyelink command that will be executed before the
        % experiment starts. Passing an empty string resets the command
        % list.
        function command(o,string)
            if isempty(string)
                o.commands= {};
            else
                o.commands = cat(2,o.commands,{string});
                if ~isempty(strfind(upper(string),'LINK_SAMPLE_DATA'))
                    o.getSamples = true;
                elseif ~isempty(strfind(upper(string),'LINK_EVENT_DATA'))
                    o.getEvents = true;
                end
            end
        end
        
        function restoreExperimentSetup(o)
            % function restoreExperimentSetup(o)
            % restores the original experiment background/foreground
            % colours.
            o.el.backgroundcolour = o.cic.screen.color.background;
            o.el.foregroundcolour = o.cic.screen.color.text;
            o.el.calibrationtargetcolour = o.el.foregroundcolour;
            
%             for i=1
                PsychEyelinkDispatchCallback(o.el);
                
                EyelinkClearCalDisplay(o.el);
                
%                 %Check the frame rate
%                 for j=1:100
%                     o.cic.tic;
%                     Screen('Flip', o.cic.onscreenWindow,0);
%                     elapsed(i,j) = o.cic.toc;
%                 end
%             end
%             writeToFeed(o,num2str(median(elapsed,2)'));
%             keyboard;
        end
        
        function eyelinkSetup(o)
            % function eyelinkSetup(o)
            % sets up Eyelink functions with background/foreground colours
            % as specified.
            o.el.backgroundcolour = o.backgroundColor;
            o.el.foregroundcolour = o.foregroundColor;
            o.el.calibrationtargetcolour = o.clbTargetColor;
            o.el.calibrationtargetsize = o.clbTargetSize;
            PsychEyelinkDispatchCallback(o.el);

        end
    end
end