function [c] = runGuiSimple(varargin)
% Demo to show the use of the nsGUI 
% The actualy experiment is the same as in adaptiveDemo, only the first few
% lines are changed to allow the nsGui to start this experiment
%
% The demo can use QUEST or a Staircase procedure to estimate the threshold
% for correct detection, separately for +45 and -45 degree oriented gratings.
%
% BK  - Feb 2020.

import neurostim.*
%% nsGUI setup
% To use nsGui, the experiment function must have the prototype
% function c = runExperiment(varargin) 
% and it must contain a call to nsGui.parse with output arguments
% [run,c,settings]
% Often, different variants of the same experiment are coded in the same
% file, with a parameter ('Mode') that selects between them. 
% Here we use the nsGui to select the Quest or Staircase adaptive
% procedured by adding the 'Modes', {'QUEST','STAIRCASE'} arguments
%
% Also, in some runs of this experiment we may want to use eyetracking, but
% in other runs (e.g. when debugging) we want to fake an eyetracker. To
% allow the user to select this, we include specifiy:
% 'Panls',{plugins.eyelink} - this will add the Eyelink gui (Defined by
% plugins.eyelink.guiLayout) to the nsGui at run time. 
%
[run,c,settings] = nsGui.parse(varargin{:},...  % Any parameters that the GUI sends (required)
                                'Panels',{'plugins.eyelink'},...  % List any guis that this experiment needs
                                'Modes',{'QUEST','STAIRCASE'});  % List modes of the experiment
% nsGui will call this function twice, first to get the list of panels and
% modes (in that case run=false), then to actually run the experiment (run =true)
if ~run    
    % This was a call only to collect information; return without running the
    % experiment.
    return; 
end

% This is the end of the nsGui dependent code; in the code below we use the
% variable c (the CIC controller, setup according to the specifications in
% the nsGui) and the settings (a struct with the .mode field that specifies
% whether Quest or Staircase was selected).

%% 
pianola = true; % Set this to true to simulate responses, false to provide your own responses ('a'=left,'l' = right).


% Define a simulated observer with different thresholds for the two
% conditions. This should be visible when you run this demo with pianola=true; one orientation
% should converge on a low contrast, the other on a high contrast.
% Note that this function should return the keyIndex of the correct key (so
% 1 for 'a', 2 for 'l')
%simulatedObserver = '@(grating.contrast<(0.1+0.5*(cic.condition-1)))+1.0';
% Or use this one for an observer with some zero mean gaussian noise on the threshold
simulatedObserver = '@(grating.contrast< (0.05*randn + (0.1+0.5*(cic.condition-1))))+1.0';
%% Setup the controller 
c.trialDuration = Inf;
c.screen.color.background = [ 0.5 0.5 0.5];
c.subjectNr= 0;

%% Add a Gabor;
% We'll simulate an experiment in which
% the grating's location (left or right) is to be detected
% and use this to estimate the contrast threshold
g=stimuli.gabor(c,'grating');
g.color            = [0.5 0.5 0.5];
g.contrast         = 0.25;
g.Y                = 0;

% The simplest adaptive parameter is used to jitter
% parameters across trials. Use the jitter class for this. 
% Becuase the same jitter object can be used for all conditions, we assign it
% to the parameter directly. 
g.X                = plugins.jitter(c,{10,-10},'distribution','1ofN'); % Jitter the location of the grating on each trial: either 10 or -10 
% If you'd want to use a different jitter (maybe drawn from a different
% distribution in different conditions) for each condition, then you specify 
% the jitter as part of the design (see below)
g.sigma            = 3;
g.phaseSpeed       = 0;
g.orientation      = 0;
g.mask             = 'CIRCLE';
g.frequency        = 3;
g.on               =  0;
g.duration         = 500;
  
