classdef rrasetup    
    
    % Public class properties. Can be set explicitly, or based on the
    % constructor to use defaults.
    properties
        participant %{mustBeText}
        condition %{mustBeText}
        mass %{mustBeNumeric}
        trialpath
        setupsfolder
        modelname
        modfullfile
        fileset
        toolsettings
        initDelMass
        totalDelMass
        numMassItrs
    end
    
    methods % public methods
        
        % Constructor. Inputs are used to define relevant directories, file
        % names, and initial properties of the class instance.
        function obj = rrasetup(trialpath,participant,condition,mass)
%             import rrafiles
%             import rraoptions
            
            obj.participant = participant; % text participant tag
            obj.condition = condition; % text condition tag
            obj.mass = mass; % participant mass
            obj.trialpath = trialpath; % construct the full path to the trial folder
            if isempty(obj.condition)
                obj.modelname = [obj.participant, '.osim']; % construct the osim model string
            else
                obj.modelname = [obj.participant, '_', obj.condition, '.osim']; % construct the osim model string
            end
            obj.modfullfile = fullfile(obj.trialpath,obj.modelname); % construct the full path name for the osim model
            obj.fileset = simTools.rrafiles(trialpath, participant, condition); % populate the file set that will be used by the RRATool
            obj.toolsettings = simTools.rraoptions(0,0,true,true,... % specify the initial settings for the RRATool
                "torso",obj.trialpath,obj.modelname,obj.fileset.actuatorfile,...
                obj.fileset.extloadsetup,obj.fileset.kinfile,obj.fileset.taskfile,...
                obj.fileset.resultspath,obj.fileset.outname,obj.fileset.rrasetupfile); 
            
            obj.initDelMass = 0; % initialize property to record initial mass adjustment
            obj.totalDelMass = 0; % record total mass adjustments for all iterations
            obj.numMassItrs = 0; % initialize property to count mass adjustment iterations
        end
        
        function btoolprinted = writeRRATool(obj)
            % FUNCTION WRITERRATOOL() creates and prints an RRA setup file
            % based on the settings specified in the toolsettings property
            % of the class instance.
            
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
            rraTool.setTaskSetFileName(fullfile(obj.toolsettings.trialpath,obj.toolsettings.taskfile));
            rraTool.setOutputModelFileName(fullfile(obj.toolsettings.trialpath,obj.toolsettings.outname));
            rraTool.setResultsDir(obj.toolsettings.resultspath);
            btoolprinted = rraTool.print(fullfile(obj.toolsettings.trialpath,obj.toolsettings.rrasetupfile));
        end
        
        function obj = initialRRA(obj,varargin)
            % FUNCTION obj = runInitialRRA() performs the first iteration of RRA
            % and adjusts model masses based on tool output. Optional name
            % value pair inputs to create tracking tasks, reserve
            % actuators, and external loads files can be specified. 
            % Note: this method should be called as "obj =
            % obj.runInitialRRA()" so that updates to the properties are
            % retained through iterations. 
            % 
            % 'CreateTasks', true
            % 'CreateReserves', true
            % 'CreateExtLoads', true
            % Defaults if not specified are false for each. In this case,
            % each method can be called separately to create the necessary
            % files, or each file can be copied into the study directory.
            %
            defaultLoads = false;
            defaultReserves=false;
            defaultTasks = false;
            inpts = inputParser;
                addRequired(inpts,'obj')
                addOptional(inpts,'CreateTasks',defaultTasks,@islogical)
                addOptional(inpts,'CreateReserves',defaultReserves,@islogical)
                addOptional(inpts,'CreateExtLoads',defaultLoads,@islogical)

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
            mydir = cd(); % remember current directory
            cd(obj.fileset.resultspath); % move to results folder to run analysis
            % create string to send to the command line
% This line for OpenSim v3.#             CommandRRA = ['rra -S "',char(fullfile(obj.fileset.trialpath,obj.fileset.rrasetupfile))];
            CommandRRA = ['opensim-cmd run-tool ', char(fullfile(obj.fileset.trialpath,obj.fileset.rrasetupfile))];

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
            % FUNCTION RUNMASSITRSRRA() performs up to 10 iterations of RRA
            % until the recomended mass change is less than the threshold
            % 0.001. Note: call the method as "obj = obj.runMassItersRRA()"
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
            obj.toolsettings.comBody = "torso";
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

                
                mydir = cd();
                cd(obj.toolsettings.resultspath);
                
                %string to send to the command line
                CommandRRA = ['opensim-cmd run-tool ', char(fullfile(obj.fileset.trialpath,obj.fileset.masssetupfile))];
