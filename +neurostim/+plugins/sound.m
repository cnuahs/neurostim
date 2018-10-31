classdef sound < neurostim.plugin
    % Generic sound plugin for PTB. Add if using sound.
    properties (Access=protected)
        paHandle
        device=-1; % -1 does autodetect of a device. 
        % If this fails, specify a device from PsychPortAudio('GetDevices')
    end
    
    
    methods (Access=public)
        function o=sound(c)
            o=o@neurostim.plugin(c,'sound');
            o.device  =c.hardware.sound.device; % Get the default device from CIC.
            % Sound initialization
            InitializePsychSound(1);
           
        end
        
        function beforeExperiment(o)
            
        try 
            o.paHandle = PsychPortAudio('Open',o.device);
        catch me
            lasterr
            disp('Try to specify the .device from PsychPortAudio(''GetDevices'')')
            rethrow(me)
        end
            %Play a dummy sound (first sound wasn't playing)
            bufferHandle = PsychPortAudio('CreateBuffer',o.paHandle,[0; 0]);
            PsychPortAudio('FillBuffer', o.paHandle,bufferHandle);
            PsychPortAudio('Start',o.paHandle);
        end
        
        function afterExperiment(o)
            PsychPortAudio('Close', o.paHandle);
        end
        
        function bufferHandle = createBuffer(o,waveform)
            
            %If a vector (mono), force to be a row
            if isvector(waveform)
                waveform = waveform(:)';
                waveform = [waveform; waveform];
            end
            
            %If neither mono, nor stereo
            if ~any(size(waveform)==2)
                error('Waveform data must be either a vector (mono) or two-column matrix (stereo)');
            end
            
            %Ensure 2 x N matrix
            if size(waveform,2)==2
                waveform = waveform';
            end
            
            bufferHandle = PsychPortAudio('CreateBuffer',o.paHandle,waveform);
        end
        
        function play(o,bufferHandle)
            PsychPortAudio('FillBuffer', o.paHandle,bufferHandle);
            
            % play sound immediately.
            PsychPortAudio('Start',o.paHandle);
        end
        
        
        function delete(o) %#ok<INUSD>
            clear PsychPortAudio;
        end
    end
end