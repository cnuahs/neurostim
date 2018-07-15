function [f,h] = str2fun(str,c)
% Convert a string into a Matlab function handle
%
% BK - Mar 2016

    % @ as the first char signifies a function
    % Here we parse the string for plugin and property names, then create
    % an anonymous funcion that receives the handles of each unique objects
    % (neurostim.plugin or neurostim.parameter) in the function.
    % The tricky thing is to exclude all characters that cannot be the
    % start of the name of an object.
    %
    % Note: Here's an online tool to test and visualise regexp matches: https://regex101.com/
    % Set flavor to pcre, with modifier (right hand box) of 'g'.
    % One catch is that \< (Matlab) should be replaced with \b (online)  
    
    str = str(2:end);
    
    %Find the unique parameter class objects and store their handles
   % strctProp = regexp(str,'(?<plg>\<[a-zA-Z_]+\w*)\.(?<strct>\w+)\.(?<prop>\w+\>)','names');
%     if ~isempty(strctProp)
%         % This is something like plg.struct.prop  - we could use this in
%         % behaviors to provide dot notation access to the properties of
%         % different states in the same behavior.
%         % f1.startTime.fixating  - the startTime of the fixating phase. To
%         % but these thngs aren't really structs so we call a function
%         % instead. - > startTime(f1,'fixating')
%     
%     end
    plgAndProp = regexp(str,'\<[a-zA-Z_]+\w*\.\w+','match');
    plgAndProp = unique(plgAndProp);
    if ~isempty(plgAndProp)
        for i=1:numel(plgAndProp)
            plg = cell2mat(regexp(plgAndProp{i},'(\<[a-zA-Z_]+\w*\.)','match'));
            prm = strrep(plgAndProp{i},plg,'');
            plg = plg(1:end-1);
            
            %Make sure plugin and property exists
            if ~(isprop(c,plg) && isprop(c.(plg),prm))
                c.error('STOPEXPERIMENT',horzcat('No such plugin or property: ',[plg,'.',prm]));
            end
            
            %Get the handle of the relevant object (neurostim.paramter or neurostim.plugin)
            if isfield(c.(plg).prms,prm)
                %It's a ns parameter. Use the param handle.
                h{i} = c.(plg).prms.(prm); %#ok<AGROW> Array of parameters.
                getLabel{i} = 'getValue()';%#ok<AGROW> Array of parameters.
            else
                %It's just a regular property. Use the plugin handle.
                h{i} = c.(plg);%#ok<AGROW> Array of parameters.
                getLabel{i} = prm;%#ok<AGROW> Array of parameters.
            end
        end
        
        %Replace each reference to them with args(i)
        for i=1:numel(h)
            str = regexprep(str, ['(\<' plgAndProp{i}, ')'],['args{',num2str(i),'}.' getLabel{i}]);
        end
    else
        h = {};
    end
    
    funStr = horzcat('@(args) ',str);
       
    % temporarily replace == with eqMarker to simplify assignment (=) parsing below.
    eqMarker = '*eq*';
    funStr = strrep(funStr,'==',eqMarker);
    % Assignments a=b are not allowed in function handles. (Not sure why). 
    % Replaceit with set(a,b);    
%     funStr = regexprep(funStr,'(?<plgin>this.cic.\w+)\.(?<param>\<\w+)\s*=\s*(.+)','setProperty($1,''$2'',$3)');
    funStr = regexprep(funStr,'(?<handle>args\(\d+\))\.value\s*=\s*(?<setValue>.+)','setProperty($1.plg,$1.hDynProp.Name,$2)');
    
    % Replace the eqMarker with ==
    funStr = strrep(funStr,eqMarker,'==');

    
    % Make sure the iff function is found inside the utils package.`
    funStr = regexprep(funStr,'\<iff\(','neurostim.utils.iff(');    
       
    % Now evaluate the string to create the function    
    try 
        f= eval(funStr);
    catch
        error(['''' str ''' could not be turned into a function: ' funStr]);        
    end
end