%                 CommandRRA = ['rra -S "',char(fullfile(obj.fileset.trialpath,obj.fileset.masssetupfile))];%,'"',options];
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
            import org.opensim.modeling.*

            %Read recommended mass adjustment
            fid = fopen(fullfile(obj.toolsettings.resultspath,'out.log'));
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
            if contains(apivers,'4.')
                res = model.scale(state,scaleset,true,newMass); % OpenSim V4.2
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
            % FUNCTION WRITETASKSFILE(obj,varargin) 
            % Writes a tracking tasks for RRA given the model provided. 
            % Reads coordinates from model and assigns tracking tasks to 
            % all non-locked independent coordinates based on user
            % specified values or defaults.
            %
            % Optional Inputs
            %   SKIPCOORDINATES - a cell array of non-constrained
            %   coordinates that should not be included in the tracking
            %   tasks. Provided as a name value pair (e.g.
            %   writeTasksFile('SkipCoordinates',{'bp_tx','bp_ty'})
            %   KP - numeric value for the proportional gain for all
            %   tracking tasks (default is 1600). Provided as a name value
            %   pair (e.g. writeTasksFile('Kp',100)). Note, critical
            %   damping will always be enforced by setting Kv = 2*sqrt(Kp).
            %   UNIFORMWEIGHTS - a boolean entry that sets all tracking
            %   weights to 1 (default is false). Use name value pair
            %   entry. e.g. writeTasksFile('UniformWeights',true)
            %   USERWEIGHTS - a cell array containing the coordinate string
            %   and desired weight for any non-constrained coordinates.
            %   Coordinates not named in this variable will use the default
            %   weights. To use the same weight for each side, a partial
            %   coordinate name can be specified (e.g. {'ankle'} rather than
            %   {'ankle_l','ankle_r'}) Names and weights should be supplied
            %   in the following syntax "{ {'ankle','knee','hip';25,10,5}
            %   }" to be parsed correctly. Use name value pair entry (e.g.
            %   writeTasksFile('UserWeights',{ {name_array;weight_array} })
            %   Note, user supplied weights are ignored if 'UniformWeights'
            %   is set to true.
            %
            
            defaultKp = 1600;
            defaultCoords = {'bp_tx','bp_ty'};
            defaultUniform = false;
            inpts = inputParser; % manage inputs 
                addRequired(inpts,'obj')
                addOptional(inpts,'SkipCoordinates',defaultCoords)
                addOptional(inpts,'Kp',defaultKp,@isnumeric)
                addOptional(inpts,'UniformWeights',defaultUniform,@islogical)
                addOptional(inpts,'UserWeights',{}) % set defualt to emtpy cell

            parse(inpts,obj,varargin{:}); % parse the inputs and assign defaults or user supplied values

            obj = inpts.Results.obj; % need to assign self
            skipCoords = inpts.Results.SkipCoordinates;
            uniformWeights = inpts.Results.UniformWeights;
            userNames = {}; % initialize as empty
            userWeights = {}; 
            if ~isempty(inpts.Results.UserWeights) % user has specified weights
                userNames = inputs.Results.UserWeights{1}(1,:); % split the coordinate names from the cell
                userWeights = inputs.Results.UserWeights{1}(2,:); % split the matched weights from the cell
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
                            curTask.setWeight(1,1,1);
                        else % weight more important coordinates higher
                            userIdx = contains(userNames,cname); 
                            if any(userIdx) % check if coordinate weight has been provided and assign the specified weight
                                curTask.setWeight(userWeights(userIdx),1,1);
                            elseif contains(cname,'pelvis')
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
                                curTask.setWeight(100,1,1);
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
        % FUNCTION WRITERESERVESFILE(mod_dir,mod_name,analysis_type) 
        % Writes a residual actuators file and tracking tasks for RRA or CMC given
        % the model provided. Reads coordiinates from model and assigns default
        % reserve actuators and tracking tasks to all non-locked independent
        % coordinates. Both files are saved into the model directory "mod_dir".
        %
        % Inputs
        %   mod_dir - directory where model is saved. Usually the trial directory
        %   where the analysis is to be performed.
        %   mod_name - name of the .osim file
        %   analysis_type - string declaring either "CMC" or "RRA"

          
            defaultReserve = 1600;
            defaultResidual = 100;
            defaultCoords = {'bp_tx','bp_ty'};
            inpts = inputParser;
                addRequired(inpts,'obj')
                addOptional(inpts,'SkipCoordinates',defaultCoords)
                addOptional(inpts,'ReserveForce',defaultReserve,@isnumeric)
                addOptional(inpts,'ResidualForce',defaultResidual,@isnumeric)

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
                    if contains(cname,'pelvis')
                        cm = Vec3;
                        cm = cmod.getBodySet().get("pelvis").getMassCenter(); % v3.3 - cmod.getBodySet().get("pelvis").getMassCenter(cm);
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
                            curAct.set_body("pelvis")
                            curAct.set_direction(Vec3(1,0,0))
                            curAct.set_point(cm);
                            curAct.set_point_is_global(false)
                            curAct.set_force_is_global(true)
                            curAct.setName('FX');
                        elseif contains(cname,'ty')
                            curAct = PointActuator();
                            curAct.setOptimalForce(residual_force);
                            curAct.set_body("pelvis")
                            curAct.set_direction(Vec3(0,1,0))
                            curAct.set_point(cm);
                            curAct.set_point_is_global(false)
                            curAct.set_force_is_global(true)
                            curAct.setName('FY');
                        elseif contains(cname,'tz')
                            curAct = PointActuator();
                            curAct.setOptimalForce(residual_force);
                            curAct.set_body("pelvis")
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
            import org.opensim.modeling.*

            extLoads = ExternalLoads();
            exf = ExternalForce();
            exfl = ExternalForce();

            exf.setName('ExternalForce_1');
