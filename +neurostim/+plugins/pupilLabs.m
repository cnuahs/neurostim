classdef pupilLabs < neurostim.plugin
    % Plugin to interact with the Pupil Labs eyetracker.
    %
    % Real-time API docs: https://pupil-labs.github.io/realtime-network-api/
    %
    % Note: this version does *not* use the Pupil Labs Matlab wrapper around
    %       their real-time API (i.e., https://github.com/pupil-labs/realtime-matlab-experiment/tree/main).
    %       Event latency when using that wrapper was ~1.3s!
    %
    %       Here we hit the API endpoints directly via urlread2()...
    %       hopefully this is better?
    %
    % NicPrice, 230623
    % 
    % 2023-09-30 - Shaun L. Cloherty <s.cloherty@ieee.org>
    %  - switch to urlread2()
        
    methods
        function o = pupilLabs(c,varargin) % c is the neurostim cic
            % check whether urlread2() is on the search path
            url = 'https://mathworks.com/matlabcentral/fileexchange/35693-urlread2';
            assert(exist('urlread2','file') == 2, ...
              'Cannot find urlread2(). Please add it to your path:\n%s',url);

            % parse arguments
            p = inputParser;
            p.KeepUnmatched = true;
            p.addOptional('name','pupilLabs',@ischar);
            
            p.addParameter('hostAddr','49.127.55.24:8080',@ischar);

            p.addParameter('startMsg','',@(x) ischar(x) || iscell(x));
            p.addParameter('stopMsg','',@(x) ischar(x) || iscell(x));

            p.parse(varargin{:});
            args = p.Results;
            %

            % call parent class constructor
            o = o@neurostim.plugin(c,args.name);

            % add properties (these are logged!):
            o.addProperty('hostAddr',args.hostAddr,'validate',@ischar);

            o.addProperty('startMsg',args.startMsg,'validate',@(x) ischar(x) || iscell(x));
            o.addProperty('stopMsg',args.stopMsg,'validate',@(x) ischar(x) || iscell(x));
        end
        
        function beforeExperiment(o)
            if isempty(o.startMsg)
                % by default, we match the messages logged by the eyelink plugin
                o.startMsg = { ...
                  sprintf('RECORDED BY %s',o.cic.experiment), ... % <-- o.cic.experiment is only set at run time
                  sprintf('NEUROSTIM FILE %s',o.cic.fullFile)};
            end
                        
            startRecording(o);
            
            sendMessage(o,o.startMsg);
        end
               
        function afterExperiment(o)
            if ~isempty(o.stopMsg)
                sendMessage(o,o.stopMsg);
            end
            
            stopRecording(o);  
        end


        function beforeTrial(o)

            % match the messages logged by the eyelink plugin
            msg = {sprintf('TR:%i',o.cic.trial);
                   sprintf('TRIALID %d-%d',o.cic.condition,o.cic.trial)};
            
            sendMessage(o,msg);
        end

        function sendMessage(o,msg)
            % sends a message to the remote host (recorded in the pupil labs events.csv file)
            if ~iscell(msg)
                msg = {msg};
            end

            for ii = 1:numel(msg)
                o.post('event',struct('name',msg{ii}));
            end
        end
    
    end

    methods (Access = protected)
        function startRecording(o)
            % start recording

            [~,status] = o.post('recording:start',[]);

%             o.connectionStatus = status.status;
        end

        function stopRecording(o,varargin)
            % stop recording (and save?)
            %
            % use o.stopRecording(false) to stop without saving

            endpoint = 'recording:stop_and_save'; % save by default
            if (nargin > 1) & ~varargin{1}
              endpoint = 'recording:cancel';
            end

            [~,status] = o.post(endpoint,[]);

%             o.connectionStatus = status.status;
        end

        function [response,status] = post(o,endpoint,payload)
            % issue http POST request to the remote host endpoint
            %
            %   [response,status] = o.post(endpoint,payload)

            if ~iscell(endpoint)
              endpoint = {endpoint};
            end

            url = strjoin({o.hostAddr,'api',endpoint{:}},'/');

            json = jsonencode(payload);

            header = struct('name','Content-Type','value','application/json');
            [response,status] = urlread2(url,'POST',json,header);

            assert(status.status.value == 200,'POST request for %s returned %i:%s.', ...
              url,status.status.value,status.status.msg);

            response = jsondecode(response);
        end

        function [response,status] = get(o,endpoint)
            % issue http GET request to the remote host endpoint
            %
            %   [response,status] = o.get(endpoint)

            if ~iscell(endpoint)
              endpoint = {endpoint};
            end

            url = strjoin({o.hostAddr,'api',endpoint{:}},'/');

            [response,status] = urlread2(url,'GET');

            assert(status.status.value == 200,'GET request for %s returned %i:%s.', ...
              url,status.status.value,status.status.msg);

            response = jsondecode(response);
        end
    end % protected methods
end