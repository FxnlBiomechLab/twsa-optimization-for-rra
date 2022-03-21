
% setup some values that we may want to iterate through and save them into
% a structure for convenience.
config.participant = 'Hamner2010_v4_subject01';
config.conditions = {'Run_20002','Run_30002','Run_40002','Run_50002'}
config.trialnums = 1:3

for c = 1%1:4 % you can use parfor if you have the parallel computing toolbox to run all conditions simultaneously
    % uses the Run_20002 condition for the example
    
    %% analyses
    import rraTools.*   
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
        r.writeTasksFile('Kp',1600,'UniformWeights',true) % uses defaults, but demonstrates how to specify as inputs
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
        %% setup the TWSA with non-default settings
        
        % get peak net ground reaction force and use to normalize residuals
        % in the optimizer
        maxGRF = r.readPeakExtForce()
        
        % specify kinematic error tolerances for normalization. Between 2
        % and 5 degrees (rotation) and 2-3 cm (translation) is likely
        % appropriate, but may vary between labs and data collection
        % systems.
        rotTol = 5; % specify in degrees. TWSA will convert to rad
        transTol = 0.03; % specify in m.
        
        % run the TWSA with all optional inputs assigned. Overwrite any
        % results currently saved in the folder.
        r.optimizeTrackingWeights('overwrite',true,'min_itrs',10,'max_itrs',200,'fcn_threshold',1,...
            'wRes',3,'wErr',2,'pRes',3,'pErr',2,'ResidualNorm',maxGRF,'RotationNorm',rotTol,'TranslationNorm',transTol)
        % 'overwrite' = true: overwite any TWSA results currently in the folder
        % 'min_itrs' = 10: run at least 10 iterations of RRA
        % 'max_itrs' = 200: don't run more than 200 iterations of RRA
        % 'fcn_threshold' = 1: stop if any iterations produce a function
        % value less than 1 after min_itrs
        %
        % 'wRes' = 3,'wErr' = 2,'pRes' = 3,'pErr' = 2: set cost function
        % weights and polynomials
        %
        % 'ResidualNorm' = maxGRF: normalize residuals based on the peak
        % ground reaction force. 5% of maxGRF for forces, 1% for moments
        %
        % 'RotationNorm' = rotTol: normalize rotational tracking errors by
        % 5 degrees
        %
        % 'TranslationNorm' = transTol: normalize translational tracking
        % errors by 3 cm
    end
end