%             exf.set_isDisabled(false); % v3.3
            exf.setAppliedToBodyName('calcn_r');
            exf.setForceExpressedInBodyName('ground');
            exf.setPointExpressedInBodyName('ground');
            exf.setForceIdentifier ('ground_force_v');
            exf.setPointIdentifier ('ground_force_p');
            exf.setTorqueIdentifier('ground_torque');
            exf.set_data_source_name(fullfile(obj.fileset.trialpath,obj.fileset.grffile));
            extLoads.cloneAndAppend(exf);


            exfl.setName('ExternalForce_2');
%             exfl.set_isDisabled(false); % v3.3
            exfl.setAppliedToBodyName('calcn_l');
            exfl.setForceExpressedInBodyName('ground');
            exfl.setPointExpressedInBodyName('ground');
            exfl.setForceIdentifier ('l_ground_force_v');
            exfl.setPointIdentifier ('l_ground_force_p');
            exfl.setTorqueIdentifier('l_ground_torque');
            exfl.set_data_source_name(fullfile(obj.fileset.trialpath,obj.fileset.grffile));
            extLoads.cloneAndAppend(exfl);

            extLoads.setDataFileName(fullfile(obj.fileset.trialpath,obj.fileset.grffile));
            extLoads.setExternalLoadsModelKinematicsFileName(fullfile(obj.fileset.trialpath,obj.fileset.kinfile));
            b = extLoads.print(fullfile(obj.fileset.trialpath,obj.fileset.extloadsetup));
        end
        
        function S = optimizeTrackingWeights(obj,varargin)
            %**************************************************************************
            % OPTIMIZE RESIDUAL FORCES AND TRACKING ERRORS
            %**************************************************************************
            % RRA Optimization scheme used to reduce residuals and kinematic errors
            %   through adjusted task weights and actuator opt forces
            % INPUTS: name - participant label (used in file structure) 
            %         trial - movement trial label (used in file structure)
            %         OPTFILES - global variable loaded within function to set file
            %             paths for all relevant supporting files including base path for
            %             files, RRA file paths, optimization iteration structure


            %   Developed by Nathan Pickle October 12, 2016 at Colorado School of Mines
            %   Code adapted by Amy Hegarty Febuary 14, 2017
            %   Further modifications by Jordan Sturdy between 2019 and 2021
            
            % setup
            defaultMass = 75;
            defaultMinItrs = 25;
            defaultMaxItrs = 50;
            defaultThresh = 2;
            defaultSwRes = 1; 
            defaultSwErr = 3;
            defaultSpRes = 3;
            defaultSpErr = 4;

            inpts = inputParser;
                addParameter(inpts,'min_itrs',defaultMinItrs,@isnumeric)
                addParameter(inpts,'max_itrs',defaultMaxItrs,@isnumeric)
                addParameter(inpts,'fcn_threshold',defaultThresh,@isnumeric)
                addParameter(inpts,'body_mass',defaultMass,@isnumeric)
                addParameter(inpts,'wRes',defaultSwRes,@isnumeric)
                addParameter(inpts,'wErr',defaultSwErr,@isnumeric)
                addParameter(inpts,'pRes',defaultSpRes,@isnumeric)
                addParameter(inpts,'pErr',defaultSpErr,@isnumeric)
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
            if exist(Sresults_file) % load current progress from results file and continue
                load(Sresults_file);
