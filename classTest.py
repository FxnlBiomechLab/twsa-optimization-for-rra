# %%
import reduceresiduals

       
trialpath = "C:/Users\Jordan\Documents\PhD\P3\SHO_46Kg\Lev\Trial_3" # full path to trial folder. must contain scaled model, and ik data
participant = "P3" # first part of the model name
condition = "SHO_46Kg" # second part of the model name
# model name is constructed as "participant_condition.osim"
mass = 75
rraopts = reduceresiduals.rrasetup( trialpath, participant, condition, mass)
# %% first pass at RRA
rraopts.initialRRA(createTasks = True, createReserves = True, createExtLoads = True)
# %% perform the mass adjustment iterations
rraopts.runMassItrsRRA()
# %% perform the tracking weight optimization
rraopts.optimizeTrackingWeights(mass = 75) # uses defaults. 
# optional inputs are "min_itrs", "max_itrs", "fcn_threshold", "wRes", "wErr", "pRes", "pErr"
        
# %%