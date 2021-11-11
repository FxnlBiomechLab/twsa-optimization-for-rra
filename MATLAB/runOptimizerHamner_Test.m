
config.participant = 'Hamner2010_v4_subject01';
config.conditions = {'Run_20002','Run_30002','Run_40002','Run_50002'}
config.mass = 75
config.trialnums = 1:3
rra_results = cell(4,3)
for c = 1:4 % you can use parfor if you have the parallel computing toolbox to run all conditions simultaneously

    %% analyses
    addpath('..\HamnerOpt\')
    import rraTools.*   
    import org.opensim.modeling.*
    for t = 1:3 %config.trialnums
        
        mydir = pwd; % get current folder (where code is running from)
        cd('..\') % move up one folder
        % get system path to data folder
        trialpath = fullfile(pwd, 'HamnerOpt\subject01\',config.conditions{c},['Trial_' num2str(t)]);
        cd(mydir) % move back to code folder
        
        r = rrasetup(trialpath,config.participant,[],config.mass);
        r.fileset.kinfile = [config.conditions{c}, '_IK.mot'];
        r.fileset.grffile = [config.conditions{c}, '_GRF.mot'];
        r.toolsettings.kinfile = [config.conditions{c}, '_IK.mot'];

        %%
        r.writeTasksFile('Kp',1600,'UniformWeights',true)
        % write external loads file
        r.writeExtLoads()
        % write ReservesFile to match specified model
        r.writeReservesFile('ReserveForce',2000)
        %%
        r = r.runInitialRRA()
        %%
        r = r.runMassItrsRRA()
            
        %%
        r.optimizeTrackingWeights('min_itrs',100,'max_itrs',200,'fcn_threshold',1)
        rra_results{c,t} = r;
    end
end

save('RRA_results.mat','rra_results')