%                 i = i+1;
                itr = i;
            else
            %========================
            % Set parameters
            %========================
                %Set objective function parameters (altering paramters will set higher or
                    %lower precedence on residuals, and errors

                S.wRes = inpts.Results.wRes;  %**multiplication factor
                S.wErr = inpts.Results.wErr;
                S.pRes = inpts.Results.pRes; %**exponential factor
                S.pErr = inpts.Results.pErr;

                % load default task values 
                taskFileName = fullfile(obj.fileset.trialpath,obj.fileset.taskfile);
                S.trackingWeights = obj.readTrackingWeights(taskFileName);%,coordsToExclude);
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

                %Run RRA tool from command line inside matlab
            %     options = ' -L "C:\Program Files\Opchar(rraSetupFile)enSim 3.1\plugins\ExpressionBasedCoordinateForce.dll"';
                CommandRRA = ['opensim-cmd run-tool ', char(rraSetupFile)];

                system(CommandRRA);%,'"',options]);


            %====================================
            %Calculate objective function values
            %====================================

                % calculate objective function values from base rra trial
                mod = Model(fullfile(obj.fileset.trialpath,obj.fileset.adjname));
                state = mod.initSystem();
                body_mass = mod.getTotalMass(state);
                
                S = obj.calculateObjectiveFunction(S,itr,body_mass);
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
                [i,S] = obj.executeRRAOptLoop(S,i,inpts.Results.body_mass);

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

            %Run RRA tool from command line inside matlab
            % this line for OpenSim v3.#     options = ' -L "C:\Program Files\OpenSim 3.1\plugins\ExpressionBasedCoordinateForce.dll"';
            CommandRRA = ['opensim-cmd run-tool ', char(rraSetupFile)];
            system(CommandRRA);%,options]);

            diary off
        end
        
        
    end
    
    methods (Access = private)
        %**************************************************************************
        % Function: Parse current tracking weights from tracking file
        function trackingWeights = readTrackingWeights(obj,taskSetFilename)%,coordsToExclude)
            import org.opensim.modeling.*
            %Default normalization factors
            rmsNormFactor_trans = 0.02;
            rmsNormFactor_rot = 2*(pi/180);

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
                if contains(currWeightName,{'pelvis_tx','pelvis_ty','pelvis_tz'})
                    trackingWeights(n).rmsNormFactor = rmsNormFactor_trans;
                else
                    trackingWeights(n).rmsNormFactor = rmsNormFactor_rot;
                end

                if contains(currWeightName,{'pelvis_tx','pelvis_ty','pelvis_tz','flex_extension','lat_bending','axial_rotation','L5_S1_FE','L5_S1_LB','L5_S1_AR'})
                    %Increase penalty on pelvis and lumbar tracking
                    trackingWeights(n).rmsNormFactor = 0.5*trackingWeights(n).rmsNormFactor;
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
        function [S] = calculateObjectiveFunction(obj,S,itr,mass)
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
            forceNormF = 1.3*9.81*mass*0.05; % 5 percent body_weight * 1.3 (Osim Guidelines are < 5 percent max ext force)
            momentNormF = forceNormF/5; % 1 percent body_weight * 1.3 (Osim guidelines are < 1 percent COM height*max ext force)

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

                % Sum of RMS forces, normalized to OpenSim guidelines
                S.sumRMSForces = (rms(Fdata(:,1))/forceNormF)^S.pRes+(rms(Fdata(:,2))/forceNormF)^S.pRes+(rms(Fdata(:,3))/forceNormF)^S.pRes;
                % sumMaxForces = (max(abs(data(:,1)))/5)^S.pRes+(max(abs(data(:,2)))/5)^S.pRes+(max(abs(data(:,3)))/5)^S.pRes;

                % Sum of RMS moments, normalized to OpenSim guidelines
                S.sumRMSMoments = (rms(Mdata(:,1))/momentNormF)^S.pRes+(rms(Mdata(:,2))/momentNormF)^S.pRes+(rms(Mdata(:,3))/momentNormF)^S.pRes;
                % Total sum of RMS forces and moments
                S.sumRMSResiduals = S.sumRMSForces+S.sumRMSMoments;
                % sumRMSResiduals = sumMaxForces+sumRMSMoments;

                %=========================================
                % Import the Errors
                %=========================================
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

                %##########################################################################

                S.fnew = S.wRes*(1/nresiduals)*S.sumRMSResiduals + S.wErr*(1/ncoords)*S.sumRMSErrors;

                %##########################################################################
            else %if RRA iteration do not run to completion set new opt funt value to inf
                S.fnew=inf;
                for i_coord=1:length({S.xnew.name})
                    %Assign maximum value for rmserror used to generate next solution of task values
                    S.xnew(i_coord).rmsErr = 0;
                end
            end

        end %calculateObjectiveFunction function


        %**************************************************************************
        % Function: Run RRA iterations with course optimization for task weights
        function S_itr = RHCP_itr(obj,S,itr,body_mass)

            import org.opensim.modeling.*

            %=========================================
            % Generate New Set of Task values
            %=========================================

            %Randomly generate a new solution, but it must not be one that has been
            %previously tested
            xunique = false;
            while xunique==false
                %TEST FEATURE
                %Bias the shift based on the tracking error
                for i_coord=1:length({S.xcurrent.name})
        %             if fIsCellMember(S.xcurrent(i_coord).name,{'pelvis_tx','pelvis_ty','pelvis_tz'})
                    if any(contains({'pelvis_tx','pelvis_ty','pelvis_tz'},S.xcurrent(i_coord).name))
                        % bounds adjusted by JS to evaluate how much this
                        % influences resulting tracking error.
                        lb = 0.01;
                        ub = 0.03;
                    else
                        lb = 1*(pi/180);
                        ub = 3*(pi/180);
                    end

                    %Bias the tracking weight change
                    if S.xcurrent(i_coord).rmsErr<lb
                        %If we are in the green, tend to decrease the weight
            %             t = randsample([-1,-1,-1,0,1],1);
                        t = randsample([-2,-1,-1,0,1],1); % JS
                        %disp([S(i_mot).xcurrent(i_coord).name,': green, t=',num2str(t),' rmsErr=',num2str(S(i_mot).xcurrent(i_coord).rmsErr)])
                    elseif S.xcurrent(i_coord).rmsErr>ub
                        %If we are in the red, tend to increase the weight
            %             t = randsample([-1,0,1,1,1],1);
                        t = randsample([-1,0,1,1,2],1); % JS
                        %disp([S(i_mot).xcurrent(i_coord).name,': red, t=',num2str(t),' rmsErr=',num2str(S(i_mot).xcurrent(i_coord).rmsErr)])
                    else
                        %Otherwise, equal chances
            %             t = randsample([-1,0,1],1);
                        t = randsample([-2,0,-1,0,1,0,2],1); % JS
                        %disp([S(i_mot).xcurrent(i_coord).name,': yellow, t=',num2str(t),' rmsErr=',num2str(S(i_mot).xcurrent(i_coord).rmsErr)])
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
            
            CommandRRA = ['opensim-cmd run-tool ', char(rraSetupFile)];
            system(CommandRRA);

            %------------------------
            %Evaluate RRA results
            %------------------------
            %Calculate new objective function value
            mod = Model(fullfile(obj.fileset.trialpath,obj.fileset.adjname));
            state = mod.initSystem();
            body_mass = mod.getTotalMass(state);
            S_itr = obj.calculateObjectiveFunction(S,itr,body_mass);

            %Store the solutions we have explored
            S_itr.TestedSolutions = [];
            S_itr.TestedSolutions(:,1) = [S.xnew.value]';
            S_itr.ObjFuncValues = S_itr.fnew;

        end


        %****************************************************************************
        % Function: Framework for initalizing optimization loop using parallel or std
        function [i,S] = executeRRAOptLoop(obj,S,i,body_mass)
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
            S_itr = obj.RHCP_itr(S,itr,body_mass);

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