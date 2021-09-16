# %%
import reduceresiduals

       
# update trial path to match where the test data is saved on your system       
trialpath = "C:/Users/Jordan/Documents/PhD/rra_tools/rra-optimization/HamnerOpt/subject01/Run_20002/Trial_1" # full path to trial folder. must contain scaled model, and ik data
participant = "Hamner2010_v4_subject01" # first part of the model name
condition = [] #empty for this test data, but is otherwise the second part of the model name constructed as "participant_condition.osim"
mass = 75 # probably not required. optimization function reads total mass from the model for normalizations.
rraopts = reduceresiduals.rrasetup( trialpath, participant, condition, mass)
# set properties different from defaults
rraopts.fileset.kinfile = "Run_20002_IK.mot"
rraopts.fileset.grffile = "Run_20002_GRF.mot"
rraopts.toolsettings.kinfile = rraopts.fileset.kinfile
# %% first pass at RRA
rraopts.initialRRA(createTasks = True, createReserves = True, createExtLoads = True)
# %% perform the mass adjustment iterations
rraopts.runMassItrsRRA()
# %% perform the tracking weight optimization
rraopts.optimizeTrackingWeights(mass = 75,min_itrs =200,max_itrs = 200,wRes = 1, wErr = 3, pRes = 3, pErr = 4)  # uses defaults. 
# optional inputs are "min_itrs", "max_itrs", "fcn_threshold", "wRes", "wErr", "pRes", "pErr"
        
# %%
