classdef rrasetup    
    % RRASETUP	Custom class definition to perform OpenSim's residual
    % reduction algorithm and implements a tracking weight selection
    % algorithm to optimize (minimize) residual forces and tracking errors.
    % Requires: 
    %   OpenSim API https://simtk-confluence.stanford.edu:8443/display/OpenSim/Scripting+with+Matlab
    %
    % To use RRASETUP, first add the path containing the "+rraTools"
    % folder, then call "import rraTools.*" in your .m file or command
    % window. 
    % 
    % RRASETUP properties: 
    %   Public properties can be set explicitly, or based on the
    %   constructor to use defaults.
    %
    %   participant - text, tag for participant identifier
    %   condition - text, specific condition tag
    %   trialpath - text, full system path to the trial folder
    %   modelname - text, constructed from participant and condition tags 
    %       as: 
    %           obj.modelname = [obj.participant, '.osim'] (if
    %           condition field is empty)
    %       or 
    %           obj.modelname = [obj.participant, '_', obj.condition, '.osim']
    %
    %   modfullfile - text, full system path to model file.
    %       Constructed by default using trialpath and modelname
    %   fileset - instance of class rrafiles. 
    %   toolsettings - instance of class rraoptions. Contains specifications 
    %       for RRA tool fields.
    %   initDelMass - numeric, mass change from runInitialRRA()
    %   totalDelMass - numeric, total mass change after runMassItrsRRA()
    %   numMassItrs - integer, number of iterations until mass change
    %       converged.
    %
    %
    % rrasetup methods:
    %
    %
    
    
    properties
        participant %{mustBeText}
        condition %{mustBeText}
        trialpath
        setupsfolder
        modelname
        modfullfile
        fileset
        toolsettings
        extloadsettings
        initDelMass
        totalDelMass
        numMassItrs
    end
    
    methods % public methods
        
        
        function obj = rrasetup(trialpath,participant,condition)
        % Constructor Method obj = RRASETUP(trialpath,participant,condition,mass)
        % Inputs are used to define relevant directories, file names, and 
        % initial properties of the class instance.
        %
            
            obj.participant = participant; % text participant tag
            obj.condition = condition; % text condition tag
            obj.trialpath = trialpath; % construct the full path to the trial folder
            if isempty(obj.condition)
                obj.modelname = [obj.participant, '.osim']; % construct the osim model string
            else
                obj.modelname = [obj.participant, '_', obj.condition, '.osim']; % construct the osim model string
            end
            obj.modfullfile = fullfile(obj.trialpath,obj.modelname); % construct the full path name for the osim model
            obj.fileset = rraTools.rrafiles(trialpath, participant, condition); % populate the file set that will be used by the RRATool
            obj.toolsettings = rraTools.rraoptions(obj.trialpath,... % specify the initial settings for the RRATool
                obj.modelname,obj.fileset.actuatorfile,...
                obj.fileset.extloadsetup,obj.fileset.kinfile,...
                obj.fileset.taskfile,obj.fileset.resultspath,...
                obj.fileset.outname,obj.fileset.rrasetupfile); 
            obj.extloadsettings = rraTools.extloadoptions();
            obj.initDelMass = 0; % initialize property to record initial mass adjustment
            obj.totalDelMass = 0; % record total mass adjustments for all iterations
            obj.numMassItrs = 0; % initialize property to count mass adjustment iterations
        end
        
        function btoolprinted = writeRRATool(obj)
            % Method WRITERRATOOL() configures the RRA tool and writes the 
            % xml setup file using determined settings. Settings are 
            % specified from the attributes of "rraoptions". These 
            % attributes can be access through the rrasetup class for 
            % manual specification.
            
            import org.opensim.modeling.*
            rraTool = RRATool();
            rraTool.setName("RRA");
            rraTool.setInitialTime(obj.toolsettings.starttime);
            rraTool.setFinalTime(obj.toolsettings.endtime);
            rraTool.setStartTime(obj.toolsettings.starttime);
            rraTool.setReplaceForceSet(obj.toolsettings.bForceset);
            rraTool.setAdjustCOMToReduceResiduals(obj.toolsettings.bAdjustCOM)
            rraTool.setAdjustedCOMBody(obj.toolsettings.comBody)
            rraTool.setModelFilename(fullfile(obj.toolsettings.trialpath,obj.toolsettings.modelname));
            forceStr = ArrayStr();
            forceStr.append(fullfile(obj.toolsettings.trialpath,obj.toolsettings.actuatorfile));
            rraTool.setForceSetFiles(forceStr);
            rraTool.setExternalLoadsFileName(fullfile(obj.toolsettings.trialpath,obj.toolsettings.extloadsetup));
            rraTool.setDesiredKinematicsFileName(fullfile(obj.toolsettings.trialpath,obj.toolsettings.kinfile));
            rraTool.setLowpassCutoffFrequency(obj.toolsettings.LPhz);
            rraTool.setTaskSetFileName(fullfile(obj.toolsettings.trialpath,obj.toolsettings.taskfile));
            rraTool.setOutputModelFileName(fullfile(obj.toolsettings.trialpath,obj.toolsettings.outname));
            rraTool.setResultsDir(obj.toolsettings.resultspath);
            btoolprinted = rraTool.print(fullfile(obj.toolsettings.trialpath,obj.toolsettings.rrasetupfile));
        end
        
        function obj = runInitialRRA(obj,varargin)
            % Method runInitialRRA() performs the first iteration of RRA
            % and adjusts model masses based on tool output.  
            % Note: this method should be called as "obj =
            % obj.RUNINITIALRRA()" so that total mass changes and other
            % properties changes are retained through RRA iterations. 
            %
            % Optional name value pair arguments: 
            % 
            % CreateTasks -- boolean, default is false. Current method
            %   calls writeTasksFile() method if true.
            % CreateReserves -- boolean, default is false. Current method
            %   calls writeReservesFile() method if true.
            % CreateExtLoads -- boolean, default is falseCurrent method
            %   calls writeExtLoads() method if true.
            %
            % In the default case,
            % each method should be called separately to create the necessary
            % files, or each file can be copied into the study directory.
            %
            
            
            defaultLoads = false;
            defaultReserves=false;
            defaultTasks = false;
            inpts = inputParser;
                addRequired(inpts,'obj')
                addParameter(inpts,'CreateTasks',defaultTasks,@islogical)
                addParameter(inpts,'CreateReserves',defaultReserves,@islogical)
                addParameter(inpts,'CreateExtLoads',defaultLoads,@islogical)

            parse(inpts,obj,varargin{:});

            obj = inpts.Results.obj;
            createTasks = inpts.Results.CreateTasks;
            createReserves = inpts.Results.CreateReserves;
            createLoads = inpts.Results.CreateExtLoads;
            
            import org.opensim.modeling.*           