%% Setup user responses
% Take the user response (Press 'a'  to report detection on the left, press 'l'  for detection on the right)
k = behaviors.keyResponse(c,'choice');
k.from = '@grating.on + grating.duration';
k.maximumRT = 2000;         %Maximum allowable RT is 2000ms
k.keys = {'a' 'l'};                       %Press 'a' for "left" motion, 'l' for "right"
k.correctFun = '@double(grating.X> 0) + 1';   %Function to define what the correct key is in each trial .It returns the index of the correct response (i.e., key 1 ('a' when X<0 and 2 'l' when X>0)
if pianola
    k.simWhat =  simulatedObserver;   % This function will provide a simulated answer
    k.simWhen = '@grating.on + grating.duration+50';  % At this time.
end
c.trialDuration = '@choice.stopTime';       %End the trial as soon as the 2AFC response is made.


%% Setup the conditions in a design object
d=design('orientation');
d.fac1.grating.orientation = [-45 45];  % One factor (orientation)
nrLevels = d.nrLevels;

% We also want to change some parameters
% in an "adaptive" way. You do this by assigning values
% to the .conditions field of the design object .
if strcmpi(settings.mode,'QUEST')
    % To estimate threshold adaptively, the Quest method can be used. We need
    % to define two functions to map the random intensity variable with values between
    % -Inf and Inf that Quest "optimizes" to a meaningful contrast value. We'll
    % assume that the Quest intensity models the log10 of the contrast. i2p and
    % p2i implement that mapping.
    i2p = @(x) (min(10.^x,1)); % Map Quest intensity to contrast values in [0 , 1]
    p2i = @(x) (log10(x));
    % Define a quest procedure with an initial guess, and our confidence in
    % that guess, and tell the Quest procedure which function to evaluate to
    % determine whether the response was correct or not. To setup Quest to use
    % the subject's responses, use the following:
    
    % Note again the .conditions usage that applies the Quest plugin to each level of the first factor.
    % An important difference with the Jitter parameter above is that we
    % want to have a separate quest for the two orientations. To achieve
    % that we could explicitly create two Quest plugins and assign those to the
    % conditions(:,1).grat ing.contrast = { quest1,quest2}, but in the current example both Quests have
    % identical parameters, so it is easier to duplicate them using the duplicate function.
    %
    % Please note that you should not use repmat for this purpose as it will repmat the
    % handles to the Quest object, not the object itself. In other words, if you used repmat you'd still use the
    % same Quest object for both orientations and could not estimate a
    % separate threshold per orientation.    
    d.conditions(:,1).grating.contrast = duplicate(plugins.quest(c, '@choice.correct','guess',p2i(0.25),'guessSD',4,'i2p',i2p,'p2i',p2i),[nrLevels 1]);   
elseif strcmpi(settings.mode,'STAIRCASE')
    % As an alternative adaptive threshold estimation procedure, consider the 1-up 1-down staircase with fixed 0.01 stepsize on contrast.
    % With user responses, you use:
    d.conditions(:,1).grating.contrast = duplicate(plugins.nDown1UpStaircase(c,'@choice.correct',rand,'min',0,'max',1,'weights',[1 1],'delta',0.1),[nrLevels 1]);
end

% If you;d want to assign a different jitter object per condition (i.e. the
% different jitters are part of the design) you'd use something like this
% (the first level of the first factor (-45) jitters between 10 and -10,
% while the +45 orientation jitters between -15 and +15). If you use this,
% there is no need to assign the jitter to the g.X above , so comment that
% out.
% d.conditions(1,1).grating.X =  plugins.jitter(c,{10,-10},'distribution','1ofN'); 
% d.conditions(2,1).grating.X =  plugins.jitter(c,{15,-15},'distribution','1ofN'); 

% Create a block for this design and specify the repeats per design
myBlock=block('myBlock',d);
myBlock.nrRepeats = 50; % Because the design has 2 conditions, this results in 2*nrRepeats trials.
c.run(myBlock);

if c.trial >2
%% Do some analysis on the data
import neurostim.utils.*;
% Retrieve orientation and contrast settings for each trial. Trials in
% which those parameters did not change willl not have an entry in the log,
% so we have to fill-in the values (e..g if there is no entry in the log
% for trial N, take the value set in trial N-1.

% 
% Because the parameter can be assigned different values (e.g. the default
% value) at some earlier point in the trial; we only want to retrieve the
% value immediately after the stimulus appeared on the screen. Because this is logged
% by the startTime event, we use the 'after' option of the parameters.get
% member function
orientation = get(c.grating.prms.orientation,'after','startTime');
contrast = get(c.grating.prms.contrast,'after','startTime');
uV = unique(orientation);
figure;
hold on
for u=uV(:)'
    stay = orientation ==u;
    plot(contrast(stay),'.-');
end
xlabel 'Trial'
ylabel 'Contrast '
title ([settings.mode ' in action...'])
legend(num2str(uV(:)))
end
end