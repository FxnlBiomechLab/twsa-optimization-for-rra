%% import necessary classes
import rraTools.*   

% setup some values that we may want to iterate through
config.participant = 'Hamner2010_v4_subject01';
config.conditions = {'Run_20002','Run_30002','Run_40002','Run_50002'}
config.trialnums = 1:3

c = 1 % set condition for this example (Run_20002)
t = 1 % set trial nubmer for this example
%% Instantiate the rrasetup object
        
mydir = pwd; % get current folder (where code is running from)
cd('..\') % move up one folder
% get system path to data folder
trialpath = fullfile(pwd, 'HamnerOpt\subject01\',config.conditions{c},['Trial_' num2str(t)]);
cd(mydir) % move back to code folder

r = rrasetup(trialpath,config.participant,[]);
% update file names from defaults
r.fileset.kinfile = [config.conditions{c}, '_IK.mot'];
r.fileset.grffile = [config.conditions{c}, '_GRF.mot'];
r.toolsettings.kinfile = [config.conditions{c}, '_IK.mot'];

%% write tasks with user specified tracking weights
myWeights = {'ankle_angle_r','knee_angle_r','hip_flexion_r','ankle_angle_l','knee_angle_l','hip_flexion_l';...
    25,10,5,10,5,15}; % all other weights will be set to 1
r.writeTasksFile('Kp',1600,'UserWeights',myWeights) 
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

