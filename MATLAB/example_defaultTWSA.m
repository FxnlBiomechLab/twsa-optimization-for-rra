
% setup some values that we may want to iterate through and save them into
% a structure for convenience.
config.participant = 'Hamner2010_v4_subject01'; % subject label
config.conditions = {'Run_20002','Run_30002','Run_40002','Run_50002'} % condition labels
config.trialnums = 1:3 % how many trials, assume each condition has the same number

for c = 1%1:4 % you can use parfor if you have the parallel computing toolbox to run all conditions simultaneously
    % uses the Run_20002 condition for the example
    
    %% analyses
    import rraTools.*   % load the class definitions
    for t = config.trialnums
        
        mydir = pwd; % get current folder (where code is running from)
        cd('..\') % move up one folder (assuming file structure from downloaded repository)
        trialpath = fullfile(pwd, 'HamnerOpt\subject01\',config.conditions{c},['Trial_' num2str(t)]); % construct the full system path to the trial folder.
        cd(mydir) % move back to code folder
        
        r = rrasetup(trialpath,config.participant,[]); % initialize an object of the rrasetup class
        r.fileset.kinfile = [config.conditions{c}, '_IK.mot']; % update the name of the IK motion file
        r.fileset.grffile = [config.conditions{c}, '_GRF.mot']; % update the name of the ground reaction force motion file
        r.toolsettings.kinfile = [config.conditions{c}, '_IK.mot'];

        %%
        % write tracking task set
        r.writeTasksFile() 
        % write external loads file
        r.writeExtLoads()
        % write ReservesFile to match specified model. 
        r.writeReservesFile()
        %% Run the first iteration of RRA 
        r = r.runInitialRRA() % swap for the line below and you don't need to call the writeTasksFile, writeExtLoads, and writeReservesFile methods first.
%         r = r.runInitialRRA('CreateTasks',true,'CreateReserves',true,'CreateExtLoads',true)
        %% Run remaining mass iterations
        r = r.runMassItrsRRA()
        %% setup and run the TWSA       
        % run the TWSA with defaults. 
        r.optimizeTrackingWeights()
    end
end

