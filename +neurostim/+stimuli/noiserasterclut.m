classdef (Abstract) noiserasterclut < neurostim.stimuli.gllutimage
    % Abstract stimulus class to present random noise rasters (e.g. for white-noise analysis).
    % Luminance noise values are drawn from Matlab's built-in probaility distributions or returned by a user-defined function.
    % Argument specification is based on that of the jitter() plugin (though custom function specification is slightly different... TODO: unify this and jitter())
    %
    % The imaging approach is similar to a CLUT, where the image that is
    % drawn is represented as a 2D matrix of indices into a vector LUT of random
    % variables for luminance. The LUT values are updated (sampled) from frame to frame.
    % This allows an arbitrary mapping of a small number of random variables onto
    % a potentially larger image of texels/pixels. The last entry in the LUT is the background luminance.
    % This allows you to make arbitrary noise stimuli, such as Cartesian grids, polar grids,
    % polygons, non-contiguous patches, etc.
    %
    % By default, luminance values are NOT logged because of potential memory load.
    % However, the state of the RNG on each frame is logged, allowing offline reconstruction.
    % There is some over-head there. Logging can also be switched off entirely.
    %
    %
    %   Settable properties:
    %
    %   parms           -   parameters for the N-parameter pdf, as an N-length cell array (see RANDOM)
    %   distribution    -   the name of a built-in pdf [default = 'uniform'],
    %                       or a handle to a custom function, f(o), which takes the plugin as a
    %                       the lone argument, and returns a vector of luminance values (size = [1, o.nRandVars]) for each of the
    %                       random variables (that are mapped internally to pixels in the ID image)
    %   bounds          -   2-element vector specifying lower and upper bounds to truncate the distribution (default = [], i.e., unbounded). Bounds cannot be Inf.
    %   width           -   width on screen (screen units)
    %   height           -   height on screen (screen units)
    %   logType         -   What should be logged? All luminance values, RNG state (for offline reconstruction), or nothing?
    %   alphaMask       -   Matrix of alpha values to apply a transparency mask. Size = o.size
    %   signal          -   [not yet supported - use alphaMask for now] A matrix of values that is added to the noise (e.g. for detection task)
    %
    %  TODO:
    %       (1) Allow a signal to be embedded (this has to happen in the shader used in gllutimage.m)
    %       (2) Add co-variance matrix, sz = [o.nRandVars,o.nRandVars], for presenting correlated noise.
    %       (3) Provide a reconstruction tool for offline analysis
    %       (4) This approach to rng is inefficient: it would be better to have a separate RNG stream for this stimulus. CIC would need to act as RNG server?
    
    properties (Access = private)
        callback@function_handle;   %Handle of function for returning luminance values on each frame
        rng;        %Pointer to the global RNG stream
        nRandVars;
        initialised = false;
        frameInterval_f;
    end
    
    methods (Access = public)
        function o = noiserasterclut(c,name)
            
            o = o@neurostim.stimuli.gllutimage(c,name);
            
            %User-definable
            o.addProperty('parms',{0 255},'validate',@(x) iscell(x));
            o.addProperty('distribution','uniform','validate',@(x) isa(x,'function_handle') | any(strcmpi(x,makedist))); %Check against the list of known distributions
            o.addProperty('bounds',[], 'validate',@(x) isempty(x) || (numel(x)==2 && ~any(isinf(x)) && diff(x) > 0));
            o.addProperty('logType','RNGSTATE', 'validate',@(x) any(strcmpi(x,{'RNGSTATE','VALUES','NONE'})));
            o.addProperty('signal',[],'validate',@isnumeric); %Luminance values to add to noise matrix.
            o.addProperty('frameInterval',o.cic.frames2ms(3));        %How long should each frame be shown for? default = 3 frames.
            
            %Internal variables for clut and mapping
            o.addProperty('randVarXY',[]);
            
            %Internal use for logging of luminance values
            o.addProperty('probObj',[]);
            o.addProperty('rngState',[]);
            o.addProperty('rngAlgorithm',[]);
            o.addProperty('clutVals',[]); %For logging luminance values, if requested
            
            o.writeToFeed('Warning: this is a new stimulus and has not been tested.');                   
        end
        
        function beforeFrame(o)
            %Usually to be overloaded in child class
            o.drawIt();
        end
        
        function drawIt(o)

            %Update the raster luminance values
            curFr = o.frame;
            frInt = o.frameInterval_f;
            if (isinf(frInt) && curFr==0) || (~isinf(frInt)&&~mod(curFr,frInt))
                o.update();
            end
            
            o.draw();
        end
        
        function afterTrial(o)
            o.initialised = false;
        end
    end % public methods
    
    
    methods (Access = protected)
        
        function initialise(o,im)
            
            %The image (im) is specified as a bitmap of arbitrary IDs for random variables.
            %IDs must be integers from 1 to N, or 0 to use background luminance.
            
            %Make sure the requested duration is a multiple of the display frame interval            
            tol = 0.05; %5% mismatch between requested frame duration and what is possible
            frInt = o.cic.ms2frames(o.frameInterval,false);
            if ~isinf(frInt) && abs(frInt-round(frInt)) > tol
                error('Requested noise frameInterval is not a multiple of the display frame interval');
            end
            o.frameInterval_f = round(frInt);

            %Set up a callback function, used to population the noise clut with luminance values
            o.setupLumCallback();
            
            %Allow the CLUT parent class to build textures and clut
            o.setImage(im);
            o.nRandVars = o.nClutColors;
            o.clut = zeros(3,o.nRandVars);
            o.prep();
            
            o.initialised = true;
        end
        
        function setupLumCallback(o)
            
            %Set up a callback function, used to population the noise clut with luminance values            
            dist = o.distribution;
            
            if isa(dist,'function_handle')
                %User-defined function. Function must receive the noiseraster plugin as its sole argument and return
                %luminance values for each of the random variables.
                o.callback = dist;
                
            elseif ischar(dist) && any(strcmpi(dist,{'1ofN','oneofN'}))
                %Picking a value from a pre-defined list
                o.callback = @oneOfN;
                
            elseif ischar(dist) && any(strcmpi(dist,makedist))
                %Using Matlab's built-in probability distributions
                o.callback = @(o) random(o.probObj,1,o.nRandVars);
                
                %Create a probability distribution object
                pd = makedist(o.distribution,o.parms{:});
                
                %Truncate the distribution, if requested
                if ~isempty(o.bounds)
                    pd = truncate(pd,o.bounds(1),o.bounds(2));
                end
                
                %Store object
                o.probObj = pd;
            elseif ischar(dist)
                error(horzcat('Unknown distribution name ', dist));
            end
            
            %Store the RNG state.
            s = RandStream.getGlobalStream;
            o.rng = s;
        end
        
        function o = update(o)
            
            %Temporarily set the rng to not use full precision, to favour speed
             s = o.rng;
