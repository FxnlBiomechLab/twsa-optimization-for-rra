

# %% load the class
import reduceresiduals

# %% setup some variables
# update trial path to match where the test data is saved on your system       
trialpath = "C:/Users/Jordan/Documents/PhD/rra_tools/rra-optimization/HamnerOpt/subject01/Run_40002/Trial_1" # full path to trial folder. must contain scaled model, and ik data
participant = "Hamner2010_v4_subject01" # first part of the model name
condition = [] #empty for this test data, but is otherwise the second part of the model name constructed as "participant_condition.osim"

# %% initialize an instance of the class
rraopts = reduceresiduals.rrasetup( trialpath, participant, condition )

# view the code documentation for some of the methods
print(rraopts.initialRRA.__doc__)
print(rraopts.runMassItrsRRA.__doc__)
print(rraopts.optimizeTrackingWeights.__doc__)
# %% set properties need to be different from defaults
rraopts.fileset.kinfile = "Run_40002_IK.mot"
rraopts.fileset.grffile = "Run_40002_GRF.mot"
rraopts.toolsettings.kinfile = rraopts.fileset.kinfile

# %% first pass at RRA. Want to write clean tasks, reserves, and external loads specifications files 
rraopts.createTasksFile()
rraopts.createReservesFile()
rraopts.createExtLoads()
rraopts.initialRRA() # by default, does not overwrite tasks, reserves, or external loads files

# instead of creating tasks, reserves, and external loads by calling each method, you can set the inputs to "initialRRA" have this done with a single method call as in the commented line below
# rraopts.initialRRA(createTasks = True, createReserves = True, createExtLoads = True)

# %% perform the mass adjustment iterations
rraopts.runMassItrsRRA()

# %% run TWSA with defaults
rraopts.optimizeTrackingWeights()
