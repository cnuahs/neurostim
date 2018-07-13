classdef behavior <  neurostim.plugin
    
    properties (SetAccess=public,GetAccess=public)
        
        everyFrame@logical =true;
        
    end
    
    properties (SetAccess=protected,GetAccess=public)
         currentState; % Function handle that represents the current state.       
    end
    
    
    %% Standard plugin member functions
    methods (Sealed)
        % Users should add functionality by defining new states, or
        % if a different response modailty (touchbar, keypress, eye) is
        % needed, by overloading the getEvent function. The regular plugin
        % functions are sealed. 
        function beforeExperiment(o)
        end
        
        
        function beforeTrial(o)
            
        end
        
        function beforeFrame(o)
            if o.everyFrame    
                e= getEvent(o);     % Get current events
                o.currentState(e);  % Each state is a member function- just pass the event
            end
        end
        
        function afterFrame(o)
        end
        
        function afterTrial(o)
        end
        function afterExperiment(o)
        end
        
        
        function transition(o,state)
            o.currentState = state;
        end
    end
    
    %% 
    methods (Access=public)  % Derived classes can overrule these if needed
        % Constructor
        function o = behavior(c,name)
            o = o@neurostim.plugin(c,name);     
            o.feedStyle = 'blue';
        end
        
        
        function e = getEvent(o)
            [e.x,e.y,e.buttons] = GetMouse;            
        end
        
      
    end
    
    %% States
    methods
        function endTrial(o,e)
            
        end
    end
    
end