classdef oephys < neurostim.plugins.ePhys
  % Plugin for interacting with the Open Ephys GUI v0.6.x via the REST API
  %
  % Version 0.6 of the open ephys GUI introduced a new REST API for remote
  % control and streaming. This plugin provides a wrapper for the REST API.
  % It is not compatible with versions of the open ephys GUI before v0.6.
  %
  % Note: if you are using a version of the open ephys GUI prior to 0.6.0-rc1
  %       you should look at plugins.openEphys.
  %
  % Example usage:
  %
  %   o = neurostim.plugins.oephys(c,'oephys');
  %   o.hostAddr = 'http://localhost:37497';
  %
  % Optional parameters may be specified via name-value pairs:
  %
  %   recDir - directory used for saving data on the open ephys computer (default: '')
  %   prependText - prefix for directory names in recDir (default: '')
  %   appendText - suffix for directory names in recDir (default: '')
  %   format - recording format (default: 'BINARY')
  %
  % See also: neurostim.plugins.ePhys
  
  % 2022-06-08 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  properties (Constant, Access = private)
    formats = {'BINARY'};
  end

  methods (Access = public)

    function o = oephys(c,name,varargin)

      % check whether urlread2() is on the search path
      url = 'https://mathworks.com/matlabcentral/fileexchange/35693-urlread2';
      assert(exist('urlread2','file') == 2, ...
        'Cannot find urlread2(). Please add it to your path:\n%s',url);
      
      % call parent class constructor
      o = o@neurostim.plugins.ePhys(c,name,varargin{:});

      % parse arguments
      p = inputParser;
      p.KeepUnmatched = true;
      p.addParameter('recDir','',@ischar); % save path on the open ephys computer
      p.addParameter('prependText','',@ischar);
      p.addParameter('appendText','',@ischar);

      p.addParameter('format','BINARY',@(x) ischar(x) && ismember(x,o.formats));

      p.parse(varargin{:});
      
      args = p.Results;
      %

      % add class properties
      o.addProperty('recDir',args.recDir,'validate',@ischar);
      o.addProperty('prependText',args.prependText,'validate',@ischar);
      o.addProperty('appendText',args.appendText,'validate',@ischar);

      o.addProperty('format',args.format,'validate',@(x) ischar(x) && ismember(x,o.formats));
    end
        
    function sendMessage(o,msg)
      % send a message to open ephys
      if ~iscell(msg)
        msg = {msg};
      end

      for ii = 1:numel(msg)
        o.put('message',struct('text',msg{ii}));
      end
    end

  end % public methods
    
  methods (Access = protected)
    function startRecording(o)
      % Start RECORDing

      % configure "global" recording information
      config = struct('parent_directory',o.recDir,'prepend_text',o.prependText,'appendText',o.appendText,'format',o.format);
      [~,status] = o.put('recording',config);

      % FIXME: 2022-06-09
      %        do we need to specify these for each Record Node in the
      %        signal chain? In testing, the global settings were not
      %        inherited as the documentation claims they are.
      %
      %        Update: parent_directory is ignored if the directory does
      %        not exist on the open ephys computer... 
      %
      %        Update: in fact, these settings don't seem to be honoured at
      %        all... they appear in the recording config bar of the GUI
      %        (sort of), but they get trashed when recording starts. It
      %        doesn't seem to matter what mode the GUI is in (e.g., IDLE or
      %        ACQUIRE), they never have any effect when recording starts. 

      [~,status] = o.put('status',struct('mode','RECORD'));
      o.connectionStatus = status.status; % <-- FIXME: is this used/useful for anything?

      % TODO: 2022-06-09
      %       Can we get open ephys clock time via the REST API? If so,
      %       save it in o.clockTime for offline alignment...
    end

    function stopRecording(o)
      % Stop RECORDing

      [~,status] = o.put('status',struct('mode','IDLE'));

      o.connectionStatus = status.status;
    end

    function [response,status] = put(o,endpoint,payload)
      % issue http PUT request to the GUI
      url = strjoin({o.hostAddr,'api',endpoint},'/');

      json = jsonencode(payload);

      header = struct('name','Content-Type','value','application/json');
      [response,status] = urlread2(url,'PUT',json,header);

      assert(status.status.value == 200,'PUT request for %s returned %i:%s.', ...
        url,status.status.value,status.status.msg);

      response = jsondecode(response);
    end

    function [response,status] = get(o,endpoint)
      % issue http GET request to the GUI
      url = strjoin({o.hostAddr,'api',endpoint},'/');

      [response,status] = urlread2(url,'GET');

      assert(status.status.value == 200,'GET request for %s returned %i:%s.', ...
        url,status.status.value,status.status.msg);

      response = jsondecode(response);
    end

  end % protected methods

end % classdef
