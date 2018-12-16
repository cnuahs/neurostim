function c = myRig(varargin)

%Convenience function to set up a CIC object with appropriate settings for the current rig/computer.
%Feel free to add your PC/rig to the list
pin = inputParser;
pin.addParameter('smallWindow',false);   %Set to true to use a half-screen window
pin.addParameter('eyelink',false);
pin.addParameter('debug',false);
pin.parse(varargin{:});
smallWindow = pin.Results.smallWindow;

import neurostim.*

%Create a Command and Intelligence Center object - the central controller for Neurostim.
c = cic;
c.cursor = 'arrow';
computerName = getenv('COMPUTERNAME');
if isempty(computerName)
    [~,computerName] =system('hostname');
    computerName = deblank(computerName);
end
c.dirs.output = tempdir; % Output files will be stored here.

switch computerName
    case {'MU00101417X','ns2'}
        % Shaun's MacBook Pro and marmolab rig #1
        c = marmolab.rigcfg();
        return
        
    case 'MU00043185'
        %Office PC
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',1680,'ypixels',1050,'screenWidth',42,'frameRate',60,'screenNumber',max(Screen('screens')));
        smallWindow = false;
        
    case 'MU00042884'
        %Neurostim A (Display++)
        c = rig(c,'eyelink',true,'mcc',true,'xpixels',1920-1,'ypixels',1080-1,'screenWidth',72,'screenDist',42,'frameRate',120,'screenNumber',0,'eyelinkCommands',{'calibration_area_proportion=0.3 0.3','validation_area_proportion=0.3 0.3'},'outputDir','C:\Neurostim Data Store');
        c.eye.eye = 'RIGHT';
    case 'MU00080600'
        %Neurostim B (CRT)
        c = rig(c,'eyelink',true,'mcc',true,'xpixels',1600-1,'ypixels',1200-1,'screenWidth',40,'frameRate',85,'screenNumber',0,'eyelinkCommands',{'calibration_area_proportion=0.6 0.6','validation_area_proportion=0.6 0.6'});
        
    case 'MOBOT'
        %Home
        c = rig(c,'xorigin',950,'yorigin',550,'xpixels',1920,'ypixels',1200,'screenWidth',42,'frameRate',60,'screenNumber',0);
        smallWindow = true;
        
    case 'CMBN-Presentation-Airbook.local'
        %Airbook
        scrNr =0;
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',60,'screenNumber',scrNr);
        smallWindow = false;
        c.useConsoleColor = true;
        
    case 'KLAB-U'        
         %if pin.Results.debug
            scrNr = 2;
            rect = Screen('rect',scrNr); 
            hz=Screen('NominalFrameRate', scrNr);
            c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',40,'frameRate',hz,'screenNumber',scrNr);
            smallWindow = false;
             Screen('Preference', 'SkipSyncTests', 2);
%         else
%             scrNr = 1;
%             rect = Screen('rect',scrNr); 
%             c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',60,'frameRate',60,'screenNumber',scrNr);
%             smallWindow = false;        
%              Screen('Preference', 'SkipSyncTests', 0);
%         end
        c.useConsoleColor = true;
        
    case 'NEUROSTIMM'
        scrNr=0;
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',34.5,'frameRate',60,'screenNumber',scrNr);
        InitializePsychSound(1)
        devs = PsychPortAudio('GetDevices');
        c.hardware.sound.device = devs(strcmpi({devs.DeviceName},'Microsoft Sound Mapper - Output')).DeviceIndex; % Automatic sound hardware detection fails on this machine. Specify device 1
        %if pin.Results.debug 
            smallWindow = true ;
        %else
        %    smallWindow = false;
        %end
        c.useConsoleColor = true;
        Screen('Preference', 'ConserveVRAM', 4096); %kPsychUseBeampositionQueryWorkaround
    case 'SURFACE2017'
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        smallWindow = true;
        c.dirs.output= 'c:/temp';
        c.useConsoleColor = true;
    case '2014B'
        scrNr = 2;
        rect = Screen('rect',scrNr);
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',38.3,'frameRate',60,'screenNumber',scrNr);
        c.screen.colorMode = 'RGB';
        Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.
        smallWindow = false;
    case '2014C'
        % Presentation computer
       c = rig(c,'eyelink',false,'outputdir','c:/temp/','mcc',false,'xpixels',1920,'ypixels',1080,'screenWidth',133,'screenHeight',75, 'frameRate',60,'screenNumber',1);
        Screen('Preference', 'SkipSyncTests', 2);
    case 'PTB-P'
        Screen('Preference', 'SkipSyncTests', 0);
        c = rig(c,'eyelink',pin.Results.eyelink,'outputdir','c:/temp/','mcc',false,'xpixels',1920,'ypixels',1080,'screenWidth',52,'frameRate',120,'screenNumber',1);
        c.screen.colorMode = 'RGB';            
        c.screen.type  = 'GENERIC';
        smallWindow = false;
        c.timing.vsyncMode =0;
        c.timing.frameSlack = 0.1;
        c.eye.sampleRate  = 250;
        c.useConsoleColor = true;
    case 'PTB-P-UBUNTU'
        c = rig(c,'keyboardNumber',[],'eyelink',pin.Results.eyelink,'outputdir','c:/temp/','mcc',false,'xpixels',1920,'ypixels',1080,'screenWidth',52,'frameRate',120,'screenNumber',1);
        
        c.screen.colorMode = 'RGB';            
        smallWindow = false;      
        c.eye.sampleRate  = 250;
    case 'PC2017A'
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        c.useConsoleColor = true;
        %Screen('Preference', 'SkipSyncTests', 2);
        smallWindow = false;
        
    case 'NEUROSTIMA2018'
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        c.useConsoleColor = true;
        Screen('Preference', 'SkipSyncTests', 2);
        smallWindow = true;        
    case 'PC-2018D'
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        c.useConsoleColor = true;
        Screen('Preference', 'SkipSyncTests', 0);
        smallWindow = false;
    case 'ROOT-PC'
        c = rig(c,'xpixels',1280,'ypixels',1024,'screenWidth',40,'frameRate',85,'screenNumber',max(Screen('screens')));
        smallWindow = false;    
    otherwise
        warning('a:b','This computer (%s) is not recognised. Using default settings.\nHint: edit neurostim.myRig to prevent this warning.',computerName);
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'eyelink',pin.Results.eyelink,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        smallWindow = true;
end

if smallWindow
    c.screen.xpixels = c.screen.xpixels/2;
    c.screen.ypixels = c.screen.ypixels/2;
end

c.screen.color.background = [0.25 0.25 0.25];
c.iti = 500;
c.trialDuration = 500;