%             adjname = strrep(obj.modname,'.osim','_adj.osim');
%             outname = strrep(obj.modname,'.osim','_adjMass.osim');


            % create the tool   
            if obj.toolsettings.starttime == obj.toolsettings.endtime
                ikdata = Storage(fullfile(obj.fileset.trialpath,obj.fileset.grffile)); % load the ik file
                timedata = ArrayDouble();
                ikdata.getTimeColumn(timedata); % retrieve the time column into the array
                obj.toolsettings.starttime = timedata.get(0); % update tool settings to start at first frame
                obj.toolsettings.endtime = timedata.getLast(); % update tool settings to end at last frame
                disp([obj.toolsettings.starttime;obj.toolsettings.endtime])
            end
            btoolprinted = writeRRATool(obj); % call method to write the RRA setup file

            if createTasks
                disp("writing tasks")
                obj.writeTasksFile(); % call method to write the tasks file
            end
            if createLoads
                disp("writing external loads")
                obj.writeExtLoads(); % call method to write the external loads file
            end
            if createReserves
                disp("writing reserves")
                obj.writeReservesFile(); % call method to write the reserve actuators file
            end
            
            % run RRA
            disp("ready to run RRA")
            if ~isfolder(obj.fileset.resultspath) % create result folder if needed
                mkdir(obj.fileset.resultspath);
            end
            
            % OpenSim 4.x has started appending to the log file rather
            % than overwriting. Delete the existing log file prior to
            % running the tool.
            if exist(fullfile(obj.toolsettings.resultspath,'out.log'), 'file')
                delete(fullfile(obj.toolsettings.resultspath,'out.log')); % OpenSim v3.x - 4.1
            elseif exist(fullfile(obj.toolsettings.resultspath,'opensim.log'), 'file')
                delete(fullfile(obj.toolsettings.resultspath,'opensim.log')); % OpenSim v4.2+
            end

            mydir = cd(); % remember current directory
            cd(obj.fileset.resultspath); % move to results folder to run analysis
            
            % try to determine version of OpenSim used
            try 
                osimvers = org.opensim.modeling.opensimCommon.GetVersion();
                if startsWith(osimvers,'4.')
                    v4 = true;
                else 
                    v4 = false;
                end
            catch % assume version 3.3 because "GetVersion() did not work
                v4 = false;
            end
            % create string to send to the command line        
            if v4 
                CommandRRA = ['opensim-cmd run-tool ', char(fullfile(obj.fileset.trialpath,obj.fileset.rrasetupfile))];
            else
                CommandRRA = ['rra -S "',char(fullfile(obj.fileset.trialpath,obj.fileset.rrasetupfile))];
            end
            
            fprintf(['Performing RRA:  ']);
            disp(CommandRRA)
            % send it to the command line
            system(CommandRRA);
            cd(mydir); % move back to original directory

            obj.initDelMass = obj.adjMass(); % perform recomended mass adjustments
            obj.totalDelMass = obj.initDelMass; % update total mass change
            obj.numMassItrs = obj.numMassItrs + 1; % update iteration counter
        end % function runInitialRRA
        
        function obj = runMassItrsRRA(obj)
            % Method RUNMASSITRSRRA() performs up to 10 iterations of RRA
            % until the recomended mass change is less than the threshold
            % 0.001. 
            % Note: call the method as obj = obj.RUNMASSITRSRRA()
            % to track the total mass change and number of iterations.
            
            disp([obj.toolsettings.starttime;obj.toolsettings.endtime])
            pause(5)
            mass_change = 100;

            % create the tool
            import org.opensim.modeling.*
            ikdata = Storage(fullfile(obj.fileset.trialpath,obj.fileset.kinfile));
            timedata = ArrayDouble();
            ikdata.getTimeColumn(timedata);
            obj.toolsettings.starttime = timedata.get(0);
            obj.toolsettings.endtime = timedata.getLast();
            obj.toolsettings.rrasetupfile = obj.fileset.masssetupfile;
            obj.toolsettings.modelname = obj.fileset.adjname;
            obj.toolsettings.resultspath = obj.fileset.adjresultspath;
            
            if ~isfolder(obj.toolsettings.resultspath)
                mkdir(obj.toolsettings.resultspath)
            end
            
            
            btoolprinted = writeRRATool(obj);
            % do until mass adjust < tolerance
            for iternum = 1:10
                if abs(mass_change) < 0.001
                    break
                end
                
                % OpenSim 4.x has started appending to the log file rather
                % than overwriting. Delete the existing log file prior to
                % running the tool.
                if exist(fullfile(obj.toolsettings.resultspath,'out.log'), 'file')
                    delete(fullfile(obj.toolsettings.resultspath,'out.log')); % OpenSim v3.x - 4.1
                elseif exist(fullfile(obj.toolsettings.resultspath,'opensim.log'), 'file')
                    delete(fullfile(obj.toolsettings.resultspath,'opensim.log')); % OpenSim v4.2
                end
                
                mydir = cd();
                cd(obj.toolsettings.resultspath);
                % try to determine version of OpenSim used
                try 
                    osimvers = org.opensim.modeling.opensimCommon.GetVersion();
                    if startsWith(osimvers,'4.')
                        v4 = true;
                    else 
                        v4 = false;
                    end
                catch % assume version 3.3 because "GetVersion() did not work
                    v4 = false;
                end
                % create string to send to the command line        
                if v4 
                    CommandRRA = ['opensim-cmd run-tool ', char(fullfile(obj.fileset.trialpath,obj.fileset.masssetupfile))];
                else
                    CommandRRA = ['rra -S "',char(fullfile(obj.fileset.trialpath,obj.fileset.masssetupfile))];
                end
               
                %A message so you know it's working
                fprintf(['Performing RRA']);
                %send it to the command line
                system(CommandRRA);

                cd(mydir);
                % count iters
                mass_change = obj.adjMass();
                % adjust model masses
                obj.totalDelMass = obj.totalDelMass + mass_change;
                obj.numMassItrs = obj.numMassItrs + 1;
            end
        end
        
        function mass_change = adjMass(obj)
            % Method mass_change = adjMass() Edits the model to make 
            % recommended mass adjustments.
            % Helper funciton used by runInitialRRA and runMassItrsRRA. 
            % Reads the recommended mass adjustments from the RRA log file, 
            % and makes mass and COM edits to the model.
            
            import org.opensim.modeling.*

            %Read recommended mass adjustment
            if exist(fullfile(obj.toolsettings.resultspath,'out.log'), 'file')
                fid = fopen(fullfile(obj.toolsettings.resultspath,'out.log')); % OpenSim v3.x - 4.1
            elseif exist(fullfile(obj.toolsettings.resultspath,'opensim.log'), 'file')
                fid = fopen(fullfile(obj.toolsettings.resultspath,'opensim.log')); % OpenSim v4.2
            else
                warning('log file not found in RRA result directory!')
            end
            
            txt = textscan(fid,'%s','delimiter','\n');
            fclose(fid);
                
            str = '*  Total mass change: ';
            lineLoc = contains(cellfun(@num2str,txt{1},'UniformOutput',false),str);
            line = txt{1}{lineLoc};
            mass_change = str2num(line(length(str):end));

            line1 = ['iteration: '];%,num2str(r)]; 
            line2 = ['Adjusting total model mass: ',num2str(mass_change)];
            disp({line1;line2})
            pause(5);

            %Initialize an OpenSim model from the RRA output
            model = Model(fullfile(obj.toolsettings.trialpath,obj.toolsettings.outname));
            state = model.initSystem();
            oldMass = model.getTotalMass(state);
            %--------------------------------------------
            %Adjust model mass using the model instance
            %--------------------------------------------
            newMass = oldMass + mass_change;
            scaleset = ScaleSet();
            
            % try to check the opensim version as scale tool takes
            % different argument order.
            try 
                apivers = char(org.opensim.modeling.opensimCommon.GetVersion());
            catch 
                % if error thrown, version might be 3.3
                apivers = '3.3';
            end
            if startsWith(apivers,'4.')
                res = model.scale(state,scaleset,true,newMass); % OpenSim v4.2+
            else
                res = model.scale(state,scaleset,newMass,true);
            end
            
            if res==0
                error('Model mass scaling failed.')
            end
            %Print the adjusted model
            model.print(fullfile(obj.trialpath,obj.fileset.adjname));
            disp({'adjusted model printed to: ';fullfile(obj.trialpath,obj.fileset.adjname)});
        end % function mass change
        
        function success = writeTasksFile(obj,varargin)
            % Method WRITETASKSFILE(obj,varargin) 
            % Configures and writes the tracking task set for RRA given the
            % model provided. 
            % Reads coordinates from model and assigns tracking tasks to 
            % all non-locked independent coordinates based on user
            % specified values or defaults.
            %
            % Optional name value pair arguments:
            %
            % SkipCoordinates - a cell array of non-constrained
            %   coordinates that should not be included in the tracking
            %   tasks. Provided as a name value pair (e.g.
            %   writeTasksFile('SkipCoordinates',{'subtalar_angle_r','subtalar_angle_l'})
            %
            % Kp - numeric value for the proportional gain for all
            %   tracking tasks (default is 1600). Provided as a name value
            %   pair (e.g. writeTasksFile('Kp',100)). Note, critical
            %   damping will always be enforced by setting Kv = 2*sqrt(Kp).
            %
            % UniformWeights - a boolean entry that sets all tracking
            %   weights to 1 (default is false). Use name value pair
            %   entry. e.g. writeTasksFile('UniformWeights',true)
            %
            % UserWeights - a cell array containing the coordinate string
            %   and desired weight for any non-constrained coordinates.
            %   Coordinates not named in this variable will use the default
            %   weights. To use the same weight for each side, a partial
            %   coordinate name can be specified (e.g. {'ankle'} rather than
            %   {'ankle_angle_l','ankle_angle_r'}). Names and weights 
            %   should be supplied in the following syntax: 
            %   "{'ankle','knee','hip';25,10,5}" 
            %   to be parsed correctly. Use name value pair entry (e.g.
            %   writeTasksFile('UserWeights', {name_array;weight_array} )
            %   Note, user supplied weights are ignored if 'UniformWeights'
            %   is set to true.
            %
            
            defaultKp = 1600;
            defaultCoords = {'bp_tx','bp_ty'};
            defaultUniform = true;
            inpts = inputParser; % manage inputs 
                addRequired(inpts,'obj')
                addParameter(inpts,'SkipCoordinates',defaultCoords)
                addParameter(inpts,'Kp',defaultKp,@isnumeric)
                addParameter(inpts,'UniformWeights',defaultUniform,@islogical)
                addParameter(inpts,'UserWeights',{}) % set defualt to emtpy cell

            parse(inpts,obj,varargin{:}); % parse the inputs and assign defaults or user supplied values

            obj = inpts.Results.obj; % need to assign self
            skipCoords = inpts.Results.SkipCoordinates;
            uniformWeights = inpts.Results.UniformWeights;
            userNames = {}; % initialize as empty
            userWeights = {}; 
            if ~isempty(inpts.Results.UserWeights) % user has specified weights
                userNames = inpts.Results.UserWeights(1,:); % split the coordinate names from the cell
                userWeights = cell2mat( inpts.Results.UserWeights(2,:) ); % split the matched weights from the cell
            end
            
            Kp = inpts.Results.Kp;
            Kv = 2*sqrt(Kp); % enforce critical damping
            
            % create reserve set
            import org.opensim.modeling.*
            cmod = Model(obj.modfullfile); % load the model
            s = cmod.initSystem();

            task_set = CMC_TaskSet();
            task_set.setModel(cmod);

            coords = cmod.getCoordinateSet(); % get model coordinates
            numc = coords.getSize();

            for rf = 0:numc-1
                if coords.get(rf).isConstrained(s) % Ignore constrained coordinates. This includes locked and coupled coordinates

                else
                    cname = char(coords.get(rf).getName()); % Get current coordinate name for comparison
                    if ~any(contains(skipCoords,cname)) % ignore coordinates that should not be tracked based on user specification
                        % create and enable the task
                        curTask = CMC_Joint(cname);
                        curTask.setName(cname);
                        curTask.setActive(true,false,false);
                        curTask.setKP(Kp,0,0);
                        curTask.setKV(Kv,0,0);
                        curTask.setOn(true);


                        if uniformWeights % set all tracking weights equal
                            userIdx = contains(userNames,cname); 
                            if any(userIdx) % check if coordinate weight has been provided and assign the specified weight
                                curTask.setWeight(userWeights(userIdx),1,1);
                            else
                                curTask.setWeight(1,1,1);
                            end
                        else % weight more important coordinates higher
                            userIdx = contains(userNames,cname); 
                            if any(userIdx) % check if coordinate weight has been provided and assign the specified weight
                                curTask.setWeight(userWeights(userIdx),1,1);
                            elseif contains(lower(cname),'pelvis')
                                curTask.setWeight(10,1,1);
                            elseif contains(cname,'ankle')
                                curTask.setWeight(25,1,1);
                            elseif contains(cname,'knee')
                                curTask.setWeight(10,1,1);
                            elseif contains(cname,'hip')
                                curTask.setWeight(5,1,1);
                            elseif any( contains({'axial_rotation','lat_bending','L5_S1_AR','L5_S1_LB'},cname) )
                                curTask.setWeight(10,1,1);
                            elseif any( contains({'flex_extension','L5_S1_FE'},cname) )
                                curTask.setWeight(10,1,1);
                            else
                                curTask.setWeight(1,1,1);
                            end
                        end
                        task_set.cloneAndAppend(curTask); % add tracking task to the set.
                        disp("task appended")
                    end
                end
            end

            disp("printing tasks")
            success = task_set.print(fullfile(obj.fileset.trialpath,obj.fileset.taskfile)); % save the tasks file
        end % function write tasks
        
        function success = writeReservesFile(obj,varargin)
        % Method WRITERESERVESFILE() 
        % Configures and prints the reserve actuators force set to xml
        % file. Reads the model coordinate set, and creates a reserve or
        % residual actuator for all unconstrained coordinates.
        %
        % Optional name value pair arguments: 
        %
        % SkipCoordinates -- a cell array of strings or char arrays 
        %   specifying any coordinates to not actuate (will be given an 
        %   optimal force of 1). These will typically be untracked or free 
        %   coordinates. Most users should leave this argument unassigned.
        % ReserveForce -- a numeric input to specify the optimal force 
        %   for all other reserves (default is 1600)
        % ResidualForce -- a numeric input to specify the optimal force
        %   given to residual actuators (FX, FY, FZ, MX, MY, and MZ: default is 100)
        % 

          
            defaultReserve = 1600;
            defaultResidual = 100;
            defaultCoords = {'bp_tx','bp_ty'}; % defaults included as a format example. 
            inpts = inputParser;
                addRequired(inpts,'obj')
                addParameter(inpts,'SkipCoordinates',defaultCoords) % most users will not need to use this input
                addParameter(inpts,'ReserveForce',defaultReserve,@isnumeric)
                addParameter(inpts,'ResidualForce',defaultResidual,@isnumeric)

            parse(inpts,obj,varargin{:});

            obj = inpts.Results.obj;
            reserve_force = inpts.Results.ReserveForce;
            residual_force = inpts.Results.ResidualForce;
            skipCoords = inpts.Results.SkipCoordinates;
            
            % create reserve set
            import org.opensim.modeling.*
            cmod = Model(obj.modfullfile);
            s = cmod.initSystem();
           
            reserve_set = ForceSet();
            coords = cmod.getCoordinateSet();
            numc = coords.getSize();

            for rf = 0:numc-1
                cname = char(coords.get(rf).getName());
                if coords.get(rf).isConstrained(s)
                    % don't actuate constrained/locked coordinates
                else
                    if any(contains(cname,{'pelvis','Pelvis'}) )
                        if contains(cname,'Pelvis')
                            bodyname = 'Pelvis';
                        else
                            bodyname = 'pelvis';
                        end
                        cm = Vec3;
                        try 
                            apivers = org.opensim.modeling.opensimCommon.GetVersion();
                        catch
                            apivers = '3.3';
                        end
                        if startsWith(apivers, '4.') % use 4.x command
                            cm = cmod.getBodySet().get(bodyname).getMassCenter(); % v3.3 - cmod.getBodySet().get("pelvis").getMassCenter(cm);
                        else
                            cmod.getBodySet().get(bodyname).getMassCenter(cm);
                        end
                        if contains(cname,'tilt')
                            curAct = CoordinateActuator();
                            curAct.setOptimalForce(residual_force);
                            curAct.set_coordinate(cname);
                            curAct.setName('MZ');
                        elseif contains(cname,'list')
                            curAct = CoordinateActuator();
                            curAct.setOptimalForce(residual_force);
                            curAct.set_coordinate(cname);
                            curAct.setName('MX');
                        elseif contains(cname,'rotation')
                            curAct = CoordinateActuator();
                            curAct.setOptimalForce(residual_force);
                            curAct.set_coordinate(cname);
                            curAct.setName('MY');
                        elseif contains(cname,'tx')
                            curAct = PointActuator();
                            curAct.setOptimalForce(residual_force);
                            curAct.set_body(bodyname)
                            curAct.set_direction(Vec3(1,0,0))
                            curAct.set_point(cm);
                            curAct.set_point_is_global(false)
                            curAct.set_force_is_global(true)
                            curAct.setName('FX');
                        elseif contains(cname,'ty')
                            curAct = PointActuator();
                            curAct.setOptimalForce(residual_force);
                            curAct.set_body(bodyname)
                            curAct.set_direction(Vec3(0,1,0))
                            curAct.set_point(cm);
                            curAct.set_point_is_global(false)
                            curAct.set_force_is_global(true)
                            curAct.setName('FY');
                        elseif contains(cname,'tz')
                            curAct = PointActuator();
                            curAct.setOptimalForce(residual_force);
                            curAct.set_body(bodyname)
                            curAct.set_direction(Vec3(0,0,1))
                            curAct.set_point(cm);
                            curAct.set_point_is_global(false)
                            curAct.set_force_is_global(true)
                            curAct.setName('FZ');
                        end
                    else
                        curAct = CoordinateActuator();
                        curAct.setName(cname);
                        curAct.set_coordinate(cname);
                        if any(contains(skipCoords, cname))
                            curAct.setOptimalForce(1);
                        else
                            curAct.setOptimalForce(reserve_force);
                        end
                    end 
                    curAct.setMaxControl(1000)
                    curAct.setMinControl(-1000)
                    reserve_set.cloneAndAppend(curAct);
                end
            end

            mNames = ArrayStr();
            fNames = ArrayStr();
            modForce = cmod.getForceSet();
            modForce.getNames(fNames);
            modAct = modForce.getActuators();
            modAct.getNames(mNames);

            % need to add any passive force elements into the reserve force
            % set if they are important during RRA. e.g. used to control
            % motion of untracked coordinates.
            fnum = modForce.getSize();
            for f = 1:fnum
                loc = mNames.rfindIndex(fNames.get(f-1));
                if loc == -1
                    if contains( char(modForce.get(f-1).getConcreteClassName()),'BushingForce' )...
                            && ~contains(char(modForce.get(f-1).getConcreteClassName()),'ExpressionBased' )
                    else
                        reserve_set.cloneAndAppend(modForce.get(fNames.get(f-1)));
                    end
                end
            end
            %
            success = reserve_set.print(fullfile(obj.fileset.trialpath,obj.fileset.actuatorfile));
        end % function write reserves
        
        function b = writeExtLoads(obj)
            % Method writeExtLoads() configures and prints the external
            % loads specification xml file based on the rrasetup.fileset
            % properties.
            
            import org.opensim.modeling.*

            extLoads = ExternalLoads();
            exf = ExternalForce();
            exfl = ExternalForce();
             
            try 
                apivers = org.opensim.modeling.opensimCommon.GetVersion();
            catch
                apivers = '3.3';
            end
            
            exf.setName(obj.extloadsettings.forceName_right); 
            if startsWith(apivers, '3.') 
                exf.set_isDisabled(false); % v3.3 only, not required for 4.x
            end
            exf.setAppliedToBodyName(obj.extloadsettings.appliedBody_right);
            exf.setForceExpressedInBodyName(obj.extloadsettings.expressedInBody);
            exf.setPointExpressedInBodyName(obj.extloadsettings.expressedInBody);
            exf.setForceIdentifier (obj.extloadsettings.forceID_right);
            exf.setPointIdentifier (obj.extloadsettings.pointID_right);
            exf.setTorqueIdentifier(obj.extloadsettings.torqueID_right);
            exf.set_data_source_name(fullfile(obj.fileset.trialpath,obj.fileset.grffile));
            extLoads.cloneAndAppend(exf);


            exfl.setName(obj.extloadsettings.forceName_left);
            if startsWith(apivers, '3.') 
                exfl.set_isDisabled(false); % v3.3 only, not required for 4.x
            end
            exfl.setAppliedToBodyName(obj.extloadsettings.appliedBody_left);
            exfl.setForceExpressedInBodyName(obj.extloadsettings.expressedInBody);
            exfl.setPointExpressedInBodyName(obj.extloadsettings.expressedInBody);
            exfl.setForceIdentifier (obj.extloadsettings.forceID_left);
            exfl.setPointIdentifier (obj.extloadsettings.pointID_left);
            exfl.setTorqueIdentifier(obj.extloadsettings.torqueID_left);
            exfl.set_data_source_name(fullfile(obj.fileset.trialpath,obj.fileset.grffile));
            extLoads.cloneAndAppend(exfl);

            extLoads.setDataFileName(fullfile(obj.fileset.trialpath,obj.fileset.grffile));
            % setExternalLoadsModelKinematicsFileName is only a method in
            % OpenSim v3.3 and prior. This is not needed even if running
            % rraTools using the 3.3 API. Will be fully removed after
            % verifying. JS
            % extLoads.setExternalLoadsModelKinematicsFileName(fullfile(obj.fileset.trialpath,obj.fileset.kinfile));
            b = extLoads.print(fullfile(obj.fileset.trialpath,obj.fileset.extloadsetup));
        end
        
        
        function peak_force = readPeakExtForce(obj)
            % Method readPeakExtForce() calculates and returns the max total
            % externally applied force (ground reaction force) as specified
            % by the external loads configuration. This value can then be
            % used to normalize residuals during TWSA.
            % 
            import org.opensim.modeling.*
            % import the grf data from the motion file
            filename = fullfile(obj.trialpath, obj.fileset.grffile);
            grf = Storage(filename);

            cols = grf.getColumnLabels();
            rstart = cols.findIndex(strcat(obj.extloadsettings.forceID_right,'x'));
            lstart = cols.findIndex(strcat(obj.extloadsettings.forceID_left,'x'));

            rforce_x = ArrayDouble();
            rforce_y = ArrayDouble();
            rforce_z = ArrayDouble();
            lforce_x = ArrayDouble();
            lforce_y = ArrayDouble();
            lforce_z = ArrayDouble();

            grf.getDataColumn(rstart,rforce_x);
            grf.getDataColumn(rstart+1,rforce_y);
            grf.getDataColumn(rstart+2,rforce_z);
            grf.getDataColumn(lstart,lforce_x);
            grf.getDataColumn(lstart+1,lforce_y);
            grf.getDataColumn(lstart+2,lforce_z);
            net_force = [];

            for x = 0:rforce_x.getSize()-1
                left_val =  sqrt(lforce_x.get(x)^2 + lforce_y.get(x)^2 + lforce_z.get(x)^2);
                right_val = sqrt(rforce_x.get(x)^2 + rforce_y.get(x)^2 + rforce_z.get(x)^2);
                value =  left_val + right_val;
                %print(value); 
                net_force(x+1) = value;
            end
            
            peak_force = max(net_force);

        end

        function S = optimizeTrackingWeights(obj,varargin)
            % Method OPTIMIZETRACKINGWEIGHTS() performs the tracking weight
            % optimization algorithm using the mass adjusted model.
            % Optional name value pair arguments:
            %
            % overwrite -- boolean to continue from saved results (false) or start over (true)
            % min_itrs -- integer to specify a minimum number of iterations to use (default = 25)
            % max_itrs -- integer to specify a maximum number of iterations (default = 75)
            % fcn_threshold -- numeric input to specify target cost function value for good enough convergence 
            % body_mass -- numeric input
            % wRes -- numeric multiplier for the residual cost term (default = 1) 
            % wErr -- numeric multiplier for the tracking errors cost term (default = 3)
            % pRes -- numeric polynomial power for the residual cost term (default = 3)
            % pErr -- polynomial power for the tracking errors cost term (default = 4)
            % 
            % ResidualNormFac -- Peak force in N used to normalize residuals.
            % Should be input such that 0.05*ResidualNormFac is equal to
            % the tolerated magnitude of residual force.
            % 
            % RotateNormFac -- tolerated rotational kinematic error in
            % degrees used to normalize the tracking errors.
            % 
            % TransNormFac -- tolerated translational kinematic error in m
            % used to normalize the tracking errors.
            % 
            % 
            % End of list of optional inputs.
            % 
            % Additional hidden methods contained are helper functions to this main 
            % tracking weight optimization method.   
            %
            % 
            
            
            %**************************************************************************
            % OPTIMIZE RESIDUAL FORCES AND TRACKING ERRORS
            %**************************************************************************
  


            %   Developed by Nathan Pickle October 12, 2016 at Colorado School of Mines
            %   Code adapted by Amy Hegarty Febuary 14, 2017
            %   Further modifications by Jordan Sturdy between 2019 and 2021
            
            % setup
            defaultMinItrs = 25;
            defaultMaxItrs = 75;
            defaultThresh = 2;
            defaultSwRes = 1; 
            defaultSwErr = 3;
            defaultSpRes = 3;
            defaultSpErr = 4;
            defaultNormForce = 0;
            defaultNormRot = 3;
            defaultNormTrans = 0.02;

            inpts = inputParser;
                addParameter(inpts,'overwrite',false,@islogical)
                addParameter(inpts,'min_itrs',defaultMinItrs,@isnumeric)
                addParameter(inpts,'max_itrs',defaultMaxItrs,@isnumeric)
                addParameter(inpts,'fcn_threshold',defaultThresh,@isnumeric)
                addParameter(inpts,'wRes',defaultSwRes,@isnumeric)
                addParameter(inpts,'wErr',defaultSwErr,@isnumeric)
                addParameter(inpts,'pRes',defaultSpRes,@isnumeric)
                addParameter(inpts,'pErr',defaultSpErr,@isnumeric)
                addParameter(inpts,'ResidualNorm',defaultNormForce,@isnumeric)
                addParameter(inpts,'RotationNorm',defaultNormRot,@isnumeric)
                addParameter(inpts,'TranslationNorm',defaultNormTrans,@isnumeric)
                parse(inpts,varargin{:});



            %time program duration...
            tic %start program timer
            import org.opensim.modeling.*


            if ~exist(obj.fileset.optpath,'dir') || ~exist(fullfile(obj.fileset.optpath,'Tasks'),'dir')|| ~exist(fullfile(obj.fileset.optpath,'Results'),'dir')
                mkdir(obj.fileset.optpath); mkdir(fullfile(obj.fileset.optpath,'Tasks'));
                mkdir(fullfile(obj.fileset.optpath,'Results'));
            end

            newtaskSetFilename = fullfile(obj.fileset.optpath,'Tasks',['optItr_',num2str(0),'_Tasks.xml']);
            copyfile(fullfile(obj.fileset.trialpath,obj.fileset.taskfile),newtaskSetFilename);
            copyfile(fullfile(obj.fileset.trialpath,obj.fileset.actuatorfile),fullfile(obj.fileset.optpath,obj.fileset.actuatorfile));
            copyfile(fullfile(obj.fileset.trialpath,obj.fileset.extloadsetup),fullfile(obj.fileset.optpath,obj.fileset.extloadsetup));
            copyfile(fullfile(obj.fileset.trialpath,obj.fileset.kinfile),fullfile(obj.fileset.optpath,obj.fileset.kinfile));
            copyfile(fullfile(obj.fileset.trialpath,obj.fileset.grffile),fullfile(obj.fileset.optpath,obj.fileset.grffile));


            %=================================
            %Define initial tracking weights
            %=================================
            % define model corrdinates not to include on tracking opt
            coordsToExclude = {'mtp_angle_r','mtp_angle_l'};

            Sresults_file = fullfile(obj.fileset.optpath,'opt_results.mat');
            if exist(Sresults_file) % delete old TWSA file and start from scratch
                if inpts.Results.overwrite
                    delete(Sresults_file);
                end
            end
            
            if exist(Sresults_file) % load current progress from results file and continue
                load(Sresults_file);
%                 i = i+1;
                itr = i;
            else
            %========================
            % Set parameters
            %========================
                %Set objective function parameters (altering paramters will set higher or
                    %lower precedence on residuals, and errors)

                S.wRes = inpts.Results.wRes;  %**multiplication factor
                S.wErr = inpts.Results.wErr;
                S.pRes = inpts.Results.pRes; %**exponential factor
                S.pErr = inpts.Results.pErr;

                
                % load model and get mass
                mod = Model(fullfile(obj.fileset.trialpath,obj.fileset.adjname));
                state = mod.initSystem();
                body_mass = mod.getTotalMass(state);
                
                if inpts.Results.ResidualNorm == 0
                    optResidNorm = 1.3*body_mass*9.81; % assume max force due to body mass
                else
                    optResidNorm = inpts.Results.ResidualNorm;
                end
                
                % set normalization values
                S.forceNormF = 0.05*optResidNorm; % assume 5% of peak external force (grf)
                S.momentNormF = 0.01*optResidNorm; % assume ~1% of peak external force*COM height
                S.rotNormF = inpts.Results.RotationNorm; % tolerated rotational error (kinematic confidence)
                S.transNormF = inpts.Results.TranslationNorm; % tolerated translational error

                % load default task values 
                taskFileName = fullfile(obj.fileset.trialpath,obj.fileset.taskfile);
%                 readTrackingWeights(obj,taskSetFilename,inpts.Results.RotateNormFac,inpts.Results.TransNormFac)
                S.trackingWeights = obj.readTrackingWeights(taskFileName,S.rotNormF,S.transNormF);%,coordsToExclude);
                S.xnew = S.trackingWeights;
                S.fnew = Inf;
                
                %Set iteration limit
                % Original value was 200
                S.thresh = inpts.Results.fcn_threshold;
                S.i_min = inpts.Results.min_itrs;
                S.i_max = inpts.Results.max_itrs;
                itr=0;

            %=============================
            %Run RRA with default values
            %=============================

                %load RRATool to assess trial variables and update RRA tool for opt itrs.
                rratool = RRATool(fullfile(obj.fileset.trialpath,obj.fileset.rrasetupfile));

                %set RRA parameters (tool name, model files, task list name, results dir)
                rratool.setName(['optItr_',num2str(itr)]);
                rratool.setModelFilename(fullfile(obj.fileset.trialpath,obj.fileset.adjname)); %rratool.setModelFilename(fullfile(obj.fileset.trialpath,obj.fileset.adjmodelfile_massonly));
                rratool.setOutputModelFileName(fullfile(obj.fileset.optpath,obj.fileset.adjname));
                rratool.setResultsDir(fullfile(obj.fileset.optpath,'Results'));
                rratool.setTaskSetFileName(newtaskSetFilename);
                rratool.setMaximumNumberOfSteps(20000);
                rratool.setAdjustCOMToReduceResiduals(false);
                % print rra setup file 
                rraSetupFile = fullfile(obj.fileset.optpath,['optItr_',num2str(itr),'_Setup.xml']);
                rratool.print(rraSetupFile);
                %Clear the tool
                clear rratool

                try
                    apivers = char(org.opensim.modeling.opensimCommon.GetVersion());
                catch 
                    % if error thrown, version might be 3.3
                    apivers = '3.3';
                end
                if startsWith(apivers,'4.')
                    CommandRRA = ['opensim-cmd run-tool ', char(rraSetupFile)];
                else
                    CommandRRA = ['rra -S "',char(rraSetupFile),'"'];
                end
                system(CommandRRA);


            %====================================
            %Calculate objective function values
            %====================================

                % calculate objective function values from base rra trial    
                S = obj.calculateObjectiveFunction(S,itr);
                S.xcurrent = S.xnew;

                %Initialize storage
                S.TestedSolutions = zeros(length([S.trackingWeights.value]),S.i_max);
                S.ObjFuncValues = zeros(1,S.i_max);

                %Store default results
                S.ObjFuncValues(1) = S.fnew;
                S.fcurrent = S.fnew;
                S.TestedSolutions(:,1) = [S.trackingWeights.value]';

            %====================================
            %Run RRA optimization iterations
            %====================================
                i = 1;
            end

            %loop through rra iterations
            while i <= S.i_max

                if i >= S.i_min
                   if min(S.ObjFuncValues(1:i)) < S.thresh
                       break;
                   end
                end
                % exectute task optimization famework (preturb task values, run rra
                %   iteration, calculate objective function new value
                [i,S] = obj.executeRRAOptLoop(S,i);

                % exit optimization if we have found an acceptable solution after a
                % minimum # of iterations.


            end %end while iterations

        %====================================
        %Run Final RRA Solution
        %====================================
            % Find the best solution and re-run it to make sure our results are current
            idx = find(S.ObjFuncValues==min(S.ObjFuncValues(1:i)));
            bestSoln = S.TestedSolutions(:,idx);

            % Assign the tracking weight values
            S.xbest = S.xnew; %Initialize
            for i_coord=1:length({S.xnew.name})
                S.xbest(i_coord).value = bestSoln(i_coord,1);
            end

            % Create setup file and task set with final tracking weights
            S.trackingWeights = S.xbest;
            taskSetFilenametemplate = fullfile(obj.fileset.trialpath,'RRA_Tasks.xml');
            taskSetFilenamenew = fullfile(obj.fileset.optpath,'Tasks','RRA_Final_Tasks.xml');
            newtaskSetFilename = obj.writeTrackingWeights(taskSetFilenametemplate,taskSetFilenamenew,S.xbest);



            %======================================
            % Run RRA with current iteration values
            %======================================

            %load RRATool to assess trial variables and update RRA tool for opt itrs.
            rratool = RRATool(fullfile(obj.fileset.trialpath,obj.fileset.rrasetupfile));

            % update rra steup tool parameters
            rratool.setName('RRA');
            rratool.setModelFilename(fullfile(obj.fileset.trialpath,obj.fileset.adjname));
            rratool.setOutputModelFileName(fullfile(obj.fileset.trialpath,obj.fileset.optname));
            rratool.setResultsDir(obj.fileset.finalpath);
            rratool.setTaskSetFileName(newtaskSetFilename);
            rratool.setMaximumNumberOfSteps(20000);
            rraSetupFile = fullfile(obj.fileset.optpath,'RRA_Final_Setup.xml');
            rratool.print(rraSetupFile);

            %Clear the tool
            clear rratool

            try
                apivers = char(org.opensim.modeling.opensimCommon.GetVersion());
            catch 
                % if error thrown, version might be 3.3
                apivers = '3.3';
            end
            if startsWith(apivers,'4.')
                CommandRRA = ['opensim-cmd run-tool ', char(rraSetupFile)];
            else
                CommandRRA = ['rra -S "',char(rraSetupFile),'"'];
            end
            system(CommandRRA);


            diary off
        end
        
        
    end
    
    methods (Access = private)
        %**************************************************************************
        % Function: Parse current tracking weights from tracking file
        function trackingWeights = readTrackingWeights(obj,taskSetFilename,RotNormFac,TransNormFac)%,coordsToExclude)
            import org.opensim.modeling.*
            %Default normalization factors
            rmsNormFactor_trans = TransNormFac;
            rmsNormFactor_rot = RotNormFac*(pi/180);

            %Grab the xml document that defines the tracking weights
            RRATask = CMC_TaskSet(taskSetFilename);
            num = RRATask.getSize();


            %Parse tracking weights into structure 
            n = 1;
            for i_weight=0:num-1

                currWeightName = char(RRATask.get(i_weight).getName());
        %         RRATask.get(i_weight).setWeight(1,1,1); % delete this line to use original weights
                currWeightValue = RRATask.get(i_weight).getWeight(0);

                trackingWeights(n).name = currWeightName;
                trackingWeights(n).value = currWeightValue;
                trackingWeights(n).rmsErr = Inf;
                if contains(lower(currWeightName),{'pelvis_tx','pelvis_ty','pelvis_tz'})
                    trackingWeights(n).rmsNormFactor = rmsNormFactor_trans;
                else
                    trackingWeights(n).rmsNormFactor = rmsNormFactor_rot;
                end


                n = n+1;

            end

        end %readTrackingWeights function


        %**************************************************************************
        % Function: Write task Set file with defined list of task weights
        function taskSetFilenameNew = writeTrackingWeights(obj,taskSetFilenameOld,taskSetFilenameNew,trackingWeights)
            import org.opensim.modeling.*
            %Grab the xml document that defines the tracking weights
            RRATask = CMC_TaskSet(taskSetFilenameOld);
            num = RRATask.getSize();

            %Parse tracking weights into structure 
            for i_weight=0:num-1
                % assign task weight for each coordinate in optfunction
                coorname = char(RRATask.get(i_weight).getName());
                loc = strmatch(coorname,{trackingWeights.name});
                if ~isempty(loc)
                    RRATask.get(i_weight).setWeight(trackingWeights(loc).value,1,1);
                end
            end

            %write the xml tasks file
            RRATask.print(taskSetFilenameNew);

        end %writeTrackingWeights function


        %**************************************************************************
        % Function: calculate objective function value for RRA iterations
        function [S] = calculateObjectiveFunction(obj,S,itr)
            %The objective function value is returned in the field 'fnew' of the
            %structure S.
            import org.opensim.modeling.*
            %=========================================
            % Import the actuation forces and moments
            %=========================================

            % JS
            % normalization factors for the residuals, adapted from OpenSim
            % Guidelines. Assume peak force is ~1.3 body weights. May
            % update to read in forces file.

%             forceNormF = 0.05*ResNormFactor; % (Osim Guidelines are < 5 percent max ext force)
%             momentNormF = forceNormF/5; % (Osim guidelines are < 1 percent COM height*max ext force - assume COM height of ~1m)

            if itr == 0   
                filename = fullfile(obj.fileset.optpath,'Results',['optItr',num2str(itr),'_Actuation_force.sto']);  
            else 
                filename = fullfile(obj.fileset.optpath,'Results',['optItr','_Actuation_force.sto']);
            end
        %     
            if exist(filename,'file') %if RRA runs to completion, calculate objective function value from itration 
                residuals = importdata(filename);
                Mdata = residuals.data(:,contains(residuals.colheaders,{'MX','MY','MZ'}));
                Fdata = residuals.data(:,contains(residuals.colheaders,{'FX','FY','FZ'}));
                nresiduals = 6;

                % calculate weighted Sum of RMS forces term, normalized to OpenSim guidelines
                S.sumRMSForces = (rms(Fdata(:,1))/S.forceNormF)^S.pRes+(rms(Fdata(:,2))/S.forceNormF)^S.pRes+(rms(Fdata(:,3))/S.forceNormF)^S.pRes;
                % sumMaxForces = (max(abs(data(:,1)))/5)^S.pRes+(max(abs(data(:,2)))/5)^S.pRes+(max(abs(data(:,3)))/5)^S.pRes;

                % calculate weighted Sum of RMS moments term, normalized to OpenSim guidelines
                S.sumRMSMoments = (rms(Mdata(:,1))/S.momentNormF)^S.pRes+(rms(Mdata(:,2))/S.momentNormF)^S.pRes+(rms(Mdata(:,3))/S.momentNormF)^S.pRes;
                % Total sum of RMS forces and moments terms
                S.sumRMSResiduals = S.sumRMSForces+S.sumRMSMoments;
                % sumRMSResiduals = sumMaxForces+sumRMSMoments;
                

                
                % Import the Errors
                if itr == 0            
                    filename = fullfile(obj.fileset.optpath,'Results',['optItr',num2str(itr),'_pErr.sto']);
                else
                    filename = fullfile(obj.fileset.optpath,'Results',['optItr','_pErr.sto']);
                end
                trackingErr = importdata(filename);

                rmsErr = zeros(size([S.xnew.value]));
                for i_coord=1:length({S.xnew.name})

                    loc = contains(trackingErr.colheaders,S.xnew(i_coord).name);
                    if sum(loc) > 1
                        loc = strmatch(S.xnew(i_coord).name,trackingErr.colheaders,'exact');
                    end
                    rmsErr(i_coord) = (rms(trackingErr.data(:,loc))/S.xnew(i_coord).rmsNormFactor)^S.pErr;
                    S.xnew(i_coord).rmsErr = rms(trackingErr.data(:,loc));

                end

                S.sumRMSErrors = sum(rmsErr);

                % Output the Objective Function
                ncoords = length({S.xnew.name});

                % calculate cost function
                S.fnew = S.wRes*(1/nresiduals)*S.sumRMSResiduals + S.wErr*(1/ncoords)*S.sumRMSErrors;

            else %if RRA iteration does not run to completion set new opt funt value to inf
                S.fnew=inf;
                for i_coord=1:length({S.xnew.name})
                    %Assign maximum value for rmserror used to generate next solution of task values
                    S.xnew(i_coord).rmsErr = 0;
                end
            end

        end %calculateObjectiveFunction function


        
        % Function: Run RRA iterations with course optimization for task weights
        function S_itr = RHCP_itr(obj,S,itr)

            import org.opensim.modeling.*

            % Generate New Set of Task values

            %Randomly generate a new solution, but it must not be one that has been
            %previously tested
            xunique = false;
            while xunique==false
                %Bias the shift based on the tracking error
                for i_coord=1:length({S.xcurrent.name})
        %             if fIsCellMember(S.xcurrent(i_coord).name,{'pelvis_tx','pelvis_ty','pelvis_tz'})
                    if any(contains(lower({'pelvis_tx','pelvis_ty','pelvis_tz'}),S.xcurrent(i_coord).name))
                        % bounds adjusted by JS to evaluate how much this
                        % influences resulting tracking error.
                                     
                        lb = 0.5*S.transNormF;
                        ub = S.transNormF;
%                         lb = 0.01;
%                         ub = 0.03;
                    else
                        lb = 0.5*S.rotNormF*(pi/180); % was 1 deg
                        ub = S.rotNormF*(pi/180);    % was 3 deg
                    end

                    %Bias the tracking weight change
                    if S.xcurrent(i_coord).rmsErr<lb
                        %If we are in the green, tend to decrease the weight
            %             t = randsample([-1,-1,-1,0,1],1);
                        t = randsample([-2,-1,-1,0,1],1); % JS, make it loosen faster
                    elseif S.xcurrent(i_coord).rmsErr>ub
                        %If we are in the red, tend to increase the weight
            %             t = randsample([-1,0,1,1,1],1);
                        t = randsample([-1,0,1,1,2],1); % JS, make it tighten faster
                    else
                        %Otherwise, equal chances
            %             t = randsample([-1,0,1],1);
                        t = randsample([-2,0,-1,0,1,0,2],1); % JS, give it greater change
                    end

                    %Use finer resolution as we get further along
                    if itr<=floor(S.i_max/2)
                        base = 1.5;
                    elseif itr>floor(S.i_max/2) && itr<=floor(3*S.i_max/4)
                        base = 1.25;
                    elseif itr>floor(3*S.i_max/4)
                        base = 1.1;
                    else
                        base = 1.5;
                    end

                    tau = base^t;
                    S.xnew(i_coord).value = tau*S.xcurrent(i_coord).value;

                end %Coordinates

                %Check if this solution has been tested previously
                xmat = repmat([S.xnew.value]',1,S.i_max);
                comp = xmat==S.TestedSolutions;
                if any(sum(comp,1)==length([S.xnew.value]))
                    %If so, pick a different x
                    xunique = false;
                else
                    %Otherwise, keep the new design variables in x
                    xunique = true;
                end
            end

            %=========================================
            % Assign Task set values to Task List
            %=========================================
            S.trackingWeights = S.xnew;
            taskSetFilenametemplate = fullfile(obj.fileset.trialpath,'RRA_Tasks.xml');
            taskSetFilename = fullfile(obj.fileset.optpath,'Tasks',['optItr_',num2str(itr),'_Tasks.xml']);
            newtaskSetFilename = obj.writeTrackingWeights(taskSetFilenametemplate,taskSetFilename,S.trackingWeights);

            %=====================================
            %Run RRA with current iteration values
            %=====================================

            %load RRATool to assess trial variables and update RRA tool for opt itrs.
            rratool = RRATool(fullfile(obj.fileset.trialpath,obj.fileset.rrasetupfile));

            rratool.setName('optItr'); % overwrite existing results to save drive space. Otherwise, append tool name with num2str(itr). JS
            rratool.setModelFilename(fullfile(obj.fileset.trialpath,obj.fileset.adjname));
            rratool.setOutputModelFileName(fullfile(obj.fileset.optpath,obj.fileset.adjname));
            rratool.setResultsDir(fullfile(obj.fileset.optpath,'Results'));
            rratool.setTaskSetFileName(newtaskSetFilename);
            rratool.setMaximumNumberOfSteps(20000);
            rraSetupFile = fullfile(obj.fileset.optpath,['optItr_',num2str(itr),'_Setup.xml']);
            rratool.print(rraSetupFile);

            %Clear the tool
            clear rratool

            %Run RRA tool from command line inside matlab
            % options = ' -L "C:\Program Files\OpenSim 3.3\plugins\ExpressionBasedCoordinateForce.dll"';
            try
                apivers = char(org.opensim.modeling.opensimCommon.GetVersion());
            catch 
                % if error thrown, version might be 3.3
                apivers = '3.3';
            end
            if startsWith(apivers,'4.')
                CommandRRA = ['opensim-cmd run-tool ', char(rraSetupFile)];
            else
                CommandRRA = ['rra -S "',char(rraSetupFile),'"'];
            end
            system(CommandRRA);

            %------------------------
            %Evaluate RRA results
            %------------------------
            %Calculate new objective function value
%             mod = Model(fullfile(obj.fileset.trialpath,obj.fileset.adjname));
%             state = mod.initSystem();
%             body_mass = mod.getTotalMass(state);
            S_itr = obj.calculateObjectiveFunction(S,itr);

            %Store the solutions we have explored
            S_itr.TestedSolutions = [];
            S_itr.TestedSolutions(:,1) = [S.xnew.value]';
            S_itr.ObjFuncValues = S_itr.fnew;

        end


        %****************************************************************************
        % Function: Framework for initalizing optimization loop using parallel or std
        function [i,S] = executeRRAOptLoop(obj,S,i)
            import org.opensim.modeling.*

            itr=i; % itr = 1; %original line (does not keep every OPT result)
            %Display current iteration
            fprintf('Iteration Number = %d\n\n',itr)

            if itr>1
                disp(['Current OF value: ',num2str(S.ObjFuncValues(itr))]);
                disp(['Initial OF value: ',num2str(S.ObjFuncValues(1))]);
            end
            disp(' ')

            %Generate new RRA solution
            S_itr = obj.RHCP_itr(S,itr);

            %---------------------------------------------------------------------
            % update the full matrix of optimization variables with values from
            % each parallel computed trial
            S.TestedSolutions(:,i+1) = S_itr.TestedSolutions(:,1);
            S.ObjFuncValues(i+1) = S_itr.ObjFuncValues;
            S.sumRMSResiduals(i+1) = S_itr.sumRMSResiduals;
            S.sumRMSErrors(i+1) = S_itr.sumRMSErrors;
            S.sumRMSForces(i+1) = S_itr.sumRMSForces;
            S.sumRMSMoments(i+1) = S_itr.sumRMSMoments;

            %check for improved objective function measures 
            %If we found a better solution, store it
            if S_itr.fnew < S.fcurrent
                S.xcurrent = S_itr.xnew;
                S.fcurrent = S_itr.fnew;
            end
            S_file = fullfile(obj.fileset.optpath,'opt_results.mat');
            clc; 
            i=i+1;
            save(S_file,'S','i');

        end
    end
    
end