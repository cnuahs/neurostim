classdef mcc < neurostim.plugin
    % Wrapper for the Psychtoolbox DAQ
    % Before using this, run the DaqTest script that is part of PTB to test
    % that your Measurement Computing hardware is working and accessible.
    %
    % In our setup (Windows 10) I cannot get DaqTest to pass, and yet the
    % minimal use of the MCC that we need (Digital output) works fine after
    % installing the mccdaq and running instacal at least once.
    % 
    % AM: I had to configure the ports as "output" for digitalOut() to
    % work, e.g.
    %       err=DaqDConfigPort(c.mcc.daq,0,0); % port A as output
    %
    % Recording Analog data:
    %  Specify an aInOptions struct to specify which analog channels should
    %  be read from the MCC device. This struct is the same as the one
    %  discussed in DaqAInScan. For instance:     
    %   options.channel = [0 ];    % Reord channel 0-1 in differential mode
    %   options.range   = [0];     % 20 V range. 
    %   options.f = 1000;          % 1 Khz sampling rate
    %   options.count = Inf;       % Keep sampling until buffer full
    %   options.trigger = 0;        % 1 means wait for trigger input (to
    %                                   synchronize with some other event)
    %    c.mcc.aInOptions = options; % Assing to mcc plugin in cic.
    %   c.mcc.aInTimeOut = 1; % Wait at most 1 s to collect all data after
    %   the end of a trial.
    % 
    % Data will be transferred from the device after evry trial (to avoid buffer 
    % overruns on the device) and storedin the mcc.aInData property. 
    % The time of the first sample is stored in mcc.aInTime. Concatenating 
    % the elements in  mcc.aInData should result in a continuous data stream.
    % BK November 2018
    
    properties (Constant)
        ANALOG=0;
        DIGITAL=1;
    end
    properties
        devices;
        daq;
        mapList;
        timer;        
    end
    
    
    properties (Dependent)
        product@char;
        status@struct;
        aIn@logical; 
    end
    
    methods
        function v= get.product(o)
            v = o.devices(o.daq).product;
        end
        
        function v= get.status(o)
            v = DaqGetStatus(o.daq);
        end
        function v = get.aIn(o)
            v  = ~isempty(o.aInOptions);
        end 
    end
    methods
        function reset(o)
            DaqReset(o.daq);
        end 
            
        function o =mcc(c)
            o  = o@neurostim.plugin(c,'mcc');
            
            o.addProperty('aInOptions',[]);
            o.addProperty('aInData',[]);
            o.addProperty('aInStartTime',[]);
            o.addProperty('aInTimeOut',1); % Timeout for Analaog In in seconds.
            
            
            
            % Check what is there.
            o.devices = PsychHID('Devices');
            
            %Find the main MCC Interface.
            o.daq  = find(arrayfun(@(device) strcmpi(device.product,'Interface 0') & strcmpi(device.manufacturer,'mcc'), o.devices));    %DaqDeviceIndex
            
            if isempty(o.daq)
               error('MCC plugin added but no device could be found.'); 
            end
            
            err=DaqDConfigPort(o.daq,0,1); % configure digital port A for input
            err=DaqDConfigPort(o.daq,1,0); % configure digital port B for output
            
            o.mapList.type = [];
            o.mapList.channel =[];
            o.mapList.prop = {};
            o.mapList.when = [];
            
            
        end
        
        function beforeExperiment(o)
            if o.aIn               
                % Setup scanning of analog input                
                DaqAInScanBegin(o.daq,o.aInOptions); % Not storing parms return to make sure data and parms always match                               
            end
        end
        
        
        function afterExperiment(o)
             if o.aIn                          
                DaqAInScanEnd(o.daq,o.aInOptions);                
             end
        end
           
        function map(o,type,channel,prop, when)
            % Map a channel to a named dynamic property.
            % INPUT
            %   type = 'ANALOG' or 'DIGITAL'
            %   channel = channel number
            %   prop   = The property to map the channel to.
            %   when = When should the value be updated. 'AFTERFRAME','AFTERTRIAL'
            %
            %
            
            % Add the property
            addprop(o,prop);
            o.mapList.type      = cat(2,o.mapList.type,o.(upper(type)));
            o.mapList.channel   = cat(2,o.mapList.channel,channel);
            o.mapList.prop      = cat(2,o.mapList.prop,prop);
            o.mapList.when      = cat(2,o.mapList.when,upper(when));

        end
        
        
        function digitalOut(o,channel,value,varargin)
            % digitalOut(o,channel,value [,duration])
            % Output the value to the digital channel
            % o.digitalOut(0,unit8(2)) will write '2' to port A
            % o.digitalOut(3,false) will set bit #3 to false.
            if isa(value,'uint8') && ismember(channel ,[0 1])
                % Writing a full byte to port A (channel 0) or  B (1)
                DaqDOut(o.daq,channel,value);
            elseif islogical(value)
                % Set a single bit
                % First get the current values of both Ports A & B;
                current = DaqDIn(o.daq);
                port = (channel>8)+1; %Determine which port the bit number belongs to.
                current = current(port); %Retrieve current value of the port 
                newValue = bitset(current,mod(channel,8),value); 
                DaqDOut(o.daq,port-1,newValue);
                
                if size(varargin) == 1 
                    duration = varargin{1};
                    % timer function may override other functions when time is met
                    % and could cause problems for time-critical tasks
                    o.timer = timer('StartDelay',duration/1000,'TimerFcn',@(~,~) outputToggle(o,channel,current)); %#ok<CPROPLC>
                    start(o.timer);
                end
            else
                error('Huh?')
            end
        end
        
        % Read the digital channel now
        function v= digitalIn(o,channel)
            % data(1) is the 8-bit value read from port A.
            % data(2) is the 8-bit value read from port B.
            data = DaqDIn(o.daq);
            % Extract the bit of the channel
            if channel<9
                v = bitget(data(1),channel);
            else
                v = bitget(data(2),channel-8);
            end
        end
    end
    
    methods (Access=public)
        function outputToggle(o,channel,value)
            % outputToggle(o,channel,value)
            % togges the output back to its previous value once time has
            % been reached
            port = (channel>8)+1;
            DaqDOut(o.daq,port-1,value);
        end
    end
    
    methods
        % Read the specified analog channel now
        function v= analogIn(o,channel)
            % range scales differential recordings. Not using for
            % now.
            range = 0;
            v  = DaqAIn(o.daq,channel,range);
        end
        
        function afterTrial(o)
            ix = any(strcmp(o.mapList.when,'AFTERTRIAL'));
            if ix
                read(o,ix);
            end
                        
            if o.aIn
                o.aInOptions.ReleaseTime = GetSecs + o.aInTimeOut; 
                [parms,o.aInData]  = DaqAInScanContinue(o.daq,o.aInOptions,true);
                o.aInStartTime = parms.times(1); % Time of the first report.
            end
            
        end
        
        function afterFrame(o)
            ix = any(strcmp(o.mapList.when,'AFTERFRAME'));
            if ix
                read(o,ix);
            end
        end
        
    end
    
    methods (Access = protected)
        
        % Read the Analog or Digital values and store them in a property.
        % Called by afterFrame and afterTrial after setting up a map()
        function ok = read(o,ix)
            ok = true;
            for i=ix
                if o.mapList.type(i) == o.ANALOG
                    v = analogIn(o,o.mapList.channel(i));
                elseif o.mapList.type(i) == o.DIGITAL
                    v = digitalIn(o,o.mapList.channel(i));
                else
                    error('Huh?')
                end
                % Set the value
                o.(o.mapList.prop{i}) = v;
            end
        end
        
        
    end
    
end