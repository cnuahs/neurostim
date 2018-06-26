classdef noiserasterradialgrid < neurostim.stimuli.noiserasterclut
    % Polar grid of noise
    % Type >> help noiserastergrid for most info about this stimulus
    %
    % See also noiseRasterRadialGridDemo, noiseRasterGridDemo, neurostim.stimuli.noiserasterclut, neurostim.stimuli.noiserasterradialgrid
    properties (Dependent)
        size
    end
    
    properties
        
    end
    
    methods
        function sz = get.size(o)
            %Size of the idImage matrix. Done this way so it can be accessed before runtime.
            sz = round(2*(o.cic.physical2Pixel(o.outerRad,0)-o.cic.physical2Pixel(0,0)))+1;
            sz = [sz sz];
        end
    end
    
    methods (Access = public)
        function o = noiserasterradialgrid(c,name)
            
            o = o@neurostim.stimuli.noiserasterclut(c,name);
            
            %User-definable
            o.addProperty('nWedges',40,'validate',@(x) isnumeric(x));
            o.addProperty('nRadii',8,'validate',@(x) isnumeric(x));
            o.addProperty('innerRad',5,'validate',@(x) isnumeric(x) & x >= 0);
            o.addProperty('outerRad',10,'validate',@(x) isnumeric(x) & x >= 0);
        end
        
        function beforeTrial(o)
            
            %Use the full pixel resolution available.
            nPixels = o.size;
            x=linspace(-1,1,nPixels(1));
            [xGrid,yGrid]=meshgrid(x,x);
            
            %Calculations here are in normalised coordinates
            inner = o.innerRad./o.outerRad;
            outer = 1;
            o.width = o.outerRad*2;
            o.height = o.outerRad*2;
            
            %Get the polar angle and radius of each texel
            [pixTh,pixR]=cart2pol(xGrid,yGrid);
            
            %Assign an integer ID to wedges
            wedgeBinWidth = 2*pi/o.nWedges;
%             radBins = linspace(inner,outer,o.nRadii+1);
            
            %%
            % scale with eccentricity c.f. Slotnick et al., Clin. Neurophys. 112(7):1349-1356, 2001.
            %
            %   (1/M) = (E - E2)/A
            %
            % where M = cortical magnification (mm/deg.)
            %       E = eccentricity (deg.)
            %       E2 = horizontal intercept (eccentricity corresponding
            %            to half the area (?) at the fovea?)
            %       A = slope (change in magnification with eccentricity)
            E2 = 0.5; % deg.
            A = 21.7; % mm
            
            invM = ([o.innerRad, o.outerRad] - E2)./A; % note: innerRad and outerRad must be in deg.!
            invM = linspace(invM(1),invM(2),o.nRadii+1);
            invM = invM(1:end-1);   
            
            dE = (outer - inner)./sum(invM); % note: normalized!
            
            radBins = cumsum([inner, invM*dE]);
            %%
            
            [~,~,thSub]=histcounts(pixTh,'binWidth',wedgeBinWidth);
            [~,~,radSub]=histcounts(pixR,radBins);
            
            thSub(thSub==0)=NaN;
            radSub(radSub==0)=NaN;
            im = sub2ind([o.nWedges,o.nRadii],thSub,radSub);
            im(isnan(im))=o.BACKGROUND;
            
            %Set up the CLUT and random variable callback functions
            initialise(o,im);
        end
        
        function mask = annulusGaussianMask(o,sigma,refAngle,arcAng)

            %Calculate points along the arc running down the middle of the annulus
            pOnCirc = pointsOnCircle(o,o.cic.screen.xpixels*4,refAngle,arcAng);

            %Get the X and Y coordinates of every pixel
            sz = o.size(1);
            [imX,imY]= pixXY(o);

            %Calculate the distance to the nearest point on the arc for every pixel
                %Note, this is solving the same problem that is solvved
                %differently in hexNoise.m. That solution was slower here,
                %but faster there. Not sure why. The two approaches
                %might scale differently with num points or grid size.
            tr = delaunayn(pOnCirc);
            nearestID = dsearchn(pOnCirc,tr,[imX(:),imY(:)]);
            dists = hypot(imX(:)-pOnCirc(nearestID,1),imY(:)-pOnCirc(nearestID,2));
            
            
            %Make the mask as a gaussian function of that distance
            scaleFilt = @(filt) (filt-min(filt(:)))/range(filt(:));
            mask = scaleFilt(normpdf(dists,0,sigma));
            mask = reshape(mask,sz,sz);
        end
        
        function pOnCirc = pointsOnCircle(o,nPoints,refAngle,arcAng)
            %Calculate points along the arc running down the middle of the annulus
            if nargin < 2
                refAngle = 0;
                arcAng = 2*pi;
            end
            
            theta = linspace(refAngle-arcAng/2,refAngle+arcAng/2,nPoints);
            r = mean([o.outerRad,o.innerRad])./o.outerRad*o.size(1)/2;
            [cx,cy] = pol2cart(theta,r);
            pOnCirc = [cx(:),cy(:)];
        end

        function [x,y] = pixXY(o)
            %X and Y coordinates of every pixel
            sz = o.size(1);
            pixCoords = linspace(-sz/2,sz/2,sz);
            [x,y]=meshgrid(pixCoords,pixCoords);
        end
    end % public methods
end % classdef
