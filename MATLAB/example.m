
% setup some values that we may want to iterate through
config.participant = 'Hamner2010_v4_subject01';
config.conditions = {'Run_20002','Run_30002','Run_40002','Run_50002'}
config.trialnums = 1:3

for c = 1:4 % you can use parfor if you have the parallel computing toolbox to run all conditions simultaneously

    %% analyses
    addpath('..\HamnerOpt\')
    import rraTools.*   
    import org.opensim.modeling.*
    for t = config.trialnums
        
        mydir = pwd; % get current folder (where code is running from)
        cd('..\') % move up one folder
        % get system path to data folder
        trialpath = fullfile(pwd, 'HamnerOpt\subject01\',config.conditions{c},['Trial_' num2str(t)]);
        cd(mydir) % move back to code folder
        
        r = rrasetup(trialpath,config.participant,[]);
        r.fileset.kinfile = [config.conditions{c}, '_IK.mot'];
        r.fileset.grffile = [config.conditions{c}, '_GRF.mot'];
        r.toolsettings.kinfile = [config.conditions{c}, '_IK.mot'];

        %%
        r.writeTasksFile('Kp',1600,'UniformWeights',true)
        % write external loads file
        r.writeExtLoads()
        % write ReservesFile to match specified model. Change the value
        % after 'ResidualForce' to increase or decrease the optimal force
        % of residual actuators (FX, FY, FZ, MX, MY, MZ). Change the value
        % after 'ReserveForce' to increase or decrease the ideal torque
        % actuators applied at each joint.
        r.writeReservesFile('ReserveForce',2000,'ResidualForce',75)
        %% Run the first iteration of RRA 
        r = r.runInitialRRA()
        %% Run remaining mass iterations
        r = r.runMassItrsRRA()
        %% setup and run the TWSA
                
        % run the TWSA with defaults. 
        r.optimizeTrackingWeights()
    end
end

%%
