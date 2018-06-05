classdef noiserastergrid < neurostim.stimuli.noiserasterclut
    % Stimulus class to present random noise rasters (e.g. for white-noise analysis).
    % Luminance noise values are drawn from built-in probaility distributions or returned by a user-defined function.
    % Argument specification is based on that of the jitter() plugin (though custom function specification is slightly different... TODO: unify this and jitter())
    % Each pixel is an independent random variable.
    %
    % By default, luminance values are NOT logged because of potential memory load.
    % However, the state of the RNG on each frame is logged, allowing offline reconstruction.
    % There is some over-head there. Logging can also be switched off entirely.
    % This approach to rng is inefficient: it would be better to have a
    % separate RNG stream for this stimulus. CIC would need to act as RNG server.
    % 
    %
    %   Settable properties:
    %
    %   size            - dimensionality of the raster matrix, as used in rand(),ones() etc.
    %   parms           - parameters for the N-parameter pdf, as an N-length cell array (see RANDOM)
    %   distribution    - the name of a built-in pdf [default = 'uniform'], or a handle to a custom function, f(o), which takes the plugin as a the lone argument)
    %   bounds          - 2-element vector specifying lower and upper bounds to truncate the distribution (default = [], i.e., unbounded). Bounds cannot be Inf.
    %   width           - width on screen (screen units)
    %   height          - height on screen (screen units)
    %   logType         - What should be logged? All luminance values, RNG state (for offline reconstruction), or nothing?
    %
    % See also neurostim.stimuli.noiserasterclut
    
    
    methods (Access = public)
        function o = noiserastergrid(c,name)
            
            o = o@neurostim.stimuli.noiserasterclut(c,name);
            
            %User-definable
            o.addProperty('size',[10 20],'validate',@(x) isnumeric(x) & ndims(x)==2); %#ok<ISMAT>
        end 
        
        function beforeTrial(o)
            
            %The image is specified as a bitmap in which each pixel value is
            %the ID of the random (luminance) variable to be used.
            imInds = 1:prod(o.size);
            im = reshape(imInds,o.size(1),o.size(2));
            
            %Set up the CLUT and random variable callback functions
            initialise(o,im);
        end
    end % public methods
end % classdef