%             s.FullPrecision = false;
            
            %Log the state of the RNG, if requested
            if strcmpi(o.logType,'RNGSTATE')
                %Allows re-construction offline. see https://au.mathworks.com/help/matlab/ref/randstream.html
                o.rngState = s.State;
                o.rngAlgorithm = s.Type;
            end
            
            %Update the values in the clut (excluding the last entry, which is the background luminance)
            o.clut = o.callback(o);
            
            %Allow parent to update its mapping texture (there should really be a setClut() in parent
            updateCLUT(o);
            
            %Log the clut luminance values, if requested (use only for small memory loads)
            if strcmpi(o.logType,'VALUES')
                o.clutVals = o.clut;
            end
            
            
            %Add in the signal
%             sig = o.signal;
%             if ~isempty(sig)
%                 o.lumImage = o.lumImage + sig;
%             end
            
            %Restore precision
%             o.rng.FullPrecision = true;
        end
          
        function setIDxy(o,xy)
            %Store a single normalised [x,y] coordinate to each random variable (e.g. patch centroid).
            if ~o.initialised
                error('You can only set the coordinates after placing the image with o.initialise(im)');
            end
            
            %Check format
            if ~isequal(size(xy),[o.nRandVars,2])
                error('The XY matrix must be a two-column matrix of x and Y coordinates with the number of rows equal to the number of unique IDs in the image, i.e., [o.nRandVars, 2]');
            end
            if ~all(xy>=0 & xy <=1)
                error('The XY mapping coordinates for IDs must be in normalised units (0 to 1)');
            end
            
            %All good.
            o.randVarXY = xy;
        end
        
%         function [x,y] = id2xy(o,id)
%             
%         end
    end % protected methods
    
    methods (Access = private)
        function vals = oneOfN(o)
            % Convenience function to pick from a set of values with equal probability.
            vals = randsample(cell2mat(o.parms),o.nRandVars,true);
        end
    end
    
    methods (Static)
        
    end
end % classdef
